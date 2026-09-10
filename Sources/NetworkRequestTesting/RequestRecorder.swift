//
//  Copyright © 2026 Marvin Nazari. All rights reserved.
//

import Foundation

/// Collects the `URLRequest`s that pass through a stub so a test can assert
/// on what was sent after the fact.
///
/// ```swift
/// let recorder = RequestRecorder()
/// let session = StubURLProtocol.session { request in
///   await recorder.record(request)
///   return .response(.empty())
/// }
///
/// try await request.send(using: session)
/// #expect(await recorder.last?.httpMethod == "POST")
/// ```
///
/// ``StubURLProtocol/session(recording:returning:)`` wires this up for the
/// common "record everything, always reply the same" case.
public actor RequestRecorder {

  /// Every recorded request, oldest first.
  public private(set) var requests: [URLRequest] = []

  public init() {}

  /// The most recently recorded request, or `nil` if none was recorded.
  public var last: URLRequest? { requests.last }

  /// The number of recorded requests.
  public var count: Int { requests.count }

  /// Appends `request` to ``requests``.
  public func record(_ request: URLRequest) {
    requests.append(request)
  }

  /// Discards every recorded request.
  public func reset() {
    requests.removeAll()
  }
}

public extension StubURLProtocol {

  /// Builds a session that records every request into `recorder` and
  /// answers each with `response`.
  static func session(recording recorder: RequestRecorder, returning response: Response) -> URLSession {
    session { request in
      await recorder.record(request)
      return .response(response)
    }
  }
}
