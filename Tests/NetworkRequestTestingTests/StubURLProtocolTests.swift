import Testing
import Foundation
import NetworkRequestTesting

@Suite("StubURLProtocol")
struct StubURLProtocolTests {

  private let url = URL(string: "https://example.com/things?page=2")!

  // MARK: Responses

  @Test func answersWithStatusHeadersAndBody() async throws {
    let session = StubURLProtocol.session { _ in
      .response(.init(status: 201, headers: ["X-Trace": "abc"], body: Data("hello".utf8)))
    }

    let (data, response) = try await session.data(from: url)
    let http = try #require(response as? HTTPURLResponse)

    #expect(http.statusCode == 201)
    #expect(http.value(forHTTPHeaderField: "X-Trace") == "abc")
    #expect(String(decoding: data, as: UTF8.self) == "hello")
  }

  @Test func jsonFactoriesSetContentType() async throws {
    let session = StubURLProtocol.session(returning: .json(#"{"ok":true}"#, status: 202))

    let (data, response) = try await session.data(from: url)
    let http = try #require(response as? HTTPURLResponse)

    #expect(http.statusCode == 202)
    #expect(http.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(String(decoding: data, as: UTF8.self) == #"{"ok":true}"#)
  }

  @Test func dataFactorySetsCustomContentType() async throws {
    let session = StubURLProtocol.session(returning: .data(Data([0x01, 0x02]), contentType: "application/octet-stream"))

    let (data, response) = try await session.data(from: url)
    let http = try #require(response as? HTTPURLResponse)

    #expect(http.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
    #expect(data == Data([0x01, 0x02]))
  }

  @Test func emptyFactoryHasNoBody() async throws {
    let session = StubURLProtocol.session(returning: .empty(status: 204))

    let (data, response) = try await session.data(from: url)
    let http = try #require(response as? HTTPURLResponse)

    #expect(http.statusCode == 204)
    #expect(data.isEmpty)
  }

  @Test func returningSessionAnswersRepeatedly() async throws {
    let session = StubURLProtocol.session(returning: .empty(status: 200))

    for _ in 0 ..< 3 {
      let (_, response) = try await session.data(from: url)
      #expect((response as? HTTPURLResponse)?.statusCode == 200)
    }
  }

  // MARK: Failures

  @Test func failureOutcomeSurfacesAsURLError() async throws {
    let session = StubURLProtocol.session { _ in .failure(URLError(.notConnectedToInternet)) }

    await #expect(throws: URLError.self) {
      try await session.data(from: url)
    }
    do {
      _ = try await session.data(from: url)
      Issue.record("expected a URLError")
    } catch let error as URLError {
      #expect(error.code == .notConnectedToInternet)
    }
  }

  // MARK: Sequences

  @Test func sequenceAnswersInOrderThenFailsWithClearError() async throws {
    let session = StubURLProtocol.session(sequence: [
      .response(.empty(status: 200)),
      .response(.empty(status: 404)),
    ])

    let (_, first) = try await session.data(from: url)
    let (_, second) = try await session.data(from: url)
    #expect((first as? HTTPURLResponse)?.statusCode == 200)
    #expect((second as? HTTPURLResponse)?.statusCode == 404)

    do {
      _ = try await session.data(from: url)
      Issue.record("expected the sequence to be exhausted")
    } catch {
      // URLSession re-creates the error as an NSError, so recover it by domain.
      #expect(StubURLProtocol.SequenceExhausted.matches(error))
      let exhausted = try #require(StubURLProtocol.SequenceExhausted(error))
      #expect(exhausted.expectedCount == 2)
      #expect(exhausted.url == url)
      #expect(exhausted.httpMethod == "GET")
      let description = error.localizedDescription
      #expect(description.contains("exhausted"))
      #expect(description.contains("request #3"))
      #expect(description.contains(url.absoluteString))
    }
  }

  @Test func sequenceCanMixFailuresAndResponses() async throws {
    let session = StubURLProtocol.session(sequence: [
      .failure(URLError(.timedOut)),
      .response(.empty()),
    ])

    await #expect(throws: URLError.self) { try await session.data(from: url) }
    let (_, response) = try await session.data(from: url)
    #expect((response as? HTTPURLResponse)?.statusCode == 200)
  }

  // MARK: Isolation

  @Test func parallelSessionsDoNotCrossTalk() async throws {
    let sessions = (0 ..< 8).map { index in
      StubURLProtocol.session(returning: .json("\(index)", status: 200 + index))
    }

    try await withThrowingTaskGroup(of: (Int, Int, String).self) { group in
      for (index, session) in sessions.enumerated() {
        group.addTask {
          let (data, response) = try await session.data(from: url)
          let status = (response as? HTTPURLResponse)?.statusCode ?? -1
          return (index, status, String(decoding: data, as: UTF8.self))
        }
      }
      for try await (index, status, body) in group {
        #expect(status == 200 + index)
        #expect(body == "\(index)")
      }
    }
  }

  @Test func handlerSeesTheOriginalRequestWithoutRegistryHeader() async throws {
    let seen = RequestRecorder()
    let session = StubURLProtocol.session { request in
      await seen.record(request)
      return .response(.empty())
    }

    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
    request.setValue("Bearer t", forHTTPHeaderField: "Authorization")
    _ = try await session.data(for: request)

    let recorded = try #require(await seen.last)
    #expect(recorded.method == "PUT")
    #expect(recorded.url == url)
    #expect(recorded.headers["Authorization"] == "Bearer t")
    #expect(recorded.headers.keys.contains { $0.hasPrefix("X-StubURLProtocol") } == false)
  }
}
