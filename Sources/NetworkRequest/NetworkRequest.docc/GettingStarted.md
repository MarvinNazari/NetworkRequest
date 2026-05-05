# Getting Started

Add NetworkRequest to your project, define your first typed request, and
dispatch it with `URLSession`.

## Installation

### Swift Package Manager

Add NetworkRequest to your `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/MarvinNazari/NetworkRequest", from: "1.0.0"),
],
targets: [
  .target(
    name: "MyApp",
    dependencies: ["NetworkRequest"]
  ),
]
```

### Xcode

In Xcode, choose **File ▸ Add Package Dependencies…**, enter the repository
URL, and select the `NetworkRequest` library product.

## Your first request

Model your response and (optionally) your API's error envelope:

```swift
import NetworkRequest

struct User: Decodable, Sendable {
  let id: Int
  let name: String
}

struct APIError: Decodable, Error, Sendable {
  let message: String
}
```

Build a typed request:

```swift
let me = NetworkRequest<User, APIError>(
  url: URL(string: "https://api.example.com/me"),
  additionalHeaderFields: ["Authorization": "Bearer \(token)"]
)
```

Dispatch it through any transport. With `async`/`await`:

```swift
let (data, response) = try await URLSession.shared.data(for: me.urlRequest())
let user = try me.parse(data, response)
```

If the server returns a non-2xx status, ``NetworkRequest/NetworkRequest``
decodes the body as `APIError` and **throws** it — your `do/catch` block
sees it as a typed `APIError`. If the body can't be decoded as `APIError`
(unexpected HTML error page, empty body, etc.), the request throws
``UnexpectedHTTPResponse`` instead, preserving the status code and raw
bytes for diagnostics.

If your API doesn't have a structured error envelope, use
``UnexpectedHTTPResponse`` directly as the error type:

```swift
let me = NetworkRequest<User, UnexpectedHTTPResponse>(
  url: URL(string: "https://api.example.com/me")
)
```

Or use `Never` if you don't want any status-code validation at all:

```swift
let me = NetworkRequest<User, Never>(
  url: URL(string: "https://api.example.com/me")
)
```

## A POST with a body

```swift
struct CreateUser: Encodable {
  let name: String
}

let create = NetworkRequest<User, APIError>(
  httpMethod: .post,
  url: URL(string: "https://api.example.com/users"),
  body: try .json(parameters: CreateUser(name: "Ada"))
)

let (data, response) = try await URLSession.shared.data(for: create.urlRequest())
let user = try create.parse(data, response)
```

## Where to next

- <doc:RealWorldExample> — a complete example wrapping NetworkRequest in an API client with bearer auth.
- <doc:Recipes> — copy-paste patterns for dispatch, mocking, retry, logging, pagination.
- <doc:BuildingRequests> — methods, headers, cache policy, timeouts, debugging.
- <doc:ParsingResponses> — pick the right convenience initializer for your endpoint.
- <doc:RequestBodies> — JSON, form-urlencoded, and custom payloads.
