//
//  SwiftTypesExtractor.swift
//  
//
//  Created by Kyle Newsome on 2020-10-26.
//

import Foundation
import SourceKittenFramework

public struct SwiftTypesExtractor {
    
    public let types: [String: TypeDescription]
    
    public init(directoryUrl: URL) throws {
        let enumerator = FileManager.default.enumerator(atPath: directoryUrl.path)
        var swiftFilePaths: [String] = []
        while let element = enumerator?.nextObject() as? String {
            if element.hasSuffix(".swift") {
                swiftFilePaths.append(element)
            }
        }
        let files = swiftFilePaths.map {
            File(pathDeferringReading: directoryUrl.appendingPathComponent($0).path)
        }
        self.types = try SwiftTypesExtractor.extractTypes(from: files)
    }
    
    public func types(inheritingFrom: String) -> [String: TypeDescription] {
        return types.filter { $0.value.inheritedTypes.contains("APIRoutingEndpoint") }
    }
    
}

extension SwiftTypesExtractor {
    
    private static func extractTypes(from files: [File]) throws -> [String: TypeDescription] {
        var allFilesTypes: [String: TypeDescription] = [:]
        try files.forEach { file in
            allFilesTypes.merge(try extractTypes(from: file)) { $0.merged(with: $1) }
        }
        return allFilesTypes
    }
    
    private static func extractTypes(from file: File) throws -> [String: TypeDescription] {
        let structure = try Structure(file: file)
        let jsonString = toJSON(toNSDictionary(structure.dictionary))

        let fileStructure = try JSONDecoder().decode(SourceKittenSwiftFileStructure.self, from: jsonString.data(using: .utf8)!)

        let makeTypeDescription = { (s: SourceKittenSubstructure) -> TypeDescription? in
            TypeDescription(substructure: s, file: file)
        }
        return getAllTypes(from: fileStructure.substructures).compactMapValues(makeTypeDescription)
    }
    
    private static func visitSubstructure(_ substructure: SourceKittenSubstructure, storeIn substructureDictionary: inout [String: SourceKittenSubstructure]) {
        if let name = substructure.name {
            if substructure.kind.isType {
                substructureDictionary[name] = substructure
            }
        }
        if let childSubstructures = substructure.substructures {
            childSubstructures.forEach {
                visitSubstructure($0, storeIn: &substructureDictionary)
            }
        }
    }
    
    private static func getAllTypes(from substructures: [SourceKittenSubstructure]) -> [String: SourceKittenSubstructure] {
        var allTypes = [String: SourceKittenSubstructure]()
        for substructure in substructures {
            visitSubstructure(substructure, storeIn: &allTypes)
        }
        allTypes = allTypes.filter { $0.value.kind.isType }
        return allTypes
    }
}
