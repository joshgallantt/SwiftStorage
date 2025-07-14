<div align="center">

<h1>SwiftStorage</h1>

[![Platforms](https://img.shields.io/badge/Platforms-iOS%2016%2B%20%7C%20iPadOS%2016%2B%20%7C%20macOS%2013%2B%20%7C%20watchOS%209%2B%20%7C%20tvOS%2016%2B%20%7C%20visionOS%201%2B-blue.svg?style=flat)](#requirements)
<br>

[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg?style=flat)](https://swift.org)
[![SPM ready](https://img.shields.io/badge/SPM-ready-brightgreen.svg?style=flat-square)](https://swift.org/package-manager/)
[![Coverage](https://img.shields.io/badge/Coverage-99.1%25-brightgreen.svg?style=flat)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

</div>

Offers type-safe persistent storage and in-memory caching in Swift applications. It features async/await-based APIs, namespace isolation, robust error handling, and built-in support for UserDefaults and multiple in-memory cache strategies.

## <br><br> Features

- Async/await support for storage operations
- Type-safe put/get for any Codable value
- Namespace isolation for UserDefaults-backed storage
- Custom error types for encoding/decoding, not found, and type mismatch
- In-memory LRU cache (with and without Combine)
- Easy to mock/test via protocols

## <br><br> Persistent Storage

UserDefaultsStorage protocol defines the API for persistent storage:

```Swift
public protocol UserDefaultsStorage: Actor {
    var namespace: String { get }
    func put<T: Encodable & Sendable>(_ value: T, forKey key: String) async throws
    func get<T: Decodable & Sendable>(forKey key: String) async throws -> T
    func remove(forKey key: String) async
    func clear() async
    func allKeys() async -> [String]
    func contains(_ key: String) async -> Bool
}
```

DefaultUserDefaultsStorage provides an actor-backed implementation using UserDefaults under a namespace. It supports String, Int, Double, Bool, Float, Date, URL, Data, and custom Codable types.

Example Usage:

```Swift
let storage = DefaultUserDefaultsStorage(namespace: "MyApp")

try await storage.put("Hello, SwiftStorage!", forKey: "greeting")
let greeting: String = try await storage.get(forKey: "greeting")

try await storage.put(User(id: 42, name: "Jane"), forKey: "currentUser")
let user: User = try await storage.get(forKey: "currentUser")

await storage.remove(forKey: "greeting")
await storage.clear()
```

## <br><br> In-Memory Storage

### <br><br> DefaultMemoryCache

A thread-safe, generic in-memory cache with LRU eviction and optional TTL expiry. Just simple fast key/value storage. Order is maintained.

```Swift
let cache = DefaultMemoryCache<String, [MyStruct]>(maxSize: 200, expiresAfter: 30)

let myList = [
    MyStruct(id: 1, name: "First"),
    MyStruct(id: 2, name: "Second")
]

cache.put("users", value: myList)

let retrieved = cache.get("users")

cache.remove("users")

cache.clear()
```

Use when you need a fast cache without reactive observation or Combine dependencies.

### <br><br> DefaultCombineMemoryCache

A thread-safe, generic in-memory cache with LRU eviction, optional TTL, and per-key Combine publishers for observation.

```Swift
let cache = DefaultCombineMemoryCache<String, Data>(maxSize: 100, expiresAfter: 60)
cache.put("image1", value: myData)
let currentData = cache.get("image1")

let cancellable = cache.publisher(for: "image1").sink { newValue in
    print("Current value for image1:", newValue)
}

cache.remove("image1") // Publisher emits nil
cache.clear()
```

#### However, if you prefer Clean Architecture, here is an example:

**1. Create your repository and initialise the Cache**

```Swift
import Combine

final class WishlistRepository {
    private let cache: ObservableMemoryCache<String, Set<String>>
    private let service: WishlistService
    private let wishlistKey = "wishlist"

    init(cache: ObservableMemoryCache<String, Set<String>>, service: WishlistService) {
        self.cache = cache
        self.service = service
    }

    func observeIsWishlisted(productID: String) -> AnyPublisher<Bool, Never> {
        cache.publisher(for: wishlistKey)
            .map { ids in ids?.contains(productID) ?? false }
            .eraseToAnyPublisher()
    }

    func addToWishlist(productID: String) async throws {
        let updatedIDs = try await service.addProduct(productID: productID)
        cache.put(wishlistKey, value: Set(updatedIDs))
    }

    func removeFromWishlist(productID: String) async throws {
        let updatedIDs = try await service.removeProduct(productID: productID)
        cache.put(wishlistKey, value: Set(updatedIDs))
    }
}
```

**2. Use Cases use the Cache**

```Swift
struct ObserveProductInWishlistUseCase {
    private let repository: WishlistRepository
    init(repository: WishlistRepository) { self.repository = repository }

    func execute(productID: String) -> AnyPublisher<Bool, Never> {
        repository.observeIsWishlisted(productID: productID)
            .removeDuplicates() // Ensures only changes are delivered to ViewModel
            .eraseToAnyPublisher()
    }
}

struct AddProductToWishlistUseCase {
    private let repository: WishlistRepository
    init(repository: WishlistRepository) { self.repository = repository }

    func execute(productID: String) async throws {
        try await repository.addToWishlist(productID: productID)
    }
}

struct RemoveProductFromWishlistUseCase {
    private let repository: WishlistRepository
    init(repository: WishlistRepository) { self.repository = repository }

    func execute(productID: String) async throws {
        try await repository.removeFromWishlist(productID: productID)
    }
}
```

**3. ViewModels use the Use Cases**

```Swift
import Combine
import Foundation

@MainActor
final class WishlistButtonViewModel: ObservableObject {
    @Published private(set) var isWishlisted: Bool = false

    private let productID: String
    private let observeProductInWishlist: ObserveProductInWishlistUseCase
    private let addProductToWishlist: AddProductToWishlistUseCase
    private let removeProductFromWishlist: RemoveProductFromWishlistUseCase

    private var cancellables = Set<AnyCancellable>()

    init(
        productID: String,
        observeProductInWishlist: ObserveProductInWishlistUseCase,
        addProductToWishlist: AddProductToWishlistUseCase,
        removeProductFromWishlist: RemoveProductFromWishlistUseCase
    ) {
        self.productID = productID
        self.observeProductInWishlist = observeProductInWishlist
        self.addProductToWishlist = addProductToWishlist
        self.removeProductFromWishlist = removeProductFromWishlist

        observeWishlistState()
    }

    private func observeWishlistState() {
        observeProductInWishlist.execute(productID: productID)
            .receive(on: DispatchQueue.main)
            .assign(to: &$isWishlisted)
    }

    func toggleWishlist() {
        let newValue = !isWishlisted
        isWishlisted = newValue

        Task(priority: .userInitiated) { [self, newValue] in
            do {
                if newValue {
                    try await addProductToWishlist.execute(productID: productID)
                } else {
                    try await removeProductFromWishlist.execute(productID: productID)
                }
            } catch {
                await MainActor.run {
                    isWishlisted = !newValue
                }
            }
        }
    }
}
```

## <br> License

MIT – see [`LICENSE`](./LICENSE)

## <br> Questions or Feedback?

Open an issue or join a discussion!

<br>

Made with ❤️ by Josh Gallant
