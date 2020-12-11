import Foundation

public enum Swagger {
    
    public typealias URLPathString = String
    public typealias HTTPMethodString = String
    
    public enum ReferenceType: String, Codable {
        case object
        case array
        case integer
        case boolean
        case string
        case number
    }
    
    public struct Document: Codable {
        public struct Info: Codable {
            public var title: String
            public var version: String
            public var description: String
        }
        
        public var openapi = "3.0.0"
        public var info: Info
        public var servers: [Server]
        public var paths: [URLPathString: [HTTPMethodString: Method]]
        public var components: Components
    }
    
    public struct Server: Codable {
        public var url: String
    }
    
    public struct Components: Codable {
        public var schemas: [String: Definition]
        public var securitySchemes: [String: [String: String]]?
    }

    public struct Definition: Codable {
        public var type = "object"
        public var description: String?
        public var `enum`: [String]?
        public var properties: [String: SchemaReference]?
        public var required: [String]? // list of required properties
    }
    
    public struct ItemReference: Codable {
        public var type: ReferenceType?
        public var format: String?
        public var ref: String?
        
        public enum CodingKeys: String, CodingKey {
            case type
            case format
            case ref = "$ref"
        }
    }
    
    public struct SchemaReference: Codable {
        public var type: ReferenceType?
        public var format: String?
        public var ref: String?
        public var items: ItemReference?
        
        public enum CodingKeys: String, CodingKey {
            case type
            case format
            case ref = "$ref"
            case items
        }
    }
    
    public struct BodyContentContainer: Codable {
        public var schema: SchemaReference
    }

    public struct Path: Codable {
        public var method: Method
    }
    
    public struct Body: Codable {
        public var description: String?
        public var content: [String: BodyContentContainer]
        public var required: Bool?
    }

    public struct Method: Codable {
        public var operationId: String
        public var summary: String
        public var parameters: [Parameter]
        public var responses: [Int: Body]
        public var tags: [String]?
        public var requestBody: Body?
        public var security: Array<[String: [String]]>?
    }

    public struct Parameter: Codable {
        public enum Location: String, Codable {
            case header
            case query
            case path
        }
        
        public var `in`: Location
        public var name: String
        public var required: Bool?
        public var schema: SchemaReference?
    }
    
}
