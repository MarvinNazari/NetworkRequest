import Testing
@testable import NetworkRequest

@Suite("HTTPMethod")
struct HTTPMethodTests {

  @Test(
    "Standard methods expose their RFC name as rawValue",
    arguments: [
      (HTTPMethod.get, "GET"),
      (HTTPMethod.post, "POST"),
      (HTTPMethod.put, "PUT"),
      (HTTPMethod.head, "HEAD"),
      (HTTPMethod.delete, "DELETE"),
      (HTTPMethod.patch, "PATCH"),
      (HTTPMethod.trace, "TRACE"),
      (HTTPMethod.options, "OPTIONS"),
      (HTTPMethod.connect, "CONNECT"),
    ]
  )
  func standardMethodRawValue(method: HTTPMethod, expected: String) {
    #expect(method.rawValue == expected)
  }

  @Test func customRawValueRoundTrips() {
    #expect(HTTPMethod(rawValue: "LINK").rawValue == "LINK")
  }

  @Test func equality() {
    #expect(HTTPMethod.get == HTTPMethod(rawValue: "GET"))
    #expect(HTTPMethod.get != HTTPMethod.post)
  }
}
