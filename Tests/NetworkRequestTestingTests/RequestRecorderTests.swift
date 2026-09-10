import Testing
import Foundation
import NetworkRequestTesting

@Suite("RequestRecorder")
struct RequestRecorderTests {

  @Test func startsEmpty() async {
    let recorder = RequestRecorder()
    #expect(await recorder.count == 0)
    #expect(await recorder.last == nil)
    #expect(await recorder.requests.isEmpty)
  }

  @Test func recordsInOrder() async throws {
    let recorder = RequestRecorder()
    let session = StubURLProtocol.session(recording: recorder, returning: .empty())

    _ = try await session.data(from: URL(string: "https://example.com/1")!)
    _ = try await session.data(from: URL(string: "https://example.com/2")!)

    #expect(await recorder.count == 2)
    #expect(await recorder.requests.map(\.url?.path) == ["/1", "/2"])
    #expect(await recorder.last?.url?.path == "/2")
  }

  @Test func resetClearsRequests() async {
    let recorder = RequestRecorder()
    await recorder.record(URLRequest(url: URL(string: "https://example.com")!))
    await recorder.reset()
    #expect(await recorder.count == 0)
  }
}
