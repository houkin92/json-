

import Foundation

/**
 API通信を行うクライアントクラス
 */
internal class ApiClient{
    let apiKeyHeader: ApiKeyHeader
    private let apStorageManager:APStorageManager
    
    /**
     コンストラクタ
     
     - parameter apiKeyHeader : ApiKeyHeaderクラス
     - parameter wpTokenManager : WPTokenManagerクラス
     */
    init(apiKeyHeader:ApiKeyHeader, apStorageManager:APStorageManager){
        self.apiKeyHeader = apiKeyHeader
        self.apStorageManager = apStorageManager
    }
    
    /**
     APIリクエスト
     
     - parameter apApiRequest : リクエストオブジェクト
     */
    func fetch(_ apApiRequest: ApApiRequest){
        guard let urlRequest = self.createURLRequest(by: apApiRequest) else {
            return
        }
        LogUtil.log("API request URL: \(urlRequest)")
        let task = URLSession.shared.dataTask(with: urlRequest) { [weak self] (data, urlResponse, error) in
            guard let weakSelf = self else {
                apApiRequest.callback.onFailure(message: "error occured while api request.")
                return
            }
            let output = weakSelf.createOutput(
                data: data,
                urlResponse: urlResponse as? HTTPURLResponse,
                error: error
            )
            switch output {
            case .noResponse:
                apApiRequest.callback.onFailure(message: "no api response.")
            case let .hasResponse(response, data):
                do{
                    try weakSelf.callCallback(response: response, payload: data, type: apApiRequest.type, callback: apApiRequest.callback)
                }catch{
                    // トークン取得後のAPI 再実行
                    LogUtil.log("retry api request")
                    weakSelf.retryRequest(originalRequest: apApiRequest)
                }
            }
        }
        task.resume()
    }
    
    private func createURLRequest(by input: ApApiRequest) -> URLRequest? {
        guard var components = URLComponents.init(string: input.urlString) else{
            input.callback.onFailure(message: "can't resolve url.")
            return nil
        }
        components.queryItems = input.params
        //APIにおいて一時的にキャッシュ無視するように変更
        //var request = URLRequest(url: (components.url)!, timeoutInterval:70)
        var request = URLRequest(url: (components.url)!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval:70)
        var header = input.header
        header["Content-Type"] = "application/json"
        header[ConstString.appKey] = ConstString.appKeyValue
        if(!input.nonApiKeyHeaderFlag){
            header[ConstString.appKey] = apiKeyHeader.hardwearId
        }
        
        //認証が必要な場合
        if(!input.nonAuthHeaderFlag){
            guard let authHeaderValue = makeAuthorizaionHeader() else{
                input.callback.onFailure(message: "can't load saved credentials.")
                return nil
            }
            header[ConstString.authKey] = authHeaderValue
        }
        
        request.allHTTPHeaderFields = header
        request.httpMethod = input.methodAndPayload.method
        request.httpBody = input.methodAndPayload.payload
        request.httpShouldHandleCookies = true
        return request
    }
    
    /**
     アクセストークンの再発行を行う
     */
    func refreshAccessToken(callback: TokenReIssueCallback){
        LogUtil.log("refreshAccessToken")
        if let credential = apStorageManager.loadCredential(), let refreshToken = credential.refreshToken{
            let requestBody = "refresh_token=\(refreshToken)".data(using: .utf8)
            self.fetch(ApApiRequest
                .Builder(urlString: ConstString.apiGetReflash, resultType: ApApiRequest.ResultType.apiGetReflash, callback:callback)
                .methodAndPayload(ApApiRequest.MethodAndPayload.post(body: requestBody))
                .nonApiKeyHeader(true)
                .nonAuthHeader(true)
                .build())
        }
        else{
            callback.onTokenValidationFailure(message: "")
        }
    }
    
    /**
     トークンのリフレッシュを行なった上でAPIリクエストをリトライする
     */
    private func retryRequest(originalRequest: ApApiRequest){
        let callback = TokenReIssueCallback(apStorageManager: apStorageManager,successMethod: {refreshedCredential in
            self.fetch(originalRequest)
        }, failureMethod: {
            originalRequest.callback.onFailure(message: "can't refresh accessToken.")
        }, refreshTokenExpiredMethod: {
            originalRequest.callback.onFailure(message: "invalid refreshToken.")
        })
        refreshAccessToken(callback: callback)
    }
    
    // 永続化されたアクセストークンを取得しヘッダー付与用のディクショナリにして返す
    private func makeAuthorizaionHeader() -> String?{
        //base64に暗号化する
        if let accessToken = apStorageManager.loadCredential()?.accessToken{
            LogUtil.log("acess token: \(accessToken)")
            let base64EncodedData = accessToken.data(using: .utf8)
            let token = base64EncodedData?.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
            
            let result = "Bearer \(token ?? "")"
            LogUtil.log("acess token: \(result)")
            return result
        }else{
            return nil
        }
    }
    
    private func callCallback(response:HTTPURLResponse, payload:Data, type:ApApiRequest.ResultType, callback: ApiRequestDelegate) throws{
        LogUtil.log("API response  code: \(response.statusCode)")
        switch response.statusCode {
        case 200:
            callSuccessCallback(payload: payload, type: type, callback: callback)
        case 400:
            callback.onFailure(message: "error code \(response.statusCode)")
        case 401: //unauthorized
            throw UnAuthorizedError()
        case 404:
            callback.onFailure(message: "error code \(response.statusCode)")
        default:
            callback.onFailure(message:"error code \(response.statusCode)")
        }
    }
    
    private func callSuccessCallback(payload:Data, type:ApApiRequest.ResultType, callback: ApiRequestDelegate){
        do{
            switch type{
            case ApApiRequest.ResultType.apiPostDevice:
                let deviceId:DeviceId = try JsonUtil.mapToObjectFromJson(data: payload)
                callback.onSuccess(result: deviceId)
            case ApApiRequest.ResultType.apiGetBarcode:
                let oneTimeCode:OneTimeCode = try JsonUtil.mapToObjectFromJson(data: payload)
                callback.onSuccess(result: oneTimeCode)
            case ApApiRequest.ResultType.apiGetSettlement:
                let settlement:Settlement = try JsonUtil.mapToObjectFromJson(data: payload)
                callback.onSuccess(result: settlement)
            case ApApiRequest.ResultType.apiGetSettlements:
                let settlements:Settlements = try JsonUtil.mapToObjectFromJson(data: payload)
                callback.onSuccess(result: settlements)
            case ApApiRequest.ResultType.apiGetCustomer:
                let customer:Customer = try JsonUtil.mapToObjectFromJson(data: payload)
                callback.onSuccess(result: customer)
            case ApApiRequest.ResultType.apiPostCreditCardAuth:
                callback.onSuccess(result: "success")
            case ApApiRequest.ResultType.apiGetReflash:
                let xAuthenticationTokens:XAuthenticationTokens = try JsonUtil.mapToObjectFromJson(data: payload)
                callback.onSuccess(result: xAuthenticationTokens)
            case ApApiRequest.ResultType.apiPostCreditCard:
                callback.onSuccess(result: "success")
            case ApApiRequest.ResultType.apiPostLogout:
                callback.onSuccess(result: "success")
            case ApApiRequest.ResultType.apiGetVersionCheck:
                let versionCheck:VersionCheck = try JsonUtil.mapToObjectFromJson(data: payload)
                callback.onSuccess(result: versionCheck)
            case ApApiRequest.ResultType.apiGetEncryption:
                callback.onSuccess(result: "success")
            }
        }catch{
            callback.onFailure(message: "json mapping failure. payload: \(payload.description)")
        }
    }
    
    enum Output {
        case hasResponse(HTTPURLResponse,Data)
        case noResponse
    }
    
    private func createOutput(
        data: Data?,
        urlResponse: HTTPURLResponse?,
        error: Error?
        ) -> Output {
        
        if let data = data, let response = urlResponse{
            return .hasResponse(response, data)
        }
        return .noResponse
    }
    
    class UnAuthorizedError: Error{}
    
}


