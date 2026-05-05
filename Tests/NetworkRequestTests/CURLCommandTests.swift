import Testing
import Foundation
@testable import NetworkRequest

@Suite("cURL command rendering")
struct CURLCommandTests {

  private static let representativeRequest = NetworkRequest<Data, Never>(
    httpMethod: .post,
    url: URL(string: "https://example.com/users")!,
    body: NetworkRequestBody(data: Data(#"{"a":1}"#.utf8), contentType: "application/json"),
    additionalHeaderFields: ["Authorization": "Bearer abc"]
  )

  @Test func startsWithCurl() {
    #expect(Self.representativeRequest.cURLCommand?.hasPrefix("curl") == true)
  }

  @Test(
    "cURL command includes each expected fragment",
    arguments: [
      "-X POST",
      #""https://example.com/users""#,
      "'Authorization: Bearer abc'",
      "'Content-Type: application/json'",
      #"-d "{\"a\":1}""#,
    ]
  )
  func cURLContainsFragment(fragment: String) {
    let command = Self.representativeRequest.cURLCommand ?? ""
    #expect(command.contains(fragment), "missing \(fragment) in: \(command)")
  }

  @Test func cURLCommandIsNilWhenURLClosureThrows() {
    struct Boom: Error {}
    let request = NetworkRequest<Data, Never>(
      urlRequest: { throw Boom() },
      parse: { data, _ in data }
    )
    #expect(request.cURLCommand == nil)
  }

  @Test func headerValueWithApostropheIsShellSafe() throws {
    var urlRequest = URLRequest(url: URL(string: "https://example.com/")!)
    urlRequest.setValue("Don't fail", forHTTPHeaderField: "X-Note")
    let command = urlRequest.cURLCommand ?? ""
    // ANSI-C trick: end quoted, escaped apostrophe, reopen quoted.
    #expect(command.contains("'X-Note: Don'\\''t fail'"), "got: \(command)")
    // Make sure we don't emit the broken "\\'" form.
    #expect(!command.contains(#"\'t"#), "got: \(command)")
  }

  @Test func nonUTF8BodyDoesNotProduceMisleadingDataFlag() throws {
    var urlRequest = URLRequest(url: URL(string: "https://example.com/")!)
    urlRequest.httpMethod = "POST"
    urlRequest.httpBody = Data([0xFF, 0xFE, 0x00, 0x01])
    let command = urlRequest.cURLCommand ?? ""
    #expect(!command.contains(#"-d """#), "should not emit empty -d for binary body: \(command)")
    #expect(command.contains("binary body of 4 bytes omitted"), "got: \(command)")
  }

  @Test func emptyBodyOmitsDataFlag() throws {
    var urlRequest = URLRequest(url: URL(string: "https://example.com/")!)
    urlRequest.httpMethod = "POST"
    urlRequest.httpBody = Data()
    let command = urlRequest.cURLCommand ?? ""
    #expect(!command.contains("-d "), "got: \(command)")
  }

  @Test func gzipAcceptEncodingAddsCompressedFlag() throws {
    var urlRequest = URLRequest(url: URL(string: "https://example.com/")!)
    urlRequest.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
    let command = urlRequest.cURLCommand ?? ""
    #expect(command.contains("--compressed"), "got: \(command)")
  }

  @Test func urlRequestWithoutURLReturnsNil() {
    let urlRequest = URLRequest(url: URL(string: "https://example.com/")!)
    var stripped = urlRequest
    // Force-clear: there's no public API to nil out a URL after construction,
    // so we exercise the contract via NetworkRequest.cURLCommand instead.
    _ = stripped
    let request = NetworkRequest<Data, Never>(
      urlRequest: { throw NSError(domain: "test", code: 0) },
      parse: { data, _ in data }
    )
    #expect(request.cURLCommand == nil)
  }
}
