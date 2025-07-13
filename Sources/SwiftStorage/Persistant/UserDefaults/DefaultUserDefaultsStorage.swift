//
//  DefaultUserDefaultsStorage.swift
//  SwiftStorage
//
//  Created by Josh Gallant on 13/07/2025.
//

import Foundation

public actor DefaultUserDefaultsStorage: UserDefaultsStorage {
    public let namespace: String
    let userDefaults: UserDefaults

    public init(namespace: String, userDefaults: UserDefaults = .standard) {
        self.namespace = namespace
        self.userDefaults = userDefaults
    }

    private func nsKey(_ key: String) -> String {
        "\(namespace).\(key)"
    }

    public func put<T: Encodable & Sendable>(_ value: T, forKey key: String) async throws {
        switch value {
        case let val as String:
            userDefaults.set(val, forKey: nsKey(key))
        case let val as Int:
            userDefaults.set(val, forKey: nsKey(key))
        case let val as Double:
            userDefaults.set(val, forKey: nsKey(key))
        case let val as Float:
            userDefaults.set(Double(val), forKey: nsKey(key))
        case let val as Bool:
            userDefaults.set(val, forKey: nsKey(key))
        case let val as Date:
            userDefaults.set(val, forKey: nsKey(key))
        case let val as URL:
            userDefaults.set(val, forKey: nsKey(key))
        case let val as Data:
            userDefaults.set(val, forKey: nsKey(key))
        default:
            do {
                let data = try await Task.detached {
                    try JSONEncoder().encode(value)
                }.value
                userDefaults.set(data, forKey: nsKey(key))
            } catch {
                throw PersistentStorageError.encodingFailed(namespace: namespace, key: key, underlyingError: error)
            }
        }
    }

    public func get<T: Decodable & Sendable>(forKey key: String) async throws -> T {
        let fullKey = nsKey(key)

        func mismatch(found: Any) -> PersistentStorageError {
            .foundButTypeMismatch(namespace: namespace, key: key, expected: T.self, found: type(of: found))
        }

        guard let object = userDefaults.object(forKey: fullKey) else {
            throw PersistentStorageError.valueNotFound(namespace: namespace, key: key)
        }

        switch T.self {
        case is String.Type:
            if let string = object as? String {
                return string as! T
            }
            throw mismatch(found: object)
        case is Int.Type:
            if let int = object as? Int {
                return int as! T
            }
            throw mismatch(found: object)
        case is Double.Type:
            if let double = object as? Double {
                return double as! T
            }
            throw mismatch(found: object)
        case is Bool.Type:
            if let bool = object as? Bool {
                return bool as! T
            }
            throw mismatch(found: object)
        case is Float.Type:
            if let float = object as? Float {
                return float as! T
            }
            throw mismatch(found: object)
        case is Date.Type:
            if let date = object as? Date {
                return date as! T
            }
            throw mismatch(found: object)
        case is URL.Type:
            if let data = object as? Data,
               let url = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSURL.self, from: data) as URL? {
                return url as! T
            } else if let url = object as? URL {
                return url as! T
            }
            throw mismatch(found: object)
        case is Data.Type:
            if let data = object as? Data {
                return data as! T
            }
            throw mismatch(found: object)
        default:
            guard let data = object as? Data else {
                throw mismatch(found: object)
            }
            do {
                return try await Task.detached {
                    try JSONDecoder().decode(T.self, from: data)
                }.value
            } catch {
                throw PersistentStorageError.decodingFailed(namespace: namespace, key: key, underlyingError: error)
            }
        }
    }

    public func remove(forKey key: String) async {
        userDefaults.removeObject(forKey: nsKey(key))
    }

    public func clear() async {
        let prefix = "\(namespace)."
        for (key, _) in userDefaults.dictionaryRepresentation() where key.hasPrefix(prefix) {
            userDefaults.removeObject(forKey: key)
        }
    }

    public func allKeys() async -> [String] {
        let prefix = "\(namespace)."
        return userDefaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }

    public func contains(_ key: String) async -> Bool {
        userDefaults.object(forKey: nsKey(key)) != nil
    }
}
