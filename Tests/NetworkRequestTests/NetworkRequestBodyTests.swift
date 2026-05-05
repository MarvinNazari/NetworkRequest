import Testing
import Foundation
@testable import NetworkRequest

private struct CreateUser: Encodable {
  let name: String
  let age: Int
}

private struct ThrowingEncodable: Encodable {
  struct Boom: Error {}
  func encode(to encoder: Encoder) throws { throw Boom() }
}

@Suite("NetworkRequestBody")
struct NetworkRequestBodyTests {

  // MARK: JSON

  @Test func jsonFromEncodable() throws {
    let body = try NetworkRequestBody.json(parameters: CreateUser(name: "Ada", age: 36))
    #expect(body.contentType == "application/json")

    let object = try JSONSerialization.jsonObject(with: body.data) as? [String: Any]
    #expect(object?["name"] as? String == "Ada")
    #expect(object?["age"] as? Int == 36)
  }

  @Test func jsonFromDictionary() throws {
    let body = try NetworkRequestBody.json(parameters: [
      "name": "Ada",
      "age": 36,
      "active": true,
    ])
    #expect(body.contentType == "application/json")

    let object = try JSONSerialization.jsonObject(with: body.data) as? [String: Any]
    #expect(object?["name"] as? String == "Ada")
    #expect(object?["age"] as? Int == 36)
    #expect(object?["active"] as? Bool == true)
  }

  @Test func jsonPropagatesEncoderErrors() {
    #expect(throws: ThrowingEncodable.Boom.self) {
      try NetworkRequestBody.json(parameters: ThrowingEncodable())
    }
  }

  @Test func jsonUsesISO8601DateStrategyByDefault() throws {
    struct Stamped: Encodable { let at: Date }
    let date = Date(timeIntervalSince1970: 0)
    let body = try NetworkRequestBody.json(parameters: Stamped(at: date))
    let string = String(data: body.data, encoding: .utf8) ?? ""
    #expect(string.contains("1970-01-01T00:00:00Z"), "got: \(string)")
  }

  @Test func jsonRespectsCustomEncoder() throws {
    struct Stamped: Encodable { let at: Date }
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970
    let body = try NetworkRequestBody.json(
      parameters: Stamped(at: Date(timeIntervalSince1970: 100)),
      encoder: encoder
    )
    let string = String(data: body.data, encoding: .utf8) ?? ""
    #expect(string == #"{"at":100}"#, "got: \(string)")
  }

  // MARK: Form

  @Test func formProducesURLEncodedPayload() {
    let body = NetworkRequestBody.form(dictionary: [
      "grant_type": "refresh_token",
      "refresh_token": "abc",
    ])
    #expect(body.contentType == "application/x-www-form-urlencoded")

    let payload = String(data: body.data, encoding: .utf8) ?? ""
    let pairs = Set(payload.split(separator: "&").map(String.init))
    #expect(pairs == ["grant_type=refresh_token", "refresh_token=abc"])
  }

  @Test(
    "Form percent-encoding pins behavior",
    arguments: [
      ("hello world & friends", "hello%20world%20%26%20friends"),
      ("a/b", "a/b"),
      ("100%", "100%25"),
      ("é", "%C3%A9"),
      ("", ""),
    ]
  )
  func formPercentEncoding(input: String, expected: String) {
    let body = NetworkRequestBody.form(dictionary: ["q": input])
    let payload = String(data: body.data, encoding: .utf8) ?? ""
    #expect(payload == "q=\(expected)", "got: \(payload)")
  }

  @Test func emptyDictionaryProducesEmptyBody() {
    let body = NetworkRequestBody.form(dictionary: [:])
    #expect(body.data == Data())
    #expect(body.contentType == "application/x-www-form-urlencoded")
  }

  // MARK: Init

  @Test func customInitWrapsRawData() {
    let body = NetworkRequestBody(data: Data([1, 2, 3]), contentType: "application/octet-stream")
    #expect(body.data == Data([1, 2, 3]))
    #expect(body.contentType == "application/octet-stream")
  }
}
