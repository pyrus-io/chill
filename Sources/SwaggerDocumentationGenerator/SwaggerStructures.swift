//
//  SwaggerStructures.swift
//  
//
//  Created by Kyle Newsome on 2020-10-25.
//

/*
 
 /users/search/{USERNAME}:
     get:
       tags:
       - Users
       summary: Search Username
       description: test
       operationId: SearchUsername
       parameters:
       - name: Authorization
         in: header
         schema:
           type: string
           default: Bearer {token}
       - name: offset
         in: query
         required: true
         schema:
           type: integer
           format: int32
       - name: limit
         in: query
         required: true
         schema:
           type: integer
           format: int32
       - name: Content-Type
         in: header
         required: true
         schema:
           type: string
       - name: USERNAME
         in: path
         required: true
         schema:
           type: string
 
 */

import Foundation

enum Swagger {
    
    typealias URLPathString = String
    typealias HTTPMethodString = String
    
    enum ReferenceType: String, Codable {
        case object
        case array
        case integer
        case boolean
        case string
        case number
    }
    
    struct ItemReference: Codable {
        var type: ReferenceType?
        var format: String?
        var ref: String?
        
        enum CodingKeys: String, CodingKey {
            case type
            case format
            case ref = "$ref"
        }
    }
    
    struct SchemaReference: Codable {
        var type: ReferenceType?
        var format: String?
        var ref: String?
        var items: ItemReference?
        
        enum CodingKeys: String, CodingKey {
            case type
            case format
            case ref = "$ref"
            case items
        }
    }
    
    struct BodyContentContainer: Codable {
        var schema: SchemaReference
    }

    struct Path: Codable {
        var method: Method
    }
    
    struct Body: Codable {
        var description: String?
        var content: [String: BodyContentContainer]
        var required: Bool?
    }

    struct Method: Codable {
        var operationId: String
        var summary: String
        var parameters: [Parameter]
        var responses: [Int: Body]
        var tags: [String]?
        var requestBody: Body?
    }

    struct Parameter: Codable {
        enum Location: String, Codable {
            case header
            case query
            case path
        }
        
        var `in`: Location
        var name: String
        var required: Bool?
        var schema: SchemaReference?
    }
    
    struct Server: Codable {
        var url: String
    }
    
    struct Components: Codable {
        var schemas: [String: Definition]
    }

    struct Definition: Codable {
        var type = "object"
        var description: String?
        var `enum`: [String]?
        var properties: [String: SchemaReference]?
        var required: [String]? // list of required properties
    }

    struct Document: Codable {
        struct Info: Codable {
            var title: String
            var version: String
            var description: String
        }
        
        var openapi = "3.0.0"
        var info: Info
        var servers: [Server]
        var paths: [URLPathString: [HTTPMethodString: Method]]
        var components: Components
    }
}


//struct Property {
//   var name: String
//   var type: String
//   var decorators: [String]
//   var parameters: [String]
//   var returnType: String
//}
//
//struct Object {
//   var name: String
//   var properties: [Property]
//   var decorators: [String]
//}
//
//struct Path {
//   var endpoint: String
//   var method: String
//   var requestBody: String
//   var successBody: String
//}
//
//struct ObjectDictionary {
//    var name: Object
//}
