//
//  Copyright © 2023 Marvin Nazari. All rights reserved.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension URLRequest {
  var cURLCommand: String? {
    var command = "curl"

    if let httpMethod = httpMethod {
      command.append(commandLineArgument: "-X \(httpMethod)")
    }

    // HTTP Body
    if let httpBody = httpBody, !httpBody.isEmpty {
      var bodyString = String(data: httpBody, encoding: .utf8) ?? ""
      [("\\", "\\\\"), ("`", "\\`"), ("\"", "\\\""), ("$", "\\$")].forEach { search, replace in
        bodyString = bodyString.replacingOccurrences(of: search, with: replace)
      }

      command.append(commandLineArgument: "-d \"\(bodyString)\"")
    }

    // Encoding
    if let acceptEncoderHeader = allHTTPHeaderFields?["Accept-Encoding"], (acceptEncoderHeader as NSString).range(of: "gzip").location != NSNotFound {
      command.append(commandLineArgument: "--compressed")
    }

    // Cookie
    if let url = url, let cookies = HTTPCookieStorage.shared.cookies(for: url), !cookies.isEmpty {
      let cookieCommand = cookies.map {
        "\($0.name)=\($0.value);"
      }
      .joined()
      command.append(commandLineArgument: "--cookie \"\(cookieCommand)\"")
    }

    // Header fields
    if let allHTTPHeaderFields = allHTTPHeaderFields {
      for (header, value) in allHTTPHeaderFields {
        command.append(commandLineArgument: "-H '\(header): \(value.replacingOccurrences(of: "\'", with: "\\\'"))'")
      }
    }

    // URL
    if let url = url {
      command.append(commandLineArgument: "\"\(url.absoluteString)\"")
    }

    return command
  }
}

private extension String {
  mutating func append(commandLineArgument: String) {
    append(" \(commandLineArgument.trimmingCharacters(in: .whitespaces))")
  }
}
