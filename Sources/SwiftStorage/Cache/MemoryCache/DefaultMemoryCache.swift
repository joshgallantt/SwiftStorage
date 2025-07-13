//
//  DefaultMemoryCache.swift
//  SwiftStorage
//
//  Created by Josh Gallant on 13/07/2025.
//

import Foundation

/// An in-memory, thread-safe, generic cache with LRU eviction and optional global entry expiration (TTL).
/// No observation or Combine. Designed for value storage and manual management only.
public final class DefaultMemoryCache<Key: Hashable, Value>: MemoryCache {

    // MARK: - Private properties

    /// Maximum number of items retained in the cache. Exceeding this limit triggers LRU eviction. Always positive.
    private var maxSize: Int

    /// Optional global time-to-live (in seconds) for cache entries. If set, entries expire after this interval.
    private let expiresAfter: TimeInterval?

    /// Tracks key order for LRU eviction. Most recently used key is at the end. Least recently used is at the start and evicted first.
    private var LRUKeys: [Key] = []

    /// Backing storage for cache entries. Each entry stores the value and its optional expiry date.
    private var storage: [Key: (value: Value, expiry: Date?)] = [:]

    /// Synchronizes access to all mutable state.
    private let lock = NSLock()

    // MARK: - Initialization

    /// Initializes a new cache instance.
    ///
    /// - Parameters:
    ///   - maxSize: Maximum cache size. When provided and positive, the cache will not store more than `maxSize` items (LRU policy).
    ///   - expiresAfter: Optional time-to-live (in seconds) for all entries. When provided and positive, each entry expires after this interval.
    public init(maxSize: Int = 500, expiresAfter: TimeInterval? = nil) {
        self.maxSize = max(1, maxSize)
        self.expiresAfter = (expiresAfter ?? 0) > 0 ? expiresAfter : nil
    }

    // MARK: - Protocol Conformance

    /// The current count of valid (non-expired) entries in the cache. Removes expired entries during this call.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        removeExpired_locked()
        return storage.count
    }

    /// All valid, non-expired items currently in the cache.
    /// Removes expired items during this call.
    public var allItems: [Key: Value] {
        lock.lock()
        defer { lock.unlock() }
        removeExpired_locked()
        var result: [Key: Value] = [:]
        for (key, entry) in storage {
            result[key] = entry.value
        }
        return result
    }

    /// Returns true if the cache contains a value for the given key (not expired).
    ///
    /// - Parameter key: The key to check.
    /// - Returns: `true` if present and not expired, else `false`.
    public func contains(_ key: Key) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = storage[key] else { return false }
        if let expiry = entry.expiry, expiry < Date() {
            storage[key] = nil
            LRUKeys.removeAll { $0 == key }
            return false
        }
        return true
    }

    /// Inserts or updates a value for the given key.
    ///
    /// If a TTL is configured, the entry expires after the TTL interval.
    /// If the cache is full (`maxSize`), the least recently used entry is evicted.
    ///
    /// - Parameters:
    ///   - key: The key to store.
    ///   - value: The value to store.
    public func put(_ key: Key, value: Value) {
        let expiry = expiresAfter.map { Date().addingTimeInterval($0) }
        lock.lock()
        defer { lock.unlock() }
        storage[key] = (value, expiry)
        updateLRU_locked(for: key)
        removeExpired_locked()
        evictIfNeeded_locked()
    }

    /// Retrieves the value for the given key, if present and not expired.
    ///
    /// If expired, removes the entry.
    /// Updates LRU order on successful get.
    ///
    /// - Parameter key: The key to retrieve.
    /// - Returns: The value if present and valid, else `nil`.
    public func get(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = storage[key] else { return nil }
        if let expiry = entry.expiry, expiry < Date() {
            storage[key] = nil
            LRUKeys.removeAll { $0 == key }
            return nil
        }
        updateLRU_locked(for: key)
        return entry.value
    }

    /// Removes the value for the given key from the cache.
    ///
    /// - Parameter key: The key to remove.
    public func remove(_ key: Key) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = nil
        LRUKeys.removeAll { $0 == key }
    }

    /// Removes all entries from the cache.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
        LRUKeys.removeAll()
    }

    // MARK: - Internal helpers

    /// Updates LRU order for the given key. Must be called with lock held. Moves key to the end as most recently used.
    private func updateLRU_locked(for key: Key) {
        LRUKeys.removeAll { $0 == key }
        LRUKeys.append(key)
    }

    /// Evicts least recently used keys if cache exceeds max size. Must be called with lock held.
    private func evictIfNeeded_locked() {
        while LRUKeys.count > maxSize {
            let oldest = LRUKeys.removeFirst()
            storage.removeValue(forKey: oldest)
        }
    }

    /// Removes all expired items. Must be called with lock held.
    private func removeExpired_locked() {
        let now = Date()
        let expiredKeys = storage.compactMap { (key, entry) -> Key? in
            if let expiry = entry.expiry, expiry < now { return key }
            return nil
        }
        for key in expiredKeys {
            storage[key] = nil
            LRUKeys.removeAll { $0 == key }
        }
    }
}
