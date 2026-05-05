import Testing
import Foundation
@testable import NetworkRequest

private struct CreateUser: Encodable {
    let name: String
    let age: Int
}

@Suite("NetworkRequestBody")
struct NetworkRequestBodyTests {

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

    @Test func formProducesURLEncodedPayload() throws {
        let body = try NetworkRequestBody.form(dictionary: [
            "grant_type": "refresh_token",
            "refresh_token": "abc",
        ])
        #expect(body.contentType == "application/x-www-form-urlencoded")

        let payload = String(data: body.data, encoding: .utf8) ?? ""
        let pairs = Set(payload.split(separator: "&").map(String.init))
        #expect(pairs == ["grant_type=refresh_token", "refresh_token=abc"])
    }

    @Test func formPercentEncodesSpecialCharacters() throws {
        let body = try NetworkRequestBody.form(dictionary: ["q": "hello world & friends"])
        let payload = String(data: body.data, encoding: .utf8) ?? ""
        // URLComponents percent-encodes spaces as %20 and ampersand as %26 inside a value.
        #expect(payload.contains("hello%20world%20%26%20friends"), "got: \(payload)")
    }

    @Test func jsonUsesISO8601DateStrategyByDefault() throws {
        struct Stamped: Encodable { let at: Date }
        let date = Date(timeIntervalSince1970: 0)
        let body = try NetworkRequestBody.json(parameters: Stamped(at: date))
        let string = String(data: body.data, encoding: .utf8) ?? ""
        #expect(string.contains("1970-01-01T00:00:00Z"), "got: \(string)")
    }

    @Test func customInitWrapsRawData() {
        let body = NetworkRequestBody(data: Data([1, 2, 3]), contentType: "application/octet-stream")
        #expect(body.data == Data([1, 2, 3]))
        #expect(body.contentType == "application/octet-stream")
    }
}
