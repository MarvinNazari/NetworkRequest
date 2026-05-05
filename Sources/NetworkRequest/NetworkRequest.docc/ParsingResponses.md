# Parsing Responses

`NetworkRequest` is generic over two parameters: the success `Response` and
the failure `ErrorResponse`. The type itself constrains
`ErrorResponse: Error`. The right combination depends on your endpoint.

## The typed shapes

Each row picks a different convenience initializer.

| `Response` | `ErrorResponse` | Status check | Behavior |
|---|---|---|---|
| `Decodable` | `Decodable` | ✅ 200..<300 | 2xx → decode `Response`. Non-2xx → decode `ErrorResponse` and throw. If that decode also fails, throws ``UnexpectedHTTPResponse``. |
| `Decodable` | `UnexpectedHTTPResponse` | ✅ 200..<300 | 2xx → decode `Response`. Non-2xx → throws ``UnexpectedHTTPResponse``. No envelope needed. |
| `Decodable` | `Never` | ❌ ignored | Always decodes the body as `Response`. |
| `Data` | `Decodable` | ✅ 200..<300 | 2xx → return raw bytes. Non-2xx → decode `ErrorResponse` and throw (or ``UnexpectedHTTPResponse`` on decode failure). |
| `Data` | `UnexpectedHTTPResponse` | ✅ 200..<300 | 2xx → return raw bytes. Non-2xx → throws ``UnexpectedHTTPResponse``. |
| `Data` | `Never` | ❌ ignored | Always returns the raw response bytes. |
| `Void` | `Decodable` | ✅ 200..<300 | 2xx → return `()`. Non-2xx → decode `ErrorResponse` and throw (or ``UnexpectedHTTPResponse`` on decode failure). |
| `Void` | `UnexpectedHTTPResponse` | ✅ 200..<300 | 2xx → return `()`. Non-2xx → throws ``UnexpectedHTTPResponse``. |
| `Void` | `Never` | ❌ ignored | Discards the body, always returns `()`. |

When none of these fit (XML, MessagePack, mixed-content endpoints, custom
status-code rules), use the base
``NetworkRequest/NetworkRequest/init(urlRequest:parse:)`` and supply your
own `parse` closure.

## Picking a row

- **JSON API with a structured error envelope** → `Decodable + Decodable`.
- **JSON API where failures are just status codes** →
  `Decodable + UnexpectedHTTPResponse`. No need to invent a placeholder
  error type.
- **No status-code awareness wanted** (e.g. you'll inspect the response
  yourself) → `* + Never`. The parse layer simply hands you what came
  back.
- **Binary downloads** → `Data + ...`.
- **Fire-and-forget / DELETE** → `Void + ...`.

## Status-code validation

The status-validated rows use the half-open range `200..<300`. Status
codes outside that range (including responses that aren't
`HTTPURLResponse` at all — rare, but possible with custom transports)
take the error path.

If you need a different success window (treat 3xx as success, accept only
200, etc.), use the base initializer and write the check yourself.

## Decoding strategy

The Decodable overloads default to `JSONDecoder.iso8601` (ISO-8601 date
handling). Pass your own decoder to override:

```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase

let request = NetworkRequest<User, APIError>(
  url: URL(string: "https://api.example.com/me")!,
  decoder: decoder
)
```

The same decoder is used for both the success body and the error body —
they should share key/date strategies.

## Concurrency

When `Response` and `ErrorResponse` both conform to `Sendable`,
``NetworkRequest/NetworkRequest`` itself becomes `Sendable` and can be
shared across actors and tasks. The Decodable / Data / Void typed
convenience initializers require `Sendable` on their type parameters
(`sendable-metatypes` rule); the base
``NetworkRequest/NetworkRequest/init(urlRequest:parse:)`` and the
component-based generic initializer do not — drop down to those if you
need to model a non-`Sendable` response type.
