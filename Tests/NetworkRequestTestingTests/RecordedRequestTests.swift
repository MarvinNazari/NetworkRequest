import Testing
import Foundation
import NetworkRequestTesting

@Suite("RecordedRequest")
struct RecordedRequestTests {

  private func recorded(_ string: String, body: String? = nil) -> RecordedRequest {
    var request = URLRequest(url: URL(string: string)!)
    request.httpBody = body.map { Data($0.utf8) }
    return RecordedRequest(request)
  }

  // MARK: Line and headers

  @Test func exposesTheUnderlyingRequest() {
    var request = URLRequest(url: URL(string: "https://example.com/a?x=1")!)
    request.httpMethod = "PATCH"
    request.setValue("Bearer t", forHTTPHeaderField: "Authorization")
    let recorded = RecordedRequest(request)

    #expect(recorded.urlRequest == request)
    #expect(recorded.url == request.url)
    #expect(recorded.method == "PATCH")
    #expect(recorded.path == "/a")
    #expect(recorded.headers == ["Authorization": "Bearer t"])
  }

  @Test func headersAreEmptyWhenNoneAreSet() {
    #expect(recorded("https://example.com/a").headers.isEmpty)
  }

  @Test func urlAndPathAreNilWithoutURL() {
    var request = URLRequest(url: URL(string: "https://example.com")!)
    request.url = nil
    let recorded = RecordedRequest(request)

    #expect(recorded.url == nil)
    #expect(recorded.path == nil)
    #expect(recorded.queryItems.isEmpty)
    #expect(recorded.queryDictionary.isEmpty)
  }

  // MARK: Query

  @Test func queryItemsPreserveOrderAndDuplicates() {
    let items = recorded("https://example.com/a?x=1&y=two&x=3&flag").queryItems
    #expect(items.map(\.name) == ["x", "y", "x", "flag"])
    #expect(items.map(\.value) == ["1", "two", "3", nil])
  }

  @Test func queryItemsIsEmptyWithoutQuery() {
    #expect(recorded("https://example.com/a").queryItems.isEmpty)
  }

  @Test func queryDictionaryKeepsLastValueAndMapsFlagsToEmpty() {
    let dictionary = recorded("https://example.com/a?x=1&y=two%20words&x=3&flag").queryDictionary
    #expect(dictionary == ["x": "3", "y": "two words", "flag": ""])
  }

  // MARK: Bodies

  @Test func bodyExposesRawBytes() {
    #expect(recorded("https://example.com", body: "hi").body == Data("hi".utf8))
    #expect(recorded("https://example.com").body == nil)
  }

  @Test func bodyStringDecodesUTF8() {
    #expect(recorded("https://example.com", body: "héllo").bodyString == "héllo")
    #expect(recorded("https://example.com").bodyString == nil)
  }

  @Test func jsonBodyParsesObjects() throws {
    let body = try recorded("https://example.com", body: #"{"name":"Ada","tags":["a","b"],"n":3}"#).jsonBody()
    #expect(body["name"] as? String == "Ada")
    #expect(body["tags"] as? [String] == ["a", "b"])
    #expect(body["n"] as? Int == 3)
  }

  @Test func jsonBodyThrowsForArraysMissingOrInvalidBodies() {
    #expect(throws: DecodingError.self) {
      try recorded("https://example.com", body: "[1,2]").jsonBody()
    }
    #expect(throws: DecodingError.self) {
      try recorded("https://example.com").jsonBody()
    }
    // A malformed body must fail loudly rather than read as "no body".
    #expect(throws: (any Error).self) {
      try recorded("https://example.com", body: "not json").jsonBody()
    }
  }

  @Test func jsonArrayBodyParsesArrays() throws {
    let body = try recorded("https://example.com", body: #"[1,"two",{"k":true}]"#).jsonArrayBody()
    #expect(body.count == 3)
    #expect(body[0] as? Int == 1)
    #expect(body[1] as? String == "two")
    #expect((body[2] as? [String: Any])?["k"] as? Bool == true)
  }

  @Test func jsonArrayBodyThrowsForObjectsMissingOrInvalidBodies() {
    #expect(throws: DecodingError.self) {
      try recorded("https://example.com", body: "{}").jsonArrayBody()
    }
    #expect(throws: DecodingError.self) {
      try recorded("https://example.com").jsonArrayBody()
    }
    #expect(throws: (any Error).self) {
      try recorded("https://example.com", body: "not json").jsonArrayBody()
    }
  }

  @Test func formBodyDecodesPairs() {
    let body = recorded(
      "https://example.com",
      body: "grant_type=refresh_token&scope=read%20write&name=Ada+Lovelace&empty=&flag"
    ).formBody
    #expect(body == [
      "grant_type": "refresh_token",
      "scope": "read write",
      "name": "Ada Lovelace",
      "empty": "",
      "flag": "",
    ])
  }

  @Test func formBodyIsNilWithoutBody() {
    #expect(recorded("https://example.com").formBody == nil)
  }
}
