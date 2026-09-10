# NetworkRequest

A tiny, type-safe, dependency-free HTTP request builder for Swift.

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2013%20%7C%20macOS%2010.15%20%7C%20tvOS%2013%20%7C%20watchOS%206-blue.svg)](https://swift.org)
[![SPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)](https://swift.org/package-manager)
[![License](https://img.shields.io/badge/license-MIT-black.svg)](LICENSE)
[![CI](https://github.com/MarvinNazari/NetworkRequest/actions/workflows/ci.yml/badge.svg)](https://github.com/MarvinNazari/NetworkRequest/actions/workflows/ci.yml)

`NetworkRequest` describes an HTTP request and how to parse its response as a
single, immutable value. It does **not** execute itself — `URLSession`,
`async`/`await`, Combine, or any mock you like is in charge of dispatch.
The library just gives you a strongly-typed, composable description of the
work.

## Quick start

```swift
import NetworkRequest

struct User: Decodable, Sendable {
    let id: Int
    let name: String
}

struct APIError: Decodable, Error, Sendable {
    let message: String
}

let me = NetworkRequest<User, APIError>(
    url: URL(string: "https://api.example.com/me"),
    additionalHeaderFields: ["Authorization": "Bearer \(token)"]
)

let (data, response) = try await URLSession.shared.data(for: me.urlRequest())
let user = try me.parse(data, response)
```

A non-2xx response decodes the body as `APIError` and throws it — your
`do/catch` block sees a typed error.

## Why NetworkRequest?

- **Type-safe.** A `NetworkRequest<User, APIError>` carries both the success
  and the failure shape in its type.
- **Execution-agnostic.** No baked-in transport. Use `URLSession`, mock it,
  swap it for Combine, plug in your own.
- **Sendable-clean.** Builds cleanly under Swift 6 strict concurrency and
  conditionally conforms to `Sendable` when its generic parameters do.
- **Zero dependencies.** Just Foundation.
- **Built-in cURL debugging.** `request.cURLCommand` reproduces a request
  on the command line.

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/MarvinNazari/NetworkRequest", from: "1.0.0"),
],
targets: [
    .target(name: "MyApp", dependencies: ["NetworkRequest"]),
]
```

In Xcode: **File ▸ Add Package Dependencies…** and paste the URL.

## Testing

The package ships a second product, **`NetworkRequestTesting`**, so you can
unit test request building and response parsing without touching the
network. Add it to your test target only:

```swift
.testTarget(
    name: "MyAppTests",
    dependencies: ["MyApp", .product(name: "NetworkRequestTesting", package: "NetworkRequest")]
)
```

`StubURLProtocol` builds an isolated `URLSession` that answers every request
through your handler, and `send(using:)` runs a `NetworkRequest` through it
in one line:

```swift
import Testing
import NetworkRequest
import NetworkRequestTesting

@Test func fetchesTheCurrentUser() async throws {
    let recorder = RequestRecorder()
    let session = StubURLProtocol.session { request in
        await recorder.record(request)
        return .response(.json(#"{"id":1,"name":"Ada"}"#))
    }

    let user = try await me.send(using: session)

    #expect(user.name == "Ada")
    let sent = try #require(await recorder.last)
    #expect(sent.url?.path == "/me")
    #expect(sent.queryDictionary == ["expand": "profile"])
    #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer \(token)")
}
```

Also included:

- `StubURLProtocol.session(returning:)` — same response every time.
- `StubURLProtocol.session(sequence:)` — scripted responses in order; an
  extra request fails with a descriptive `SequenceExhausted` error.
- `.failure(URLError(...))` outcomes to simulate transport errors.
- `URLRequest` inspection helpers: `queryItems`, `queryDictionary`,
  `bodyString`, `jsonBody`, `jsonArrayBody`, `formBody`.
- `NetworkRequest.makeURLRequest()` for assertions on the built request.

Every stub session has its own handler, so suites run safely in parallel.

## Documentation

Full API reference and articles (Getting Started, A Real-World Example,
Recipes, Building Requests, Parsing Responses, Request Bodies) are
published as **[Documentation](https://wavio.co/NetworkRequest/documentation/networkrequest/)**.

The same documentation is bundled as a DocC catalog inside the package; in
Xcode, choose **Product ▸ Build Documentation** to browse it locally.

## Requirements

- Swift 6.2 toolchain (Xcode 17+)
- iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+

## License

MIT — see [LICENSE](LICENSE).
