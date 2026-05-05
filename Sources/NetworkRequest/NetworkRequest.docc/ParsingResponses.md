# Parsing Responses

`NetworkRequest` is generic over two parameters: the success `Response` and
the failure `ErrorResponse`. The right combination depends on your endpoint.

## The five typed shapes

Each row picks a different convenience initializer. The behavior column
describes what happens after `URLSession` hands the response back.

| `Response` | `ErrorResponse` | Behavior |
|---|---|---|
| `Decodable` | `Decodable & Error` | 2xx → decode `Response`. Non-2xx → decode and **throw** `ErrorResponse`. |
| `Decodable` | `Void` | Always decode `Response`. No status-code check. |
| `Data` | `Void` | Returns the raw response body. |
| `Void` | `Void` | Discards the body. Useful for fire-and-forget. |
| `Void` | `Decodable & Error` | 2xx → return `()`. Non-2xx → decode and **throw** `ErrorResponse`. |

When none of these fit (XML, MessagePack, mixed-content endpoints, custom
status-code rules), use the base
``NetworkRequest/NetworkRequest/init(urlRequest:parse:)`` and supply your own
`parse` closure.

## Status-code validation

The two overloads that take an error type validate the response is an
`HTTPURLResponse` with a status in `200..<300`. Anything else is assumed to
be a typed error envelope and is decoded — if **that** decode also fails,
the decoding error propagates.

If you need a different success window (for example treating 3xx as
success, or accepting only 200), reach for the base initializer.

## Decoding strategy

The Decodable overloads default to a `JSONDecoder` with
`dateDecodingStrategy = .iso8601`. Pass your own decoder to override:

```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase

let request = NetworkRequest<User, APIError>(
    url: URL(string: "https://api.example.com/me")!,
    decoder: decoder
)
```

## Concurrency

When `Response` and `ErrorResponse` both conform to `Sendable`, the
``NetworkRequest/NetworkRequest`` value itself becomes `Sendable` and can be
shared across actors and tasks. The five typed convenience initializers
require `Sendable` conformance on their type parameters; the base
``NetworkRequest/NetworkRequest/init(urlRequest:parse:)`` does not, so you
can drop down to it if you need to model a non-`Sendable` response type.
