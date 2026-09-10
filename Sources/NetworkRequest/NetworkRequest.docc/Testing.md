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

  let user = try await me.send(using: session)

  #expect(user.name == "Ada")
  let sent = try #require(await recorder.last)
  #expect(sent.url?.path == "/me")
  #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer \(token)")
}
```

`send(using:)` builds the `URLRequest`, sends it, and parses the reply — so
typed error envelopes and `UnexpectedHTTPResponse` are thrown exactly as in
production code.

### Canned responses and failures

- `StubURLProtocol.session(returning:)` answers every request with the same
  `Response`.
- `StubURLProtocol.session(sequence:)` answers requests in order; once the
  script is exhausted an extra request fails with a descriptive
  `SequenceExhausted` error instead of silently reusing an earlier reply.
- `.failure(URLError(.notConnectedToInternet))` makes `URLSession` throw a
  transport error, so you can test retry and offline paths.

`Response` has `.json(_:status:)`, `.data(_:contentType:status:)` and
`.empty(status:)` factories, or build one from `status`, `headers` and
`body` directly.

### Asserting on the built request

`URLRequest` gains read-only helpers for assertions: `queryItems`,
`queryDictionary`, `bodyString`, `jsonBody`, `jsonArrayBody` and `formBody`
(for `application/x-www-form-urlencoded`). `makeURLRequest()` is a readable
alias for invoking the `urlRequest` closure:

```swift
let built = try createUser.makeURLRequest()
#expect(built.httpMethod == "POST")
#expect(built.jsonBody?["name"] as? String == "Ada")
```
