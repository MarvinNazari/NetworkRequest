# ``NetworkRequest``

A tiny, type-safe, dependency-free HTTP request builder for Swift.

## Overview

`NetworkRequest` describes an HTTP request and how to parse its response as
a single, immutable value. It is **execution-agnostic**: the library never
calls the network for you. Instead, a ``NetworkRequest/NetworkRequest`` bundles
two closures — one that builds a `URLRequest` and one that parses the
response — leaving you free to dispatch the request through `URLSession`,
`async`/`await`, Combine, a mock, or any other transport.

```swift
struct User: Decodable, Sendable { let id: Int; let name: String }
struct APIError: Decodable, Error, Sendable { let message: String }

let request = NetworkRequest<User, APIError>(
    url: URL(string: "https://api.example.com/me")!,
    additionalHeaderFields: ["Authorization": "Bearer \(token)"]
)

let (data, response) = try await URLSession.shared.data(for: request.urlRequest())
let user = try request.parse(data, response)
```

The two generic parameters — `Response` and `ErrorResponse` — let the call
site know at compile time both what a successful payload looks like and what
kind of error the API may return.

## Topics

### Essentials

- <doc:GettingStarted>

### Building Requests

- ``NetworkRequest/NetworkRequest``
- ``HTTPMethod``
- <doc:BuildingRequests>

### Parsing Responses

- <doc:ParsingResponses>

### Request Bodies

- ``NetworkRequestBody``
- <doc:RequestBodies>
