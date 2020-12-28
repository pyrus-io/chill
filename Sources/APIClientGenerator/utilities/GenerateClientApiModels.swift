import Foundation
import Stencil
import PathKit
import SwaggerDocumentationGenerator
import SwiftFormat

func generateClientApiModels(doc: Swagger.Document, in outputDirectory: URL) throws {
    
    var models: [Model] = []
    var enums: [Enum] = []
    
    doc.components.schemas.forEach { (schemaName, schemaDef) in
        if let model = model(schemaName: schemaName, definition: schemaDef) {
            models.append(model)
        } else if let enumInfo = schemaDef.enum {
            enums.append(.init(name: schemaName, cases: enumInfo))
        }
    }
    
    let templatePath = URL(fileURLWithPath: #file)
        .deletingLastPathComponent()
        .appendingPathComponent("templates/")
        .path
    let environment = Environment(loader: FileSystemLoader(paths: [Path(templatePath)]))
    let endpointOutputDir = outputDirectory.appendingPathComponent("Models")
    try FileManager.default.createDirectory(at: endpointOutputDir, withIntermediateDirectories: true, attributes: nil)
    
    let spaceRegex = try NSRegularExpression(pattern: "(\\\n\\s+)+", options: [])

    try models.forEach { (model) in
        let context = [
          "model": model
        ]
        
        var rendered = try environment.renderTemplate(name: "model.stencil", context: context)
        rendered = spaceRegex.stringByReplacingMatches(
            in: rendered, options: [],
            range: NSRange(location: 0, length: rendered.utf16.count),
            withTemplate: "\n"
        )
        .replacingOccurrences(of: "\n,", with: ",")
        
        let formatted = try format(rendered, rules: FormatRules.all)
        let outputPath = endpointOutputDir.appendingPathComponent("\(model.name).swift").path
        
        FileManager.default.createFile(
            atPath: outputPath,
            contents: formatted.data(using: .utf8),
            attributes: [:]
        )
    }
    
    try enums.forEach { (enumInfo) in
        let context = [
          "enum": enumInfo
        ]
        
        var rendered = try environment.renderTemplate(name: "enum.stencil", context: context)
        rendered = spaceRegex.stringByReplacingMatches(
            in: rendered, options: [],
            range: NSRange(location: 0, length: rendered.utf16.count),
            withTemplate: "\n"
        )
        .replacingOccurrences(of: "\n,", with: ",")
        
        let formatted = try format(rendered, rules: FormatRules.all)
        let outputPath = endpointOutputDir.appendingPathComponent("\(enumInfo.name).swift").path
        
        FileManager.default.createFile(
            atPath: outputPath,
            contents: formatted.data(using: .utf8),
            attributes: [:]
        )
    }
}

func model(schemaName: String, definition: Swagger.Definition) -> Model? {
    
    var properties = [Property]()
    
    guard let sortedProps = definition.properties?.sorted(by: {
        // ids first
        if $0.key == "id" { return true }
        else if $1.key == "id" { return false }
        else {
            // required status second
            let aRequired = definition.required?.contains($0.key) == true
            let bRequired = definition.required?.contains($1.key) == true
            
            if aRequired && !bRequired {
                return true
            }
            else if !aRequired && bRequired {
                return false
            }
            // finally alphabetical
            return $0.key < $1.key
        }
    }) else {
        return nil
    }
    
    for (key, prop) in sortedProps {
        if let type = prop.type  {
            var typeName = type.rawValue
            
            if type == .array {
                if let primitiveItemType = prop.items?.type?.rawValue {
                    typeName = openApiTypeToSwiftType(primitiveItemType, format: prop.items?.format)
                } else if let ref = prop.items?.ref {
                    typeName = ref.replacingOccurrences(of: Constants.componentsSchemasPrefix, with: "")
                } else {
                    continue
                }
                
                typeName = "[" + typeName + "]"
            } else {
                typeName = openApiTypeToSwiftType(typeName, format: prop.format)
            }
            
            let required = definition.required?.contains(key) == true
            if !required {
                typeName += "?"
            }
            properties.append(.init(
                name: key,
                type: typeName,
                required: required
            ))
        }
        else if let items = prop.items {
            var typeName: String
            if let itemsRef = items.ref {
                typeName = itemsRef.replacingOccurrences(of: Constants.componentsSchemasPrefix, with: "")
            }
            else if let type = items.type {
                typeName = openApiTypeToSwiftType(type.rawValue, format: items.format)
            } else {
                continue
            }
            
            typeName = "[" + typeName + "]"
            let required = definition.required?.contains(key) == true
            if !required {
                typeName += "?"
            }
            properties.append(.init(
                name: key,
                type: typeName,
                required: required
            ))
        }
        else if let ref = prop.ref {
            var typeName = ref.replacingOccurrences(of: Constants.componentsSchemasPrefix, with: "")
            let required = definition.required?.contains(key) == true
            if !required {
                typeName += "?"
            }
            properties.append(.init(
                name: key,
                type: typeName,
                required: required
            ))
        }
        
    }
    return Model(
        name: schemaName,
        properties: properties
    )
}





