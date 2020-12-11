import Foundation

public enum HTTPMethod: String {
    case get
    case put
    case post
    case patch
    case delete
}

public protocol AnyAPIRequest {
    static var method: HTTPMethod { get }
    static var baseUrl: String { get }
    var endpoint: String { get }
}

public protocol APIRequest: AnyAPIRequest {

    associatedtype DecodedResponse
    
    static var method: HTTPMethod { get }
    static var baseUrl: String { get }
    var endpoint: String { get }
    var requiresAuth: Bool { get }
    var additionalHeaders: [String: String] { get }
    
    func getContentType() throws -> String?
    func getBody() throws -> Data?
}

public extension APIRequest {
    
    var description: String {
        return "\(Self.method.rawValue.uppercased()) \(Self.baseUrl)\(endpoint)"
    }

    var requiresAuth: Bool { return false }
    var additionalHeaders: [String: String] { [:] }
    
    func getContentType() -> String? { nil }
    func getBody() throws -> Data? { nil }
}

public extension APIRequest where Self: Encodable {
    
    func getContentType() -> String? { "application/json" }
    
    func getBody() throws -> Data? {
        try JSONEncoder().encode(self)
    }
}
