//
//  Copyright © 2026 Marvin Nazari. All rights reserved.
//

import Foundation

/// A `URLRequest` captured by a stub, wrapped in a value type that exposes
/// read-only conveniences for assertions.
///
/// The helpers live here rather than on `URLRequest` so that
/// `NetworkRequestTesting` never adds API to a type it does not own.
/// ``urlRequest`` is always available when a test needs something this type
/// does not surface.
///
/// ```swift
/// let sent = try #require(await recorder.last)
/// #expect(sent.method == "POST")
/// #expect(sent.path == "/users")
/// #expect(try sent.jsonBody()["name"] as? String == "Ada")
/// ```
public struct RecordedRequest: Sendable {

  /// The request exactly as it was sent.
  public let urlRequest: URLRequest

  /// Wraps `urlRequest` for inspection.
  public init(_ urlRequest: URLRequest) {
    self.urlRequest = urlRequest
  }

  // MARK: - Line and headers

  /// The request URL, or `nil` if the request has none.
  public var url: URL? { urlRequest.url }

  /// The HTTP method, or `nil` if the request has none.
  public var method: String? { urlRequest.httpMethod }

  /// The URL's path, or `nil` if the request has no URL.
  public var path: String? { urlRequest.url?.path }

  /// The header fields, or an empty dictionary when none are set.
  public var headers: [String: String] { urlRequest.allHTTPHeaderFields ?? [:] }

  // MARK: - Query

  /// The URL's query items, in order, or an empty array when there is no
  /// URL or no query.
  public var queryItems: [URLQueryItem] {
    guard let url = urlRequest.url,
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else { return [] }
    return components.queryItems ?? []
  }

  /// Query items keyed by name. Duplicated names keep the last value; a
  /// valueless item (`?flag`) maps to an empty string.
  public var queryDictionary: [String: String] {
    Self.dictionary(from: queryItems)
  }

  // MARK: - Body

  /// The raw request body, or `nil` if the request has none.
  public var body: Data? { urlRequest.httpBody }

  /// The body decoded as UTF-8, or `nil` if there is no body or it is not
  /// valid UTF-8.
  public var bodyString: String? {
    guard let body else { return nil }
    return String(data: body, encoding: .utf8)
  }

  /// The body parsed as a JSON object.
  ///
  /// Throws rather than returning `nil` so that a malformed or unexpected
  /// body fails the test loudly instead of reading as "no body".
  ///
  /// - Throws: A `DecodingError` if there is no body or the body is valid
  ///   JSON that is not an object, or the `JSONSerialization` error if the
  ///   body is not valid JSON at all.
  public func jsonBody() throws -> [String: Any] {
    try json()
  }

  /// The body parsed as a JSON array.
  ///
  /// Throws rather than returning `nil` so that a malformed or unexpected
  /// body fails the test loudly instead of reading as "no body".
  ///
  /// - Throws: A `DecodingError` if there is no body or the body is valid
  ///   JSON that is not an array, or the `JSONSerialization` error if the
  ///   body is not valid JSON at all.
  public func jsonArrayBody() throws -> [Any] {
    try json()
  }

  /// The body parsed as `application/x-www-form-urlencoded` pairs, or `nil`
  /// if there is no body or it is not valid UTF-8.
  ///
  /// Both `%20` and `+` are decoded as a space. Duplicated names keep the
  /// last value; a valueless pair maps to an empty string.
  public var formBody: [String: String]? {
    guard let bodyString else { return nil }
    var components = URLComponents()
    // URLComponents follows RFC 3986, where "+" is literal; form encoding
    // (HTML spec) treats it as a space, so normalize before parsing.
    components.percentEncodedQuery = bodyString.replacingOccurrences(of: "+", with: "%20")
    return Self.dictionary(from: components.queryItems ?? [])
  }

  // MARK: - Internal

  private func json<T>() throws -> T {
    guard let body else {
      throw DecodingError.valueNotFound(
        T.self,
        DecodingError.Context(codingPath: [], debugDescription: "The request has no body.")
      )
    }
    let object = try JSONSerialization.jsonObject(with: body)
    guard let typed = object as? T else {
      throw DecodingError.typeMismatch(
        T.self,
        DecodingError.Context(
          codingPath: [],
          debugDescription: "The request body is JSON, but not \(T.self)."
        )
      )
    }
    return typed
  }

  private static func dictionary(from items: [URLQueryItem]) -> [String: String] {
    var result: [String: String] = [:]
    for item in items {
      result[item.name] = item.value ?? ""
    }
    return result
  }
}
