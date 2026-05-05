# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-05-05

First public release.

### Added

- `NetworkRequest<Response, ErrorResponse>`: a generic, execution-agnostic
  HTTP request description with two closures, `urlRequest` and `parse`.
  Conditionally conforms to `Sendable` when its generic parameters do.
- Convenience initializers covering the five common typed shapes:
  `Decodable + Decodable & Error`, `Decodable + Void`, `Data + Void`,
  `Void + Void`, and `Void + Decodable & Error`.
- `HTTPMethod`: a `Sendable`, `Hashable`, `RawRepresentable` value with
  static cases for the nine standard methods plus support for custom
  methods.
- `NetworkRequestBody`: helpers for JSON (`Encodable` and
  `[String: Encodable]` overloads), URL-encoded forms, and arbitrary
  payloads via `init(data:contentType:)`.
- `cURLCommand` debug helper that renders a request as an equivalent
  `curl` invocation, including method, headers, body, and shared cookies.
- DocC catalog with articles: *Getting Started*, *Building Requests*,
  *Parsing Responses*, *Request Bodies*.

### Requirements

- Swift 6.2 toolchain (Xcode 17+)
- iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+

[1.0.0]: https://github.com/MarvinNazari/NetworkRequest/releases/tag/1.0.0
