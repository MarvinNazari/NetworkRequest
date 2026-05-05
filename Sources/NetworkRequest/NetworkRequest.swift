//
//  Copyright © 2023 Marvin Nazari. All rights reserved.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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
/// struct User: Decodable { let id: Int; let name: String }
/// struct APIError: Decodable, Error { let message: String }
///
/// let request = NetworkRequest<User, APIError>(
///     url: URL(string: "https://api.example.com/me")!
/// )
///
/// let (data, response) = try await URLSession.shared.data(for: request.urlRequest())
/// let user = try request.parse(data, response)
/// ```
///
/// See <doc:GettingStarted> for a full walkthrough.
public struct NetworkRequest<Response, ErrorResponse> {

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
  /// Returns an empty string if ``urlRequest`` throws when invoked.
  public var cURLCommand: String {
    let request = try? urlRequest()
    return request?.cURLCommand ?? ""
  }
}

extension NetworkRequest: Sendable where Response: Sendable, ErrorResponse: Sendable {}

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
  /// When `body` is supplied its `contentType` is added as `Content-Type`.
  /// Values in `additionalHeaderFields` are applied last and may override
  /// any of the above.
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
    url: @Sendable @escaping () throws -> URL,
    body: NetworkRequestBody? = nil,
    additionalHeaderFields: [String: String] = [:],
    cachePolicy: URLRequest.CachePolicy? = nil,
    timeoutInterval: TimeInterval? = nil,
    parse: @Sendable @escaping (Data, URLResponse) throws -> Response
  ) {
    self.init(
      urlRequest: {
        let urlToSend = try url()

        var urlRequest = URLRequest(url: urlToSend)

        if let cachePolicy = cachePolicy {
          urlRequest.cachePolicy = cachePolicy
        }

        if let timeoutInterval = timeoutInterval {
          urlRequest.timeoutInterval = timeoutInterval
        }

        urlRequest.httpMethod = httpMethod.rawValue

        if let body = body {
          urlRequest.httpBody = body.data
          urlRequest.addValue(body.contentType, forHTTPHeaderField: "Content-Type")
        }

        urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")

        additionalHeaderFields.forEach { key, value in
          urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        return urlRequest
      },
      parse: parse
    )
  }
}

// MARK: - Decodable response, decodable error

public extension NetworkRequest where Response: Decodable & Sendable, ErrorResponse: Decodable & Swift.Error & Sendable {

  /// Builds a JSON request whose successful response decodes into `Response`
  /// and whose non-2xx response decodes into a throwable `ErrorResponse`.
  ///
  /// This is the most common shape for talking to JSON APIs that return a
  /// structured error envelope on failure.
  ///
  /// Status codes in `200..<300` decode the body as `Response`; any other
  /// status decodes the body as `ErrorResponse` and throws it.
  ///
  /// - Parameters:
  ///   - httpMethod: The HTTP method to use. Defaults to ``HTTPMethod/get``.
  ///   - url: The destination URL (auto-closure, evaluated lazily).
  ///   - body: The request body to send, or `nil`.
  ///   - additionalHeaderFields: Extra headers to set on the request.
  ///   - cachePolicy: A cache policy to apply, or `nil` for the default.
  ///   - timeoutInterval: A timeout in seconds, or `nil` for the default.
  ///   - decoder: The `JSONDecoder` used for both success and error
  ///     decoding. Defaults to one with `dateDecodingStrategy = .iso8601`.
  init(
    httpMethod: HTTPMethod = .get,
    url: @autoclosure @Sendable @escaping () throws -> URL,
    body: NetworkRequestBody? = nil,
    additionalHeaderFields: [String: String] = [:],
    cachePolicy: URLRequest.CachePolicy? = nil,
    timeoutInterval: TimeInterval? = nil,
    decoder: JSONDecoder = {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      return decoder
    }()
  ) {

    self.init(
      httpMethod: httpMethod,
      url: url,
      body: body,
      additionalHeaderFields: additionalHeaderFields,
      cachePolicy: cachePolicy,
      timeoutInterval: timeoutInterval,
      parse: { data, urlResponse in
        guard let httpUrlResponse = urlResponse as? HTTPURLResponse,
           200 ..< 300 ~= httpUrlResponse.statusCode else {

          let error = try decoder.decode(ErrorResponse.self, from: data)
          throw error
        }

        return try decoder.decode(Response.self, from: data)
      }
    )
  }
}

// MARK: - Decodable response, no error type

public extension NetworkRequest where Response: Decodable & Sendable, ErrorResponse == Void {

  /// Builds a JSON request whose response decodes into `Response`, without
  /// any structured error decoding.
  ///
  /// Use this overload for endpoints where you don't model failures as a
  /// typed payload. Failures still propagate — they will surface as
  /// transport errors thrown by `URLSession` or as decoding errors thrown
  /// by the decoder when the response body doesn't match `Response`.
  ///
  /// - Parameters:
  ///   - httpMethod: The HTTP method to use. Defaults to ``HTTPMethod/get``.
  ///   - url: The destination URL.
  ///   - body: The request body to send, or `nil`.
  ///   - additionalHeaderFields: Extra headers to set on the request.
  ///   - cachePolicy: A cache policy to apply, or `nil` for the default.
  ///   - timeoutInterval: A timeout in seconds, or `nil` for the default.
  ///   - decoder: The `JSONDecoder` used to decode the response body.
  init(
    httpMethod: HTTPMethod = .get,
    url: @autoclosure @Sendable @escaping () throws -> URL,
    body: NetworkRequestBody? = nil,
    additionalHeaderFields: [String: String] = [:],
    cachePolicy: URLRequest.CachePolicy? = nil,
    timeoutInterval: TimeInterval? = nil,
    decoder: JSONDecoder = {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      return decoder
    }()
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

// MARK: - Raw Data response

public extension NetworkRequest where Response == Data, ErrorResponse == Void {

  /// Builds a request whose response is returned as raw `Data`.
  ///
  /// Useful for downloading binary content, capturing pre-parsed payloads
  /// for inspection, or interacting with non-JSON endpoints.
  ///
  /// - Parameters:
  ///   - httpMethod: The HTTP method to use. Defaults to ``HTTPMethod/get``.
  ///   - url: The destination URL.
  ///   - body: The request body to send, or `nil`.
  ///   - additionalHeaderFields: Extra headers to set on the request.
  ///   - cachePolicy: A cache policy to apply, or `nil` for the default.
  ///   - timeoutInterval: A timeout in seconds, or `nil` for the default.
  init(
    httpMethod: HTTPMethod = .get,
    url: @autoclosure @Sendable @escaping () throws -> URL,
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
      parse: { data, _ in
        data
      }
    )
  }
}

// MARK: - Void response, void error (fire-and-forget)

public extension NetworkRequest where Response == Void, ErrorResponse == Void {

  /// Builds a fire-and-forget request that ignores the response body.
  ///
  /// The response body is dropped and parsing always succeeds with `()`.
  /// HTTP-level failures still surface through the transport's error path.
  ///
  /// - Parameters:
  ///   - httpMethod: The HTTP method to use. Defaults to ``HTTPMethod/get``.
  ///   - url: The destination URL.
  ///   - body: The request body to send, or `nil`.
  ///   - additionalHeaderFields: Extra headers to set on the request.
  ///   - cachePolicy: A cache policy to apply, or `nil` for the default.
  ///   - timeoutInterval: A timeout in seconds, or `nil` for the default.
  init(
    httpMethod: HTTPMethod = .get,
    url: @autoclosure @Sendable @escaping () throws -> URL,
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
      parse: { _, _ in
        ()
      }
    )
  }
}

// MARK: - Void response, decodable error

public extension NetworkRequest where Response == Void, ErrorResponse: Decodable & Swift.Error & Sendable {

  /// Builds a request that ignores the success response body but decodes a
  /// structured error on non-2xx responses.
  ///
  /// Useful for `DELETE` or `POST` endpoints where success carries no
  /// payload but failures do.
  ///
  /// - Parameters:
  ///   - httpMethod: The HTTP method to use. Defaults to ``HTTPMethod/get``.
  ///   - url: The destination URL.
  ///   - body: The request body to send, or `nil`.
  ///   - additionalHeaderFields: Extra headers to set on the request.
  ///   - cachePolicy: A cache policy to apply, or `nil` for the default.
  ///   - timeoutInterval: A timeout in seconds, or `nil` for the default.
  ///   - decoder: The `JSONDecoder` used to decode the error body.
  init(
    httpMethod: HTTPMethod = .get,
    url: @autoclosure @Sendable @escaping () throws -> URL,
    body: NetworkRequestBody? = nil,
    additionalHeaderFields: [String: String] = [:],
    cachePolicy: URLRequest.CachePolicy? = nil,
    timeoutInterval: TimeInterval? = nil,
    decoder: JSONDecoder = {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      return decoder
    }()
  ) {

    self.init(
      httpMethod: httpMethod,
      url: url,
      body: body,
      additionalHeaderFields: additionalHeaderFields,
      cachePolicy: cachePolicy,
      timeoutInterval: timeoutInterval,
      parse: { data, urlResponse in
        guard let httpUrlResponse = urlResponse as? HTTPURLResponse,
           200 ..< 300 ~= httpUrlResponse.statusCode else {

          let error = try decoder.decode(ErrorResponse.self, from: data)
          throw error
        }

        return ()
      }
    )
  }
}
