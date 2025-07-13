//
//  CombineMemoryCache.swift
//  SwiftStorage
//
//  Created by Josh Gallant on 13/07/2025.
//


import Foundation
import Combine


/// An in-memory, thread-safe, generic cache with LRU eviction and optional global entry expiration.
/// Supports per-key value observation using Combine publishers.
///
/// Features:
/// - Generic key-value storage.
/// - Optional global TTL (time-to-live) for all entries.
/// - Maximum size limit with LRU (least-recently-used) eviction policy.
/// - Thread safety via `NSLock`. Safe for use from multiple threads.
/// - Per-key Combine publisher for observing value changes, removals, and expiry.
/// - Manual cache management (put, get, remove, clear).
/// - Easy extensibility: count, contains, future per-entry TTL, O(1) LRU.
public protocol CombineMemoryCache {
    associatedtype Key: Hashable
    associatedtype Value
    
    // Query

    var count: Int { get }
    var allItems: [Key: Value] { get }
    func contains(_ key: Key) -> Bool

    // Operations

    func put(_ key: Key, value: Value)
    func get(_ key: Key) -> Value?
    func remove(_ key: Key)
    func clear()

    // Observation

    func publisher(for key: Key) -> AnyPublisher<Value?, Never>
}
