//
//  ApApiRequest.swift
//  json练习
//
//  Created by 方瑾 on 2019/7/8.
//  Copyright © 2019 Houkin. All rights reserved.
//


APIリクエスト。ビルダーを使ってインスタンス化できる
*/
internal class ApApiRequest{
    let urlString: String
    var params: [URLQueryItem]
    var header: [String: String]
    let methodAndPayload: MethodAndPayload
    let type:ResultType
    let callback: ApiRequestDelegate
    let nonApiKeyHeaderFlag: Bool
    let nonAuthHeaderFlag: Bool
    
    /**
     認証ヘッダー（アクセストークンなど）なしのAPIリクエスト
     
     - parameter urlString : リクエストURL
     - parameter params : クエリパラメータ
     - parameter headers : リクエストヘッダー
     - parameter methodAndPayload : HTTPメソッド
     - parameter type : レスポンスに期待する型のタイプ
     - parameter callback : コールバック
     - parameter nonApiKeyHeaderFlag : X-WP-API-KEY-HEADERの要否
     - parameter nonAuthHeaderFlag : Authorizationヘッダーの要否
     */
    init(urlString: String,
         params: [URLQueryItem],
         header: [String: String],
         methodAndPayload: MethodAndPayload,
         type:ResultType,
         callback: ApiRequestDelegate,
         nonApiKeyHeaderFlag: Bool = false,
         nonAuthHeaderFlag: Bool = false){
        self.urlString = urlString
        self.params = params
        self.header = header
        self.methodAndPayload = methodAndPayload
        self.type = type
        self.callback = callback
        self.nonApiKeyHeaderFlag = nonApiKeyHeaderFlag
        self.nonAuthHeaderFlag = nonAuthHeaderFlag
    }
    
    func builder() -> Builder{
        return Builder(urlString: urlString, resultType: type, callback: callback)
            .header(header)
            .methodAndPayload(methodAndPayload)
            .nonApiKeyHeader(nonApiKeyHeaderFlag)
            .nonAuthHeader(nonAuthHeaderFlag)
    }
    
    class Builder{
        private let urlString: String
        private var params: [URLQueryItem] = []
        private var header: [String: String] = [:]
        private var methodAndPayload: MethodAndPayload = .get
        private let type: ResultType
        private let callback: ApiRequestDelegate
        private var nonApiKeyHeaderFlag: Bool = false
        private var nonAuthHeaderFlag: Bool = false
        
        init(urlString: String, resultType: ResultType, callback: ApiRequestDelegate){
            self.urlString = urlString
            self.type = resultType
            self.callback = callback
        }
        
        func queryParameter(_ params: [URLQueryItem]) -> Builder{
            self.params = params
            return self
        }
        
        func header(_ header: [String: String]) -> Builder{
            self.header = header
            return self
        }
        
        func methodAndPayload(_ methodAndPayload: MethodAndPayload) -> Builder{
            self.methodAndPayload = methodAndPayload
            return self
        }
        
        func nonApiKeyHeader(_ nonApiKeyHeaderFlag: Bool) -> Builder{
            self.nonApiKeyHeaderFlag = nonApiKeyHeaderFlag
            return self
        }
        
        func nonAuthHeader(_ nonAuthHeaderFlag: Bool) -> Builder{
            self.nonAuthHeaderFlag = nonAuthHeaderFlag
            return self
        }
        
        func build() -> ApApiRequest{
            return ApApiRequest(urlString: urlString,
                                params: params,
                                header: header,
                                methodAndPayload: methodAndPayload,
                                type: type,
                                callback: callback,
                                nonApiKeyHeaderFlag: nonApiKeyHeaderFlag,
                                nonAuthHeaderFlag: nonAuthHeaderFlag)
        }
    }
    
    enum MethodAndPayload {
        case get
        case post(body: Data?)
        var method: String {
            switch self {
            case .get:
                return "GET"
            case .post:
                return "POST"
            }
        }
        var payload: Data? {
            switch self {
            case .get:
                return nil
            case .post(let payload):
                return payload
            }
        }
    }
    
    enum ResultType{
        case apiGetVersionCheck
        case apiPostDevice
        case apiGetBarcode
        case apiGetSettlement
        case apiGetSettlements
        case apiPostLogout
        case apiGetCustomer
        case apiPostCreditCard
        case apiPostCreditCardAuth
        case apiGetEncryption
        case apiGetReflash
    }
}
