//
//  UserDefaultsStorage.swift
//  SwiftStorage
//
//  Created by Josh Gallant on 13/07/2025.
//


import Foundation

public protocol UserDefaultsStorage: Actor {
    var namespace: String { get }

    func put<T: Encodable & Sendable>(_ value: T, forKey key: String) async throws
    func get<T: Decodable & Sendable>(forKey key: String) async throws -> T
    func remove(forKey key: String) async
    func clear() async
    func allKeys() async -> [String]
    func contains(_ key: String) async -> Bool
}

public enum PersistentStorageError: Error, CustomStringConvertible {
    case encodingFailed(namespace: String, key: String, underlyingError: Error)
    case decodingFailed(namespace: String, key: String, underlyingError: Error)
    case valueNotFound(namespace: String, key: String)
    case foundButTypeMismatch(namespace: String, key: String, expected: Any.Type, found: Any.Type)

    public var description: String {
        switch self {
        case let .encodingFailed(namespace, key, underlyingError):
            return "PersistentStorage \(namespace) encoding failed for key '\(key)': \(underlyingError)"
        case let .decodingFailed(namespace, key, underlyingError):
            return "PersistentStorage \(namespace) decoding failed for key '\(key)': \(underlyingError)"
        case let .valueNotFound(namespace, key):
            return "PersistentStorage \(namespace) could not find value for key '\(key)'"
        case let .foundButTypeMismatch(namespace, key, expected, found):
            return "PersistentStorage \(namespace) found value for key '\(key)' but type mismatch: expected \(expected), found \(found)"
        }
    }
}
