import Testing
import Foundation
@testable import NetworkRequest

@Suite("cURL command rendering")
struct CURLCommandTests {

    private static let representativeRequest = NetworkRequest<Data, Void>(
        httpMethod: .post,
        url: URL(string: "https://example.com/users")!,
        body: NetworkRequestBody(data: Data(#"{"a":1}"#.utf8), contentType: "application/json"),
        additionalHeaderFields: ["Authorization": "Bearer abc"]
    )

    @Test func startsWithCurl() {
        #expect(Self.representativeRequest.cURLCommand.hasPrefix("curl"))
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
        let command = Self.representativeRequest.cURLCommand
        #expect(command.contains(fragment), "missing \(fragment) in: \(command)")
    }

    @Test func cURLCommandIsEmptyWhenURLClosureThrows() {
        struct Boom: Error {}
        let request = NetworkRequest<Data, Void>(
            urlRequest: { throw Boom() },
            parse: { data, _ in data }
        )
        #expect(request.cURLCommand == "")
    }
}
