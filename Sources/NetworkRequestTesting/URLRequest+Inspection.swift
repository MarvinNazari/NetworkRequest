//
//  Copyright © 2026 Marvin Nazari. All rights reserved.
//

import Foundation

/// Read-only conveniences for asserting on a built `URLRequest`.
public extension URLRequest {

  /// The URL's query items, in order, or an empty array when there is no
  /// URL or no query.
  var queryItems: [URLQueryItem] {
    guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return []
    }
    return components.queryItems ?? []
  }

  /// Query items keyed by name. Duplicated names keep the last value; a
  /// valueless item (`?flag`) maps to an empty string.
  var queryDictionary: [String: String] {
    var result: [String: String] = [:]
    for item in queryItems {
      result[item.name] = item.value ?? ""
    }
    return result
  }

  /// The body decoded as UTF-8, or `nil` if there is no body or it is not
  /// valid UTF-8.
  var bodyString: String? {
    guard let httpBody else { return nil }
    return String(data: httpBody, encoding: .utf8)
  }

  /// The body parsed as a JSON object, or `nil` if there is no body or it
  /// is not a JSON object.
  var jsonBody: [String: Any]? {
    guard let httpBody else { return nil }
    return (try? JSONSerialization.jsonObject(with: httpBody)) as? [String: Any]
  }

  /// The body parsed as a JSON array, or `nil` if there is no body or it is
  /// not a JSON array.
  var jsonArrayBody: [Any]? {
    guard let httpBody else { return nil }
    return (try? JSONSerialization.jsonObject(with: httpBody)) as? [Any]
  }

  /// The body parsed as `application/x-www-form-urlencoded` pairs, or `nil`
  /// if there is no body or it is not valid UTF-8.
  ///
  /// Both `%20` and `+` are decoded as a space. Duplicated names keep the
  /// last value; a valueless pair maps to an empty string.
  var formBody: [String: String]? {
    guard let bodyString else { return nil }
    var components = URLComponents()
    // URLComponents follows RFC 3986, where "+" is literal; form encoding
    // (HTML spec) treats it as a space, so normalize before parsing.
    components.percentEncodedQuery = bodyString.replacingOccurrences(of: "+", with: "%20")
    var result: [String: String] = [:]
    for item in components.queryItems ?? [] {
      result[item.name] = item.value ?? ""
    }
    return result
  }
}
