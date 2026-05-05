//
//  Copyright © 2023 Marvin Nazari. All rights reserved.
//

import Foundation

/// The body of a network request, paired with the `Content-Type` header value
/// it should be sent with.
///
/// Use the static helpers ``json(parameters:encoder:)-(Encodable,_)``,
/// ``json(parameters:encoder:)-([String:Encodable],_)``, and
/// ``form(dictionary:)`` to construct common bodies, or call
/// ``init(data:contentType:)`` directly to wrap arbitrary payloads such as
/// `multipart/form-data` or binary uploads.
public struct NetworkRequestBody: Sendable {

    /// The raw bytes of the request body.
    public let data: Data

    /// The MIME type to send in the `Content-Type` header (for example,
    /// `"application/json"` or `"application/x-www-form-urlencoded"`).
    public let contentType: String

    /// Creates a request body from raw bytes and an explicit content type.
    ///
    /// - Parameters:
    ///   - data: The encoded body bytes.
    ///   - contentType: The MIME type to advertise in the `Content-Type` header.
    public init(data: Data, contentType: String) {
        self.data = data
        self.contentType = contentType
    }
}

public extension NetworkRequestBody {

    /// Encodes a single `Encodable` value as a JSON request body with content
    /// type `application/json`.
    ///
    /// - Parameters:
    ///   - parameters: The value to encode. Any `Encodable` type is accepted.
    ///   - encoder: The encoder to use. Defaults to a `JSONEncoder` with
    ///     `dateEncodingStrategy = .iso8601`.
    /// - Returns: A request body containing the JSON-encoded payload.
    /// - Throws: Whatever `encoder.encode(_:)` throws.
    static func json(
        parameters: Encodable,
        encoder: JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return encoder
        }()
    ) throws -> Self {

        Self(
            data: try encoder.encode(AnyEncodable(parameters)),
            contentType: "application/json"
        )
    }

    /// Encodes a heterogeneous `[String: Encodable]` dictionary as a JSON
    /// object request body with content type `application/json`.
    ///
    /// Useful when assembling an ad-hoc payload whose values have different
    /// concrete types without defining a custom struct.
    ///
    /// - Parameters:
    ///   - parameters: The key/value pairs to encode as a JSON object.
    ///   - encoder: The encoder to use. Defaults to a `JSONEncoder` with
    ///     `dateEncodingStrategy = .iso8601`.
    /// - Returns: A request body containing the JSON-encoded object.
    /// - Throws: Whatever `encoder.encode(_:)` throws.
    static func json(
        parameters: [String: Encodable],
        encoder: JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return encoder
        }()
    ) throws -> Self {

        Self(
            data: try encoder.encode(parameters.compactMapValues { AnyEncodable($0) }),
            contentType: "application/json"
        )
    }

    /// Builds a URL-form-encoded request body with content type
    /// `application/x-www-form-urlencoded`.
    ///
    /// Keys and values are percent-encoded according to URL query rules.
    ///
    /// - Parameter dictionary: The key/value pairs to encode.
    /// - Returns: A request body containing the form-encoded payload.
    static func form(
        dictionary: [String: String]
    ) throws -> Self {

        var urlParser = URLComponents()
        urlParser.queryItems = dictionary.map {
            URLQueryItem(name: $0, value: $1)
        }

        let data = urlParser
            .percentEncodedQuery?
            .data(using: .utf8) ?? Data()

        return Self(
            data: data,
            contentType: "application/x-www-form-urlencoded"
        )
    }

}

private struct AnyEncodable: Encodable {
    var value: Encodable

    init(_ value: Encodable) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try value.encode(to: &container)
    }
}

private extension Encodable {
    func encode(to container: inout SingleValueEncodingContainer) throws {
        try container.encode(self)
    }
}
