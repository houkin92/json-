//
//  JsonObject.swift
//  json练习
//
//  Created by 方瑾 on 2019/7/8.
//  Copyright © 2019 Houkin. All rights reserved.
//

*  JSON から初期化可能な型が準拠すべき protocol
*/
internal protocol JSONDecodable {
    init(json: JSONObject) throws
}

/**
 JSON から値を得ようとしたときに期待するものと違ったら出力されるエラー
 - MissingRequiredKey:   必要なキーが存在しない
 - UnexpectedType:       値が期待する型ではない
 - UnexpectedValue:      値が期待するようなものではない
 */
internal enum JSONDecodeError: Error, CustomDebugStringConvertible {
    case missingRequiredKey(String)
    case unexpectedType(key: String, expected: Any.Type, actual: Any.Type)
    case unexpectedValue(key: String, value: Any, message: String?)
    
    var debugDescription: String {
        switch self {
        case .missingRequiredKey(let key):
            return "JSON Decode Error: Required key '\(key)' missing"
        case let .unexpectedType(key: key, expected: expected, actual: actual):
            return "JSON Decode Error: Unexpected type '\(actual)' was supplied for '\(key): \(expected)'"
        case let .unexpectedValue(key: key, value: value, message: message):
            return "JSON Decode Error: \(message ?? "Unexpected value") '\(value)' was supplied for '\(key)"
        }
    }
}

/**
 *  JSON の値を変換する型
 */
internal protocol JSONValueConverter {
    associatedtype FromType
    associatedtype ToType
    
    func convert(key: String, value: FromType) throws -> ToType
}

/**
 *  変換しない
 */
internal struct DefaultConverter<T>: JSONValueConverter {
    typealias FromType = T
    typealias ToType = T
    
    func convert(key: String, value: FromType) -> DefaultConverter.ToType {
        return value
    }
}

/**
 *  JSON のオブジェクトを何らかの JSONDecodable な型に変換する
 */
internal struct ObjectConverter<T: JSONDecodable>: JSONValueConverter {
    typealias FromType = [String: Any]
    typealias ToType = T
    
    func convert(key: String, value: FromType) throws -> ObjectConverter.ToType {
        return try T(json: JSONObject(json: value))
    }
}

/**
 *  JSON の配列を何らかの JSONDecodable な型の配列に変換する
 */
internal struct ArrayConverter<T: JSONDecodable>: JSONValueConverter {
    typealias FromType = [[String: Any]]
    typealias ToType = [T]
    
    func convert(key: String, value: FromType) throws -> ArrayConverter.ToType {
        return try value.map(JSONObject.init).map(T.init)
    }
}

/**
 *  JSON のプリミティブな値
 */
internal protocol JSONPrimitive {}

extension String: JSONPrimitive {}
extension Int: JSONPrimitive {}
extension Double: JSONPrimitive {}
extension Bool: JSONPrimitive {}

/**
 *  JSONValueConverter を利用して変換されることができる型
 */
internal protocol JSONConvertible {
    associatedtype ConverterType: JSONValueConverter
    static var converter: ConverterType { get }
}

/**
 *  JSON のオブジェクトから何らかの型の値を得るためのラップオブジェクト
 *  `get(_:)` のオーバーロードによって適切なメソッドが選択される
 */
internal struct JSONObject {
    
    /// 元の JSON オブジェクトの Dictionary
    let json: [String: Any]
    
    init(json: [String: Any]) {
        self.json = json
    }
    
    func get<Converter: JSONValueConverter>(_ key: String, converter: Converter) throws -> Converter.ToType {
        guard let value = json[key] else {
            throw JSONDecodeError.missingRequiredKey(key)
        }
        guard let typedValue = value as? Converter.FromType else {
            throw JSONDecodeError.unexpectedType(key: key, expected: Converter.FromType.self, actual: type(of: value))
        }
        return try converter.convert(key: key, value: typedValue)
    }
    
    func get<Converter: JSONValueConverter>(_ key: String, converter: Converter) throws -> Converter.ToType? {
        guard let value = json[key] else {
            return nil
        }
        if value is NSNull {
            return nil
        }
        guard let typedValue = value as? Converter.FromType else {
            throw JSONDecodeError.unexpectedType(key: key, expected: Converter.FromType.self, actual: type(of: value))
        }
        return try converter.convert(key: key, value: typedValue)
    }
    
    func get<T: JSONPrimitive>(_ key: String) throws -> T {
        return try get(key, converter: DefaultConverter())
    }
    
    func get<T: JSONPrimitive>(_ key: String) throws -> T? {
        return try get(key, converter: DefaultConverter())
    }
    
    func get<T: JSONConvertible>(_ key: String) throws -> T where T == T.ConverterType.ToType {
        return try get(key, converter: T.converter)
    }
    
    func get<T: JSONConvertible>(_ key: String) throws -> T? where T == T.ConverterType.ToType {
        return try get(key, converter: T.converter)
    }
    
    func get<T: JSONDecodable>(_ key: String) throws -> T {
        return try get(key, converter: ObjectConverter())
    }
    
    func get<T: JSONDecodable>(_ key: String) throws -> T? {
        return try get(key, converter: ObjectConverter())
    }
    
    func get<T: JSONDecodable>(_ key: String) throws -> [T] {
        return try get(key, converter: ArrayConverter())
    }
    
    func get<T: JSONDecodable>(_ key: String) throws -> [T]? {
        return try get(key, converter: ArrayConverter())
    }
    
}

// MARK: - Foundation 向け拡張
// URL や Date を作れるようにする
import Foundation

extension URL: JSONConvertible {
    typealias ConverterType = URLConverter
    static var converter: ConverterType {
        return URLConverter()
    }
}

extension Date: JSONConvertible {
    typealias ConverterType = DateConverter
    static var converter: ConverterType {
        return DateConverter()
    }
}

internal struct URLConverter: JSONValueConverter {
    typealias FromType = String
    typealias ToType = URL
    
    func convert(key: String, value: FromType) throws -> URLConverter.ToType {
        guard let URL = URL(string: value) else {
            throw JSONDecodeError.unexpectedValue(key: key, value: value, message: "Invalid URL")
        }
        return URL
    }
}

internal struct DateConverter: JSONValueConverter {
    typealias FromType = TimeInterval
    typealias ToType = Date
    
    func convert(key: String, value: FromType) -> DateConverter.ToType {
        return Date(timeIntervalSince1970: value)
    }
}

