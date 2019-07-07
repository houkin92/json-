//
//  ViewController.swift
//  json练习
//
//  Created by 方瑾 on 2019/7/7.
//  Copyright © 2019 Houkin. All rights reserved.
//

import UIKit
import WebKit

extension WKProcessPool {
    static let shared = WKProcessPool()
}

/**
 認証やネイティブ連varの機能を持ったViewvartroller
 */
internal class NewViewController: UIViewController, WKNavigationDelegate, UIScrollViewDelegate{
    var brightControllable: BrightControllable!
    var codeVerifier: String = ""
    var requestedUrl: String? = nil
    var currentUrl: String!
    var callback: PageEventDelegate!
    var apiClient: ApiClient!
    var webView: WKWebView!
    var aeonPayMemberId: String?  = nil
    var doc: UIDocumentInteractionController? = nil
    var apStorageManager: APStorageManager!
    var clientId: String!
    var userScript: WKUserScript? = nil
    
    @IBOutlet weak var webViewContainer: UIView!
    
    /**
     WebView画面を表示する。認証画面以外を表示する際に使用する
     - parameter urlStr : 表示する画面のURL
     - parameter callback : ページイベントデリゲート
     - parameter apiClient : APIクライアント
     - parameter params : クエリパラメータ
     - parameter apStorageManager : 認証トークン管理クラス
     */
    func loadWebView(urlStr:String,
                     callback:PageEventDelegate,
                     apiClient:ApiClient,
                     params:[URLQueryItem]?=nil,
                     apStorageManager: APStorageManager
        ){
        self.callback = callback
        self.apiClient = apiClient
        self.apStorageManager = apStorageManager
        setupViewController()
        self.loadPage(urlStr: urlStr, params:params)
    }
    
   // 認証が必要な画面はないので削除予定
    /**
     認証画面を表示する。APP利用可否判定APIを叩いてから、利用規約画面をリクエストする
     - parameter callback : ページイベントデリゲート
     - parameter apiClient : APIクライアント
     - parameter requestedUrl : クエリパラメータ
     - parameter apStorageManager : 認証トークン管理クラス
     */
    func loadAuthenticationView(callback:PageEventDelegate,
                                apiClient:ApiClient,
                                requestedUrl:String? = nil,
                                apStorageManager:APStorageManager){
        self.callback = callback
        self.apiClient = apiClient
        self.requestedUrl = requestedUrl
        self.apStorageManager = apStorageManager
        setupViewController()
        
        apiClient.fetch(
            
            ApApiRequest.Builder(
                urlString: ConstString.appCheck,
                resultType: ApApiRequest.ResultType.appCheck,
                callback: AppCheckCallback(
                    apViewController: self,
                    apStorageManager: apStorageManager
            ))
                .nonAuthHeader(true)
                .build())
    }
    
    /**
     WebViewにページを読み込む
     
     - parameter urlStr: 読み込むページのURL
     - parameter params: クエリパラメータ
     */
    internal func loadPage(urlStr: String, params:[URLQueryItem]?=nil){
        let url = URL(string: urlStr)!
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: nil != url.baseURL)!
        if let params = params {
            urlComponents.queryItems = params
        }
        loadPage(request: URLRequest(url: urlComponents.url!))
    }
    
    /**
     WebViewにページを読み込む
     
     - parameter request: 読み込むページのURLリクエスト
     */
    internal func loadPage(request:URLRequest){
        currentUrl = request.url?.absoluteString
        var request = request
        request.httpShouldHandleCookies = true
        
        var apiClientCookie: String = ""
        let apiCookies = HTTPCookieStorage.shared.cookies ?? []
        var apiCookieList:[String] = []
        apiCookies.forEach { c in
            apiCookies .forEach { c in apiCookieList.append("\(c.name)=\(c.value)") }
        }
        apiClientCookie = apiCookieList.joined(separator: ";")
        
        var webviewCookie: String = ""
        if let webviewCookieField = request.value(forHTTPHeaderField: "Cookie"){
            webviewCookie = ";\(webviewCookieField)"
        }
        let joinedCookie = apiClientCookie + webviewCookie
        
        request.allHTTPHeaderFields = ["Cookie": joinedCookie, ConstString.appKey: apiClient.apiKeyHeader.hardwearId]
        webView.load(request)
        
    }
    
    /**
     WebViewの設定を行う。具体的にはjavaScriptInterfaceの設定、WebViewのイベントデリゲートの登録、レイアウトの設定、Cookie引継ぎを行う
     */
    func setupViewController(){
        setupWebView()
    }
    
    func setupWebView(){
        let scriptMessageHandler = NativeMethods(viewController: self, apiClient: apiClient, apStorageManager: apStorageManager)
        let webCfg: WKWebViewConfiguration = WKWebViewConfiguration()
        let userController: WKUserContentController = WKUserContentController()
        brightControllable = BrightControllable()
        userController.add(scriptMessageHandler, name: "native")
        webCfg.userContentController = userController
        
        webView = WKWebView(frame: self.view.subviews[0].bounds, configuration: webCfg)
        webView.navigationDelegate = self
        webView.scrollView.delegate = self
        webView.allowsLinkPreview = false
        
        if(userScript != nil){
            userController.addUserScript(userScript!)
        }
        
        let subviews = webViewContainer.subviews
        for subview in subviews{
            subview.removeFromSuperview()
        }
        webViewContainer.addSubview(webView)
    }
    
    /**
     SDKに内包するオフラインエラー画面をWebViewに読み込む
     */
    internal func showOfflineError(){
        showInternalHtml(name: "offline")
    }
    
    /**
     SDKに内包するその他エラー画面をWebViewに読み込む
     */
    internal func showUnknownError(){
        showInternalHtml(name: "unknown")
    }
    
    private func showInternalHtml(name: String){
        if let path = Bundle(for: AeonPayViewController.self).path(forResource: name, ofType: "html") {
            let offlineURL = URL(fileURLWithPath: path)
            DispatchQueue.main.async{
                self.webView.loadFileURL(offlineURL, allowingReadAccessTo: offlineURL)
            }
        } else {
            callback.onFailure(message: "can't load offline error page.")
            dismiss(animated: true, completion: nil)
        }
    }
    
    /**
     WebViewを閉じる。
     */
    internal func closeWebView(){
        DispatchQueue.main.async{
            self.dismiss(animated: true)
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        if let urlStr = navigationAction.request.url?.absoluteString{
            LogUtil.log("WebView load url: \(urlStr)")
        }
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let code = (error as NSError).code
        LogUtil.log("WebView didFailProvisionalNavigation  code:\(code)")
        // -1001:TimedOut -1003:CannotFindHost -1004:CannotConnectToHost -1009:NotConnectedToInternet
        if(code == -1001 || code == -1003 || code == -1004 || code == -1009){
            brightControllable.resetBrightness()
            showOfflineError()
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler:
        @escaping(WKNavigationResponsePolicy) -> Void){
        
        if(navigationResponse.response .isKind(of: HTTPURLResponse.self)){
            let response = navigationResponse.response as! HTTPURLResponse
            
            LogUtil.log("WebView NavigationResponse HTTP Status Code: "+String(response.statusCode))
            switch(response.statusCode){
            case 200:
                break
            case 403:
                decisionHandler(.cancel)
                showUnknownError()
                return
            case 404:
                if(response.expectedContentLength < 100){
                    decisionHandler(.cancel)
                    showOfflineError()
                    return
                }
            default: break
                
            }
            
            //レスポンスヘッダに認証情報がある場合は保存する
            LogUtil.log("check X-API-AUTHENTICATION-TOKENS TOKENS")
            if(response.allHeaderFields["X-API-AUTHENTICATION-TOKENS"] != nil){
                LogUtil.log("Look X-API-AUTHENTICATION-TOKENS TOKENS")
                let tokens = response.allHeaderFields["X-API-AUTHENTICATION-TOKENS"] ?? ""
                LogUtil.log("get tokens=\(tokens)")
                
                //base64デコード
                let base64EncodedString = tokens as! String
                let data = Data(base64Encoded: base64EncodedString, options: Data.Base64DecodingOptions(rawValue: 0))
                let token = String(data: data!, encoding: .utf8)!
                LogUtil.log("get token=\(token)")
                
                if let xAuthenticationTokens:XAuthenticationTokens = try? JsonUtil.mapToObjectFromJson(data: token.data(using: .utf8)!) {
                    LogUtil.log("access token=\(xAuthenticationTokens.accessToken.token)")
                    //トークンをKeyChainに保存する
                    LogUtil.log("loadCredential start")
                    let loadCredential = apStorageManager.loadCredential()
                    LogUtil.log("loadCredential end")
                    if loadCredential != nil {
                        LogUtil.log("update keyChain")
                        let credential: Credential = Credential(accessToken: xAuthenticationTokens.accessToken.token, refreshToken: xAuthenticationTokens.refreshToken.token, smartPhoneManagementId: loadCredential!.smartPhoneManagementId)
                        apStorageManager.saveCredential(credential: credential)
                    } else {
                        LogUtil.log("create keyChain")
                        let credential: Credential = Credential(accessToken: xAuthenticationTokens.accessToken.token, refreshToken: xAuthenticationTokens.refreshToken.token, smartPhoneManagementId: "")
                        apStorageManager.saveCredential(credential: credential)
                    }
                } else {
                    LogUtil.log("mapping error")
                }
            }
            
        }
        decisionHandler(.allow)
    }
    
    @available(iOS 10.0, *)
    func webView(_ webView: WKWebView, shouldPreviewElement elementInfo: WKPreviewElementInfo) -> Bool {
        return false
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return nil
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        DispatchQueue.main.async {
            self.brightControllable.resetBrightness()
        }
        super.viewWillDisappear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        callback!.onPageClosed()
        NotificationCenter.default.removeObserver(self)
    }
    
    override var shouldAutorotate: Bool{
        get{
            return false
        }
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask{
        get{
            return .portrait
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        webView.frame = webViewContainer.bounds
        webView.bounds = webViewContainer.bounds
    }
    
    deinit {
        webView.navigationDelegate = nil
        webView.scrollView.delegate = nil
    }
    
    @objc private func applicationWillResignActive() {
        self.brightControllable.resetBrightness()
    }
    
}





