//
//  nativeViewController.swift
//  json练习
//
//  Created by 方瑾 on 2019/7/8.
//  Copyright © 2019 Houkin. All rights reserved.
//

import Foundation
import WebKit

internal class NativeMethods: NSObject,WKScriptMessageHandler {
    var viewController:FirstPayViewController
    var apiClient: ApiClient
    let apStorageManager: APStorageManager
    
    init(viewController:FirstViewController, apiClient:ApiClient, apStorageManager:APStorageManager) {
        self.viewController = viewController
        self.apiClient = apiClient
        self.apStorageManager = apStorageManager
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let nativeCaller:NativeCaller = try? JsonUtil.mapToObjectFromJson(data: (message.body as! String).data(using: .utf8)!){
            switch nativeCaller.method {
            case .increaseBrightness:
                LogUtil.log("JavascriptInterface: increaseBrightness")
                if let param : ParamIncreaseBrightness = try? JsonUtil.mapToObjectFromJson(data: nativeCaller.params!.data(using: .utf8)!){
                    viewController.brightControllable.increaseBrightness(durationMilliSec: param.durationMilliSec)
                }
            case .showCardRegister:
                LogUtil.log("JavascriptInterface: closeWebView")
                DispatchQueue.main.async {
                    self.viewController.dismiss(animated: true, completion: nil)
                }
            case .closeWebView:
                LogUtil.log("JavascriptInterface: closeWebView")
                DispatchQueue.main.async {
                    self.viewController.dismiss(animated: true, completion: nil)
                }
            case .logging:
                LogUtil.log("JavaScriptLog: \(nativeCaller.params ?? "")")
            }
        }
        else{
            LogUtil.log("javascript cooperation error. call unknown method name")
        }
    }
    
    /**
     javasciprtのコールバックメソッドを実行する
     
     - parameter callback: javascriptのコールバック文字列
     - parameter paramJson: コールバックに渡すjson形式の引数
     - parameter callbackObjectKey: javascript側で採番されるコールバックオブジェクト番号（javascript連携呼び出し時に受けたものをそのまま設定する）
     */
    private func executeCallback(callback: String?, paramJson: String?, callbackObjectKey: String?){
        if let callback = callback{
            let ObjectKey = callbackObjectKey != nil ? "'"+callbackObjectKey!+"',": ""
            let arg: String = paramJson != nil ? "'"+paramJson!+"'" : ""
            
            DispatchQueue.main.async {
                self.viewController.webView!.evaluateJavaScript(
                    "var callback = "+callback+";callback("+ObjectKey + arg+");", completionHandler: { (object, error) -> Void in
                        LogUtil.log("evaluateJavaScript complete with error="+error.debugDescription)
                })
            }
        }
    }
    
}
