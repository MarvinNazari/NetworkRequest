# Building Requests

Configure the HTTP method, headers, cache policy, and timeout for a
request — and inspect what's about to go on the wire.

## HTTP method

Pass any of the built-in ``HTTPMethod`` cases:

```swift
let delete = NetworkRequest<Void, APIError>(
  httpMethod: .delete,
  url: URL(string: "https://api.example.com/users/42")!
)
```

Define custom methods by initializing ``HTTPMethod`` directly:

```swift
extension HTTPMethod {
  static let link = HTTPMethod(rawValue: "LINK")
}
```

## Headers

`Accept: application/json` is set automatically. When you pass a
``NetworkRequestBody``, its `contentType` is added as `Content-Type`.
Anything you put in `additionalHeaderFields` is applied last and wins on
collision:

```swift
let request = NetworkRequest<User, APIError>(
  url: URL(string: "https://api.example.com/me")!,
  additionalHeaderFields: [
    "Authorization": "Bearer \(token)",
    "X-Client-Version": appVersion,
  ]
)
```

## Cache policy and timeout

Both default to the system defaults. Override on a per-request basis:

```swift
let request = NetworkRequest<User, APIError>(
  url: URL(string: "https://api.example.com/me")!,
  cachePolicy: .reloadIgnoringLocalCacheData,
  timeoutInterval: 10
)
```

## Lazy URL evaluation

The `url` parameter is evaluated **each time** ``NetworkRequest/NetworkRequest/urlRequest``
is invoked. That means you can bake in values that should be resolved at
dispatch time, not at construction time:

```swift
let now = NetworkRequest<Telemetry, APIError>(
  url: URL(string: "https://api.example.com/now?t=\(Date().timeIntervalSince1970)")!
)
```

When you build a request from individual components, the `url:` parameter
is an `@autoclosure` — passing a non-trivial expression defers it.

## Debugging with cURL

Every ``NetworkRequest/NetworkRequest`` exposes a
``NetworkRequest/NetworkRequest/cURLCommand`` property that renders an
equivalent `curl` invocation, including method, headers, body, and cookies
in the shared cookie storage. Paste it into a terminal to reproduce the
request outside your app:

```swift
print(request.cURLCommand ?? "<request unavailable>")
// curl -X POST -d "..." -H 'Content-Type: application/json' "https://api.example.com/users"
```

The property returns `nil` if the URL closure throws or the underlying
request has no URL. Header values containing apostrophes are escaped using
the ANSI-C `'\''` trick so the rendered command pastes cleanly into a
shell. Binary (non-UTF-8) bodies are reported as
`# (binary body of N bytes omitted)` rather than producing a misleading
`-d ""`.
