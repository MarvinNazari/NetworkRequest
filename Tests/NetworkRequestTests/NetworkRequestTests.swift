import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import NetworkRequest

@Suite("URLRequest construction")
struct NetworkRequestTests {

  @Test func defaultMethodIsGET() throws {
    let request = NetworkRequest<Data, Void>(
      url: URL(string: "https://example.com/x")!
    )
    let urlRequest = try request.urlRequest()
    #expect(urlRequest.httpMethod == "GET")
  }

  @Test func httpMethodIsPropagated() throws {
    let request = NetworkRequest<Data, Void>(
      httpMethod: .post,
      url: URL(string: "https://example.com/x")!
    )
    let urlRequest = try request.urlRequest()
    #expect(urlRequest.httpMethod == "POST")
  }

  @Test func acceptHeaderDefaultsToJSON() throws {
    let request = NetworkRequest<Data, Void>(
      url: URL(string: "https://example.com/x")!
    )
    let urlRequest = try request.urlRequest()
    #expect(urlRequest.value(forHTTPHeaderField: "Accept") == "application/json")
  }

  @Test func bodyContentTypeHeaderSet() throws {
    let body = NetworkRequestBody(data: Data("hi".utf8), contentType: "text/plain")
    let request = NetworkRequest<Data, Void>(
      httpMethod: .post,
      url: URL(string: "https://example.com/x")!,
      body: body
    )
    let urlRequest = try request.urlRequest()
    #expect(urlRequest.value(forHTTPHeaderField: "Content-Type") == "text/plain")
    #expect(urlRequest.httpBody == Data("hi".utf8))
  }

  @Test func additionalHeadersMerged() throws {
    let request = NetworkRequest<Data, Void>(
      url: URL(string: "https://example.com/x")!,
      additionalHeaderFields: [
        "Authorization": "Bearer abc",
        "X-Custom": "value",
      ]
    )
    let urlRequest = try request.urlRequest()
    #expect(urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
    #expect(urlRequest.value(forHTTPHeaderField: "X-Custom") == "value")
  }

  @Test func cachePolicyApplied() throws {
    let request = NetworkRequest<Data, Void>(
      url: URL(string: "https://example.com/x")!,
      cachePolicy: .reloadIgnoringLocalCacheData
    )
    let urlRequest = try request.urlRequest()
    #expect(urlRequest.cachePolicy == .reloadIgnoringLocalCacheData)
  }

  @Test func timeoutIntervalApplied() throws {
    let request = NetworkRequest<Data, Void>(
      url: URL(string: "https://example.com/x")!,
      timeoutInterval: 7
    )
    let urlRequest = try request.urlRequest()
    #expect(urlRequest.timeoutInterval == 7)
  }

  @Test func urlClosureEvaluatedLazily() throws {
    let counter = Counter()
    let request = NetworkRequest<Data, Void>(
      urlRequest: {
        counter.increment()
        return URLRequest(url: URL(string: "https://example.com/x")!)
      },
      parse: { data, _ in data }
    )
    #expect(counter.value == 0)
    _ = try request.urlRequest()
    _ = try request.urlRequest()
    #expect(counter.value == 2)
  }
}

private final class Counter: @unchecked Sendable {
  private let lock = NSLock()
  private var _value = 0
  var value: Int {
    lock.lock(); defer { lock.unlock() }
    return _value
  }
  func increment() {
    lock.lock(); defer { lock.unlock() }
    _value += 1
  }
}
