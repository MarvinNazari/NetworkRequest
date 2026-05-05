//
//  Copyright © 2026 Marvin Nazari. All rights reserved.
//

import Foundation

/// A type-safe, execution-agnostic description of an HTTP request and how to
/// parse its response.
///
/// `NetworkRequest` is a value type that bundles together two closures:
///
/// - ``urlRequest`` builds the underlying `URLRequest` lazily, on demand.
/// - ``parse`` turns the raw response (`Data` and `URLResponse`) into a
///   typed `Response`, or throws an `ErrorResponse`.
///
/// The two generic parameters give the call site compile-time knowledge of
/// what a successful response looks like and what kind of error the API is
/// allowed to return. `NetworkRequest` does **not** execute itself — pass
/// the result of ``urlRequest`` to `URLSession` (or any other transport) and
/// feed the response back through ``parse``.
///
/// ```swift
/// import NetworkRequest
///
/// struct User: Decodable, Sendable { let id: Int; let name: String }
/// struct APIError: Decodable, Error, Sendable { let message: String }
///
/// let request = NetworkRequest<User, APIError>(
///   url: URL(string: "https://api.example.com/me")
/// )
///
/// let (data, response) = try await URLSession.shared.data(for: request.urlRequest())
/// let user = try request.parse(data, response)
/// ```
///
/// When an endpoint has no typed error envelope, use `Never` as the
/// `ErrorResponse` parameter — `NetworkRequest<User, Never>` documents at the
/// type level that the request never throws a decoded error.
///
/// See <doc:GettingStarted> for a full walkthrough.
public struct NetworkRequest<Response, ErrorResponse: Error> {

  // MARK: - Stored state

  /// Builds the underlying `URLRequest` on demand.
  ///
  /// The closure is invoked each time you read it, so per-request values
  /// such as authentication tokens or timestamps embedded in the URL are
  /// resolved at the moment the request is dispatched, not at the moment
  /// `NetworkRequest` was created.
  public let urlRequest: @Sendable () throws -> URLRequest

  /// Transforms the raw response into a typed `Response`, or throws an
  /// `ErrorResponse` describing why the request failed.
  public let parse: @Sendable (Data, URLResponse) throws -> Response

  // MARK: - Designated initializer

  /// Creates a request from raw `urlRequest` and `parse` closures.
  ///
  /// Most callers should prefer one of the convenience initializers, which
  /// build the `URLRequest` for you from common pieces (URL, method,
  /// headers, body) and provide a default JSON-decoding `parse`.
  ///
  /// - Parameters:
  ///   - urlRequest: A closure that builds the `URLRequest` to send.
  ///   - parse: A closure that converts the response into `Response`.
  public init(
    urlRequest: @Sendable @escaping () throws -> URLRequest,
    parse: @Sendable @escaping (Data, URLResponse) throws -> Response
  ) {
    self.urlRequest = urlRequest
    self.parse = parse
  }

  // MARK: - Debugging

  /// A `curl` command equivalent to the request, useful for reproducing
  /// requests outside the app.
  ///
  /// Returns `nil` if ``urlRequest`` throws when invoked, or if the
  /// underlying `URLRequest` has no URL.
  public var cURLCommand: String? {
    guard let request = try? urlRequest() else { return nil }
    return request.cURLCommand
  }
}

extension NetworkRequest: Sendable where Response: Sendable, ErrorResponse: Sendable {}

/// An error thrown by typed `NetworkRequest` initializers when the response
/// is non-2xx and its body cannot be decoded as the declared `ErrorResponse`,
/// or when the response is not an `HTTPURLResponse` at all.
///
/// Captures the status code (or `-1` for non-HTTP responses) and the raw
/// body so callers can log, surface, or retry the request without losing
/// the original failure context.
public struct UnexpectedHTTPResponse: Error, Sendable {

  /// The HTTP status code, or `-1` if the response was not an `HTTPURLResponse`.
  public let statusCode: Int

  /// The raw response body.
  public let data: Data

  public init(statusCode: Int, data: Data) {
    self.statusCode = statusCode
    self.data = data
  }
}

// MARK: - Generic convenience initializer

public extension NetworkRequest {

  /// Builds a request from individual components, deferring to a custom
  /// `parse` closure.
  ///
  /// Use this initializer when none of the typed specializations below fit
  /// — for example, when the response is XML, when status-code handling is
  /// non-standard, or when you need to inspect headers during parsing.
  ///
  /// The constructed `URLRequest` always advertises `Accept: application/json`.
  /// When `body` is supplied its `contentType` is set as `Content-Type`.
  /// Values in `additionalHeaderFields` are applied last and replace any of
  /// the above on collision.
  ///
  /// - Parameters:
  ///   - httpMethod: The HTTP method to use. Defaults to ``HTTPMethod/get``.
  ///   - url: A closure returning the destination URL. Evaluated each time
  ///     the request is built.
  ///   - body: The request body to send, or `nil` for no body.
  ///   - additionalHeaderFields: Extra headers to set on the request.
  ///   - cachePolicy: A `URLRequest.CachePolicy` to apply, or `nil` to use
  ///     the system default.
  ///   - timeoutInterval: A request timeout in seconds, or `nil` to use
  ///     the system default.
  ///   - parse: A closure converting the response to `Response`.
  init(
    httpMethod: HTTPMethod = .get,
    url: @Sendable @escaping () throws -> URL?,
    body: NetworkRequestBody? = nil,
    additionalHeaderFields: [String: String] = [:],
    cachePolicy: URLRequest.CachePolicy? = nil,
    timeoutInterval: TimeInterval? = nil,
    parse: @Sendable @escaping (Data, URLResponse) throws -> Response
  ) {
    self.init(
      urlRequest: {
        guard let resolvedURL = try url() else {
          throw URLError(.badURL)
        }
        var urlRequest = URLRequest(url: resolvedURL)

        if let cachePolicy = cachePolicy {
          urlRequest.cachePolicy = cachePolicy
        }

        if let timeoutInterval = timeoutInterval {
          urlRequest.timeoutInterval = timeoutInterval
        }

        urlRequest.httpMethod = httpMethod.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = body {
          urlRequest.httpBody = body.data
          urlRequest.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
        }

        for (key, value) in additionalHeaderFields {
          urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        return urlRequest
      },
      parse: parse
    )
  }
}

// MARK: - Decodable response, decodable error

public extension NetworkRequest where Response: Decodable & Sendable, ErrorResponse: Decodable & Sendable {

  /// Builds a JSON request whose successful response decodes into `Response`
  /// and whose non-2xx response decodes into a throwable `ErrorResponse`.
  ///
  /// This is the most common shape for talking to JSON APIs that return a
  /// structured error envelope on failure.
  ///
  /// **Status-code handling:**
  /// - `200..<300`: the body is decoded as `Response`.
  /// - Any other status (including non-`HTTPURLResponse`): the body is
  ///   decoded as `ErrorResponse` and thrown. If that decode fails, an
  ///   ``UnexpectedHTTPResponse`` is thrown instead, preserving the status
  ///   code and raw body.
  ///
  /// - Parameters:
  ///   - httpMethod: The HTTP method to use. Defaults to ``HTTPMethod/get``.
  ///   - url: The destination URL (auto-closure, evaluated lazily). Throws `URLError(.badURL)` if `nil`.
  ///   - body: The request body to send, or `nil`.
  ///   - additionalHeaderFields: Extra headers to set on the request.
  ///   - cachePolicy: A cache policy to apply, or `nil` for the default.
  ///   - timeoutInterval: A timeout in seconds, or `nil` for the default.
  ///   - decoder: The `JSONDecoder` used for both success and error
  ///     decoding. Defaults to a decoder configured for ISO-8601 dates.
  init(
    httpMethod: HTTPMethod = .get,
    url: @autoclosure @Sendable @escaping () throws -> URL?,
    body: NetworkRequestBody? = nil,
    additionalHeaderFields: [String: String] = [:],
    cachePolicy: URLRequest.CachePolicy? = nil,
    timeoutInterval: TimeInterval? = nil,
    decoder: JSONDecoder = .iso8601
  ) {
    self.init(
      httpMethod: httpMethod,
      url: url,
      body: body,
      additionalHeaderFields: additionalHeaderFields,
      cachePolicy: cachePolicy,
      timeoutInterval: timeoutInterval,
      parse: { data, urlResponse in
        let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? -1
        if 200 ..< 300 ~= statusCode {
          return try decoder.decode(Response.self, from: data)
        }
        let decodedError: ErrorResponse
        do {
          decodedError = try decoder.decode(ErrorResponse.self, from: data)
        } catch {
          throw UnexpectedHTTPResponse(statusCode: statusCode, data: data)
        }
        throw decodedError
      }
    )
  }
}

// MARK: - Decodable response, UnexpectedHTTPResponse error

public extension NetworkRequest where Response: Decodable & Sendable, ErrorResponse == UnexpectedHTTPResponse {

  /// Builds a JSON request that validates the HTTP status code without
  /// requiring a typed error envelope.
  ///
  /// Useful for APIs whose only failure signal is the status code (CRUD
  /// endpoints, S3-style services). Saves callers from defining a
  /// placeholder `Decodable & Error` type just to satisfy the typed-error
  /// overload.
  ///
  /// **Status-code handling:**
  /// - `200..<300`: the body is decoded as `Response`.
  /// - Any other status (including non-`HTTPURLResponse`): an
  ///   ``UnexpectedHTTPResponse`` is thrown with the status code and raw body.
  ///
  /// - Parameters:
  ///   - httpMethod: The HTTP method to use. Defaults to ``HTTPMethod/get``.
  ///   - url: The destination URL. Throws `URLError(.badURL)` if `nil`.
  ///   - body: The request body to send, or `nil`.
  ///   - additionalHeaderFields: Extra headers to set on the request.
  ///   - cachePolicy: A cache policy to apply, or `nil` for the default.
  ///   - timeoutInterval: A timeout in seconds, or `nil` for the default.
  ///   - decoder: The `JSONDecoder` used to decode the response body.
  init(
    httpMethod: HTTPMethod = .get,
    url: @autoclosure @Sendable @escaping () throws -> URL?,
    body: NetworkRequestBody? = nil,
    additionalHeaderFields: [String: String] = [:],
    cachePolicy: URLRequest.CachePolicy? = nil,
    timeoutInterval: TimeInterval? = nil,
    decoder: JSONDecoder = .iso8601
  ) {
    self.init(
      httpMethod: httpMethod,
      url: url,
      body: body,
      additionalHeaderFields: additionalHeaderFields,
      cachePolicy: cachePolicy,
      timeoutInterval: timeoutInterval,
      parse: { data, urlResponse in
        let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? -1
        if 200 ..< 300 ~= statusCode {
          return try decoder.decode(Response.self, from: data)
        }
        throw UnexpectedHTTPResponse(statusCode: statusCode, data: data)
      }
    )
  }
}

// MARK: - Raw Data response, UnexpectedHTTPResponse error

public extension NetworkRequest where Response == Data, ErrorResponse == UnexpectedHTTPResponse {

  /// Builds a request whose successful response is returned as raw `Data`,
  /// validating the HTTP status code without requiring a typed error envelope.
  ///
  /// **Status-code handling:**
  /// - `200..<300`: the raw response bytes are returned.
  /// - Any other status (including non-`HTTPURLResponse`): an
  ///   ``UnexpectedHTTPResponse`` is thrown with the status code and raw body.
  init(
    httpMethod: HTTPMethod = .get,
    url: @autoclosure @Sendable @escaping () throws -> URL?,
    body: NetworkRequestBody? = nil,
    additionalHeaderFields: [String: String] = [:],
    cachePolicy: URLRequest.CachePolicy? = nil,
    timeoutInterval: TimeInterval? = nil
  ) {
    self.init(
      httpMethod: httpMethod,
      url: url,
      body: body,
      additionalHeaderFields: additionalHeaderFields,
      cachePolicy: cachePolicy,
      timeoutInterval: timeoutInterval,
      parse: { data, urlResponse in
        let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? -1
        if 200 ..< 300 ~= statusCode {
          return data
        }
        throw UnexpectedHTTPResponse(statusCode: statusCode, data: data)
      }
    )
  }
}

// MARK: - Void response, UnexpectedHTTPResponse error

public extension NetworkRequest where Response == Void, ErrorResponse == UnexpectedHTTPResponse {

  /// Builds a request that ignores the success body and validates the HTTP
  /// status code without requiring a typed error envelope.
  ///
  /// Useful for fire-and-forget endpoints where you still want a non-2xx
  /// response to fail loudly.
  ///
  /// **Status-code handling:**
  /// - `200..<300`: returns `()`.
  /// - Any other status (including non-`HTTPURLResponse`): an
  ///   ``UnexpectedHTTPResponse`` is thrown with the status code and raw body.
  init(
    httpMethod: HTTPMethod = .get,
    url: @autoclosure @Sendable @escaping () throws -> URL?,
    body: NetworkRequestBody? = nil,
    additionalHeaderFields: [String: String] = [:],
    cachePolicy: URLRequest.CachePolicy? = nil,
    timeoutInterval: TimeInterval? = nil
  ) {
    self.init(
      httpMethod: httpMethod,
      url: url,
      body: body,
      additionalHeaderFields: additionalHeaderFields,
      cachePolicy: cachePolicy,
      timeoutInterval: timeoutInterval,
      parse: { data, urlResponse in
        let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? -1
        if 200 ..< 300 ~= statusCode {
          return ()
        }
        throw UnexpectedHTTPResponse(statusCode: statusCode, data: data)
      }
    )
  }
}

// MARK: - Decodable response, no error type

public extension NetworkRequest where Response: Decodable & Sendable, ErrorResponse == Never {

  /// Builds a JSON request whose response decodes into `Response`, without
  /// any structured error decoding.
  ///
  /// **This overload does not validate the HTTP status code.** A non-2xx
  /// response is fed to the decoder as-is — if the body is not parseable as
  /// `Response`, you will see a `DecodingError`. Use the
  /// ``init(httpMethod:url:body:additionalHeaderFields:cachePolicy:timeoutInterval:decoder:)-(_,_,_,_,_,_,_)``
  /// overload that takes a typed `ErrorResponse` if you need status-code-aware
  /// error handling.
  ///
  /// - Parameters:
  ///   - httpMethod: The HTTP method to use. Defaults to ``HTTPMethod/get``.
  ///   - url: The destination URL. Throws `URLError(.badURL)` if `nil`.
  ///   - body: The request body to send, or `nil`.
  ///   - additionalHeaderFields: Extra headers to set on the request.
  ///   - cachePolicy: A cache policy to apply, or `nil` for the default.
  ///   - timeoutInterval: A timeout in seconds, or `nil` for the default.
  ///   - decoder: The `JSONDecoder` used to decode the response body.
  init(
    httpMethod: HTTPMethod = .get,
    url: @autoclosure @Sendable @escaping () throws -> URL?,
    body: NetworkRequestBody? = nil,
    additionalHeaderFields: [String: String] = [:],
    cachePolicy: URLRequest.CachePolicy? = nil,
    timeoutInterval: TimeInterval? = nil,
    decoder: JSONDecoder = .iso8601
  ) {
    self.init(
      httpMethod: httpMethod,
      url: url,
      body: body,
      additionalHeaderFields: additionalHeaderFields,
      cachePolicy: cachePolicy,
      timeoutInterval: timeoutInterval,
      parse: { data, _ in
        try decoder.decode(Response.self, from: data)
      }
    )
  }
}

// MARK: - Raw Data response, no error type

public extension NetworkRequest where Response == Data, ErrorResponse == Never {

  /// Builds a request whose response is returned as raw `Data`.
  ///
  /// Useful for downloading binary content, capturing pre-parsed payloads
  /// for inspection, or interacting with non-JSON endpoints.
  ///
  /// **This overload does not validate the HTTP status code.** A 4xx/5xx
  /// response is returned to the caller as raw bytes. Use the overload
  /// whose `ErrorResponse` is `Decodable` or ``UnexpectedHTTPResponse`` if
  /// you need status-code-aware error handling.
  init(
    httpMethod: HTTPMethod = .get,
    url: @autoclosure @Sendable @escaping () throws -> URL?,
    body: NetworkRequestBody? = nil,
    additionalHeaderFields: [String: String] = [:],
    cachePolicy: URLRequest.CachePolicy? = nil,
    timeoutInterval: TimeInterval? = nil
  ) {
    self.init(
      httpMethod: httpMethod,
      url: url,
      body: body,
      additionalHeaderFields: additionalHeaderFields,
      cachePolicy: cachePolicy,
      timeoutInterval: timeoutInterval,
      parse: { data, _ in data }
    )
  }
}

// MARK: - Raw Data response, decodable error

public extension NetworkRequest where Response == Data, ErrorResponse: Decodable & Sendable {

  /// Builds a request whose successful response is returned as raw `Data`,
  /// and whose non-2xx response decodes into a throwable `ErrorResponse`.
  ///
  /// Useful when downloading binary content (images, files) from a JSON API
  /// that returns structured error envelopes on failure.
  ///
  /// **Status-code handling:**
  /// - `200..<300`: the raw response bytes are returned.
  /// - Any other status (including non-`HTTPURLResponse`): the body is
  ///   decoded as `ErrorResponse` and thrown. If that decode fails, an
  ///   ``UnexpectedHTTPResponse`` is thrown instead.
  ///
  /// - Parameters:
  ///   - httpMethod: The HTTP method to use. Defaults to ``HTTPMethod/get``.
  ///   - url: The destination URL. Throws `URLError(.badURL)` if `nil`.
  ///   - body: The request body to send, or `nil`.
  ///   - additionalHeaderFields: Extra headers to set on the request.
  ///   - cachePolicy: A cache policy to apply, or `nil` for the default.
  ///   - timeoutInterval: A timeout in seconds, or `nil` for the default.
  ///   - decoder: The `JSONDecoder` used to decode the error body.
  init(
    httpMethod: HTTPMethod = .get,
    url: @autoclosure @Sendable @escaping () throws -> URL?,
    body: NetworkRequestBody? = nil,
    additionalHeaderFields: [String: String] = [:],
    cachePolicy: URLRequest.CachePolicy? = nil,
    timeoutInterval: TimeInterval? = nil,
    decoder: JSONDecoder = .iso8601
  ) {
    self.init(
      httpMethod: httpMethod,
      url: url,
      body: body,
      additionalHeaderFields: additionalHeaderFields,
      cachePolicy: cachePolicy,
      timeoutInterval: timeoutInterval,
      parse: { data, urlResponse in
        let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? -1
        if 200 ..< 300 ~= statusCode {
          return data
        }
        let decodedError: ErrorResponse
        do {
          decodedError = try decoder.decode(ErrorResponse.self, from: data)
        } catch {
          throw UnexpectedHTTPResponse(statusCode: statusCode, data: data)
        }
        throw decodedError
      }
    )
  }
}

// MARK: - Void response, void error (fire-and-forget)

public extension NetworkRequest where Response == Void, ErrorResponse == Never {

  /// Builds a fire-and-forget request that ignores the response body.
  ///
  /// The response body is dropped and parsing always succeeds with `()`.
  ///
  /// **This overload does not validate the HTTP status code.** Even a 5xx
  /// response is treated as success at the parse layer; HTTP-level failures
  /// can only surface through the transport's own error path. Use the
  /// overload whose `ErrorResponse` is `Decodable` or
  /// ``UnexpectedHTTPResponse`` if you need status-code-aware error
  /// handling.
  init(
    httpMethod: HTTPMethod = .get,
    url: @autoclosure @Sendable @escaping () throws -> URL?,
    body: NetworkRequestBody? = nil,
    additionalHeaderFields: [String: String] = [:],
    cachePolicy: URLRequest.CachePolicy? = nil,
    timeoutInterval: TimeInterval? = nil
  ) {
    self.init(
      httpMethod: httpMethod,
      url: url,
      body: body,
      additionalHeaderFields: additionalHeaderFields,
      cachePolicy: cachePolicy,
      timeoutInterval: timeoutInterval,
      parse: { _, _ in () }
    )
  }
}

// MARK: - Void response, decodable error

public extension NetworkRequest where Response == Void, ErrorResponse: Decodable & Sendable {

  /// Builds a request that ignores the success response body but decodes a
  /// structured error on non-2xx responses.
  ///
  /// Useful for `DELETE` or `POST` endpoints where success carries no
  /// payload but failures do.
  ///
  /// **Status-code handling:**
  /// - `200..<300`: the body is discarded and `()` is returned.
  /// - Any other status (including non-`HTTPURLResponse`): the body is
  ///   decoded as `ErrorResponse` and thrown. If that decode fails, an
  ///   ``UnexpectedHTTPResponse`` is thrown instead.
  ///
  /// - Parameters:
  ///   - httpMethod: The HTTP method to use. Defaults to ``HTTPMethod/get``.
  ///   - url: The destination URL. Throws `URLError(.badURL)` if `nil`.
  ///   - body: The request body to send, or `nil`.
  ///   - additionalHeaderFields: Extra headers to set on the request.
  ///   - cachePolicy: A cache policy to apply, or `nil` for the default.
  ///   - timeoutInterval: A timeout in seconds, or `nil` for the default.
  ///   - decoder: The `JSONDecoder` used to decode the error body.
  init(
    httpMethod: HTTPMethod = .get,
    url: @autoclosure @Sendable @escaping () throws -> URL?,
    body: NetworkRequestBody? = nil,
    additionalHeaderFields: [String: String] = [:],
    cachePolicy: URLRequest.CachePolicy? = nil,
    timeoutInterval: TimeInterval? = nil,
    decoder: JSONDecoder = .iso8601
  ) {
    self.init(
      httpMethod: httpMethod,
      url: url,
      body: body,
      additionalHeaderFields: additionalHeaderFields,
      cachePolicy: cachePolicy,
      timeoutInterval: timeoutInterval,
      parse: { data, urlResponse in
        let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? -1
        if 200 ..< 300 ~= statusCode {
          return ()
        }
        let decodedError: ErrorResponse
        do {
          decodedError = try decoder.decode(ErrorResponse.self, from: data)
        } catch {
          throw UnexpectedHTTPResponse(statusCode: statusCode, data: data)
        }
        throw decodedError
      }
    )
  }
}
