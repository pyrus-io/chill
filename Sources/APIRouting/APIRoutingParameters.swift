import Foundation
import Vapor

public extension Parameters {
    func decode<T: Decodable>(_ decodable: T.Type) throws -> T {
        return try T(from: VaporParameterDecoder(parameters: self))
    }
}

public struct VaporParameterDecoder: Decoder {
    
    public enum ParameterDecoderError: Error {
        case unexpectedContainerTypeShouldUserKeyedDecodingOnly
    }
    
    public var codingPath: [CodingKey] = []
    public var userInfo: [CodingUserInfoKey : Any] = [:]
    
    public var parameters: Parameters
    
    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        return KeyedDecodingContainer<Key>(VaporParametersDecodingContainer(parameters: parameters))
    }
    
    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw ParameterDecoderError.unexpectedContainerTypeShouldUserKeyedDecodingOnly
    }
    
    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        throw ParameterDecoderError.unexpectedContainerTypeShouldUserKeyedDecodingOnly
    }
    
}

public struct VaporParametersDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    
    public enum ParameterDecoderContainerError: Error {
        case notFound(K)
        case cantDecodeParametersToNonStandardType(String)
        case noNesting
    }
    
    public typealias Key = K
    
    public var codingPath: [CodingKey] = []
    
    public var allKeys: [K] {
        return []
    }
    
    public var parameters: Parameters
    
    public init(parameters: Parameters) {
        self.parameters = parameters
    }
    
    public func contains(_ key: K) -> Bool {
        parameters.get(key.stringValue) != nil
    }
    
    public func decodeNil(forKey key: K) throws -> Bool {
        parameters.get(key.stringValue) == nil
    }
    
    public func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
        guard let val = parameters.get(key.stringValue, as: type) else {
            throw ParameterDecoderContainerError.notFound(key)
        }
        return val
    }
    
    public func decode(_ type: String.Type, forKey key: K) throws -> String {
        guard let val = parameters.get(key.stringValue, as: type) else {
            throw ParameterDecoderContainerError.notFound(key)
        }
        return val
    }
    
    public func decode(_ type: Double.Type, forKey key: K) throws -> Double {
        guard let val = parameters.get(key.stringValue, as: type) else {
            throw ParameterDecoderContainerError.notFound(key)
        }
        return val
    }
    
    public func decode(_ type: Float.Type, forKey key: K) throws -> Float {
        guard let val = parameters.get(key.stringValue, as: type) else {
            throw ParameterDecoderContainerError.notFound(key)
        }
        return val
    }
    
    public func decode(_ type: Int.Type, forKey key: K) throws -> Int {
        guard let val = parameters.get(key.stringValue, as: type) else {
            throw ParameterDecoderContainerError.notFound(key)
        }
        return val
    }
    
    public func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 {
        guard let val = parameters.get(key.stringValue, as: type) else {
            throw ParameterDecoderContainerError.notFound(key)
        }
        return val
    }
    
    public func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 {
        guard let val = parameters.get(key.stringValue, as: type) else {
            throw ParameterDecoderContainerError.notFound(key)
        }
        return val
    }
    
    public func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 {
        guard let val = parameters.get(key.stringValue, as: type) else {
            throw ParameterDecoderContainerError.notFound(key)
        }
        return val
    }
    
    public func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 {
        guard let val = parameters.get(key.stringValue, as: type) else {
            throw ParameterDecoderContainerError.notFound(key)
        }
        return val
    }
    
    public func decode(_ type: UInt.Type, forKey key: K) throws -> UInt {
        guard let val = parameters.get(key.stringValue, as: type) else {
            throw ParameterDecoderContainerError.notFound(key)
        }
        return val
    }
    
    public func decode(_ type: UInt8.Type, forKey key: K) throws -> UInt8 {
        guard let val = parameters.get(key.stringValue, as: type) else {
            throw ParameterDecoderContainerError.notFound(key)
        }
        return val
    }
    
    public func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 {
        guard let val = parameters.get(key.stringValue, as: type) else {
            throw ParameterDecoderContainerError.notFound(key)
        }
        return val
    }
    
    public func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 {
        guard let val = parameters.get(key.stringValue, as: type) else {
            throw ParameterDecoderContainerError.notFound(key)
        }
        return val
    }
    
    public func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 {
        guard let val = parameters.get(key.stringValue, as: type) else {
            throw ParameterDecoderContainerError.notFound(key)
        }
        return val
    }
    
    public func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T : Decodable {
        throw ParameterDecoderContainerError.cantDecodeParametersToNonStandardType(String(describing: T.self))
    }
    
    public func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        throw ParameterDecoderContainerError.noNesting
    }
    
    public func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        throw ParameterDecoderContainerError.noNesting
    }
    
    public func superDecoder() throws -> Decoder {
        VaporParameterDecoder(parameters: parameters)
    }
    
    public func superDecoder(forKey key: K) throws -> Decoder {
        VaporParameterDecoder(parameters: parameters)
    }
    
}

