//
//  CombineMemoryCacheTests.swift
//  SwiftStorage
//
//  Created by Josh Gallant on 13/07/2025.
//


import XCTest
import Combine

final class CombineMemoryCacheTests: XCTestCase {

    typealias Key = String
    typealias Value = Int

    var cache: MockCombineMemoryCache<Key, Value>!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cache = MockCombineMemoryCache()
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
        // Given, When, Then
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

    func test_givenNoValue_whenPublisherSubscribesAndPut_thenEmitsNilThenValue() {
        // Given
        let expectation = self.expectation(description: "Publisher emits value")
        var received: [Value?] = []
        cache.publisher(for: "pub").sink { value in
            received.append(value)
            if received.count == 2 { expectation.fulfill() }
        }.store(in: &cancellables)

        // When
        cache.put("pub", value: 99)

        // Then
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(received, [nil, 99])
    }

    func test_givenValue_whenPublisherSubscribesAndRemove_thenEmitsValueThenNil() {
        // Given
        cache.put("pub", value: 100)
        let expectation = self.expectation(description: "Publisher emits nil after removal")
        var values: [Value?] = []
        cache.publisher(for: "pub").sink { value in
            values.append(value)
            if values.contains(nil) { expectation.fulfill() }
        }.store(in: &cancellables)

        // When
        cache.remove("pub")

        // Then
        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(values.contains(nil))
    }

    func test_givenValue_whenPublisherSubscribesAndClear_thenEmitsValueThenNil() {
        // Given
        cache.put("x", value: 1)
        let expectation = self.expectation(description: "Publisher emits nil after clear")
        var values: [Value?] = []
        cache.publisher(for: "x").sink { value in
            values.append(value)
            if values.contains(nil) { expectation.fulfill() }
        }.store(in: &cancellables)

        // When
        cache.clear()

        // Then
        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(values.contains(nil))
    }

    func test_givenMultipleSubscribers_whenPut_thenAllSubscribersAreNotified() {
        // Given
        cache.put("abc", value: 10)
        let expectation1 = expectation(description: "Subscriber 1 notified")
        let expectation2 = expectation(description: "Subscriber 2 notified")

        cache.publisher(for: "abc").sink { value in
            if value == 20 { expectation1.fulfill() }
        }.store(in: &cancellables)

        cache.publisher(for: "abc").sink { value in
            if value == 20 { expectation2.fulfill() }
        }.store(in: &cancellables)

        // When
        cache.put("abc", value: 20)

        // Then
        wait(for: [expectation1, expectation2], timeout: 1)
    }

    func test_givenNonExistentKey_whenPublisherSubscribes_thenEmitsNil() {
        // Given
        let expectation = self.expectation(description: "Initial value nil")

        // When
        cache.publisher(for: "nope").sink { value in
            // Then
            XCTAssertNil(value)
            expectation.fulfill()
        }.store(in: &cancellables)

        wait(for: [expectation], timeout: 1)
    }
}
