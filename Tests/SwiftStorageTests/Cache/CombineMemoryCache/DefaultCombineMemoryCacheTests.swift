//
//  DefaultCombineMemoryCacheTests.swift
//  SwiftStorage
//
//  Created by Josh Gallant on 13/07/2025.
//


import XCTest
import Combine

@testable import SwiftStorage

final class DefaultCombineMemoryCacheTests: XCTestCase {
    typealias Cache = DefaultCombineMemoryCache<String, Int>
    var cache: Cache!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    override func tearDown() {
        cache = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Initialisation

    func test_givenNegativeMaxSize_whenInit_thenUsesDefaultMaxSizeAndEvictsOldest() {
        // Given
        cache = Cache(maxSize: -10)
        cache.put("x", value: 1)
        // When
        for i in 0..<500 { cache.put("n\(i)", value: i) }
        cache.put("y", value: 2)
        // Then
        XCTAssertNil(cache.get("x"))
    }

    func test_givenNegativeExpiresAfter_whenInit_thenNeverExpires() {
        // Given
        cache = Cache(expiresAfter: -1)
        cache.put("x", value: 1)
        // When
        usleep(100_000)
        // Then
        XCTAssertEqual(cache.get("x"), 1)
    }

    func test_givenNilExpiresAfter_whenInit_thenNeverExpires() {
        // Given
        cache = Cache(expiresAfter: nil)
        cache.put("a", value: 1)
        // When
        usleep(100_000)
        // Then
        XCTAssertEqual(cache.get("a"), 1)
    }

    func test_givenZeroExpiresAfter_whenInit_thenNeverExpires() {
        // Given
        cache = Cache(expiresAfter: 0)
        cache.put("b", value: 2)
        // When
        usleep(100_000)
        // Then
        XCTAssertEqual(cache.get("b"), 2)
    }

    // MARK: - Basic Put/Get/Remove

    func test_givenEmptyCache_whenPut_thenGetReturnsValue() {
        // Given
        cache = Cache()
        // When
        cache.put("a", value: 10)
        // Then
        XCTAssertEqual(cache.get("a"), 10)
        XCTAssertNil(cache.get("b"))
    }

    func test_givenKeyInCache_whenRemove_thenValueAndPublisherAreRemoved() {
        // Given
        cache = Cache()
        cache.put("x", value: 42)
        // When
        cache.remove("x")
        // Then
        XCTAssertNil(cache.get("x"))
        let exp = expectation(description: "Publisher sends nil")
        cache.publisher(for: "x").sink { value in
            XCTAssertNil(value)
            exp.fulfill()
        }.store(in: &cancellables)
        wait(for: [exp], timeout: 1)
    }

    func test_givenNonexistentKey_whenRemove_thenDoesNotCrashAndGetReturnsNil() {
        // Given
        cache = Cache()
        
        // When
        cache.remove("not-there")
        
        // Then
        XCTAssertNil(cache.get("not-there"))
    }

    // MARK: - Clear

    func test_givenCacheWithValues_whenClear_thenAllRemovedAndPublishersEmitNil() {
        // Given
        cache = Cache()
        cache.put("a", value: 1)
        cache.put("b", value: 2)
        let exp1 = expectation(description: "Publisher for a sends nil")
        let exp2 = expectation(description: "Publisher for b sends nil")
        cache.publisher(for: "a").sink { if $0 == nil { exp1.fulfill() } }.store(in: &cancellables)
        cache.publisher(for: "b").sink { if $0 == nil { exp2.fulfill() } }.store(in: &cancellables)
        
        // When
        cache.clear()
        
        // Then
        XCTAssertNil(cache.get("a"))
        XCTAssertNil(cache.get("b"))
        wait(for: [exp1, exp2], timeout: 1)
        XCTAssertEqual(cache.count, 0)
    }

    // MARK: - LRU eviction

    func test_givenMaxSize_whenPutBeyondLimit_thenEvictsLeastRecentlyUsed() {
        // Given
        cache = Cache(maxSize: 2)
        cache.put("one", value: 1)
        cache.put("two", value: 2)
        
        // When
        cache.put("three", value: 3)
        
        // Then
        let items = cache.allItems
        XCTAssertNil(items["one"])
        XCTAssertNotNil(items["two"])
        XCTAssertNotNil(items["three"])
        XCTAssertEqual(items.count, 2)
    }

    func test_givenItemAccessed_whenPutBeyondLimit_thenEvictionOrderUpdated() {
        // Given
        cache = Cache(maxSize: 2)
        cache.put("one", value: 1)
        cache.put("two", value: 2)
        
        // When
        _ = cache.get("one")
        cache.put("three", value: 3)
        
        // Then
        let items = cache.allItems
        XCTAssertNotNil(items["one"])
        XCTAssertNil(items["two"])
        XCTAssertNotNil(items["three"])
    }

    // MARK: - TTL/Expiry

    func test_givenShortTTL_whenEntryExpires_thenIsRemoved() {
        // Given
        cache = Cache(expiresAfter: 0.1)
        cache.put("expiring", value: 123)
        
        // When
        XCTAssertTrue(cache.contains("expiring"))
        XCTAssertEqual(cache.get("expiring"), 123)
        let exp = expectation(description: "Entry expires")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { exp.fulfill() }
        wait(for: [exp], timeout: 1)
        
        // Then
        XCTAssertFalse(cache.contains("expiring"))
        XCTAssertNil(cache.get("expiring"))
        XCTAssertEqual(cache.count, 0)
    }

    func test_givenExpiringEntry_whenExpires_thenPublisherSendsNilAndIsRemoved() {
        // Given
        cache = Cache(expiresAfter: 0.1)
        let exp = expectation(description: "Publisher sends nil after expiry")
        cache.put("expirePub", value: 88)
        cache.publisher(for: "expirePub").sink { val in
            if val == nil { exp.fulfill() }
        }.store(in: &cancellables)
        
        // When
        usleep(200_000)
        _ = cache.get("expirePub")
        
        // Then
        wait(for: [exp], timeout: 1)
    }

    func test_givenExpiredEntry_whenAllItems_thenRemovedAndPublisherNotified() {
        // Given
        cache = Cache(expiresAfter: 0.05)
        cache.put("a", value: 1)
        let exp = expectation(description: "Publisher notified nil on allItems")
        cache.publisher(for: "a").sink { v in
            if v == nil { exp.fulfill() }
        }.store(in: &cancellables)
        
        // When
        usleep(100_000)
        let items = cache.allItems
        
        // Then
        XCTAssertTrue(items.isEmpty)
        wait(for: [exp], timeout: 1)
    }

    func test_givenExpiredEntry_whenCount_thenCleansUpAndCountIsZero() {
        // Given
        cache = Cache(expiresAfter: 0.05)
        cache.put("soonExpired", value: 5)
        // When
        usleep(100_000)
        // Then
        XCTAssertEqual(cache.count, 0)
    }

    func test_givenExpiredEntry_whenAllItems_thenEntryNotPresent() {
        // Given
        cache = Cache(expiresAfter: 0.05)
        cache.put("expired", value: 123)
        
        // When
        usleep(100_000)
        
        // Then
        XCTAssertFalse(cache.allItems.keys.contains("expired"))
    }

    func test_givenExpiredEntry_whenContains_thenRemovesAndPublisherEmitsNil() {
        // Given
        cache = Cache(expiresAfter: 0.05)
        let exp = expectation(description: "Publisher emits nil after contains triggers expiry cleanup")
        cache.put("foo", value: 99)
        cache.publisher(for: "foo").sink { v in
            if v == nil { exp.fulfill() }
        }.store(in: &cancellables)
        
        // When
        usleep(100_000)
        XCTAssertFalse(cache.contains("foo"))
        
        // Then
        wait(for: [exp], timeout: 1)
    }

    func test_givenExpiredEntry_whenContainsCalledTwice_thenPublisherEmitsNilOnlyOnce() {
        // Given
        cache = Cache(expiresAfter: 0.05)
        var nilCount = 0
        let exp = expectation(description: "Publisher emits nil exactly once")
        cache.put("bar", value: 1)
        cache.publisher(for: "bar").sink { v in
            if v == nil { nilCount += 1 }
        }.store(in: &cancellables)
        
        // When
        usleep(100_000)
        XCTAssertFalse(cache.contains("bar"))
        XCTAssertFalse(cache.contains("bar"))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        
        // Then
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(nilCount, 1)
    }

    // MARK: - Publishers
    
    func test_givenValueExists_whenPublisherSubscribes_thenEmitsCurrentValue() {
        // Given
        cache = Cache()
        cache.put("exists", value: 42)
        
        // When
        let exp = expectation(description: "Publisher emits current value")
        var results: [Int?] = []
        cache.publisher(for: "exists").sink { value in
            results.append(value)
            exp.fulfill()
        }.store(in: &cancellables)
        
        // Then
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(results, [42])
    }
    

    func test_givenNoValue_whenPublisherSubscribesAndPut_thenEmitsNilThenValue() {
        // Given
        cache = Cache()
        var results: [Int?] = []
        let exp = expectation(description: "Publisher emits on put")
        cache.publisher(for: "pubkey").sink { value in
            results.append(value)
            if results.count == 2 { exp.fulfill() }
        }.store(in: &cancellables)
        
        // When
        cache.put("pubkey", value: 55)
        
        // Then
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(results, [nil, 55])
    }

    func test_givenValue_whenRemoved_thenPublisherEmitsNilAndResubscribeReceivesNil() {
        // Given
        cache = Cache()
        let exp = expectation(description: "Publisher sends nil after removal")
        cache.put("z", value: 5)
        cache.publisher(for: "z").sink { value in
            if value == nil { exp.fulfill() }
        }.store(in: &cancellables)
        
        // When
        cache.remove("z")
        
        // Then
        wait(for: [exp], timeout: 1)
        let exp2 = expectation(description: "New subscriber gets nil")
        cache.publisher(for: "z").sink { value in
            XCTAssertNil(value)
            exp2.fulfill()
        }.store(in: &cancellables)
        wait(for: [exp2], timeout: 1)
    }

    func test_givenMultipleSubscribers_whenPut_thenAllAreNotified() {
        // Given
        cache = Cache()
        cache.put("shared", value: 99)
        let exp1 = expectation(description: "Sub1 notified")
        let exp2 = expectation(description: "Sub2 notified")
        cache.publisher(for: "shared").sink { value in
            if value == 42 { exp1.fulfill() }
        }.store(in: &cancellables)
        cache.publisher(for: "shared").sink { value in
            if value == 42 { exp2.fulfill() }
        }.store(in: &cancellables)
        
        // When
        cache.put("shared", value: 42)
        
        // Then
        wait(for: [exp1, exp2], timeout: 1)
    }

    func test_givenNonexistentKey_whenPublisherSubscribes_thenEmitsNil() {
        // Given
        cache = Cache()
        let exp = expectation(description: "Publisher starts nil for missing key")
        
        // When
        cache.publisher(for: "nope").sink { value in
            // Then
            XCTAssertNil(value)
            exp.fulfill()
        }.store(in: &cancellables)
        
        wait(for: [exp], timeout: 1)
    }
    
    func test_givenPublisher_whenKeyEvictedLRU_thenPublisherSendsNil() {
        // Given
        cache = Cache(maxSize: 2)
        cache.put("a", value: 1)
        cache.put("b", value: 2)
        
        let exp = expectation(description: "Publisher for a receives nil on LRU eviction")

        cache.publisher(for: "a").sink { value in
            if value == nil { exp.fulfill() }
        }.store(in: &cancellables)
        
        // When
        cache.put("c", value: 3)
        
        // Then
        wait(for: [exp], timeout: 1)
        XCTAssertNil(cache.get("a"))
    }

    // MARK: - Miscellaneous

    func test_givenCacheWithValues_whenAllItems_thenReturnsAllNonExpired() {
        // Given
        cache = Cache()
        cache.put("a", value: 1)
        cache.put("b", value: 2)
        
        // When
        let items = cache.allItems
        
        // Then
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items["a"], 1)
        XCTAssertEqual(items["b"], 2)
    }

    func test_givenCache_whenPutRemoveClear_thenCountReflectsNonExpired() {
        // Given
        cache = Cache()
        XCTAssertEqual(cache.count, 0)
        
        // When
        cache.put("a", value: 1)
        XCTAssertEqual(cache.count, 1)
        cache.put("b", value: 2)
        XCTAssertEqual(cache.count, 2)
        cache.remove("a")
        XCTAssertEqual(cache.count, 1)
        cache.clear()
        
        // Then
        XCTAssertEqual(cache.count, 0)
    }

    func test_givenExpiresAfterSet_whenContains_thenWorksForExpiredAndValidEntries() {
        // Given
        cache = Cache(expiresAfter: 0.1)
        cache.put("v", value: 2)
        
        // When
        XCTAssertTrue(cache.contains("v"))
        usleep(200_000)
        
        // Then
        XCTAssertFalse(cache.contains("v"))
    }

    func test_givenExpiredEntry_whenContains_thenReturnsFalse() {
        // Given
        cache = Cache(expiresAfter: 0.05)
        cache.put("expireme", value: 7)
        
        // When
        usleep(100_000)
        
        // Then
        XCTAssertFalse(cache.contains("expireme"))
    }

    func test_givenExistingKey_whenPutTwice_thenUpdatesValue() {
        // Given
        cache = Cache()
        cache.put("a", value: 1)
        
        // When
        cache.put("a", value: 2)
        
        // Then
        XCTAssertEqual(cache.get("a"), 2)
    }

    func test_givenExpiredEntry_whenGet_thenPublisherEmitsNil() {
        // Given
        cache = Cache(expiresAfter: 0.05)
        cache.put("a", value: 1)
        let exp = expectation(description: "Publisher emits nil after expired get")
        cache.publisher(for: "a").sink { v in
            if v == nil { exp.fulfill() }
        }.store(in: &cancellables)
        
        // When
        usleep(100_000)
        _ = cache.get("a")
        
        // Then
        wait(for: [exp], timeout: 1)
    }
    
    func test_givenManyConcurrentPutsAndRemoves_thenNoCrashAndConsistentState() {
        // Given
        cache = Cache(maxSize: 10)
        nonisolated(unsafe) let localCache = cache!
        
        // When
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        for i in 0..<1000 {
            group.enter()
            queue.async {
                if i % 2 == 0 {
                    localCache.put("k\(i % 10)", value: i)
                } else {
                    localCache.remove("k\(i % 10)")
                }
                group.leave()
            }
        }
        
        // Then
        XCTAssertEqual(group.wait(timeout: .now() + 2), .success)
    }

}
