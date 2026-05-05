import Testing
import Foundation
@testable import NetworkRequest

private struct User: Decodable, Equatable, Sendable {
  let id: Int
  let name: String
}

private struct APIError: Decodable, Error, Equatable, Sendable {
  let message: String
}

@Suite("Decodable response handling", .serialized)
final class DecodableResponseTests {

  deinit {
    URLProtocolMock.reset()
  }

  @Test func successDecodesResponse() async throws {
    let url = URL(string: "https://example.com/me")!
    let json = #"{"id":1,"name":"Ada"}"#
    URLProtocolMock.requestHandler = { _ in
      (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
      Data(json.utf8))
    }
    let session = URLProtocolMock.makeSession()

    let request = NetworkRequest<User, APIError>(url: url)
    let (data, response) = try await session.data(for: request.urlRequest())
    let user = try request.parse(data, response)

    #expect(user == User(id: 1, name: "Ada"))
  }

  @Test func nonSuccessStatusThrowsDecodedError() async throws {
    let url = URL(string: "https://example.com/me")!
    let json = #"{"message":"forbidden"}"#
    URLProtocolMock.requestHandler = { _ in
      (HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: nil)!,
      Data(json.utf8))
    }
    let session = URLProtocolMock.makeSession()

    let request = NetworkRequest<User, APIError>(url: url)
    let (data, response) = try await session.data(for: request.urlRequest())

    #expect(throws: APIError(message: "forbidden")) {
      try request.parse(data, response)
    }
  }

  @Test func voidErrorOverloadSkipsStatusCheck() throws {
    let url = URL(string: "https://example.com/me")!
    let request = NetworkRequest<User, Void>(url: url)
    // Even with a 500 response, the Void-error overload decodes whatever the body holds.
    let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
    let body = Data(#"{"id":7,"name":"Grace"}"#.utf8)
    let user = try request.parse(body, response)
    #expect(user == User(id: 7, name: "Grace"))
  }

  @Test func dataResponseReturnsRawBytes() throws {
    let url = URL(string: "https://example.com/blob")!
    let request = NetworkRequest<Data, Void>(url: url)
    let bytes = Data([0x00, 0x01, 0x02, 0x03])
    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    #expect(try request.parse(bytes, response) == bytes)
  }

  @Test func voidVoidOverloadIgnoresBody() throws {
    let url = URL(string: "https://example.com/ping")!
    let request = NetworkRequest<Void, Void>(httpMethod: .post, url: url)
    let response = HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil)!
    try request.parse(Data("ignored".utf8), response)
  }

  @Test func voidResponseDecodableErrorThrowsOnFailure() throws {
    let url = URL(string: "https://example.com/users/42")!
    let request = NetworkRequest<Void, APIError>(httpMethod: .delete, url: url)
    let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
    let body = Data(#"{"message":"not found"}"#.utf8)
    #expect(throws: APIError(message: "not found")) {
      try request.parse(body, response)
    }
  }

  @Test func voidResponseDecodableErrorSucceedsOn2xx() throws {
    let url = URL(string: "https://example.com/users/42")!
    let request = NetworkRequest<Void, APIError>(httpMethod: .delete, url: url)
    let response = HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil)!
    try request.parse(Data(), response)
  }
}
