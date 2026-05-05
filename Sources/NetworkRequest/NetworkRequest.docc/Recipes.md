# Recipes

Short, self-contained patterns for the things every consumer of
`NetworkRequest` ends up doing. Copy-paste, then adapt.

## A minimal `URLSession` helper

The smallest amount of glue you can write to dispatch a request. Drop this
into your project and you have an end-to-end pipeline:

```swift
import Foundation
import NetworkRequest

extension URLSession {
  func send<Response, ErrorResponse>(
    _ request: NetworkRequest<Response, ErrorResponse>
  ) async throws -> Response {
    let (data, response) = try await self.data(for: request.urlRequest())
    return try request.parse(data, response)
  }
}

// Usage:
let user = try await URLSession.shared.send(
  NetworkRequest<User, APIError>(url: URL(string: "https://api.example.com/me")!)
)
```

## Bearer-token authentication with on-demand refresh

A common shape: a closure supplies the access token, the dispatcher
attaches it as `Authorization: Bearer …`, and a 401 triggers a refresh.

```swift
public actor APIClient {
  private let urlSession: URLSession
  private let accessToken: @Sendable () async throws -> String?
  private let refresh: @Sendable () async throws -> Void

  public init(
    urlSession: URLSession = .shared,
    accessToken: @Sendable @escaping () async throws -> String?,
    refresh: @Sendable @escaping () async throws -> Void
  ) {
    self.urlSession = urlSession
    self.accessToken = accessToken
    self.refresh = refresh
  }

  public func send<Response, ErrorResponse>(
    _ request: NetworkRequest<Response, ErrorResponse>,
    authorized: Bool = true
  ) async throws -> Response {
    try await dispatch(request, authorized: authorized, retried: false)
  }

  private func dispatch<R, E>(
    _ request: NetworkRequest<R, E>,
    authorized: Bool,
    retried: Bool
  ) async throws -> R {
    var urlRequest = try request.urlRequest()
    if authorized, let token = try await accessToken() {
      urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    let (data, response) = try await urlSession.data(for: urlRequest)
    let status = (response as? HTTPURLResponse)?.statusCode

    if status == 401, !retried {
      try await refresh()
      return try await dispatch(request, authorized: authorized, retried: true)
    }

    return try request.parse(data, response)
  }
}
```

Keep tokens in the keychain and pass `accessToken: { keychain.load() }` —
the closure is called on every request so token rotation is invisible to
endpoint code.

## Mocking in tests with `URLProtocol`

The same trick `NetworkRequest`'s own test suite uses. Stub responses
without touching the network:

```swift
final class URLProtocolMock: URLProtocol {
  nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = URLProtocolMock.handler else {
      client?.urlProtocol(self, didFailWithError: NSError(domain: "Mock", code: 0))
      return
    }
    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}

func makeMockSession() -> URLSession {
  let config = URLSessionConfiguration.ephemeral
  config.protocolClasses = [URLProtocolMock.self]
  return URLSession(configuration: config)
}
```

Use it in a test:

```swift
URLProtocolMock.handler = { _ in
  let url = URL(string: "https://test.local")!
  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
  return (response, Data(#"{"id":1,"name":"Ada"}"#.utf8))
}
let session = makeMockSession()
let user = try await session.send(NetworkRequest<User, APIError>(url: URL(string: "https://test.local")!))
```

## Logging every request

Layer logging into your dispatcher. The
``NetworkRequest/NetworkRequest/cURLCommand`` property is the single most
useful thing to print:

```swift
import os

extension URLSession {
  func send<Response, ErrorResponse>(
    _ request: NetworkRequest<Response, ErrorResponse>,
    logger: Logger
  ) async throws -> Response {
    if let curl = request.cURLCommand {
      logger.debug("→ \(curl, privacy: .public)")
    }
    let urlRequest = try request.urlRequest()
    let (data, response) = try await self.data(for: urlRequest)
    let status = (response as? HTTPURLResponse)?.statusCode ?? -1
    logger.debug("← \(status) \(data.count) bytes")
    return try request.parse(data, response)
  }
}
```

## Retry with exponential backoff

For idempotent requests on transient failures (5xx, transport errors).
Keep it deliberate — don't retry every error indiscriminately:

```swift
extension URLSession {
  func sendWithRetry<R, E>(
    _ request: NetworkRequest<R, E>,
    maxAttempts: Int = 3
  ) async throws -> R {
    var attempt = 0
    while true {
      attempt += 1
      do {
        return try await send(request)
      } catch let error as UnexpectedHTTPResponse where (500..<600).contains(error.statusCode) && attempt < maxAttempts {
        try await Task.sleep(for: .seconds(pow(2.0, Double(attempt - 1))))
        continue
      } catch let error as URLError where error.isTransient && attempt < maxAttempts {
        try await Task.sleep(for: .seconds(pow(2.0, Double(attempt - 1))))
        continue
      }
    }
  }
}

private extension URLError {
  var isTransient: Bool {
    [.timedOut, .networkConnectionLost, .notConnectedToInternet, .dnsLookupFailed].contains(code)
  }
}
```

## Multi-format date decoding

Real APIs return ISO-8601 with milliseconds, plain ISO-8601, and (sigh)
date-only strings — sometimes in the same response. A custom strategy that
falls through formats in order:

```swift
extension JSONDecoder {
  static var apiDecoder: JSONDecoder {
    let formatters: [ISO8601DateFormatter] = [
      {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
      }(),
      {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
      }(),
    ]
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let string = try decoder.singleValueContainer().decode(String.self)
      for formatter in formatters {
        if let date = formatter.date(from: string) {
          return date
        }
      }
      throw DecodingError.dataCorruptedError(
        in: try decoder.singleValueContainer(),
        debugDescription: "Cannot decode date string \(string)"
      )
    }
    return decoder
  }
}

let request = NetworkRequest<Activity, APIError>(
  url: URL(string: "https://api.example.com/activities/1")!,
  decoder: .apiDecoder
)
```

## Pagination with cursors

Compose multiple requests into one async sequence. The library doesn't
offer pagination as a primitive — but the deferred-URL closure makes it
easy to build:

```swift
struct Page<Item: Decodable & Sendable>: Decodable, Sendable {
  let items: [Item]
  let nextCursor: String?
}

extension URLSession {
  func paginated<Item, ErrorResponse>(
    base: URL,
    errorType: ErrorResponse.Type
  ) -> AsyncThrowingStream<Item, Error> where Item: Decodable & Sendable, ErrorResponse: Decodable & Sendable & Error {
    AsyncThrowingStream { continuation in
      Task {
        var cursor: String? = nil
        repeat {
          let page: Page<Item> = try await send(
            NetworkRequest<Page<Item>, ErrorResponse>(
              url: cursor.map { base.appending(queryItems: [.init(name: "cursor", value: $0)]) } ?? base
            )
          )
          for item in page.items { continuation.yield(item) }
          cursor = page.nextCursor
        } while cursor != nil
        continuation.finish()
      }
    }
  }
}
```

## Inspecting response headers

The base init's `parse` closure receives the full `URLResponse`. Cast it
when you need headers:

```swift
let request = NetworkRequest<(User, String?), APIError>(
  httpMethod: .get,
  url: { URL(string: "https://api.example.com/me")! },
  parse: { data, response in
    let http = response as? HTTPURLResponse
    let etag = http?.value(forHTTPHeaderField: "ETag")
    let user = try JSONDecoder.iso8601.decode(User.self, from: data)
    return (user, etag)
  }
)
```
