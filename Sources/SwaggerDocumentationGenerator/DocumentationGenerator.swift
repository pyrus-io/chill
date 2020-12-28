import Foundation
import SourceKittenFramework
import SwiftTypesExtractor

public struct DocumentationGenerator {
    
    public struct Configuration {
        public var securitySchemes: [String: [String: String]]?
        public var authForContext: ((String) -> String?)?
    
        public init(
            securitySchemes: [String: [String: String]]? = nil,
            authForContext: ((String) -> String?)? = nil
        ) {
            self.securitySchemes = securitySchemes
            self.authForContext = authForContext
        }
    }
    
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
        static var vaporPageRegex = try! NSRegularExpression(
            pattern: "(Page<)([a-zA-Z]+)(>)",
            options: []
        )
        
        static let ignoredReturnTypes = ["String", "Int", "HTTPStatus"]
    }
    
    public static func generateOpenAPIJSONString(
        readDirectoryUrls: [URL],
        config: Configuration
    ) throws -> String {
        let document = try generateOpenAPIDocument(readDirectoryUrls: readDirectoryUrls, config: config)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try JSONEncoder().encode(document)
        guard let jsonString =  String(data: jsonData, encoding: .utf8) else {
            throw DocsError.failedToConvertToJSON
        }
        return jsonString
    }
    
    public static func generateOpenAPIDocument(
        readDirectoryUrls: [URL],
        config: Configuration
    ) throws -> Swagger.Document {
        let extractor = try SwiftTypesExtractor(directoryUrls: readDirectoryUrls)
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
            var security: Array<[String: [String]]>?
            
            try executionFunc.arguments.values
                .sorted(by: { $0.order < $1.order })
                .forEach { argument in
                switch argument.name {
                case "context":
                    if let authName = config.authForContext?(argument.type) {
                        security = [
                            [authName: []]
                        ]
                    }
                case "body" where argument.type != "Void":
                    guard let requestBodyType = extractor.types[argument.type] else {
                        throw DocsError.missingCriticalEndpointInformation("Can't find information about \(argument.type) but it is used in the query of \(endpointType.name)")
                    }
                    
                    requestBody = Swagger.Body(content: [
                        "application/json": .init(schema: .init(ref: "#/components/schemas/\(argument.type)")),
                    ], required: true)
                    
                    createDefinition(
                        from: requestBodyType,
                        insertingInto: &definitions,
                        withName: argument.type,
                        extractor: extractor
                    )
                case "parameters" where argument.type != "Void":
                    guard let queryTypeInfo = extractor.types[argument.type] else {
                        throw DocsError.missingCriticalEndpointInformation("Can't find information about \(argument.type) but it is used in the query of \(endpointType.name)")
                    }
                    queryTypeInfo.instanceProperties.values
                        .sorted(by: { $0.order < $1.order })
                        .forEach { property in
                        cleanedPath = cleanedPath.replacingOccurrences(of: ":\(property.name)", with: "{\(property.name)}")
                        parameters.append(Swagger.Parameter(
                            in: .path,
                            name: property.name,
                            required: typeIsRequired(property.type),
                            schema: .init(type: Swagger.ReferenceType(rawValue: cleanType(property.type)) ?? .object)
                            )
                        )
                    }
                case "query" where argument.type != "Void":
                    guard let queryTypeInfo = extractor.types[argument.type] else {
                        throw DocsError.missingCriticalEndpointInformation("Can't find information about \(argument.type) but it is used in the query of \(endpointType.name)")
                    }
                    queryTypeInfo.instanceProperties.values
                        .sorted(by: { $0.order < $1.order })
                        .forEach { property in
                        
                        let cleanName: String = cleanType(property.type)
                        let refType = Swagger.ReferenceType(rawValue: cleanName) ?? .object
                        
                        if refType != .object {
                            parameters.append(Swagger.Parameter(
                                in: .query,
                                name: property.name,
                                required: typeIsRequired(property.type),
                                schema: .init(type: refType, format: cleanFormat(property.type))
                                )
                            )
                        } else {
                            var schema: Swagger.SchemaReference
                            
                            if typeIsArray(cleanName),
                               let typeName = extractType(from: cleanName, regex: Constants.arrayRegex) {
                                
                                let cleanItemName = cleanType(typeName)
                                let refType = Swagger.ReferenceType(rawValue: cleanItemName) ?? .object
                                if refType != .object {
                                    schema = .init(
                                        type: .array,
                                        items: .init(type: refType, format: cleanFormat(typeName)))
                                } else {
                                    createDefinition(from: cleanItemName, insertingInto: &definitions, extractor: extractor)
                                    schema = .init(
                                        type: .array,
                                        items: .init(ref: "#/components/schemas/\(cleanItemName)"))
                                }
                            }
                            else {
                                createDefinition(from: cleanName, insertingInto: &definitions, extractor: extractor)
                                schema = .init(ref: "#/components/schemas/\(cleanName)")
                            }
                            
                            parameters.append(Swagger.Parameter(
                                in: .query,
                                name: property.name,
                                required: typeIsRequired(property.type),
                                schema: schema
                            ))
                        }
                    }
                default: break
                
                }
            }
            
            if let returnTypeName = executionFunc.returnType {
                let cleanReturnName = cleanReturnTypeName(returnTypeName)
                let isArray = !Constants.arrayRegex.matches(in: cleanReturnName, options: [], range: NSRange(location: 0, length: cleanReturnName.utf16.count)).isEmpty
                let isDictionary = !Constants.dictRegex.matches(in: cleanReturnName, options: [], range: NSRange(location: 0, length: cleanReturnName.utf16.count)).isEmpty
                let isVaporPage = !Constants.vaporPageRegex.matches(in: cleanReturnName, options: [], range: NSRange(location: 0, length: cleanReturnName.utf16.count)).isEmpty
                
                if !Constants.ignoredReturnTypes.contains(cleanReturnName)
                    && !isDictionary
                    && !isArray
                    && !isVaporPage {
                    guard let returnType = extractor.types[cleanReturnName] else {
                        throw DocsError.missingCriticalEndpointInformation("Can't find information about \(cleanReturnName) but it is used in the return type of \(endpointType.name)")
                    }
        
                    createDefinition(
                        from: returnType,
                        insertingInto: &definitions,
                        withName: cleanReturnName,
                        extractor: extractor
                    )
                    
                    responses[200] = .init(
                        description: "",
                        content: ["application/json": .init(schema: .init(
                            ref: "#/components/schemas/\(cleanReturnName)")
                        )]
                    )
                } else if isArray, let typeName = extractType(from: cleanReturnName, regex: Constants.arrayRegex) {
                    guard let returnType = extractor.types[typeName] else {
                        throw DocsError.missingCriticalEndpointInformation("Can't find information about \(cleanReturnName) but it is used in an array of the return type for \(endpointType.name)")
                    }

                    createDefinition(
                        from: returnType,
                        insertingInto: &definitions,
                        withName: typeName,
                        extractor: extractor
                    )
                    
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
                else if isVaporPage, let typeName = extractType(from: cleanReturnName, regex: Constants.vaporPageRegex) {
                    guard let returnType = extractor.types[typeName] else {
                        throw DocsError.missingCriticalEndpointInformation("Can't find information about \(cleanReturnName) but it is used in an vapor page of the return type for \(endpointType.name)")
                    }
                    
                    let pageTypeName = "PageOf\(typeName)"
                    createPageDefinition(pagedTypeName: typeName, insertingInto: &definitions, withName: pageTypeName)
                    createDefinition(
                        from: returnType,
                        insertingInto: &definitions,
                        withName: typeName,
                        extractor: extractor
                    )
                    
                    responses[200] = .init(
                        description: "",
                        content: ["application/json": .init(schema: .init(
                            ref: "#/components/schemas/\(pageTypeName)")
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
                tags: cleanedPath.split(separator: "/").first.map { [String($0).capitalized] },
                requestBody: requestBody,
                security: security)
        }
        
        document.components.securitySchemes = config.securitySchemes
        document.components.schemas = definitions

        return document
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
        case "String", "UUID", "URL", "Date": return "string"
        case "Bool": return "boolean"
        case "Int": return "integer"
        case "Double": return "number"
        default:
            return trimmed
        }
    }
    
    private static func cleanFormat(_ type: String) -> String? {
        let trimmed = type.trimmingCharacters(in: .init(arrayLiteral: "?"))
        switch trimmed {
        case "Date": return "date-time"
        case "UUID": return "uuid"
        case "Double": return "double"
        case "URL": return "uri"
        default:
            return nil
        }
    }

    private static func typeIsRequired(_ type: String) -> Bool {
        return !type.contains("?")
    }
    
    private static func typeIsNonPrimitive(_ type: String) -> Bool {
        let trimmed = type.trimmingCharacters(in: .init(arrayLiteral: "?"))
        switch trimmed {
        case "String", "UUID", "Bool", "Int", "Double", "Date", "URL":
            return false
        default:
            return true
        }
    }
    
    private static func typeIsArray(_ type: String) -> Bool {
        !Constants.arrayRegex.matches(in: type, options: [], range: NSRange(location: 0, length: type.utf16.count)).isEmpty
    }
    
    private static func typeIsEnum(_ type: String, extractor: SwiftTypesExtractor) -> Bool {
        return extractor.types[type]?.kind == .enumTypeDecl
    }
    
    private static func typeIsDict(_ type: String) -> Bool {
        !Constants.dictRegex.matches(in: type, options: [], range: NSRange(location: 0, length: type.utf16.count)).isEmpty
    }
    
    private static func typeIsVaporPage(_ type: String) -> Bool {
        !Constants.vaporPageRegex.matches(in: type, options: [], range: NSRange(location: 0, length: type.utf16.count)).isEmpty
    }

    private static func cleanReturnTypeName(_ returnTypeName: String) -> String {
        return String(returnTypeName
                        .dropFirst(Constants.returnTypePrefix.count)
                        .dropLast(Constants.returnTypeSuffix.count))
    }
    
    private static func createDefinition(
        from typeName: String,
        insertingInto definitionsTable: inout [String: Swagger.Definition],
        extractor: SwiftTypesExtractor
    ) {
        let cleanTypeName = typeName.trimmingCharacters(in: .init(arrayLiteral: "?"))
        if typeIsArray(cleanTypeName) {
            guard let typeName = extractType(from: cleanTypeName, regex: Constants.arrayRegex),
                  let type = extractor.types[typeName] else {
                return
            }
            createDefinition(from: type, insertingInto: &definitionsTable, withName: typeName, extractor: extractor)
        }
        else {
            guard let type = extractor.types[cleanTypeName] else {
                return
            }
            createDefinition(from: type, insertingInto: &definitionsTable, withName: cleanTypeName, extractor: extractor)
        }
    }

    private static func createDefinition(
        from type: TypeDescription,
        insertingInto definitionsTable: inout [String: Swagger.Definition],
        withName name: String,
        extractor: SwiftTypesExtractor
    ) {
        
        guard definitionsTable[name] == nil else {
            return
        }
        
        if type.kind == .enumTypeDecl {
            createEnumDefinition(
                from: type,
                insertingInto: &definitionsTable,
                withName: name,
                extractor: extractor
            )
            return
        }
        
        var properties: [String: Swagger.SchemaReference] = [:]
        var requiredProperties: [String] = []
        type.instanceProperties.values
            .sorted(by: { $0.order < $1.order })
            .forEach { (property) in
                
            let nonOptionalName = property.type.trimmingCharacters(in: .init(arrayLiteral: "?"))
            
            if typeIsNonPrimitive(property.type) {
                if typeIsArray(property.type),
                   let typeName = extractType(from: property.type, regex: Constants.arrayRegex) {
                    if typeIsNonPrimitive(typeName),
                       let returnType = extractor.types[typeName] {
                        createDefinition(
                            from: returnType,
                            insertingInto: &definitionsTable,
                            withName: typeName,
                            extractor: extractor
                        )
                        properties[property.name] = .init(
                            items: Swagger.ItemReference(
                            ref: "#/components/schemas/\(typeName)"
                        ))
                    } else {
                        properties[property.name] = .init(
                            items: Swagger.ItemReference(
                                type: Swagger.ReferenceType(rawValue: cleanType(typeName)) ?? .object,
                                format: cleanFormat(typeName)
                        ))
                    }
                }
                else if let typeDescription = extractor.types[nonOptionalName] {
                    createDefinition(
                        from: typeDescription,
                        insertingInto: &definitionsTable,
                        withName: nonOptionalName,
                        extractor: extractor
                    )
                    properties[property.name] = .init(
                        ref: "#/components/schemas/\(nonOptionalName)"
                    )
                }
            } else {
                properties[property.name] = .init(
                    type: Swagger.ReferenceType(rawValue: cleanType(property.type)) ?? .object,
                    format: cleanFormat(property.type)
                )
            }
            if typeIsRequired(property.type) {
                requiredProperties.append(property.name)
            }
        }
        let def = Swagger.Definition(
            description: nil,
            properties: properties,
            required: requiredProperties.isEmpty ? nil : requiredProperties
        )
        definitionsTable[name] = def
    }
    
    private static func createEnumDefinition(
        from type: TypeDescription,
        insertingInto definitionsTable: inout [String: Swagger.Definition],
        withName name: String,
        extractor: SwiftTypesExtractor
    ) {
        guard definitionsTable[name] == nil else {
            print("Skipping insertion of \(name) because it already exists")
            return
        }
        
        guard type.kind == .enumTypeDecl else {
            return
        }
        
        let def = Swagger.Definition(
            type: "string",
            enum: type
                .cases
                .values
                .sorted(by: { $0.order < $1.order })
                .map { $0.value }
        )
        definitionsTable[name] = def
    }
    
    private static func createPageDefinition(
        pagedTypeName: String,
        insertingInto definitionsTable: inout [String: Swagger.Definition],
        withName name: String
    ) {
        let def = Swagger.Definition(
            description: nil,
            properties: [
                "items": .init(
                    type: .array,
                    items: .init(ref: "#/components/schemas/\(pagedTypeName)")),
                "metadata": .init(ref: "#/components/schemas/VaporPageMetadata")
            ],
            required: ["items", "metadata"]
        )
        definitionsTable[name] = def
        
        createVaporPageMetadataDefinition(insertingInto: &definitionsTable)
    }
    
    private static func createVaporPageMetadataDefinition(
        insertingInto definitionsTable: inout [String: Swagger.Definition]
    ) {
        let def = Swagger.Definition(
            description: nil,
            properties: [
                "page": .init(type: .integer),
                "per": .init(type: .integer),
                "total": .init(type: .integer)
            ],
            required: ["page", "per", "total"]
        )
        definitionsTable["VaporPageMetadata"] = def
    }

    private static func extractType(from value: String, regex: NSRegularExpression) -> String? {
        let matches = regex.matches(in: value, options: [], range: NSRange(location: 0, length: value.utf16.count))
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
