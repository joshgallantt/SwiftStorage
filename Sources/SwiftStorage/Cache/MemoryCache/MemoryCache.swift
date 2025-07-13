//
//  MemoryCache.swift
//  SwiftStorage
//
//  Created by Josh Gallant on 13/07/2025.
//


/// A thread-safe, generic in-memory cache interface with LRU and optional TTL (global expiration).
public protocol MemoryCache {
    associatedtype Key: Hashable
    associatedtype Value

    /// The current count of valid (non-expired) entries in the cache.
    var count: Int { get }

    /// All valid, non-expired items currently in the cache.
    var allItems: [Key: Value] { get }

    /// Returns true if the cache contains a value for the given key (not expired).
    ///
    /// - Parameter key: The key to check.
    /// - Returns: `true` if present and not expired, else `false`.
    func contains(_ key: Key) -> Bool

    /// Inserts or updates a value for the given key.
    ///
    /// If a TTL is configured, the entry expires after the TTL interval.
    /// If the cache is full, the least recently used entry is evicted.
    ///
    /// - Parameters:
    ///   - key: The key to store.
    ///   - value: The value to store.
    func put(_ key: Key, value: Value)

    /// Retrieves the value for the given key, if present and not expired.
    ///
    /// If expired, removes the entry.
    /// Updates LRU order on successful get.
    ///
    /// - Parameter key: The key to retrieve.
    /// - Returns: The value if present and valid, else `nil`.
    func get(_ key: Key) -> Value?

    /// Removes the value for the given key from the cache.
    ///
    /// - Parameter key: The key to remove.
    func remove(_ key: Key)

    /// Removes all entries from the cache.
    func clear()
}
