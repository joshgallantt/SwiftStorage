//
//  CombineMemoryCacheTests.swift
//  SwiftStorage
//
//  Created by Josh Gallant on 13/07/2025.
//


import XCTest
import Combine

final class MemoryCacheTests: XCTestCase {

    typealias Key = String
    typealias Value = Int

    var cache: MockMemoryCache<Key, Value>!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cache = MockMemoryCache()
        cancellables = []
    }

    override func tearDown() {
        cache = nil
        cancellables = nil
        super.tearDown()
    }

    func test_givenEmptyCache_whenPut_thenGetReturnsValue() {
        // Given
        // A new cache

        // When
        cache.put("a", value: 1)

        // Then
        XCTAssertEqual(cache.get("a"), 1)
        XCTAssertNil(cache.get("b"))
    }

    func test_givenCacheWithKey_whenRemove_thenKeyIsRemoved() {
        // Given
        cache.put("a", value: 2)

        // When
        cache.remove("a")

        // Then
        XCTAssertNil(cache.get("a"))
    }

    func test_givenNonExistentKey_whenRemove_thenContainsReturnsFalse() {
        // Given
        // The key "z" does not exist

        // When
        cache.remove("z")

        // Then
        XCTAssertFalse(cache.contains("z"))
    }

    func test_givenCacheWithValues_whenClear_thenCacheIsEmpty() {
        // Given
        cache.put("a", value: 1)
        cache.put("b", value: 2)

        // When
        cache.clear()

        // Then
        XCTAssertEqual(cache.count, 0)
        XCTAssertFalse(cache.contains("a"))
        XCTAssertFalse(cache.contains("b"))
    }

    func test_givenCacheWithValues_whenAllItems_thenReturnsAllItems() {
        // Given
        cache.put("x", value: 42)
        cache.put("y", value: 24)

        // When
        let items = cache.allItems

        // Then
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items["x"], 42)
        XCTAssertEqual(items["y"], 24)
    }

    func test_givenCacheWithKey_whenContains_thenReturnsTrueOrFalse() {
        // Given
        cache.put("k", value: 9)

        // When & Then
        XCTAssertTrue(cache.contains("k"))
        XCTAssertFalse(cache.contains("missing"))
    }

    func test_givenCache_whenPutAndRemoveAndClear_thenCountIsCorrect() {
        // Given
        // An empty cache

        XCTAssertEqual(cache.count, 0)

        // When
        cache.put("a", value: 1)
        // Then
        XCTAssertEqual(cache.count, 1)

        // When
        cache.put("b", value: 2)
        // Then
        XCTAssertEqual(cache.count, 2)

        // When
        cache.remove("a")
        // Then
        XCTAssertEqual(cache.count, 1)

        // When
        cache.clear()
        // Then
        XCTAssertEqual(cache.count, 0)
    }

    func test_givenExistingKey_whenPutTwice_thenUpdatesValue() {
        // Given
        cache.put("dup", value: 1)

        // When
        cache.put("dup", value: 99)

        // Then
        XCTAssertEqual(cache.get("dup"), 99)
    }

    func test_givenRemoveOnEmptyCache_thenNoCrash() {
        // Given
        // An empty cache

        // When
        cache.remove("ghost")

        // Then
        XCTAssertNil(cache.get("ghost"))
    }

    func test_givenClearOnEmptyCache_thenNoCrash() {
        // Given
        // An empty cache

        // When
        cache.clear()

        // Then
        XCTAssertEqual(cache.count, 0)
    }

    func test_givenContainsOnEmptyCache_thenReturnsFalse() {
        // Given
        // An empty cache

        // When
        let result = cache.contains("not-there")

        // Then
        XCTAssertFalse(result)
    }
}
