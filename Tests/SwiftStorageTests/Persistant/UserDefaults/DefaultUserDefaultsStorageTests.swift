//
//  DefaultUserDefaultsStorageTests.swift
//  SwiftStorage
//
//  Created by Josh Gallant on 13/07/2025.
//


import XCTest
@testable import SwiftStorage

final class DefaultUserDefaultsStorageTests: XCTestCase {
    var storage: DefaultUserDefaultsStorage!
    let namespace = "testNamespace"

    struct TestObject: Codable, Equatable, Sendable {
        let id: Int
        let name: String
    }

    override func setUp() {
        super.setUp()
        let userDefaults = UserDefaults(suiteName: "DefaultUserDefaultsStorageTests")!
        userDefaults.removePersistentDomain(forName: "DefaultUserDefaultsStorageTests")
        storage = DefaultUserDefaultsStorage(namespace: namespace, userDefaults: userDefaults)
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Put and Get Basic Types

    func test_givenString_whenPutAndGet_thenValueIsReturned() async throws {
        // Given
        let value = "hello"

        // When
        try await storage.put(value, forKey: "myString")
        let result: String = try await self.storage.get(forKey: "myString")

        // Then
        XCTAssertEqual(result, value)
    }

    func test_givenEmptyString_whenPutAndGet_thenEmptyStringIsReturned() async throws {
        // Given
        let value = ""

        // When
        try await storage.put(value, forKey: "myString")
        let result: String = try await self.storage.get(forKey: "myString")

        // Then
        XCTAssertEqual(result, value)
    }

    func test_givenInt_whenPutAndGet_thenValueIsReturned() async throws {
        // Given
        let value = 42

        // When
        try await storage.put(value, forKey: "myInt")
        let result: Int = try await self.storage.get(forKey: "myInt")

        // Then
        XCTAssertEqual(result, value)
    }

    func test_givenDouble_whenPutAndGet_thenValueIsReturned() async throws {
        // Given
        let value = 3.14

        // When
        try await storage.put(value, forKey: "myDouble")
        let result: Double = try await self.storage.get(forKey: "myDouble")

        // Then
        XCTAssertEqual(result, value)
    }

    func test_givenBool_whenPutAndGet_thenValueIsReturned() async throws {
        // Given
        let value = true

        // When
        try await storage.put(value, forKey: "myBool")
        let result: Bool = try await self.storage.get(forKey: "myBool")

        // Then
        XCTAssertEqual(result, value)
    }

    func test_givenFloat_whenPutAndGet_thenValueIsReturned() async throws {
        // Given
        let value = Float(1.23)

        // When
        try await storage.put(value, forKey: "myFloat")
        let result: Float = try await self.storage.get(forKey: "myFloat")

        // Then
        XCTAssertEqual(result, value)
    }

    func test_givenDate_whenPutAndGet_thenValueIsReturned() async throws {
        // Given
        let value = Date()

        // When
        try await storage.put(value, forKey: "myDate")
        let result: Date = try await self.storage.get(forKey: "myDate")

        // Then
        XCTAssertEqual(result.timeIntervalSince1970, value.timeIntervalSince1970, accuracy: 0.01)
    }

    func test_givenURL_whenPutAndGet_thenValueIsReturned() async throws {
        // Given
        let value = URL(string: "https://apple.com")!

        // When
        try await storage.put(value, forKey: "myURL")
        let result: URL = try await self.storage.get(forKey: "myURL")

        // Then
        XCTAssertEqual(result, value)
    }

    func test_givenData_whenPutAndGet_thenValueIsReturned() async throws {
        // Given
        let value = "swift".data(using: .utf8)!

        // When
        try await storage.put(value, forKey: "myData")
        let result: Data = try await self.storage.get(forKey: "myData")

        // Then
        XCTAssertEqual(result, value)
    }

    // MARK: - Custom Codable

    func test_givenCodable_whenPutAndGet_thenValueIsReturned() async throws {
        // Given
        let value = TestObject(id: 1, name: "Josh")

        // When
        try await storage.put(value, forKey: "object")
        let result: TestObject = try await self.storage.get(forKey: "object")

        // Then
        XCTAssertEqual(result, value)
    }

    // MARK: - Nonexistent Keys

    func test_givenNonexistentStringKey_whenGet_thenThrowsValueNotFound() async {
        // Given
        let key = "doesNotExist"

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(forKey: key) as String) { error in
            guard let storageError = error as? PersistentStorageError,
                  case .valueNotFound(let ns, let gotKey) = storageError else {
                XCTFail("Expected valueNotFound error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(gotKey, key)
        }
    }

    // All types version, pattern repeated for coverage
    func test_givenNonexistentIntKey_whenGet_thenThrowsValueNotFound() async {
        // Given
        let key = "doesNotExistInt"

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(forKey: key) as Int) { error in
            guard let storageError = error as? PersistentStorageError,
                  case .valueNotFound(let ns, let gotKey) = storageError else {
                XCTFail("Expected valueNotFound error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(gotKey, key)
        }
    }

    func test_givenNonexistentDoubleKey_whenGet_thenThrowsValueNotFound() async {
        // Given
        let key = "doesNotExistDouble"

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(forKey: key) as Double) { error in
            guard let storageError = error as? PersistentStorageError,
                  case .valueNotFound(let ns, let gotKey) = storageError else {
                XCTFail("Expected valueNotFound error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(gotKey, key)
        }
    }

    func test_givenNonexistentBoolKey_whenGet_thenThrowsValueNotFound() async {
        // Given
        let key = "doesNotExistBool"

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(forKey: key) as Bool) { error in
            guard let storageError = error as? PersistentStorageError,
                  case .valueNotFound(let ns, let gotKey) = storageError else {
                XCTFail("Expected valueNotFound error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(gotKey, key)
        }
    }

    func test_givenNonexistentFloatKey_whenGet_thenThrowsValueNotFound() async {
        // Given
        let key = "doesNotExistFloat"

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(forKey: key) as Float) { error in
            guard let storageError = error as? PersistentStorageError,
                  case .valueNotFound(let ns, let gotKey) = storageError else {
                XCTFail("Expected valueNotFound error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(gotKey, key)
        }
    }

    func test_givenNonexistentDateKey_whenGet_thenThrowsValueNotFound() async {
        // Given
        let key = "doesNotExistDate"

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(forKey: key) as Date) { error in
            guard let storageError = error as? PersistentStorageError,
                  case .valueNotFound(let ns, let gotKey) = storageError else {
                XCTFail("Expected valueNotFound error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(gotKey, key)
        }
    }

    func test_givenNonexistentURLKey_whenGet_thenThrowsValueNotFound() async {
        // Given
        let key = "doesNotExistURL"

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(forKey: key) as URL) { error in
            guard let storageError = error as? PersistentStorageError,
                  case .valueNotFound(let ns, let gotKey) = storageError else {
                XCTFail("Expected valueNotFound error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(gotKey, key)
        }
    }

    func test_givenNonexistentDataKey_whenGet_thenThrowsValueNotFound() async {
        // Given
        let key = "doesNotExistData"

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(forKey: key) as Data) { error in
            guard let storageError = error as? PersistentStorageError,
                  case .valueNotFound(let ns, let gotKey) = storageError else {
                XCTFail("Expected valueNotFound error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(gotKey, key)
        }
    }

    func test_givenNonexistentCodableKey_whenGet_thenThrowsValueNotFound() async {
        // Given
        let key = "doesNotExistObject"

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(forKey: key) as TestObject) { error in
            guard let storageError = error as? PersistentStorageError,
                  case .valueNotFound(let ns, let gotKey) = storageError else {
                XCTFail("Expected valueNotFound error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(gotKey, key)
        }
    }

    // MARK: - Remove and Clear

    func test_givenKeyExists_whenRemove_thenKeyIsRemoved() async throws {
        // Given
        try await storage.put("value", forKey: "removeMe")

        // When
        await storage.remove(forKey: "removeMe")

        // Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(forKey: "removeMe") as String) { error in
            guard let storageError = error as? PersistentStorageError,
                  case .valueNotFound = storageError else {
                XCTFail("Expected valueNotFound error")
                return
            }
        }
    }

    func test_givenMultipleKeys_whenClear_thenAllNamespaceKeysAreRemoved() async throws {
        // Given
        try await storage.put("A", forKey: "one")
        try await storage.put("B", forKey: "two")

        // When
        await storage.clear()

        // Then
        let keys = await storage.allKeys()
        XCTAssertTrue(keys.isEmpty)
    }

    func test_givenKeyExists_whenClearAndRemoveAgain_thenNoErrorIsThrown() async throws {
        // Given
        try await storage.put("something", forKey: "toRemove")
        await storage.clear()

        // When/Then
        await storage.remove(forKey: "toRemove")
    }

    func test_givenOtherSuiteKey_whenClear_thenOtherSuiteKeyRemains() async throws {
        // Given
        let otherDefaults = UserDefaults(suiteName: "OtherSuite")!
        otherDefaults.set("shouldRemain", forKey: "randomKey")
        try await storage.put("one", forKey: "shouldRemove")

        // When
        await storage.clear()

        // Then
        XCTAssertEqual(otherDefaults.string(forKey: "randomKey"), "shouldRemain")
    }

    // MARK: - allKeys & contains

    func test_givenKeysExist_whenAllKeys_thenReturnsOnlyNamespaceKeys() async throws {
        // Given
        try await storage.put("a", forKey: "key1")
        try await storage.put("b", forKey: "key2")

        // When
        let keys = await storage.allKeys()

        // Then
        XCTAssertEqual(Set(keys), Set(["key1", "key2"]))
    }

    func test_givenNoKeys_whenAllKeys_thenReturnsEmpty() async throws {
        // Given/When
        let keys = await storage.allKeys()

        // Then
        XCTAssertTrue(keys.isEmpty)
    }

    func test_givenKeyExists_whenContains_thenReturnsTrue() async throws {
        // Given
        try await storage.put(123, forKey: "foo")

        // When
        let contains = await storage.contains("foo")

        // Then
        XCTAssertTrue(contains)
    }

    func test_givenKeyDoesNotExist_whenContains_thenReturnsFalse() async throws {
        // Given/When
        let contains = await storage.contains("nope")

        // Then
        XCTAssertFalse(contains)
    }

    // MARK: - Type Safety / Decoding / Encoding / Type mismatch

    func test_givenCorruptedData_whenGetCodable_thenThrowsDecodingFailed() async throws {
        // Given
        let key = "badCodable"
        let badData = "notjson".data(using: .utf8)!
        let udKey = "\(namespace).\(key)"
        let userDefaults = UserDefaults(suiteName: "DefaultUserDefaultsStorageTests")!
        userDefaults.set(badData, forKey: udKey)

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(forKey: key) as TestObject) { error in
            guard let storageError = error as? PersistentStorageError,
                  case .decodingFailed(let ns, let gotKey, _) = storageError else {
                XCTFail("Expected decodingFailed error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(gotKey, key)
        }
    }

    func test_givenFailingEncodable_whenPut_thenThrowsEncodingFailed() async throws {
        // Given
        struct FailingEncodable: Encodable, Sendable {
            func encode(to encoder: Encoder) throws {
                throw NSError(domain: "Test", code: 123, userInfo: nil)
            }
        }

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.put(FailingEncodable(), forKey: "bad")) { error in
            guard let storageError = error as? PersistentStorageError,
                  case .encodingFailed(let ns, let key, _) = storageError else {
                XCTFail("Expected encodingFailed error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(key, "bad")
        }
    }

    func test_givenLegacyURLData_whenGetURL_thenHandlesLegacyDataFormat() async throws {
        // Given
        let key = "urlFromData"
        let url = URL(string: "https://swift.org")!
        let data = try NSKeyedArchiver.archivedData(withRootObject: url, requiringSecureCoding: false)
        let udKey = "\(namespace).\(key)"
        let userDefaults = UserDefaults(suiteName: "DefaultUserDefaultsStorageTests")!
        userDefaults.set(data, forKey: udKey)

        // When
        let result: URL = try await self.storage.get(forKey: key)

        // Then
        XCTAssertEqual(result, url)
    }

    // MARK: - Type Mismatch

    func test_givenIntStored_whenGetAsString_thenThrowsTypeMismatch() async throws {
        // Given
        try await storage.put(123, forKey: "typeMismatchKey")

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(forKey: "typeMismatchKey") as String) { error in
            guard let storageError = error as? PersistentStorageError,
                  case .foundButTypeMismatch(let ns, let key, _, _) = storageError else {
                XCTFail("Expected foundButTypeMismatch error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(key, "typeMismatchKey")
        }
    }

    func test_givenStringStored_whenGetAsInt_thenThrowsTypeMismatch() async throws {
        // Given
        try await storage.put("abc", forKey: "intButString")

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(forKey: "intButString") as Int) { error in
            guard let storageError = error as? PersistentStorageError,
                  case .foundButTypeMismatch(let ns, let key, _, _) = storageError else {
                XCTFail("Expected foundButTypeMismatch error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(key, "intButString")
        }
    }

    func test_givenStringStored_whenGetAsDouble_thenThrowsTypeMismatch() async throws {
        // Given
        try await storage.put("hello", forKey: "doubleButString")

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(forKey: "doubleButString") as Double) { error in
            guard let storageError = error as? PersistentStorageError,
                  case .foundButTypeMismatch(let ns, let key, _, _) = storageError else {
                XCTFail("Expected foundButTypeMismatch error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(key, "doubleButString")
        }
    }

    func test_givenStringStored_whenGetAsURL_thenThrowsTypeMismatch() async throws {
        // Given
        try await storage.put("notAURL", forKey: "urlButString")

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(forKey: "urlButString") as URL) { error in
            guard let storageError = error as? PersistentStorageError,
                  case .foundButTypeMismatch(let ns, let key, _, _) = storageError else {
                XCTFail("Expected foundButTypeMismatch error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(key, "urlButString")
        }
    }

    func test_givenFloatStored_whenGetAsString_thenThrowsTypeMismatch() async throws {
        // Given
        try await storage.put(Float(1.23), forKey: "floatAsString")

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(forKey: "floatAsString") as String) { error in
            guard let storageError = error as? PersistentStorageError,
                  case .foundButTypeMismatch(let ns, let key, _, _) = storageError else {
                XCTFail("Expected foundButTypeMismatch error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(key, "floatAsString")
        }
    }

    func test_givenStringStored_whenGetAsFloat_thenThrowsTypeMismatch() async throws {
        // Given
        try await storage.put("hello", forKey: "floatButString")

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(forKey: "floatButString") as Float) { error in
            guard let storageError = error as? PersistentStorageError,
                  case .foundButTypeMismatch(let ns, let key, _, _) = storageError else {
                XCTFail("Expected foundButTypeMismatch error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(key, "floatButString")
        }
    }

    func test_givenIntStored_whenGetAsDate_thenThrowsTypeMismatch() async throws {
        // Given
        try await storage.put(42, forKey: "dateButInt")

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(forKey: "dateButInt") as Date) { error in
            guard let storageError = error as? PersistentStorageError,
                  case .foundButTypeMismatch(let ns, let key, _, _) = storageError else {
                XCTFail("Expected foundButTypeMismatch error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(key, "dateButInt")
        }
    }

    func test_givenStringStored_whenGetAsData_thenThrowsTypeMismatch() async throws {
        // Given
        try await storage.put("notdata", forKey: "dataButString")

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(forKey: "dataButString") as Data) { error in
            guard let storageError = error as? PersistentStorageError,
                  case .foundButTypeMismatch(let ns, let key, _, _) = storageError else {
                XCTFail("Expected foundButTypeMismatch error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(key, "dataButString")
        }
    }

    // MARK: - Overwrite

    func test_givenKeyExists_whenPutAgain_thenValueIsOverwrittenAndNoDuplicateKey() async throws {
        // Given
        let initial = TestObject(id: 1, name: "First")
        let updated = TestObject(id: 2, name: "Second")
        try await storage.put(initial, forKey: "sharedKey")

        // When
        let keysAfterFirstPut = await storage.allKeys()
        try await storage.put(updated, forKey: "sharedKey")
        let keysAfterUpdate = await storage.allKeys()
        let result: TestObject = try await self.storage.get(forKey: "sharedKey")

        // Then
        XCTAssertEqual(keysAfterFirstPut, ["sharedKey"])
        XCTAssertEqual(keysAfterUpdate, ["sharedKey"])
        XCTAssertEqual(result, updated)
    }

    // MARK: - Helper

    func XCTAssertThrowsErrorAsync<T>(
        _ expression: @autoclosure @escaping () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error to be thrown" + (message().isEmpty ? "" : ": \(message())"), file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }
}
