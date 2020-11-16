//
//  main.swift
//  
//
//  Created by Kyle Newsome on 2020-10-26.
//

import Foundation
import SourceKittenFramework
import SwiftTypesExtractor

public struct DocumentationGenerator {
    
    enum DocsError: Error {
        case missingCriticalEndpointInformation(String)
        case failedToConvertToJSON
    }
    
    struct Constants {
        static var returnTypePrefix = "EventLoopFuture<"
        static var returnTypeSuffix = ">"
        
        static var arrayRegex = try! NSRegularExpression(
            pattern: "(Array<|\\[)([a-zA-Z]+)(>|\\])",
            options: []
        )
        static var dictRegex = try! NSRegularExpression(
            pattern: "((Dictionary<)([a-zA-Z]+)(\\s*,)(\\s*)([a-zA-Z]+)(>))|((\\[)([a-zA-Z]+)(\\s*:)(\\s*)([a-zA-Z]+)(\\]))",
            options: []
        )
        
        static let ignoredReturnTypes = ["String", "Int"]
    }
    
    public static func generateOpenAPIJSONString(apiDirectoryUrl: URL) throws -> String {
        let extractor = try SwiftTypesExtractor(directoryUrl: apiDirectoryUrl)
        let endpointTypes = extractor.types(inheritingFrom: "APIRoutingContext")

        var document = Swagger.Document(
            info: .init(title: "My API", version: "1.0", description: "My API Document"),
            servers: [],
            paths: [:],
            components: Swagger.Components(schemas: [:])
        )
        var definitions: [String: Swagger.Definition] = [:]
        
        try endpointTypes.values.forEach { endpointType in
            
            guard let method = endpointType.staticProperties["method"]?.defaultValue,
                  let path = endpointType.staticProperties["path"]?.defaultValue else {
                throw DocsError.missingCriticalEndpointInformation("method/path issue in \(endpointType.name). Expecting a static var with default value set")
            }
            
            guard let executionFunc = endpointType.staticMethods["run(context:parameters:query:body:)"] else {
                throw DocsError.missingCriticalEndpointInformation("run function not in expected format")
            }
            
            var cleanedPath = cleanPath(path)
            var parameters: [Swagger.Parameter] = []
            var requestBody: Swagger.Body?
            var responses: [Int: Swagger.Body] = [:]
            
            try executionFunc.arguments.forEach { argument in
                switch argument.name {
                // TODO: determine how to use the context, could be useful info to include
                case "context": break
                case "body" where argument.type != "Void":
                    guard let requestBodyType = extractor.types[argument.type] else {
                        throw DocsError.missingCriticalEndpointInformation("Can't find information about \(argument.type) but it is used in the query of \(endpointType.name)")
                    }
                    
                    requestBody = Swagger.Body(content: [
                        "application/json": .init(schema: .init(ref: "#/components/schemas/\(argument.type)")),
                    ], required: true)
                    
                    let def = createDefinition(from: requestBodyType)
                    definitions[argument.type] = def
                case "parameters" where argument.type != "Void":
                    guard let queryTypeInfo = extractor.types[argument.type] else {
                        throw DocsError.missingCriticalEndpointInformation("Can't find information about \(argument.type) but it is used in the query of \(endpointType.name)")
                    }
                    queryTypeInfo.instanceProperties.values.forEach { property in
                        cleanedPath = cleanedPath.replacingOccurrences(of: ":\(property.name)", with: "{\(property.name)}")
                        parameters.append(Swagger.Parameter(
                            in: .path,
                            name: property.name,
                            required: typeIsRequired(property.type),
                            schema: .init(type: Swagger.SchemaReference.ReferenceType(rawValue: cleanType(property.type)) ?? .object)
                            )
                        )
                    }
                case "query" where argument.type != "Void":
                    guard let queryTypeInfo = extractor.types[argument.type] else {
                        throw DocsError.missingCriticalEndpointInformation("Can't find information about \(argument.type) but it is used in the query of \(endpointType.name)")
                    }
                    queryTypeInfo.instanceProperties.values.forEach { property in
                        parameters.append(Swagger.Parameter(
                            in: .query,
                            name: property.name,
                            required: typeIsRequired(property.type),
                            schema: .init(type: Swagger.SchemaReference.ReferenceType(rawValue: cleanType(property.type)) ?? .object)
                            )
                        )
                    }
                default: break
                
                }
            }
            
            if let returnTypeName = executionFunc.returnType {
                let cleanReturnName = cleanReturnTypeName(returnTypeName)
                let isArray = !Constants.arrayRegex.matches(in: cleanReturnName, options: [], range: NSRange(location: 0, length: cleanReturnName.utf16.count)).isEmpty
                let isDictionary = !Constants.dictRegex.matches(in: cleanReturnName, options: [], range: NSRange(location: 0, length: cleanReturnName.utf16.count)).isEmpty
                
                if !Constants.ignoredReturnTypes.contains(cleanReturnName)
                    && !isDictionary
                    && !isArray {
                    guard let returnType = extractor.types[cleanReturnName] else {
                        throw DocsError.missingCriticalEndpointInformation("Can't find information about \(cleanReturnName) but it is used in the return type of \(endpointType.name)")
                    }
                    let def = createDefinition(from: returnType)
                    definitions[cleanReturnName] = def
                    responses[200] = .init(
                        description: "",
                        content: ["application/json": .init(schema: .init(
                            ref: "#/components/schemas/\(cleanReturnName)")
                        )]
                    )
                } else if isArray, let typeName = extractArrayType(from: cleanReturnName) {
                    guard let returnType = extractor.types[typeName] else {
                        throw DocsError.missingCriticalEndpointInformation("Can't find information about \(cleanReturnName) but it is used in an array of the return type for \(endpointType.name)")
                    }
                    let def = createDefinition(from: returnType)
                    definitions[typeName] = def
                    responses[200] = .init(
                        description: "",
                        content: ["application/json": .init(
                            schema: Swagger.SchemaReference(
                                type: .array,
                                items: Swagger.ItemReference(
                                    ref: "#/components/schemas/\(typeName)")
                            )
                        )]
                    )
                }
            }
            
            if responses[200] == nil {
                responses[200] = .init(
                    description: "",
                    content: [:]
                )
            }
            
            document.paths[cleanedPath, default: [:]][cleanMethod(method)] = Swagger.Method(
                operationId: endpointType.name,
                summary: endpointType.name,
                parameters: parameters,
                responses: responses,
                tags: nil,
                requestBody: requestBody)
        }
        document.components.schemas = definitions

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try JSONEncoder().encode(document)
        guard let jsonString =  String(data: jsonData, encoding: .utf8) else {
            throw DocsError.failedToConvertToJSON
        }
        return jsonString
    }
    
    private static func cleanPath(_ path: String) -> String {
        return path.trimmingCharacters(in: .init(arrayLiteral: "\""))
    }

    private static func cleanMethod(_ method: String) -> String {
        return method.trimmingCharacters(in: .init(arrayLiteral: "."))
    }

    private static func cleanType(_ type: String) -> String {
        let trimmed = type.trimmingCharacters(in: .init(arrayLiteral: "?"))
        switch trimmed {
        case "String", "UUID": return "string"
        case "Bool": return "boolean"
        case "Int": return "integer"
        default:
            return trimmed
        }
    }

    private static func typeIsRequired(_ type: String) -> Bool {
        return !type.contains("?")
    }

    private static func cleanReturnTypeName(_ returnTypeName: String) -> String {
        return String(returnTypeName
                        .dropFirst(Constants.returnTypePrefix.count)
                        .dropLast(Constants.returnTypeSuffix.count))
    }

    private static func createDefinition(from type: TypeDescription) -> Swagger.Definition {
        var properties: [String: Swagger.DefinitionProperties] = [:]
        var requiredProperties: [String] = []
        type.instanceProperties.values.forEach { (property) in
            properties[property.name] = .init(type: cleanType(property.type), ref: nil, items: nil)
            if typeIsRequired(property.type) {
                requiredProperties.append(property.name)
            }
        }
        return .init(description: nil, properties: properties, required: requiredProperties)
    }

    private static func extractArrayType(from value: String) -> String? {
        let matches = Constants.arrayRegex.matches(in: value, options: [], range: NSRange(location: 0, length: value.utf16.count))
        return matches.flatMap { result in
            (0..<result.numberOfRanges).map {
                            result.range(at: $0).location != NSNotFound
                                ? (value as NSString).substring(with: result.range(at: $0))
                                : ""
                        }
        }
        .filter { !$0.isEmpty && $0.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil }
        .first
    }

    private static func extractDictType(from value: String) -> (String, String)? {
        let matches = Constants.dictRegex.matches(in: value, options: [], range: NSRange(location: 0, length: value.utf16.count))
        let values = matches.flatMap { result in
            (0..<result.numberOfRanges).map {
                            result.range(at: $0).location != NSNotFound
                                ? (value as NSString).substring(with: result.range(at: $0))
                                : ""
                        }
        }
        .filter { !$0.isEmpty && $0.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil }
        guard let key = values.first, let value = values.last else { return nil }
        return (key, value)
    }
    
}
