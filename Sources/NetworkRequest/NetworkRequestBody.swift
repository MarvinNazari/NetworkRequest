//
//  Copyright © 2023 Marvin Nazari. All rights reserved.
//

import Foundation

public struct NetworkRequestBody {
    public let data: Data
    public let contentType: String
    
    public init(data: Data, contentType: String) {
        self.data = data
        self.contentType = contentType
    }
}

public extension NetworkRequestBody {
    
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
