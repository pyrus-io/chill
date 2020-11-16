//
//  FileStructure.swift
//  
//
//  Created by Kyle Newsome on 2020-10-25.
//

import Foundation

struct SourceKittenSwiftFileStructure: Codable {
    enum CodingKeys: String, CodingKey {
        case substructures = "key.substructure"
    }
    
    var substructures: [SourceKittenSubstructure]
}
