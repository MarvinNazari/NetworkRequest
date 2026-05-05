//
//  Copyright © 2026 Marvin Nazari. All rights reserved.
//

import Foundation

extension URLRequest {

  /// Renders a `curl` command equivalent to this request.
  ///
  /// Returns `nil` when the request has no URL — without one there is
  /// nothing meaningful to render. Binary (non-UTF8) bodies are reported
  /// as `# (binary body of N bytes omitted)` rather than producing a
  /// runnable-but-incorrect command.
  var cURLCommand: String? {
    guard let url = url else { return nil }
    var command = "curl"

    if let httpMethod = httpMethod {
      command.append(commandLineArgument: "-X \(httpMethod)")
    }

    if let httpBody = httpBody, !httpBody.isEmpty {
      if var bodyString = String(data: httpBody, encoding: .utf8) {
        for (search, replace) in [("\\", "\\\\"), ("`", "\\`"), ("\"", "\\\""), ("$", "\\$")] {
          bodyString = bodyString.replacingOccurrences(of: search, with: replace)
        }
        command.append(commandLineArgument: "-d \"\(bodyString)\"")
      } else {
        command.append(commandLineArgument: "# (binary body of \(httpBody.count) bytes omitted)")
      }
    }

    if let acceptEncoding = allHTTPHeaderFields?["Accept-Encoding"], acceptEncoding.contains("gzip") {
      command.append(commandLineArgument: "--compressed")
    }

    if let cookies = HTTPCookieStorage.shared.cookies(for: url), !cookies.isEmpty {
      let cookieString = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
      command.append(commandLineArgument: "--cookie \"\(cookieString)\"")
    }

    if let allHTTPHeaderFields = allHTTPHeaderFields {
      for (header, value) in allHTTPHeaderFields {
        // Wrap header values in single quotes. Use the ANSI-C trick for
        // embedded apostrophes: end the quoted string, insert an escaped
        // apostrophe, reopen — `'\''`.
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        command.append(commandLineArgument: "-H '\(header): \(escaped)'")
      }
    }

    command.append(commandLineArgument: "\"\(url.absoluteString)\"")
    return command
  }
}

private extension String {
  mutating func append(commandLineArgument: String) {
    append(" \(commandLineArgument.trimmingCharacters(in: .whitespaces))")
  }
}
