//
//  DefaultCombineMemoryCache.swift
//  SwiftStorage
//
//  Created by Josh Gallant on 13/07/2025.
//


import Foundation
import Combine

/// An in-memory, thread-safe, generic cache with LRU eviction and optional global entry expiration (TTL).
/// Supports per-key value observation using Combine publishers.
/// On every key removal (explicit, LRU, or expiry), publishers are notified with `nil`.
public final class DefaultCombineMemoryCache<Key: Hashable, Value>: CombineMemoryCache {

    // MARK: - Private properties

    /// Maximum number of items retained in the cache. Exceeding this limit triggers LRU eviction.
    private var maxSize: Int

    /// Optional global time-to-live (in seconds) for cache entries. If set, entries expire after this interval.
    private let expiresAfter: TimeInterval?

    /// Tracks key order for LRU eviction. Most recently used key is at the end.
    private var LRUKeys: [Key] = []

    /// Backing storage for cache entries. Each entry stores the value and its optional expiry date.
    private var storage: [Key: (value: Value, expiry: Date?)] = [:]

    /// Per-key publisher for observation. Sends `nil` on removal or expiry.
    private var subjects: [Key: CurrentValueSubject<Value?, Never>] = [:]

    /// Synchronizes access to all mutable state.
    private let lock = NSLock()

    // MARK: - Initialization

    /// Initializes a new cache instance.
    ///
    /// - Parameters:
    ///   - maxSize: Maximum cache size. When positive, the cache will not store more than this many items.
    ///   - expiresAfter: Optional TTL (in seconds) for all entries.
    public init(maxSize: Int = 500, expiresAfter: TimeInterval? = nil) {
        self.maxSize = max(1, maxSize)
        self.expiresAfter = (expiresAfter ?? 0) > 0 ? expiresAfter : nil
    }

    // MARK: - Public API

    /// The current count of valid (non-expired) entries in the cache.
    /// Expired entries are purged and their publishers are notified as `nil`.
    public var count: Int {
        var expiredSubjects: [CurrentValueSubject<Value?, Never>] = []
        lock.lock()
        expiredSubjects = removeExpired_locked()
        let count = storage.count
        lock.unlock()
        // Notify publishers for expired entries after unlocking.
        expiredSubjects.forEach { $0.send(nil) }
        return count
    }

    /// All valid, non-expired items currently in the cache.
    /// Expired items are removed and their publishers are notified as `nil`.
    public var allItems: [Key: Value] {
        var expiredSubjects: [CurrentValueSubject<Value?, Never>] = []
        var result: [Key: Value] = [:]
        lock.lock()
        expiredSubjects = removeExpired_locked()
        for (key, entry) in storage {
            result[key] = entry.value
        }
        lock.unlock()
        expiredSubjects.forEach { $0.send(nil) }
        return result
    }

    /// Returns true if the cache contains a value for the given key (not expired).
    /// Expired entries are removed and their publishers notified as `nil`.
    public func contains(_ key: Key) -> Bool {
        var expiredSubject: CurrentValueSubject<Value?, Never>?
        var result = false
        lock.lock()
        if let entry = storage[key] {
            if let expiry = entry.expiry, expiry < Date() {
                // Entry expired, remove and schedule publisher notification
                storage[key] = nil
                LRUKeys.removeAll { $0 == key }
                expiredSubject = subjects[key]
                subjects.removeValue(forKey: key)
                result = false
            } else {
                result = true
            }
        }
        lock.unlock()
        // Notify publisher after unlock if expired
        expiredSubject?.send(nil)
        return result
    }

    /// Inserts or updates a value for the given key.
    ///
    /// - If a TTL is configured, entry expires after the TTL interval.
    /// - If the cache is full, the least recently used entry is evicted (publisher notified as `nil`).
    /// - If an existing key, publisher is updated with new value.
    public func put(_ key: Key, value: Value) {
        let expiry = expiresAfter.map { Date().addingTimeInterval($0) }
        var removedSubjects: [CurrentValueSubject<Value?, Never>] = []
        var subject: CurrentValueSubject<Value?, Never>?
        lock.lock()
        storage[key] = (value, expiry)
        updateLRU_locked(for: key)
        // Only notify if a publisher exists for this key
        subject = subjects[key]
        // Remove expired before evicting LRU, and collect all publishers to notify
        removedSubjects.append(contentsOf: removeExpired_locked())
        removedSubjects.append(contentsOf: evictIfNeeded_locked())
        lock.unlock()
        // Notify observers (after unlock)
        subject?.send(value)
        removedSubjects.forEach { $0.send(nil) }
    }

    /// Retrieves the value for the given key, if present and not expired.
    /// If expired, removes the entry and notifies its publisher as `nil`.
    /// Updates LRU order on successful get.
    public func get(_ key: Key) -> Value? {
        var result: Value?
        var expiredSubject: CurrentValueSubject<Value?, Never>?
        lock.lock()
        if let entry = storage[key] {
            if let expiry = entry.expiry, expiry < Date() {
                // Expired, remove and notify publisher
                storage[key] = nil
                LRUKeys.removeAll { $0 == key }
                expiredSubject = subjects[key]
                subjects.removeValue(forKey: key)
            } else {
                updateLRU_locked(for: key)
                result = entry.value
            }
        }
        lock.unlock()
        expiredSubject?.send(nil)
        return result
    }

    /// Removes the value for the given key from the cache.
    /// Always notifies its publisher with `nil`.
    public func remove(_ key: Key) {
        var removedSubject: CurrentValueSubject<Value?, Never>?
        lock.lock()
        storage[key] = nil
        LRUKeys.removeAll { $0 == key }
        removedSubject = subjects[key]
        subjects.removeValue(forKey: key)
        lock.unlock()
        removedSubject?.send(nil)
    }

    /// Returns a publisher that emits the current and future value changes for the specified key.
    ///
    /// - Publisher sends the current value (or `nil`) on subscription, then emits on every change, removal, or expiry.
    /// - When the key is removed or expires, publisher sends `.send(nil)` and will not emit again unless a new value is set and a new publisher is created.
    public func publisher(for key: Key) -> AnyPublisher<Value?, Never> {
        lock.lock()
        let subject: CurrentValueSubject<Value?, Never>
        if let existing = subjects[key] {
            subject = existing
        } else {
            let value: Value? = {
                if let entry = storage[key], entry.expiry == nil || entry.expiry! >= Date() {
                    return entry.value
                } else {
                    return nil
                }
            }()
            subject = .init(value)
            subjects[key] = subject
        }
        lock.unlock()
        return subject.eraseToAnyPublisher()
    }

    /// Removes all entries from the cache, including all keys and publishers.
    /// Notifies all publishers with `nil` before removal.
    public func clear() {
        var removedSubjects: [CurrentValueSubject<Value?, Never>] = []
        lock.lock()
        storage.removeAll()
        LRUKeys.removeAll()
        removedSubjects = Array(subjects.values)
        subjects.removeAll()
        lock.unlock()
        removedSubjects.forEach { $0.send(nil) }
    }

    // MARK: - Internal helpers

    /// Updates LRU order for the given key.
    /// Moves key to the end as most recently used.
    private func updateLRU_locked(for key: Key) {
        LRUKeys.removeAll { $0 == key }
        LRUKeys.append(key)
    }

    /// Removes all expired items and collects their publishers for notification.
    /// Returns subjects that must be notified with `.send(nil)` after unlocking.
    private func removeExpired_locked() -> [CurrentValueSubject<Value?, Never>] {
        let now = Date()
        var expiredSubjects: [CurrentValueSubject<Value?, Never>] = []
        let expiredKeys = storage.compactMap { (key, entry) -> Key? in
            if let expiry = entry.expiry, expiry < now { return key }
            return nil
        }
        for key in expiredKeys {
            storage[key] = nil
            LRUKeys.removeAll { $0 == key }
            if let subject = subjects.removeValue(forKey: key) {
                expiredSubjects.append(subject)
            }
        }
        return expiredSubjects
    }

    /// Evicts least recently used keys if cache exceeds max size.
    /// Collects their publishers for notification.
    private func evictIfNeeded_locked() -> [CurrentValueSubject<Value?, Never>] {
        var removedSubjects: [CurrentValueSubject<Value?, Never>] = []
        while LRUKeys.count > maxSize {
            let oldest = LRUKeys.removeFirst()
            storage.removeValue(forKey: oldest)
            if let subject = subjects.removeValue(forKey: oldest) {
                removedSubjects.append(subject)
            }
        }
        return removedSubjects
    }
}
