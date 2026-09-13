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

/// The two-line shape the library documents: build and send the request with
/// `URLSession`, then feed the reply back through `parse`.
private func send<Response, ErrorResponse>(
  _ request: NetworkRequest<Response, ErrorResponse>,
  using session: URLSession
) async throws -> Response {
  let (data, response) = try await session.data(for: try request.urlRequest())
  return try request.parse(data, response)
}

@Suite("Sending a NetworkRequest through a stub")
struct StubbedSendTests {

  private let url = URL(string: "https://api.example.com/me")!

  @Test func buildsTheRequestFromItsComponents() throws {
    let request = NetworkRequest<User, APIError>(
      httpMethod: .post,
      url: url,
      body: .form(dictionary: ["q": "a b"]),
      additionalHeaderFields: ["Authorization": "Bearer t"]
    )

    let built = RecordedRequest(try request.urlRequest())
    #expect(built.url == url)
    #expect(built.method == "POST")
    #expect(built.headers["Authorization"] == "Bearer t")
    #expect(built.formBody == ["q": "a b"])
  }

  @Test func buildingPropagatesErrors() {
    let request = NetworkRequest<User, APIError>(url: URL(string: ""))
    #expect(throws: URLError.self) { try request.urlRequest() }
  }

  @Test func decodesASuccessfulResponse() async throws {
    let recorder = RequestRecorder()
    let session = StubURLProtocol.session(recording: recorder, returning: .json(#"{"id":1,"name":"Ada"}"#))

    let request = NetworkRequest<User, APIError>(
      url: url,
      additionalHeaderFields: ["Authorization": "Bearer t"]
    )
    let user = try await send(request, using: session)

    #expect(user == User(id: 1, name: "Ada"))
    let sent = try #require(await recorder.last)
    #expect(sent.url == url)
    #expect(sent.path == "/me")
    #expect(sent.headers["Authorization"] == "Bearer t")
    #expect(sent.headers["Accept"] == "application/json")
  }

  @Test func throwsUnexpectedHTTPResponseForNon2xx() async throws {
    let session = StubURLProtocol.session(returning: .json(#"{"unexpected":"shape"}"#, status: 503))
    let request = NetworkRequest<User, UnexpectedHTTPResponse>(url: url)

    do {
      _ = try await send(request, using: session)
      Issue.record("expected UnexpectedHTTPResponse")
    } catch let error as UnexpectedHTTPResponse {
      #expect(error.statusCode == 503)
      #expect(error.data == Data(#"{"unexpected":"shape"}"#.utf8))
    }
  }

  @Test func throwsTypedErrorEnvelope() async throws {
    let session = StubURLProtocol.session(returning: .json(#"{"message":"nope"}"#, status: 401))
    let request = NetworkRequest<User, APIError>(url: url)

    await #expect(throws: APIError(message: "nope")) {
      try await send(request, using: session)
    }
  }

  @Test func surfacesTransportFailures() async throws {
    let session = StubURLProtocol.session { _ in .failure(URLError(.cannotFindHost)) }
    let request = NetworkRequest<User, APIError>(url: url)

    await #expect(throws: URLError.self) {
      try await send(request, using: session)
    }
  }

  @Test func worksWithSequences() async throws {
    let session = StubURLProtocol.session(sequence: [
      .response(.json(#"{"id":1,"name":"Ada"}"#)),
      .response(.json(#"{"id":2,"name":"Grace"}"#)),
    ])
    let request = NetworkRequest<User, APIError>(url: url)

    #expect(try await send(request, using: session) == User(id: 1, name: "Ada"))
    #expect(try await send(request, using: session) == User(id: 2, name: "Grace"))
    await #expect { try await send(request, using: session) } throws: { error in
      StubURLProtocol.SequenceExhausted.matches(error)
    }
  }
}
