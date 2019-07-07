//
//  ApiKeyHeader.swift
//  json练习
//
//  Created by 方瑾 on 2019/7/8.
//  Copyright © 2019 Houkin. All rights reserved.
//

import Foundation

/**
 当SDKの独自ヘッダであるX-WP-API-KEYの生成などを行うクラス
 */
internal class ApiKeyHeader{
    let hardwearId: String
    let apStorageManager: APStorageManager
    
    /**
     コンストラクタ
     
     - parameter hardwearId : ハードウェアID
     */
    init(hardwearId:String, apStorageManager: APStorageManager) {
        self.hardwearId = hardwearId
        self.apStorageManager = apStorageManager
    }
    
    /**
     ディクショナリーでX-APPLICATION-KEYを生成
     
     - returns : ディクショナリー型のX-APPLICATION-KEYヘッダ
     */
    func getApplicationKey() -> [String:String]{
        return [ConstString.appKey :hardwearId]
    }
    
    
}
