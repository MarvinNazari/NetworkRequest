//
//  Copyright © 2023 Marvin Nazari. All rights reserved.
//

import Foundation

public struct HTTPMethod: RawRepresentable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension HTTPMethod {
    static let get = Self(rawValue: "GET")
    static let post = Self(rawValue: "POST")
    static let put = Self(rawValue: "PUT")
    static let head = Self(rawValue: "HEAD")
    static let delete = Self(rawValue: "DELETE")
    static let patch = Self(rawValue: "PATCH")
    static let trace = Self(rawValue: "TRACE")
    static let options = Self(rawValue: "OPTIONS")
    static let connect = Self(rawValue: "CONNECT")
}
