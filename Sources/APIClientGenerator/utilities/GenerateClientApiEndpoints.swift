import Foundation
import Stencil
import PathKit
import SwaggerDocumentationGenerator
import SwiftFormat

func generateClientApiEndpoints(doc: Swagger.Document, in outputDirectory: URL) throws {
    
    let endpoints = doc.paths.flatMap { (path, methodsDict) in
        methodsDict.map { (httpMethod, methodData) -> Endpoint in
            
            var finalPath = path
            
            guard let response = methodData.responses[200] else {
                fatalError("no 200 response")
            }
            
            let responseType: String
            if let jsonResponse = response.content[Constants.applicationJson]?.schema.ref {
                responseType = jsonResponse.replacingOccurrences(of: Constants.componentsSchemasPrefix, with: "")
            }
            else if response.content[Constants.applicationJson]?.schema.type == .array,
                      let itemsType = response.content[Constants.applicationJson]?.schema.items?.ref {
                responseType = "[" + itemsType.replacingOccurrences(of: Constants.componentsSchemasPrefix, with: "") + "]"
            }
            else {
                responseType = "Void"
            }
            
            var parameters: [Property] = []
            var queryItems: [Property] = []
            
            for param in methodData.parameters {
                switch param.in {
                case .path:
                    guard var typeName = param.schema?.type?.rawValue else {
                        continue
                    }
                    
                    typeName = openApiTypeToSwiftType(typeName, format: param.schema?.format)
                    if param.required != true {
                        typeName += "?"
                    }
                    parameters.append(.init(
                        name: param.name,
                        type: typeName,
                        required: param.required == true
                    ))
                    
                    finalPath = finalPath.replacingOccurrences(of: "{\(param.name)}", with: "\\(parameters.\(param.name))")
                    
                case .query:
                    guard let type = param.schema?.type else {
                        continue
                    }
                    var typeName = type.rawValue
                    
                    if type == .array {
                        if let primitiveItemType = param.schema?.items?.type?.rawValue {
                            typeName = openApiTypeToSwiftType(primitiveItemType, format: param.schema?.items?.format)
                        } else if let ref = param.schema?.items?.ref {
                            typeName = ref.replacingOccurrences(of: Constants.componentsSchemasPrefix, with: "")
                        } else {
                            continue
                        }
                        
                        typeName = "[" + typeName + "]"
                    } else {
                        typeName = openApiTypeToSwiftType(typeName, format: param.schema?.format)
                    }
                    
                    if param.required != true {
                        typeName += "?"
                    }
                    queryItems.append(.init(
                                        name: param.name,
                                        type: typeName,
                                        required: param.required == true))
                case .header: break
                }
            }
            
            var bodyType: String? = nil
            if let body = methodData.requestBody?.content[Constants.applicationJson]?.schema.ref {
                bodyType = body.replacingOccurrences(of: Constants.componentsSchemasPrefix, with: "")
            }
            
            return Endpoint(
                name: methodData.operationId,
                method: httpMethod,
                path: finalPath,
                parameters: parameters,
                query: queryItems,
                bodyType: bodyType,
                responseType: responseType,
                requiresAuth: methodData.security != nil,
                tags: methodData.tags
            )
        }
    }

    let templatePath = URL(fileURLWithPath: #file)
        .deletingLastPathComponent()
        .appendingPathComponent("templates/")
        .path
    let environment = Environment(loader: FileSystemLoader(paths: [Path(templatePath)]))
    let endpointOutputDir = outputDirectory.appendingPathComponent("Endpoints")
    try FileManager.default.createDirectory(at: endpointOutputDir, withIntermediateDirectories: true, attributes: nil)
    
    let spaceRegex = try NSRegularExpression(pattern: "(\\\n\\s+)+", options: [])

    try endpoints.forEach { (endpoint) in
        let context = [
          "endpoint": endpoint
        ]
        
        var rendered = try environment.renderTemplate(name: "endpoint.stencil", context: context)
        rendered = spaceRegex.stringByReplacingMatches(
            in: rendered, options: [],
            range: NSRange(location: 0, length: rendered.utf16.count),
            withTemplate: "\n"
        )
        .replacingOccurrences(of: "\n,", with: ",")
        
        let formatted = try format(rendered, rules: FormatRules.all)
        var outputPath = endpointOutputDir
        if let firstTag = endpoint.tags?.first {
            outputPath.appendPathComponent(firstTag)
            try FileManager.default.createDirectory(at: outputPath, withIntermediateDirectories: true, attributes: nil)
        }
        outputPath.appendPathComponent("\(endpoint.name).swift")
        
        FileManager.default.createFile(
            atPath: outputPath.path,
            contents: formatted.data(using: .utf8),
            attributes: [:]
        )
    }
}






