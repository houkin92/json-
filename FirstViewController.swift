//
//  FirstViewController.swift
//  json练习
//
//  Created by 方瑾 on 2019/7/8.
//  Copyright © 2019 Houkin. All rights reserved.
//

/**
 画面輝度の調整（輝度を最大化し、一定時間後に戻す処理）を行うクラス
 */
internal class BrightControllable{
    var originBrightness: CGFloat?
    var brighteningTimer: Timer?
    
    /**
     輝度を元に戻すタイマーをスタートする
     */
    private func startBrightnessTimer(durationMilliSec: Double){
        let durationSec:Double = durationMilliSec*0.001
        self.brighteningTimer = Timer.scheduledTimer(timeInterval: durationSec, target:self, selector: #selector(BrightControllable.resetBrightness), userInfo: nil, repeats: false)
    }
    
    /**
     輝度を最大化し、輝度を元に戻すタイマーをスタートする
     
     - parameter durationMilliSec : 輝度を最大にしておく持続時間（単位はミリ秒）
     */
    func increaseBrightness(durationMilliSec: Double){
        if stopBrightnessTimer() == false{
            originBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
        }
        startBrightnessTimer(durationMilliSec: durationMilliSec)
    }
    
    /**
     輝度を元に戻す
     */
    @objc func resetBrightness(){
        _ = stopBrightnessTimer()
        
        if originBrightness != nil{
            UIScreen.main.brightness = originBrightness!
            originBrightness = nil
        }
    }
    
    /**
     輝度を元に戻すタイマーを停止する
     */
    private func stopBrightnessTimer() ->Bool{
        var isProcessing = false
        if brighteningTimer != nil && brighteningTimer!.isValid{
            brighteningTimer!.invalidate()
            isProcessing = true
        }
        return isProcessing
    }
}
