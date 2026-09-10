import Testing
import Foundation
import NetworkRequestTesting

@Suite("URLRequest inspection helpers")
struct URLRequestInspectionTests {

  private func request(_ string: String, body: String? = nil) -> URLRequest {
    var request = URLRequest(url: URL(string: string)!)
    request.httpBody = body.map { Data($0.utf8) }
    return request
  }

  // MARK: Query

  @Test func queryItemsPreserveOrderAndDuplicates() {
    let items = request("https://example.com/a?x=1&y=two&x=3&flag").queryItems
    #expect(items.map(\.name) == ["x", "y", "x", "flag"])
    #expect(items.map(\.value) == ["1", "two", "3", nil])
  }

  @Test func queryItemsIsEmptyWithoutQuery() {
    #expect(request("https://example.com/a").queryItems.isEmpty)
  }

  @Test func queryDictionaryKeepsLastValueAndMapsFlagsToEmpty() {
    let dictionary = request("https://example.com/a?x=1&y=two%20words&x=3&flag").queryDictionary
    #expect(dictionary == ["x": "3", "y": "two words", "flag": ""])
  }

  @Test func queryDictionaryIsEmptyWithoutURL() {
    var request = URLRequest(url: URL(string: "https://example.com")!)
    request.url = nil
    #expect(request.queryDictionary.isEmpty)
    #expect(request.queryItems.isEmpty)
  }

  // MARK: Bodies

  @Test func bodyStringDecodesUTF8() {
    #expect(request("https://example.com", body: "héllo").bodyString == "héllo")
    #expect(request("https://example.com").bodyString == nil)
  }

  @Test func jsonBodyParsesObjects() throws {
    let body = try #require(request("https://example.com", body: #"{"name":"Ada","tags":["a","b"],"n":3}"#).jsonBody)
    #expect(body["name"] as? String == "Ada")
    #expect(body["tags"] as? [String] == ["a", "b"])
    #expect(body["n"] as? Int == 3)
  }

  @Test func jsonBodyIsNilForArraysOrMissingOrInvalid() {
    #expect(request("https://example.com", body: "[1,2]").jsonBody == nil)
    #expect(request("https://example.com", body: "not json").jsonBody == nil)
    #expect(request("https://example.com").jsonBody == nil)
  }

  @Test func jsonArrayBodyParsesArrays() throws {
    let body = try #require(request("https://example.com", body: #"[1,"two",{"k":true}]"#).jsonArrayBody)
    #expect(body.count == 3)
    #expect(body[0] as? Int == 1)
    #expect(body[1] as? String == "two")
    #expect((body[2] as? [String: Any])?["k"] as? Bool == true)
  }

  @Test func jsonArrayBodyIsNilForObjectsOrMissing() {
    #expect(request("https://example.com", body: "{}").jsonArrayBody == nil)
    #expect(request("https://example.com").jsonArrayBody == nil)
  }

  @Test func formBodyDecodesPairs() {
    let body = request("https://example.com", body: "grant_type=refresh_token&scope=read%20write&name=Ada+Lovelace&empty=&flag").formBody
    #expect(body == [
      "grant_type": "refresh_token",
      "scope": "read write",
      "name": "Ada Lovelace",
      "empty": "",
      "flag": "",
    ])
  }

  @Test func formBodyIsNilWithoutBody() {
    #expect(request("https://example.com").formBody == nil)
  }
}
