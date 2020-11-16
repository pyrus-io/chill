//
//  APIEndpoint.swift
//  
//
//  Created by Kyle Newsome on 2020-10-23.
//

import Foundation
import Vapor
import FluentKit

public enum APIRoutingHTTPMethod: String {
    case get
    case post
    case put
    case patch
    case delete
}

public protocol APIRoutingContext {
    static func createFrom(request: Request) -> Self
}

public protocol APIRoutingEndpoint {
    
    associatedtype Context: APIRoutingContext
    associatedtype Parameters
    associatedtype Query
    associatedtype Body
    associatedtype Response: ResponseEncodable
    
    static var method: APIRoutingHTTPMethod { get }
    static var path: String { get }
    
    static func buildAndRun(from request: Request) throws -> EventLoopFuture<Response>
    static func run(
        context: Context,
        parameters: Parameters,
        query: Query,
        body: Body
    ) throws -> EventLoopFuture<Response>
}


public extension APIRoutingEndpoint {
    static func register(in routesBuilder: RoutesBuilder) {
        let pathComponents = path.split(separator: "/").map { PathComponent(stringLiteral: String($0)) }
        switch method {
        case .get:
            routesBuilder.get(pathComponents, use: buildAndRun)
        case .post:
            routesBuilder.post(pathComponents, use: buildAndRun)
        case .put:
            routesBuilder.put(pathComponents, use: buildAndRun)
        case .patch:
            routesBuilder.patch(pathComponents, use: buildAndRun)
        case .delete:
            routesBuilder.delete(pathComponents, use: buildAndRun)
        }
    }
}

// MARK: - Combination Extensions

// All
public extension APIRoutingEndpoint where Parameters: Decodable, Query: Decodable, Body: Decodable {
    static func buildAndRun(from request: Request) throws -> EventLoopFuture<Response> {
        let requestParameters = try request.parameters.decode(Parameters.self)
        let requestQuery = try request.query.decode(Query.self)
        let requestBody = try request.content.decode(Body.self)
        return try self.run(
            context: Context.createFrom(request: request),
            parameters: requestParameters,
            query: requestQuery,
            body: requestBody
        )
    }
}

// None
public extension APIRoutingEndpoint where Parameters == Void, Query == Void, Body == Void {
    static func buildAndRun(from request: Request) throws -> EventLoopFuture<Response> {
        return try self.run(
            context: Context.createFrom(request: request),
            parameters: (),
            query: (),
            body: ()
        )
    }
}

// Param alone
public extension APIRoutingEndpoint where Parameters: Decodable, Query == Void, Body == Void {
    static func buildAndRun(from request: Request) throws -> EventLoopFuture<Response> {
        let requestParameters = try request.parameters.decode(Parameters.self)
        return try self.run(
            context: Context.createFrom(request: request),
            parameters: requestParameters,
            query: (),
            body: ()
        )
    }
}

// Params & Query
public extension APIRoutingEndpoint where Parameters: Decodable, Query: Decodable, Body == Void {
    static func buildAndRun(from request: Request) throws -> EventLoopFuture<Response> {
        let requestParameters = try request.parameters.decode(Parameters.self)
        let requestQuery = try request.query.decode(Query.self)
        return try self.run(
            context: Context.createFrom(request: request),
            parameters: requestParameters,
            query: requestQuery,
            body: ()
        )
    }
}

// Param & Body
public extension APIRoutingEndpoint where Parameters: Decodable, Query == Void, Body: Decodable {
    static func buildAndRun(from request: Request) throws -> EventLoopFuture<Response> {
        let requestParameters = try request.parameters.decode(Parameters.self)
        let requestBody = try request.content.decode(Body.self)
        return try self.run(
            context: Context.createFrom(request: request),
            parameters: requestParameters,
            query: (),
            body: requestBody
        )
    }
}

// Query only
public extension APIRoutingEndpoint where Parameters == Void, Query: Decodable, Body == Void {
    static func buildAndRun(from request: Request) throws -> EventLoopFuture<Response> {
        let requestQuery = try request.query.decode(Query.self)
        return try self.run(
            context: Context.createFrom(request: request),
            parameters: (),
            query: requestQuery,
            body: ()
        )
    }
}

// Query & Body
public extension APIRoutingEndpoint where Parameters == Void, Query: Decodable, Body: Decodable {
    static func buildAndRun(from request: Request) throws -> EventLoopFuture<Response> {
        let requestQuery = try request.query.decode(Query.self)
        let requestBody = try request.content.decode(Body.self)
        return try self.run(
            context: Context.createFrom(request: request),
            parameters: (),
            query: requestQuery,
            body: requestBody
        )
    }
}

// Body alone
public extension APIRoutingEndpoint where Parameters == Void, Query == Void, Body: Decodable {
    static func buildAndRun(from request: Request) throws -> EventLoopFuture<Response> {
        let requestBody = try request.content.decode(Body.self)
        return try self.run(
            context: Context.createFrom(request: request),
            parameters: (),
            query: (),
            body: requestBody
        )
    }
}
