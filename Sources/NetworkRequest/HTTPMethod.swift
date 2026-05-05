//
//  Copyright © 2023 Marvin Nazari. All rights reserved.
//

import Foundation

/// An HTTP request method.
///
/// `HTTPMethod` is a thin, extensible wrapper around the HTTP method string.
/// The standard methods defined by RFC 9110 are exposed as static properties
/// (``get``, ``post``, ``put``, ``patch``, ``delete``, etc.), and you can
/// define custom methods by calling ``init(rawValue:)`` directly:
///
/// ```swift
/// extension HTTPMethod {
///     static let link = HTTPMethod(rawValue: "LINK")
/// }
/// ```
public struct HTTPMethod: RawRepresentable, Hashable, Sendable {

  /// The uppercased HTTP method string (for example, `"GET"` or `"POST"`).
  public let rawValue: String

  /// Creates an HTTP method from its raw string value.
  ///
  /// Prefer the standard static properties (``get``, ``post``, ...) when possible;
  /// use this initializer to define custom or non-standard methods.
  ///
  /// - Parameter rawValue: The HTTP method string. Conventionally uppercased.
  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

public extension HTTPMethod {
  /// The HTTP `GET` method, used to request a representation of a resource.
  static let get = Self(rawValue: "GET")
  /// The HTTP `POST` method, used to submit data to a resource.
  static let post = Self(rawValue: "POST")
  /// The HTTP `PUT` method, used to replace the target resource with the request payload.
  static let put = Self(rawValue: "PUT")
  /// The HTTP `HEAD` method, identical to `GET` but without a response body.
  static let head = Self(rawValue: "HEAD")
  /// The HTTP `DELETE` method, used to remove the target resource.
  static let delete = Self(rawValue: "DELETE")
  /// The HTTP `PATCH` method, used to apply a partial update to a resource.
  static let patch = Self(rawValue: "PATCH")
  /// The HTTP `TRACE` method, used to perform a message loop-back test along the path to the target.
  static let trace = Self(rawValue: "TRACE")
  /// The HTTP `OPTIONS` method, used to describe the communication options for the target.
  static let options = Self(rawValue: "OPTIONS")
  /// The HTTP `CONNECT` method, used to establish a tunnel to the server.
  static let connect = Self(rawValue: "CONNECT")
}
