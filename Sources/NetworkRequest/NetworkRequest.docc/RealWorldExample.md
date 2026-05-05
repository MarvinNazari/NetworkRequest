# A Real-World Example

A complete, end-to-end example of wrapping `NetworkRequest` in a small API
client, including bearer auth and typed error handling.

## One way to do it (not the only way)

`NetworkRequest` deliberately stays out of the way of how you dispatch
requests. The pattern below is **one** layout that scales well — it's
roughly the shape of a real production client built on this library. Don't
treat it as canonical: a different app might keep things flatter (a free
function per endpoint), use Combine, or use a third-party transport. The
library doesn't care.

The recipe in three pieces:

1. A **configuration** value carrying the base URL, the URLSession, and any
   shared headers.
2. A small **request factory** that defers `NetworkRequest` construction
   until configuration is available.
3. An **API client** that turns a request factory into a real
   `URLSession` call, threads in the bearer token, and unwraps errors.

## Configuration

```swift
import Foundation

public struct APIConfiguration: Sendable {
  public let baseURL: URL
  public let urlSession: URLSession
  public let additionalHeaderFields: [String: String]

  public init(
    baseURL: URL,
    urlSession: URLSession = .shared,
    additionalHeaderFields: [String: String] = [:]
  ) {
    self.baseURL = baseURL
    self.urlSession = urlSession
    self.additionalHeaderFields = additionalHeaderFields
  }
}
```

## Request factory

A tiny wrapper around a closure that builds a ``NetworkRequest`` from an
`APIConfiguration`. The `authorized` flag tells the client whether to
attach a bearer token.

```swift
import NetworkRequest

public struct APIRequest<Response: Sendable>: Sendable {
  public let authorized: Bool
  public let request: @Sendable (APIConfiguration) throws -> NetworkRequest<Response, APIError>

  public init(
    authorized: Bool = true,
    request: @Sendable @escaping (APIConfiguration) throws -> NetworkRequest<Response, APIError>
  ) {
    self.authorized = authorized
    self.request = request
  }
}

public struct APIError: Decodable, Error, Sendable {
  public let message: String
}
```

## Client

A small actor that dispatches an `APIRequest`. It calls the
`accessToken` closure on demand so callers can keep tokens in a keychain,
refresh them lazily, etc.

```swift
public actor APIClient {
  private let configuration: APIConfiguration
  private let accessToken: @Sendable () async throws -> String?

  public init(
    configuration: APIConfiguration,
    accessToken: @Sendable @escaping () async throws -> String? = { nil }
  ) {
    self.configuration = configuration
    self.accessToken = accessToken
  }

  @discardableResult
  public func send<Response>(
    _ apiRequest: APIRequest<Response>
  ) async throws -> Response {
    let networkRequest = try apiRequest.request(configuration)
    var urlRequest = try networkRequest.urlRequest()

    for (key, value) in configuration.additionalHeaderFields {
      urlRequest.setValue(value, forHTTPHeaderField: key)
    }

    if apiRequest.authorized, let token = try await accessToken() {
      urlRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    let (data, response) = try await configuration.urlSession.data(for: urlRequest)
    return try networkRequest.parse(data, response)
  }
}
```

The single point that ties it all together is
`networkRequest.parse(data, response)` — that's where ``NetworkRequest``
either decodes the success type or throws your typed `APIError`.

## Defining endpoints

With those primitives, an endpoint is one short factory function:

```swift
struct User: Decodable, Sendable {
  let id: Int
  let name: String
}

extension APIRequest where Response == User {
  static func fetchCurrentUser() -> Self {
    APIRequest { config in
      NetworkRequest(
        url: config.baseURL.appendingPathComponent("me")
      )
    }
  }
}

extension APIRequest where Response == User {
  static func updateName(_ name: String) -> Self {
    APIRequest { config in
      // The `try` is for `.json(parameters:)`, which can throw
      // encoder errors — `NetworkRequest.init` itself does not throw.
      try NetworkRequest(
        httpMethod: .patch,
        url: config.baseURL.appendingPathComponent("me"),
        body: .json(parameters: ["name": name])
      )
    }
  }
}
```

## Calling sites

```swift
let client = APIClient(
  configuration: APIConfiguration(
    baseURL: URL(string: "https://api.example.com")!
  ),
  accessToken: { keychain.loadAccessToken() }
)

let me = try await client.send(.fetchCurrentUser())
let updated = try await client.send(.updateName("Ada"))
```

## What this example is doing for you

- The endpoint factories don't know about networking — they just describe
  the request. Easy to test by calling them with a stub `APIConfiguration`
  and inspecting the resulting `URLRequest`.
- The client is the only place that touches `URLSession` — swap it for
  `URLProtocol`-based mocks in tests without touching endpoint code.
- Authentication, base URL, and shared headers all live in one place;
  endpoints stay declarative.

## Other directions you might take

- **No wrapper at all.** Just call `try NetworkRequest(...)` inline,
  `URLSession.shared.data(for: request.urlRequest())`, and
  `request.parse(...)`. Perfectly fine for small apps.
- **Combine instead of async/await.** Map `URLSession.dataTaskPublisher`
  through `tryMap { try networkRequest.parse($0.data, $0.response) }`.
- **Retry, refresh-on-401, request signing.** Layer those into the
  client's `send`; the request itself stays unchanged.
- **Custom decoders per endpoint.** Pass `decoder:` into the
  `NetworkRequest` initializer that takes one — useful for APIs with
  unusual date formats or snake_case keys.

The library's job is to give you a typed, immutable description of a
request. What you do with that description is up to you.
