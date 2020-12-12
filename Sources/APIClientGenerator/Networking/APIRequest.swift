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
    var endpoint: String { get }
}

public protocol APIRequest: AnyAPIRequest {

    associatedtype BodyType
    associatedtype ResponseType
    
    static var method: HTTPMethod { get }
    static var requiresAuth: Bool { get }
    
    var endpoint: String { get }
    var additionalHeaders: [String: String] { get }
    
    var body: BodyType { get }
    
    func getContentType() throws -> String?
    func getBody() throws -> Data?
}

public extension APIRequest {
    
    var description: String {
        return "\(Self.method.rawValue.uppercased()) \(endpoint)"
    }

    static var requiresAuth: Bool { false }
    
    var additionalHeaders: [String: String] { [:] }
    
    func getContentType() -> String? { nil }
    func getBody() throws -> Data? { nil }
}

public extension APIRequest where BodyType: Encodable {
    
    func getContentType() -> String? { "application/json" }
    
    func getBody() throws -> Data? {
        try JSONEncoder().encode(self.body)
    }
}
