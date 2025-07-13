//
//  MockMemoryCache.swift
//  SwiftStorage
//
//  Created by Josh Gallant on 13/07/2025.
//

import Foundation

final class MockMemoryCache<Key: Hashable, Value> {
    private var storage: [Key: Value] = [:]
    
    var count: Int { storage.count }
    var allItems: [Key: Value] { storage }
    
    func put(_ key: Key, value: Value) {
        storage[key] = value
    }
    
    func get(_ key: Key) -> Value? {
        storage[key]
    }
    
    func remove(_ key: Key) {
        storage.removeValue(forKey: key)
    }
    
    func clear() {
        storage.removeAll()
    }
    
    func contains(_ key: Key) -> Bool {
        storage[key] != nil
    }
}
