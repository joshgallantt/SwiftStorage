//
//  MockCombineMemoryCache.swift
//  SwiftStorage
//
//  Created by Josh Gallant on 13/07/2025.
//


import Foundation
import Combine

@testable import SwiftStorage

final class MockCombineMemoryCache<Key: Hashable, Value>: CombineMemoryCache {
    private var storage: [Key: Value] = [:]
    private var subjects: [Key: CurrentValueSubject<Value?, Never>] = [:]
    private let lock = NSLock()

    var count: Int { storage.count }
    
    var allItems: [Key: Value] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func put(_ key: Key, value: Value) {
        lock.lock()
        storage[key] = value
        if let subj = subjects[key] {
            subj.send(value)
        } else {
            let subj = CurrentValueSubject<Value?, Never>(value)
            subjects[key] = subj
        }
        lock.unlock()
    }

    func get(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func remove(_ key: Key) {
        lock.lock()
        storage.removeValue(forKey: key)
        subjects[key]?.send(nil)
        lock.unlock()
    }

    func clear() {
        lock.lock()
        storage.keys.forEach { key in
            subjects[key]?.send(nil)
        }
        storage.removeAll()
        lock.unlock()
    }

    func contains(_ key: Key) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage[key] != nil
    }

    func publisher(for key: Key) -> AnyPublisher<Value?, Never> {
        lock.lock()
        let subject: CurrentValueSubject<Value?, Never>
        if let subj = subjects[key] {
            subject = subj
        } else {
            subject = CurrentValueSubject<Value?, Never>(storage[key])
            subjects[key] = subject
        }
        lock.unlock()
        return subject.eraseToAnyPublisher()
    }
}
