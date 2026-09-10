import Testing
import Foundation
import NetworkRequest
import NetworkRequestTesting

private struct User: Decodable, Equatable, Sendable {
  let id: Int
  let name: String
}

private struct APIError: Decodable, Error, Equatable, Sendable {
  let message: String
}

@Suite("NetworkRequest + Testing")
struct NetworkRequestSendTests {

  private let url = URL(string: "https://api.example.com/me")!

  @Test func makeURLRequestInvokesTheClosure() throws {
    let request = NetworkRequest<User, APIError>(
      httpMethod: .post,
      url: url,
      body: .form(dictionary: ["q": "a b"]),
      additionalHeaderFields: ["Authorization": "Bearer t"]
    )

    let built = try request.makeURLRequest()
    #expect(built.url == url)
    #expect(built.httpMethod == "POST")
    #expect(built.value(forHTTPHeaderField: "Authorization") == "Bearer t")
    #expect(built.formBody == ["q": "a b"])
  }

  @Test func makeURLRequestPropagatesErrors() {
    let request = NetworkRequest<User, APIError>(url: URL(string: ""))
    #expect(throws: URLError.self) { try request.makeURLRequest() }
  }

  @Test func sendDecodesASuccessfulResponse() async throws {
    let recorder = RequestRecorder()
    let session = StubURLProtocol.session(recording: recorder, returning: .json(#"{"id":1,"name":"Ada"}"#))

    let request = NetworkRequest<User, APIError>(
      url: url,
      additionalHeaderFields: ["Authorization": "Bearer t"]
    )
    let user = try await request.send(using: session)

    #expect(user == User(id: 1, name: "Ada"))
    let sent = try #require(await recorder.last)
    #expect(sent.url == url)
    #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer t")
    #expect(sent.value(forHTTPHeaderField: "Accept") == "application/json")
  }

  @Test func sendThrowsUnexpectedHTTPResponseForNon2xx() async throws {
    let session = StubURLProtocol.session(returning: .json(#"{"unexpected":"shape"}"#, status: 503))
    let request = NetworkRequest<User, UnexpectedHTTPResponse>(url: url)

    do {
      _ = try await request.send(using: session)
      Issue.record("expected UnexpectedHTTPResponse")
    } catch let error as UnexpectedHTTPResponse {
      #expect(error.statusCode == 503)
      #expect(error.data == Data(#"{"unexpected":"shape"}"#.utf8))
    }
  }

  @Test func sendThrowsTypedErrorEnvelope() async throws {
    let session = StubURLProtocol.session(returning: .json(#"{"message":"nope"}"#, status: 401))
    let request = NetworkRequest<User, APIError>(url: url)

    await #expect(throws: APIError(message: "nope")) {
      try await request.send(using: session)
    }
  }

  @Test func sendSurfacesTransportFailures() async throws {
    let session = StubURLProtocol.session { _ in .failure(URLError(.cannotFindHost)) }
    let request = NetworkRequest<User, APIError>(url: url)

    await #expect(throws: URLError.self) {
      try await request.send(using: session)
    }
  }

  @Test func sendWorksWithSequences() async throws {
    let session = StubURLProtocol.session(sequence: [
      .response(.json(#"{"id":1,"name":"Ada"}"#)),
      .response(.json(#"{"id":2,"name":"Grace"}"#)),
    ])
    let request = NetworkRequest<User, APIError>(url: url)

    #expect(try await request.send(using: session) == User(id: 1, name: "Ada"))
    #expect(try await request.send(using: session) == User(id: 2, name: "Grace"))
    await #expect { try await request.send(using: session) } throws: { error in
      StubURLProtocol.SequenceExhausted.matches(error)
    }
  }
}
