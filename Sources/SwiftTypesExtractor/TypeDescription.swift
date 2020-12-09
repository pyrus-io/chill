//
//  TypeDescription.swift
//  
//
//  Created by Kyle Newsome on 2020-10-26.
//

import Foundation
import SourceKittenFramework

public struct TypeDescription: Codable {
    
    public struct PropertyDescription: Codable {
        public var order: Int
        public var name: String
        public var type: String
        public var defaultValue: String?
    }
    
    public struct MethodDescription: Codable {
        public var order: Int
        public var name: String
        public var returnType: String?
        public var arguments: [String: ArgumentDescription]
    }
    
    public struct ArgumentDescription: Codable {
        public var order: Int
        public var name: String
        public var type: String
    }
    
    public struct EnumCase: Codable {
        public var order: Int
        public var name: String
        public var value: String
    }
    
    public var name: String
    public var kind: SourceKittenSubstructure.Kind
    public var inheritedTypes: [String]
    public var staticProperties: [String: PropertyDescription]
    public var staticMethods: [String: MethodDescription]
    public var instanceProperties: [String: PropertyDescription]
    public var instanceMethods: [String: MethodDescription]
    public var cases: [String: EnumCase]
    
    internal init?(substructure: SourceKittenSubstructure, file: File) {
        guard substructure.kind.isType,
              let name = substructure.name
        else {
            return nil
        }
        self.name = name
        self.kind = substructure.kind
        self.inheritedTypes = substructure.inheritedTypes?.map { $0.name } ?? []
        self.staticProperties = [:]
        self.staticMethods = [:]
        self.instanceProperties = [:]
        self.instanceMethods = [:]
        self.cases = [:]
                
        substructure.substructures?.forEach { childSubstructure in
            switch childSubstructure.kind {
            case .enumCaseDecl:
                guard let subChildSubstructure = childSubstructure.substructures?.first,
                      subChildSubstructure.kind == .enumElementDecl,
                      let name = subChildSubstructure.name else { return }
                
                let index = self.cases.count + 1
                self.cases[name] = EnumCase(order: index, name: name, value: name)
                if let offset = childSubstructure.offset,
                   let length = childSubstructure.length {
                    let remainingInfo = file.stringView.string
                        .dropFirst(offset)
                        .prefix(length)
                        .drop(while: { $0 != "=" })
                        .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: "=")))
                    if !remainingInfo.isEmpty {
                        self.cases[name] = EnumCase(
                            order: index,
                            name: name,
                            value: remainingInfo
                        )
                    }
                }
            case .staticVarDecl:
                guard let childSubstructureName = childSubstructure.name else { return }
                guard let typename = childSubstructure.typename else { return }
                var defaultValue: String?
                if let offset = childSubstructure.offset,
                   let length = childSubstructure.length,
                   let nameoffset = childSubstructure.nameoffset,
                   let namelength = childSubstructure.namelength {
                    let remainingInfo = file.stringView.string
                        .dropFirst(nameoffset + namelength)
                        .prefix((offset + length) - (nameoffset + namelength))
                        .drop(while: { $0 != "=" })
                        .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: "=")))
                    defaultValue = remainingInfo.isEmpty ? nil : remainingInfo
                }
                staticProperties[childSubstructureName] = PropertyDescription(
                    order: staticProperties.count + 1,
                    name: childSubstructureName,
                    type: typename,
                    defaultValue: defaultValue)
            case .staticMethodDecl:
                guard let childSubstructureName = childSubstructure.name else { return }
                var arguments: [String: ArgumentDescription] = [:]
                childSubstructure.substructures?.forEach { subChildSubstructure in
                    guard subChildSubstructure.kind == .parameterDecl,
                          let name = subChildSubstructure.name,
                          let typename = subChildSubstructure.typename else { return }
                    arguments[name] = ArgumentDescription(
                        order: arguments.count + 1,
                        name: name,
                        type: typename
                    )
                }
                staticMethods[childSubstructureName] = MethodDescription(
                    order: staticMethods.count + 1,
                    name: childSubstructureName,
                    returnType: childSubstructure.typename,
                    arguments: arguments
                )
            case .instanceVarDecl:
                guard let childSubstructureName = childSubstructure.name else { return }
                guard let typename = childSubstructure.typename else { return }
                var defaultValue: String?
                if let offset = childSubstructure.offset,
                   let length = childSubstructure.length,
                   let nameoffset = childSubstructure.nameoffset,
                   let namelength = childSubstructure.namelength {
                    let remainingInfo = file.stringView.string
                        .dropFirst(nameoffset + namelength)
                        .prefix((offset + length) - (nameoffset + namelength))
                        .drop(while: { $0 != "=" })
                        .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: "=")))
                    defaultValue = remainingInfo.isEmpty ? nil : remainingInfo
                }
                instanceProperties[childSubstructureName] = PropertyDescription(
                    order: instanceProperties.count,
                    name: childSubstructureName,
                    type: typename,
                    defaultValue: defaultValue)
            case .instanceMethodDecl:
                guard let childSubstructureName = childSubstructure.name else { return }
                var arguments: [String: ArgumentDescription] = [:]
                childSubstructure.substructures?.forEach { subChildSubstructure in
                    guard subChildSubstructure.kind == .parameterDecl,
                          let name = subChildSubstructure.name,
                          let typename = subChildSubstructure.typename else { return }
                        arguments[name] = ArgumentDescription(
                            order: arguments.count + 1,
                            name: name,
                            type: typename
                        )
                }
                instanceMethods[childSubstructureName] = MethodDescription(
                    order: instanceMethods.count + 1,
                    name: childSubstructureName,
                    returnType: childSubstructure.typename,
                    arguments: arguments
                )
            default: break
            }
        }
        
    }
    
    func merged(with info: TypeDescription) -> TypeDescription {
        // todo: merge info
        return self
    }
}
