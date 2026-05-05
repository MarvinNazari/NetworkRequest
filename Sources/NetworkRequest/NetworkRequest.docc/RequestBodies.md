# Request Bodies

Build the payload that ships in the body of `POST`, `PUT`, and `PATCH`
requests.

## JSON from a model

The most common case — encode any `Encodable` value as JSON:

```swift
struct CreateUser: Encodable {
    let name: String
    let createdAt: Date
}

let body = try NetworkRequestBody.json(
    parameters: CreateUser(name: "Ada", createdAt: .now)
)
```

The default encoder uses `dateEncodingStrategy = .iso8601`. Pass a custom
`JSONEncoder` to override that or any other strategy.

## JSON from a heterogeneous dictionary

When you don't want to define a struct for an ad-hoc payload, encode a
`[String: Encodable]` directly:

```swift
let body = try NetworkRequestBody.json(parameters: [
    "name": "Ada",
    "age": 36,
    "active": true,
])
```

## URL-encoded forms

For `application/x-www-form-urlencoded` payloads:

```swift
let body = try NetworkRequestBody.form(dictionary: [
    "grant_type": "refresh_token",
    "refresh_token": refreshToken,
])
```

Keys and values are percent-encoded according to URL query rules.

## Anything else

Reach for ``NetworkRequestBody/init(data:contentType:)`` to wrap arbitrary
payloads — `multipart/form-data`, protobuf, image uploads, etc:

```swift
let body = NetworkRequestBody(
    data: pngData,
    contentType: "image/png"
)
```

The supplied `contentType` is what gets sent in the `Content-Type` header
when the body is attached to a request.
