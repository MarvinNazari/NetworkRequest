# NetworkRequest

Generic, execution-agnostic HTTP request builder. v1.0.0 shipped — public API is
frozen, additive changes only. Source: github.com/MarvinNazari/NetworkRequest.
Docs: https://wavio.co/NetworkRequest/.

## Scope

- Apple platforms only — iOS 13 / macOS 10.15 / tvOS 13 / watchOS 6.
- Execution-agnostic — never add URLSession/Combine/async dispatch helpers; that's intentional separation.
- `HTTPMethod` is RFC 9110 + PATCH only — custom methods go through `HTTPMethod(rawValue:)`.

## Style

- 2-space indentation in all Swift files.
- Swift Testing only (`@Test`, `#expect`, `@Suite`, `arguments:`) — no XCTest.
- `///` on every public symbol; `// MARK:` to group sections.
- Comments explain *why*, never *what*.

## Concurrency (Swift 6 strict)

- `NetworkRequest: Sendable where Response: Sendable, ErrorResponse: Sendable`.
- Stored closures and closure parameters are `@Sendable @escaping`.
- Typed convenience inits require `Sendable` on type params (sendable-metatypes rule).
- Base `init(urlRequest:parse:)` is the escape hatch for non-Sendable types.

## Verify before claiming done

- `swift build` — zero warnings under Swift 6.
- `swift test` — all tests pass.
- `swift package generate-documentation --target NetworkRequest` — no broken DocC links.

## Releasing (user-driven)

- Bump `CHANGELOG.md` under new `## [X.Y.Z]` heading (Keep a Changelog).
- `git tag X.Y.Z && git push --tags` — triggers Pages deploy.
- Don't tag without explicit approval.
