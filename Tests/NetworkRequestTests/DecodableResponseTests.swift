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

private struct SnakeUser: Decodable, Equatable, Sendable {
  let userId: Int
  let displayName: String
}

@Suite("Decodable response handling", .serialized)
final class DecodableResponseTests {

  deinit {
    URLProtocolMock.reset()
  }

  // MARK: Success path end-to-end

  @Test func successDecodesResponse() async throws {
    let url = URL(string: "https://example.com/me")!
    URLProtocolMock.requestHandler = { _ in
      (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
       Data(#"{"id":1,"name":"Ada"}"#.utf8))
    }
    let session = URLProtocolMock.makeSession()

    let request = NetworkRequest<User, APIError>(url: url)
    let (data, response) = try await session.data(for: request.urlRequest())
    let user = try request.parse(data, response)

    #expect(user == User(id: 1, name: "Ada"))
  }

  // MARK: Status-code boundaries (Decodable + Decodable & Error)

  @Test(
    "200..<300 boundary in Decodable+Error overload",
    arguments: [
      (199, false), // throws — below window
      (200, true),  // success
      (299, true),  // success
      (300, false), // throws — above window
    ]
  )
  func decodableErrorBoundary(statusCode: Int, succeeds: Bool) throws {
    let url = URL(string: "https://example.com/me")!
    let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    let request = NetworkRequest<User, APIError>(url: url)

    if succeeds {
      let user = try request.parse(Data(#"{"id":1,"name":"Ada"}"#.utf8), response)
      #expect(user == User(id: 1, name: "Ada"))
    } else {
      #expect(throws: APIError(message: "boom")) {
        try request.parse(Data(#"{"message":"boom"}"#.utf8), response)
      }
    }
  }

  @Test(
    "200..<300 boundary in Void+Error overload",
    arguments: [199, 200, 299, 300]
  )
  func voidErrorBoundary(statusCode: Int) throws {
    let url = URL(string: "https://example.com/me")!
    let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    let request = NetworkRequest<Void, APIError>(httpMethod: .delete, url: url)
    let body = Data(#"{"message":"boom"}"#.utf8)

    if 200 ..< 300 ~= statusCode {
      try request.parse(body, response)
    } else {
      #expect(throws: APIError(message: "boom")) {
        try request.parse(body, response)
      }
    }
  }

  // MARK: Error decoding fallback

  @Test func malformedErrorBodyThrowsUnexpectedHTTPResponse() throws {
    let url = URL(string: "https://example.com/me")!
    let response = HTTPURLResponse(url: url, statusCode: 502, httpVersion: nil, headerFields: nil)!
    let body = Data("<html>bad gateway</html>".utf8)
    let request = NetworkRequest<User, APIError>(url: url)

    #expect {
      try request.parse(body, response)
    } throws: { error in
      guard let unexpected = error as? UnexpectedHTTPResponse else { return false }
      return unexpected.statusCode == 502 && unexpected.data == body
    }
  }

  @Test func nonHTTPResponseThrowsUnexpectedHTTPResponseWithStatusMinusOne() throws {
    let url = URL(string: "https://example.com/me")!
    let response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
    let request = NetworkRequest<User, APIError>(url: url)

    #expect {
      try request.parse(Data("plain".utf8), response)
    } throws: { error in
      (error as? UnexpectedHTTPResponse)?.statusCode == -1
    }
  }

  // MARK: Custom decoder substitution

  @Test func customDecoderUsedForSuccess() throws {
    let url = URL(string: "https://example.com/me")!
    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let request = NetworkRequest<SnakeUser, APIError>(url: url, decoder: decoder)

    let user = try request.parse(Data(#"{"user_id":7,"display_name":"Grace"}"#.utf8), response)
    #expect(user == SnakeUser(userId: 7, displayName: "Grace"))
  }

  @Test func customDecoderUsedForErrorPath() throws {
    struct WeirdError: Decodable, Error, Equatable {
      let messageKey: String
    }
    let url = URL(string: "https://example.com/me")!
    let response = HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)!
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let request = NetworkRequest<User, WeirdError>(url: url, decoder: decoder)

    #expect(throws: WeirdError(messageKey: "nope")) {
      try request.parse(Data(#"{"message_key":"nope"}"#.utf8), response)
    }
  }

  // MARK: Other typed overloads

  @Test func voidErrorOverloadSkipsStatusCheck() throws {
    let url = URL(string: "https://example.com/me")!
    let request = NetworkRequest<User, Never>(url: url)
    // Even with a 500 response, the no-error overload decodes whatever the body holds.
    let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
    let user = try request.parse(Data(#"{"id":7,"name":"Grace"}"#.utf8), response)
    #expect(user == User(id: 7, name: "Grace"))
  }

  @Test func dataResponseReturnsRawBytes() throws {
    let url = URL(string: "https://example.com/blob")!
    let request = NetworkRequest<Data, Never>(url: url)
    let bytes = Data([0x00, 0x01, 0x02, 0x03])
    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    #expect(try request.parse(bytes, response) == bytes)
  }

  @Test func dataResponseReturnsEmptyBytes() throws {
    let url = URL(string: "https://example.com/blob")!
    let request = NetworkRequest<Data, Never>(url: url)
    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    #expect(try request.parse(Data(), response) == Data())
  }

  @Test func dataResponseWithDecodableErrorThrowsOnFailure() throws {
    let url = URL(string: "https://example.com/blob")!
    let request = NetworkRequest<Data, APIError>(url: url)
    let response = HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: nil)!
    let body = Data(#"{"message":"forbidden"}"#.utf8)

    #expect(throws: APIError(message: "forbidden")) {
      try request.parse(body, response)
    }
  }

  @Test func dataResponseWithDecodableErrorReturnsBytesOn2xx() throws {
    let url = URL(string: "https://example.com/blob")!
    let request = NetworkRequest<Data, APIError>(url: url)
    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    let bytes = Data([0xCA, 0xFE])
    #expect(try request.parse(bytes, response) == bytes)
  }

  @Test func voidVoidOverloadIgnoresBody() throws {
    let url = URL(string: "https://example.com/ping")!
    let request = NetworkRequest<Void, Never>(httpMethod: .post, url: url)
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

  // MARK: UnexpectedHTTPResponse-error overloads (status-validated, no envelope)

  @Test func decodableUnexpectedHTTPResponseSuccess() throws {
    let url = URL(string: "https://example.com/me")!
    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    let request = NetworkRequest<User, UnexpectedHTTPResponse>(url: url)
    let user = try request.parse(Data(#"{"id":1,"name":"Ada"}"#.utf8), response)
    #expect(user == User(id: 1, name: "Ada"))
  }

  @Test func decodableUnexpectedHTTPResponseFailure() throws {
    let url = URL(string: "https://example.com/me")!
    let response = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!
    let body = Data("maintenance".utf8)
    let request = NetworkRequest<User, UnexpectedHTTPResponse>(url: url)

    #expect {
      try request.parse(body, response)
    } throws: { error in
      let unexpected = error as? UnexpectedHTTPResponse
      return unexpected?.statusCode == 503 && unexpected?.data == body
    }
  }

  @Test func dataUnexpectedHTTPResponseSuccess() throws {
    let url = URL(string: "https://example.com/blob")!
    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    let request = NetworkRequest<Data, UnexpectedHTTPResponse>(url: url)
    let bytes = Data([0xCA, 0xFE])
    #expect(try request.parse(bytes, response) == bytes)
  }

  @Test func dataUnexpectedHTTPResponseFailure() throws {
    let url = URL(string: "https://example.com/blob")!
    let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
    let body = Data("not found".utf8)
    let request = NetworkRequest<Data, UnexpectedHTTPResponse>(url: url)

    #expect {
      try request.parse(body, response)
    } throws: { error in
      (error as? UnexpectedHTTPResponse)?.statusCode == 404
    }
  }

  @Test func voidUnexpectedHTTPResponseSuccess() throws {
    let url = URL(string: "https://example.com/ping")!
    let response = HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil)!
    let request = NetworkRequest<Void, UnexpectedHTTPResponse>(httpMethod: .post, url: url)
    try request.parse(Data(), response)
  }

  @Test func voidUnexpectedHTTPResponseFailure() throws {
    let url = URL(string: "https://example.com/ping")!
    let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
    let request = NetworkRequest<Void, UnexpectedHTTPResponse>(httpMethod: .post, url: url)

    #expect {
      try request.parse(Data(), response)
    } throws: { error in
      (error as? UnexpectedHTTPResponse)?.statusCode == 500
    }
  }
}
