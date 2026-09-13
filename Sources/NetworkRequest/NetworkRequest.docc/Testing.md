# Testing

Unit test request building and response parsing without the network.

## Overview

Because a ``NetworkRequest/NetworkRequest`` is just two closures, you can test
it by calling ``NetworkRequest/NetworkRequest/urlRequest`` and
``NetworkRequest/NetworkRequest/parse`` directly. For end-to-end tests that
also exercise `URLSession`, the package ships a separate
**`NetworkRequestTesting`** product. Add it to your test target only — it
never needs to ship in your app:

```swift
.testTarget(
  name: "MyAppTests",
  dependencies: [
    "MyApp",
    .product(name: "NetworkRequestTesting", package: "NetworkRequest"),
  ]
)
```

The product is deliberately small. It adds exactly three types —
`StubURLProtocol`, `RequestRecorder` and `RecordedRequest` — and no
extensions on `NetworkRequest`, `URLRequest`, `URLSession` or any other type
it does not own.

### Sending a request

The core library already exposes everything a test needs, so sending a
request is two lines — the same two lines production code uses:

```swift
let (data, response) = try await session.data(for: try request.urlRequest())
let value = try request.parse(data, response)
```

Typed error envelopes and ``NetworkRequest/UnexpectedHTTPResponse`` are
thrown from `parse` exactly as they are in production. If a suite sends many
requests, wrap those two lines in a local helper in your own test target.

### Stubbing a session

`StubURLProtocol.session(_:)` returns an ephemeral `URLSession` whose every
request is answered by your handler. Each session has its own handler, so
tests can run in parallel without sharing state.

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

  let (data, response) = try await session.data(for: try me.urlRequest())
  let user = try me.parse(data, response)

  #expect(user.name == "Ada")
  let sent = try #require(await recorder.last)
  #expect(sent.path == "/me")
  #expect(sent.headers["Authorization"] == "Bearer \(token)")
}
```

### Canned responses and failures

- `StubURLProtocol.session(returning:)` answers every request with the same
  `Response`.
- `StubURLProtocol.session(sequence:)` answers requests in order; once the
  script is exhausted an extra request fails with a descriptive
  `SequenceExhausted` error instead of silently reusing an earlier reply.
- `StubURLProtocol.session(recording:returning:)` records into a
  `RequestRecorder` and always replies the same way.
- `.failure(URLError(.notConnectedToInternet))` makes `URLSession` throw a
  transport error, so you can test retry and offline paths.

`Response` has `.json(_:status:)`, `.data(_:contentType:status:)` and
`.empty(status:)` factories, or build one from `status`, `headers` and
`body` directly.

### Asserting on the request that was sent

`RequestRecorder` is an actor that stores every request it is handed as a
`RecordedRequest`. That value type carries the original `urlRequest` plus
read-only helpers: `url`, `method`, `path`, `headers`, `queryItems`,
`queryDictionary`, `body`, `bodyString`, `jsonBody()`, `jsonArrayBody()` and
`formBody` (for `application/x-www-form-urlencoded`).

The JSON accessors throw rather than returning `nil`, so a malformed or
unexpectedly shaped body fails the test loudly instead of reading as "no
body". Wrap any `URLRequest` you already have — including one you just
built — to get the same helpers:

```swift
let built = RecordedRequest(try createUser.urlRequest())
#expect(built.method == "POST")
#expect(try built.jsonBody()["name"] as? String == "Ada")
```
