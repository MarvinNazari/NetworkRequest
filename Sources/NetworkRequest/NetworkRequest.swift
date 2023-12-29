//
//  Copyright © 2023 Marvin Nazari. All rights reserved.
//

import Foundation

public struct NetworkRequest<Response, ErrorResponse> {
        
    public let urlRequest: () throws -> (URLRequest)
    public let parse: (Data, URLResponse) throws -> Response
    
    public init(
        urlRequest: @escaping () throws -> URLRequest,
        parse: @escaping (Data, URLResponse) throws -> Response
    ) {
        self.urlRequest = urlRequest
        self.parse = parse
    }
    
    public var cURLCommand: String {
        let request = try? urlRequest()
        return request?.cURLCommand ?? ""
    }
}

public extension NetworkRequest {
    
    init(
        httpMethod: HTTPMethod = .get,
        url: @escaping () throws -> (URL),
        body: NetworkRequestBody? = nil,
        additionalHeaderFields: [String: String] = [:],
        cachePolicy: URLRequest.CachePolicy? = nil,
        timeoutInterval: TimeInterval? = nil,
        parse: @escaping (Data, URLResponse) throws -> Response
    ) {
        self.init(
            urlRequest: {
                let urlToSend = try url()

                var urlRequest = URLRequest(url: urlToSend)

                if let cachePolicy = cachePolicy {
                    urlRequest.cachePolicy = cachePolicy
                }

                if let timeoutInterval = timeoutInterval {
                    urlRequest.timeoutInterval = timeoutInterval
                }

                urlRequest.httpMethod = httpMethod.rawValue

                if let body = body {
                    urlRequest.httpBody = body.data
                    urlRequest.addValue(body.contentType, forHTTPHeaderField: "Content-Type")
                }

                urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")

                additionalHeaderFields.forEach { key, value in
                    urlRequest.setValue(value, forHTTPHeaderField: key)
                }

                return urlRequest
            },
            parse: parse
        )
    }
}

public extension NetworkRequest where Response: Decodable, ErrorResponse: Decodable & Swift.Error {
    
    init(
        httpMethod: HTTPMethod = .get,
        url: @autoclosure @escaping () throws -> (URL),
        body: NetworkRequestBody? = nil,
        additionalHeaderFields: [String: String] = [:],
        cachePolicy: URLRequest.CachePolicy? = nil,
        timeoutInterval: TimeInterval? = nil,
        decoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }()
    ) {
        
        self.init(
            httpMethod: httpMethod,
            url: url,
            body: body,
            additionalHeaderFields: additionalHeaderFields,
            cachePolicy: cachePolicy,
            timeoutInterval: timeoutInterval,
            parse: { data, urlResponse in
                guard let httpUrlResponse = urlResponse as? HTTPURLResponse,
                      200 ..< 300 ~= httpUrlResponse.statusCode else {

                    let error = try decoder.decode(ErrorResponse.self, from: data)
                    throw error
                }

                return try decoder.decode(Response.self, from: data)
            }
        )
    }
}

public extension NetworkRequest where Response: Decodable, ErrorResponse == Void {

    init(
        httpMethod: HTTPMethod = .get,
        url: @autoclosure @escaping () throws -> (URL),
        body: NetworkRequestBody? = nil,
        additionalHeaderFields: [String: String] = [:],
        cachePolicy: URLRequest.CachePolicy? = nil,
        timeoutInterval: TimeInterval? = nil,
        decoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }()
    ) {

        self.init(
            httpMethod: httpMethod,
            url: url,
            body: body,
            additionalHeaderFields: additionalHeaderFields,
            cachePolicy: cachePolicy,
            timeoutInterval: timeoutInterval,
            parse: { data, httpUrlResponse in
                return try decoder.decode(Response.self, from: data)
            }
        )
    }
}

public extension NetworkRequest where Response == Data, ErrorResponse == Void {

    init(
        httpMethod: HTTPMethod = .get,
        url: @autoclosure @escaping () throws -> (URL),
        body: NetworkRequestBody? = nil,
        additionalHeaderFields: [String: String] = [:],
        cachePolicy: URLRequest.CachePolicy? = nil,
        timeoutInterval: TimeInterval? = nil
    ) {

        self.init(
            httpMethod: httpMethod,
            url: url,
            body: body,
            additionalHeaderFields: additionalHeaderFields,
            cachePolicy: cachePolicy,
            timeoutInterval: timeoutInterval,
            parse: { data, httpUrlResponse in
                return data
            }
        )
    }
}

public extension NetworkRequest where Response == Void, ErrorResponse == Void {

    init(
        httpMethod: HTTPMethod = .get,
        url: @autoclosure @escaping () throws -> (URL),
        body: NetworkRequestBody? = nil,
        additionalHeaderFields: [String: String] = [:],
        cachePolicy: URLRequest.CachePolicy? = nil,
        timeoutInterval: TimeInterval? = nil
    ) {

        self.init(
            httpMethod: httpMethod,
            url: url,
            body: body,
            additionalHeaderFields: additionalHeaderFields,
            cachePolicy: cachePolicy,
            timeoutInterval: timeoutInterval,
            parse: { data, httpUrlResponse in
                return ()
            }
        )
    }
}

public extension NetworkRequest where Response == Void, ErrorResponse: Decodable & Swift.Error {

    init(
        httpMethod: HTTPMethod = .get,
        url: @autoclosure @escaping () throws -> (URL),
        body: NetworkRequestBody? = nil,
        additionalHeaderFields: [String: String] = [:],
        cachePolicy: URLRequest.CachePolicy? = nil,
        timeoutInterval: TimeInterval? = nil,
        decoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }()
    ) {

        self.init(
            httpMethod: httpMethod,
            url: url,
            body: body,
            additionalHeaderFields: additionalHeaderFields,
            cachePolicy: cachePolicy,
            timeoutInterval: timeoutInterval,
            parse: { data, urlResponse in
                guard let httpUrlResponse = urlResponse as? HTTPURLResponse,
                      200 ..< 300 ~= httpUrlResponse.statusCode else {

                    let error = try decoder.decode(ErrorResponse.self, from: data)
                    throw error
                }

                return ()
            }
        )
    }
}
