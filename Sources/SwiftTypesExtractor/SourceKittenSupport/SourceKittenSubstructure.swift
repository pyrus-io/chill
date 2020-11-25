//
//  SourceKittenSubstructure.swift
//  
//
//  Created by Kyle Newsome on 2020-10-26.
//

import Foundation
import SourceKittenFramework

struct SourceKittenSubstructure: Codable {
    
    struct InheritedType: Codable {
        var name: String
        
        enum CodingKeys: String, CodingKey {
            case name = "key.name"
        }
    }
    
    enum Kind: String, Codable {
        case localVarDecl = "source.lang.swift.decl.var.local"
        case instanceVarDecl = "source.lang.swift.decl.var.instance"
        case staticVarDecl = "source.lang.swift.decl.var.static"
        case instanceMethodDecl = "source.lang.swift.decl.function.method.instance"
        case staticMethodDecl = "source.lang.swift.decl.function.method.static"
        
        case structTypeDecl = "source.lang.swift.decl.struct"
        case enumTypeDecl = "source.lang.swift.decl.enum"
        case classTypeDecl = "source.lang.swift.decl.class"
        case extensionTypeDecl = "source.lang.swift.decl.extension"
        case protocolTypeDecl = "source.lang.swift.decl.protocol"
        case associatedTypeDecl = "source.lang.swift.decl.associatedtype"
        case freeFunctionDecl = "source.lang.swift.decl.function.free"
        case genericTypeParamDecl = "source.lang.swift.decl.generic_type_param"
        case typealiasDecl = "source.lang.swift.decl.typealias"
        case enumCaseDecl = "source.lang.swift.decl.enumcase"
        case parameterDecl = "source.lang.swift.decl.var.parameter"
        case enumElementDecl = "source.lang.swift.decl.enumelement"
        
        case braceStatement = "source.lang.swift.stmt.brace"
        case ifStatement = "source.lang.swift.stmt.if"
        case caseStatement = "source.lang.swift.stmt.case"
        case switchStatement = "source.lang.swift.stmt.switch"
        case guardStatement = "source.lang.swift.stmt.guard"
        case foreachStatement = "source.lang.swift.stmt.foreach"
        
        case argumentExpr = "source.lang.swift.expr.argument"
        case callExpr = "source.lang.swift.expr.call"
        case closureExpr = "source.lang.swift.expr.closure"
        case arrayExpr = "source.lang.swift.expr.array"
        case dictionaryExpr = "source.lang.swift.expr.dictionary"
        case tupleExpr = "source.lang.swift.expr.tuple"
        
        case commentMark = "source.lang.swift.syntaxtype.comment.mark"
        
        var isType: Bool {
            switch self {
            case .structTypeDecl, .enumTypeDecl, .classTypeDecl, .protocolTypeDecl:
                return true
            default:
                return false
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case name = "key.name"
        case typename = "key.typename"
        case substructures = "key.substructure"
        case comment = "key.doc.comment"
        case kind = "key.kind"
        case inheritedTypes = "key.inheritedtypes"
        
        case offset = "key.offset"
        case length = "key.length"
        case namelength = "key.namelength"
        case nameoffset = "key.nameoffset"
    }
    
    var name: String?
    var typename: String?
    var comment: String?
    var kind: Kind
    var inheritedTypes: [InheritedType]?
    var substructures: [SourceKittenSubstructure]?
    
    var offset: Int?
    var length: Int?
    var namelength: Int?
    var nameoffset: Int?
}
