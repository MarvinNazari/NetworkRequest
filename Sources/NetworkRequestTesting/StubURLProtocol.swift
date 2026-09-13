//
//  Copyright © 2026 Marvin Nazari. All rights reserved.
//

import Foundation

/// An in-process HTTP stub for unit tests.
///
/// Every `URLSession` produced by ``session(_:)``, ``session(returning:)`` or
/// ``session(sequence:)`` carries its own handler, so tests can run in
/// parallel without sharing mutable state and without touching the network.
///
/// ```swift
/// let session = StubURLProtocol.session { request in
///   #expect(request.url?.path == "/me")
///   return .response(.json(#"{"id":1,"name":"Ada"}"#))
/// }
///
/// let (data, response) = try await session.data(for: try request.urlRequest())
/// let user = try request.parse(data, response)
/// ```
public final class StubURLProtocol: URLProtocol, @unchecked Sendable {

  // MARK: - Response

  /// A canned HTTP response returned by a stub handler.
  public struct Response: Sendable {

    /// The HTTP status code to report.
    public var status: Int

    /// The response header fields.
    public var headers: [String: String]

    /// The response body.
    public var body: Data

    /// Creates a response from its raw components.
    public init(status: Int = 200, headers: [String: String] = [:], body: Data = Data()) {
      self.status = status
      self.headers = headers
      self.body = body
    }

    /// A JSON response built from a string literal.
    public static func json(_ body: String, status: Int = 200) -> Response {
      Response(status: status, headers: ["Content-Type": "application/json"], body: Data(body.utf8))
    }

    /// A JSON response built from already-encoded bytes.
    public static func json(_ data: Data, status: Int = 200) -> Response {
      Response(status: status, headers: ["Content-Type": "application/json"], body: data)
    }

    /// A response with an arbitrary body and content type.
    public static func data(_ body: Data, contentType: String, status: Int = 200) -> Response {
      Response(status: status, headers: ["Content-Type": contentType], body: body)
    }

    /// A response with no body and no headers.
    public static func empty(status: Int = 200) -> Response {
      Response(status: status, headers: [:], body: Data())
    }
  }

  // MARK: - Outcome

  /// What the stub does with a request: answer it, or fail at the
  /// transport level as `URLSession` would for a dropped connection.
  public enum Outcome: Sendable {
    case response(Response)
    case failure(URLError)
  }

  /// Thrown by a ``session(sequence:)`` session once every scripted
  /// outcome has been consumed.
  ///
  /// `URLSession` re-creates errors thrown by a `URLProtocol` as plain
  /// `NSError`s, so this type is a `CustomNSError` and the value your test
  /// catches is identified by ``errorDomain`` rather than by a Swift `as`
  /// cast. Use ``init(_:)`` to recover the typed form, or
  /// ``matches(_:)`` for a quick check.
  public struct SequenceExhausted: CustomNSError, LocalizedError, Sendable {

    /// The `NSError` domain used when the error crosses `URLSession`.
    public static let errorDomain = "NetworkRequestTesting.StubURLProtocol.SequenceExhausted"

    /// How many outcomes the sequence was created with.
    public let expectedCount: Int

    /// The URL of the request that had no outcome left to answer it.
    public let url: URL?

    /// The HTTP method of that request.
    public let httpMethod: String?

    init(expectedCount: Int, request: URLRequest) {
      self.expectedCount = expectedCount
      self.url = request.url
      self.httpMethod = request.httpMethod
    }

    /// Recovers the typed error from one caught after a `URLSession` call,
    /// or returns `nil` if `error` is not a ``SequenceExhausted``.
    public init?(_ error: any Error) {
      if let typed = error as? SequenceExhausted {
        self = typed
        return
      }
      let nsError = error as NSError
      guard nsError.domain == Self.errorDomain,
        let expectedCount = nsError.userInfo[Self.expectedCountKey] as? Int
      else { return nil }
      self.expectedCount = expectedCount
      self.url = (nsError.userInfo[Self.urlKey] as? String).flatMap(URL.init(string:))
      self.httpMethod = nsError.userInfo[Self.httpMethodKey] as? String
    }

    /// Whether `error` is a ``SequenceExhausted``, in typed or bridged form.
    public static func matches(_ error: any Error) -> Bool {
      SequenceExhausted(error) != nil
    }

    public var errorDescription: String? {
      let method = httpMethod ?? "GET"
      let url = url?.absoluteString ?? "<no URL>"
      return "StubURLProtocol: sequence of \(expectedCount) outcome(s) exhausted; "
        + "unexpected request #\(expectedCount + 1): \(method) \(url)"
    }

    public var errorCode: Int { expectedCount }

    public var errorUserInfo: [String: Any] {
      var info: [String: Any] = [
        NSLocalizedDescriptionKey: errorDescription ?? "",
        Self.expectedCountKey: expectedCount,
      ]
      info[Self.urlKey] = url?.absoluteString
      info[Self.httpMethodKey] = httpMethod
      return info
    }

    private static let expectedCountKey = "expectedCount"
    private static let urlKey = "url"
    private static let httpMethodKey = "httpMethod"
  }

  /// Decides how a request is answered.
  ///
  /// The handler is `async` so it can `await` an actor such as
  /// ``RequestRecorder``; the response is only delivered once the handler
  /// returns, which keeps assertions made after the call deterministic.
  /// Synchronous closures satisfy this type unchanged.
  public typealias Handler = @Sendable (URLRequest) async -> Outcome

  // MARK: - Session factories

  /// Builds an ephemeral session that answers every request through `handler`.
  public static func session(_ handler: @escaping Handler) -> URLSession {
    session(resolving: { .success(await handler($0)) })
  }

  /// Builds a session that answers every request with the same `response`.
  public static func session(returning response: Response) -> URLSession {
    session { _ in .response(response) }
  }

  /// Builds a session that answers requests with `outcomes` in order.
  ///
  /// Once the sequence is exhausted, further requests fail with
  /// ``SequenceExhausted`` so an unexpected extra call is reported instead of
  /// silently reusing an earlier response.
  public static func session(sequence outcomes: [Outcome]) -> URLSession {
    let script = Script(outcomes)
    return session(resolving: { request in
      if let outcome = script.next() {
        return .success(outcome)
      }
      return .failure(SequenceExhausted(expectedCount: outcomes.count, request: request))
    })
  }

  /// The internal handler shape: a scripted session can fail with an error
  /// that is not a `URLError`, which the public ``Outcome`` deliberately
  /// does not model.
  private typealias Resolver = @Sendable (URLRequest) async -> Result<Outcome, SequenceExhausted>

  private static func session(resolving resolver: @escaping Resolver) -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    Registry.shared.register(resolver, for: configuration)
    return URLSession(configuration: configuration)
  }

  // MARK: - URLProtocol

  public override class func canInit(with request: URLRequest) -> Bool { true }

  public override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  private var resolution: Task<Void, Never>?

  public override func startLoading() {
    guard let resolver = Registry.shared.resolver(for: request) else {
      client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
      return
    }

    // The registry header is an implementation detail; hide it so handlers
    // and recorders see exactly the headers the code under test produced.
    var visibleRequest = request
    visibleRequest.setValue(nil, forHTTPHeaderField: Registry.headerName)

    resolution = Task { [request] in
      let resolution = await resolver(visibleRequest)
      guard !Task.isCancelled else { return }
      deliver(resolution, for: request)
    }
  }

  public override func stopLoading() {
    resolution?.cancel()
    resolution = nil
  }

  private func deliver(_ resolution: Result<Outcome, SequenceExhausted>, for request: URLRequest) {
    switch resolution {
    case .failure(let error):
      client?.urlProtocol(self, didFailWithError: error)

    case .success(.failure(let error)):
      client?.urlProtocol(self, didFailWithError: error)

    case .success(.response(let response)):
      guard let url = request.url,
        let httpResponse = HTTPURLResponse(
          url: url,
          statusCode: response.status,
          httpVersion: "HTTP/1.1",
          headerFields: response.headers
        )
      else {
        client?.urlProtocol(self, didFailWithError: URLError(.badURL))
        return
      }
      client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: response.body)
      client?.urlProtocolDidFinishLoading(self)
    }
  }

  // MARK: - Registry

  /// Maps a session to its handler. `URLProtocol` instances only see the
  /// request, so the session identity is smuggled through an additional
  /// header applied by the session configuration.
  private final class Registry: @unchecked Sendable {
    static let shared = Registry()
    static let headerName = "X-StubURLProtocol-Session"

    private let lock = NSLock()
    private var resolvers: [String: Resolver] = [:]

    func register(_ resolver: @escaping Resolver, for configuration: URLSessionConfiguration) {
      let id = UUID().uuidString
      var headers = configuration.httpAdditionalHeaders ?? [:]
      headers[Self.headerName] = id
      configuration.httpAdditionalHeaders = headers
      lock.lock()
      defer { lock.unlock() }
      resolvers[id] = resolver
    }

    func resolver(for request: URLRequest) -> Resolver? {
      guard let id = request.value(forHTTPHeaderField: Self.headerName) else { return nil }
      lock.lock()
      defer { lock.unlock() }
      return resolvers[id]
    }
  }

  // MARK: - Script

  /// A thread-safe cursor over a list of scripted outcomes.
  private final class Script: @unchecked Sendable {
    private let lock = NSLock()
    private var remaining: ArraySlice<Outcome>

    init(_ outcomes: [Outcome]) {
      remaining = outcomes[...]
    }

    func next() -> Outcome? {
      lock.lock()
      defer { lock.unlock() }
      return remaining.popFirst()
    }
  }
}
