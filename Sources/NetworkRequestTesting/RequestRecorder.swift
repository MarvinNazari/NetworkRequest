//
//  Copyright © 2026 Marvin Nazari. All rights reserved.
//

import Foundation

/// Collects the requests that pass through a stub so a test can assert on
/// what was sent after the fact.
///
/// Each request is stored as a ``RecordedRequest``, which carries the
/// original `URLRequest` plus assertion helpers.
///
/// ```swift
/// let recorder = RequestRecorder()
/// let session = StubURLProtocol.session { request in
///   await recorder.record(request)
///   return .response(.empty())
/// }
///
/// let (data, response) = try await session.data(for: try request.urlRequest())
/// _ = try request.parse(data, response)
/// #expect(await recorder.last?.method == "POST")
/// ```
///
/// ``StubURLProtocol/session(recording:returning:)`` wires this up for the
/// common "record everything, always reply the same" case.
public actor RequestRecorder {

  /// Every recorded request, oldest first.
  public private(set) var requests: [RecordedRequest] = []

  public init() {}

  /// The most recently recorded request, or `nil` if none was recorded.
  public var last: RecordedRequest? { requests.last }

  /// The number of recorded requests.
  public var count: Int { requests.count }

  /// Wraps `request` in a ``RecordedRequest`` and appends it to ``requests``.
  public func record(_ request: URLRequest) {
    requests.append(RecordedRequest(request))
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
