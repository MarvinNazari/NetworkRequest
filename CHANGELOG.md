# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-05-05

First public release.

### Added

- `NetworkRequest<Response, ErrorResponse: Error>`: a generic,
  execution-agnostic HTTP request description with two `@Sendable` closures,
  `urlRequest` and `parse`. Conditionally conforms to `Sendable` when its
  generic parameters do.
- Nine convenience initializers covering the typed-response × typed-error
  matrix:
  - `Decodable + Decodable`, `Decodable + Never`, `Decodable + UnexpectedHTTPResponse`
  - `Data + Decodable`, `Data + Never`, `Data + UnexpectedHTTPResponse`
  - `Void + Decodable`, `Void + Never`, `Void + UnexpectedHTTPResponse`
- `UnexpectedHTTPResponse`: an `Error & Sendable` value carrying the
  `statusCode` and raw `data` of a response that couldn't be turned into
  the declared `Response` or `ErrorResponse`. Thrown by the typed-error
  variants when the error body fails to decode, and as the dedicated error
  type for the status-validated, no-envelope variants.
- `HTTPMethod`: a `Sendable`, `Hashable`, `RawRepresentable` value with
  static cases for the nine standard methods plus support for custom
  methods.
- `NetworkRequestBody`: helpers for JSON (`Encodable` and
  `[String: Encodable]` overloads), URL-encoded forms, and arbitrary
  payloads via `init(data:contentType:)`.
- `JSONDecoder.iso8601` and `JSONEncoder.iso8601` factories for ISO-8601
  date handling, used as the library's defaults and exposed for callers
  who want to layer further configuration.
- `cURLCommand` debug helper (returning `String?`) that renders a request
  as an equivalent `curl` invocation. Header values containing apostrophes
  are escaped with the ANSI-C `'\''` trick; non-UTF-8 bodies render as
  `# (binary body of N bytes omitted)` rather than producing a misleading
  `-d ""`.
- DocC catalog with articles: *Getting Started*, *A Real-World Example*,
  *Building Requests*, *Parsing Responses*, *Request Bodies*.

### Requirements

- Swift 6.2 toolchain (Xcode 17+)
- iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+

[1.0.0]: https://github.com/MarvinNazari/NetworkRequest/releases/tag/1.0.0
