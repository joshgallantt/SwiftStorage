//
//  DefaultMemoryCacheTests.swift
//  SwiftStorage
//
//  Created by Josh Gallant on 13/07/2025.
//

import XCTest
@testable import SwiftStorage

final class DefaultMemoryCacheTests: XCTestCase {
    typealias Cache = DefaultMemoryCache<String, Int>
    var cache: Cache!

    override func setUp() {
        super.setUp()
        cache = Cache()
    }

    override func tearDown() {
        cache = nil
        super.tearDown()
    }
    
    struct MyStruct: Equatable {
        let id: Int
        let name: String
    }
    
    // MARK: - Struct and List Tests
    
    func test_givenEmptyCache_whenPutMyStruct_thenGetReturnsStruct() {
        // Given
        let person = MyStruct(id: 10, name: "Alice")
        let cache = DefaultMemoryCache<String, MyStruct>()

        // When
        cache.put("user", value: person)

        // Then
        XCTAssertEqual(cache.get("user"), person)
        XCTAssertNil(cache.get("missing"))
    }

    func test_givenEmptyCache_whenPutListOfMyStruct_thenGetReturnsListInSameOrder() {
        // Given
        let list = [
            MyStruct(id: 1, name: "A"),
            MyStruct(id: 2, name: "B"),
            MyStruct(id: 3, name: "C")
        ]
        let cache = DefaultMemoryCache<String, [MyStruct]>()

        // When
        cache.put("people", value: list)

        // Then
        let result = cache.get("people")
        XCTAssertEqual(result, list)
        XCTAssertEqual(result?.map { $0.id }, [1, 2, 3])
    }

    func test_givenCacheWithList_whenPutNewList_thenGetReturnsNewListInOrder() {
        // Given
        let firstList = [
            MyStruct(id: 1, name: "A"),
            MyStruct(id: 2, name: "B")
        ]
        let newList = [
            MyStruct(id: 5, name: "X"),
            MyStruct(id: 6, name: "Y")
        ]
        let cache = DefaultMemoryCache<String, [MyStruct]>()
        cache.put("people", value: firstList)

        // When
        cache.put("people", value: newList)

        // Then
        let result = cache.get("people")
        XCTAssertEqual(result, newList)
        XCTAssertEqual(result?.map { $0.id }, [5, 6])
    }

    func test_givenCacheWithList_whenRemove_thenGetReturnsNil() {
        // Given
        let list = [
            MyStruct(id: 1, name: "A"),
            MyStruct(id: 2, name: "B")
        ]
        let cache = DefaultMemoryCache<String, [MyStruct]>()
        cache.put("team", value: list)

        // When
        cache.remove("team")

        // Then
        XCTAssertNil(cache.get("team"))
    }

    // MARK: - Basic Put/Get/Remove/Clear

    func test_givenEmptyCache_whenPut_thenGetReturnsValue() {
        cache.put("a", value: 1)
        XCTAssertEqual(cache.get("a"), 1)
        XCTAssertNil(cache.get("b"))
    }

    func test_givenCacheWithKey_whenRemove_thenKeyIsRemoved() {
        cache.put("a", value: 2)
        cache.remove("a")
        XCTAssertNil(cache.get("a"))
    }

    func test_givenNonExistentKey_whenRemove_thenContainsReturnsFalse() {
        cache.remove("z")
        XCTAssertFalse(cache.contains("z"))
    }

    func test_givenCacheWithValues_whenClear_thenCacheIsEmpty() {
        cache.put("a", value: 1)
        cache.put("b", value: 2)
        cache.clear()
        XCTAssertEqual(cache.count, 0)
        XCTAssertFalse(cache.contains("a"))
        XCTAssertFalse(cache.contains("b"))
    }

    func test_givenCacheWithValues_whenAllItems_thenReturnsAllItems() {
        cache.put("x", value: 42)
        cache.put("y", value: 24)
        let items = cache.allItems
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items["x"], 42)
        XCTAssertEqual(items["y"], 24)
    }

    func test_givenCacheWithKey_whenContains_thenReturnsTrueOrFalse() {
        cache.put("k", value: 9)
        XCTAssertTrue(cache.contains("k"))
        XCTAssertFalse(cache.contains("missing"))
    }

    func test_givenCache_whenPutAndRemoveAndClear_thenCountIsCorrect() {
        XCTAssertEqual(cache.count, 0)
        cache.put("a", value: 1)
        XCTAssertEqual(cache.count, 1)
        cache.put("b", value: 2)
        XCTAssertEqual(cache.count, 2)
        cache.remove("a")
        XCTAssertEqual(cache.count, 1)
        cache.clear()
        XCTAssertEqual(cache.count, 0)
    }

    func test_givenExistingKey_whenPutTwice_thenUpdatesValue() {
        cache.put("dup", value: 1)
        cache.put("dup", value: 99)
        XCTAssertEqual(cache.get("dup"), 99)
    }

    func test_givenRemoveOnEmptyCache_thenNoCrash() {
        cache.remove("ghost")
        XCTAssertNil(cache.get("ghost"))
    }

    func test_givenClearOnEmptyCache_thenNoCrash() {
        cache.clear()
        XCTAssertEqual(cache.count, 0)
    }

    func test_givenContainsOnEmptyCache_thenReturnsFalse() {
        XCTAssertFalse(cache.contains("not-there"))
    }

    // MARK: - LRU Eviction

    func test_givenMaxSize_whenPutBeyondLimit_thenEvictsLeastRecentlyUsed() {
        cache = Cache(maxSize: 2)
        cache.put("one", value: 1)
        cache.put("two", value: 2)
        cache.put("three", value: 3) // Should evict "one"
        let items = cache.allItems
        XCTAssertNil(items["one"])
        XCTAssertNotNil(items["two"])
        XCTAssertNotNil(items["three"])
        XCTAssertEqual(items.count, 2)
    }

    func test_givenItemAccessed_whenPutBeyondLimit_thenEvictionOrderUpdated() {
        cache = Cache(maxSize: 2)
        cache.put("one", value: 1)
        cache.put("two", value: 2)
        _ = cache.get("one") // Access updates LRU order
        cache.put("three", value: 3) // Should evict "two"
        let items = cache.allItems
        XCTAssertNotNil(items["one"])
        XCTAssertNil(items["two"])
        XCTAssertNotNil(items["three"])
    }

    // MARK: - Expiry/TTL

    func test_givenShortTTL_whenEntryExpires_thenIsRemoved() {
        cache = Cache(expiresAfter: 0.1)
        cache.put("expiring", value: 123)
        XCTAssertTrue(cache.contains("expiring"))
        XCTAssertEqual(cache.get("expiring"), 123)
        let exp = expectation(description: "Entry expires")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { exp.fulfill() }
        wait(for: [exp], timeout: 1)
        XCTAssertFalse(cache.contains("expiring"))
        XCTAssertNil(cache.get("expiring"))
        XCTAssertEqual(cache.count, 0)
    }

    func test_givenNilExpiresAfter_whenInit_thenNeverExpires() {
        cache = Cache(expiresAfter: nil)
        cache.put("a", value: 1)
        usleep(100_000)
        XCTAssertEqual(cache.get("a"), 1)
    }

    func test_givenZeroExpiresAfter_whenInit_thenNeverExpires() {
        cache = Cache(expiresAfter: 0)
        cache.put("b", value: 2)
        usleep(100_000)
        XCTAssertEqual(cache.get("b"), 2)
    }

    func test_givenNegativeExpiresAfter_whenInit_thenNeverExpires() {
        cache = Cache(expiresAfter: -1)
        cache.put("x", value: 1)
        usleep(100_000)
        XCTAssertEqual(cache.get("x"), 1)
    }

    func test_givenExpiredEntry_whenAllItems_thenRemoved() {
        cache = Cache(expiresAfter: 0.05)
        cache.put("expired", value: 123)
        usleep(100_000)
        XCTAssertFalse(cache.allItems.keys.contains("expired"))
    }

    func test_givenExpiredEntry_whenCount_thenCountIsZero() {
        cache = Cache(expiresAfter: 0.05)
        cache.put("soonExpired", value: 5)
        usleep(100_000)
        XCTAssertEqual(cache.count, 0)
    }
    
    func test_givenExpiredEntry_whenContains_thenReturnsFalse() {
        cache = Cache(expiresAfter: 0.05)
        cache.put("expireme", value: 7)
        usleep(100_000)
        XCTAssertFalse(cache.contains("expireme"))
    }
    
    func test_givenExpiredEntry_whenGet_thenReturnsNilAndRemovesEntry() {
        cache = Cache(expiresAfter: 0.01)
        cache.put("foo", value: 23)
        usleep(20_000) // Wait for entry to expire
        XCTAssertNil(cache.get("foo"), "Getting an expired entry should return nil and remove it")
        XCTAssertFalse(cache.contains("foo"), "Entry should be gone after expired get")
    }
}
