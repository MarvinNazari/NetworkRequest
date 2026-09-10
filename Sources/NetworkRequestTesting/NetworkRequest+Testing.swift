//
//  Copyright © 2026 Marvin Nazari. All rights reserved.
//

import Foundation
import NetworkRequest

/// Test-only conveniences for executing a `NetworkRequest` end to end
/// against a stubbed `URLSession`.
///
/// These helpers live in `NetworkRequestTesting` on purpose: the core
/// library stays execution-agnostic, while tests get a one-liner.
public extension NetworkRequest {

  /// Builds the `URLRequest` by invoking the `urlRequest` closure.
  ///
  /// A readable alias for `try request.urlRequest()` in assertions.
  func makeURLRequest() throws -> URLRequest {
    try urlRequest()
  }

  /// Builds the request, sends it through `session`, and parses the reply.
  ///
  /// Equivalent to:
  ///
  /// ```swift
  /// let (data, response) = try await session.data(for: try request.urlRequest())
  /// let value = try request.parse(data, response)
  /// ```
  ///
  /// - Parameter session: Typically one produced by ``StubURLProtocol``.
  /// - Returns: The parsed `Response`.
  /// - Throws: Whatever `urlRequest`, `URLSession`, or `parse` throws —
  ///   including the request's `ErrorResponse` and `UnexpectedHTTPResponse`.
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  func send(using session: URLSession) async throws -> Response {
    let (data, response) = try await session.data(for: try urlRequest())
    return try parse(data, response)
  }
}
