import Foundation
import ArgumentParser
import APIClientGenerator
import SwaggerDocumentationGenerator
import PathKit

struct CLI: ParsableCommand {
    // Customize your command's help and subcommands by implementing the
    // `configuration` property.
    static var configuration = CommandConfiguration(
        // Optional abstracts and discussions are used for help output.
        abstract: "A utility for generating documentation and api clients from vapor endpoints",
        version: "1.0.0",
        subcommands: [APIDocs.self, APIClient.self],
        defaultSubcommand: APIDocs.self)

}

extension CLI {
    static func format(_ result: Int, usingHex: Bool) -> String {
        usingHex ? String(result, radix: 16)
            : String(result)
    }

    struct APIDocs: ParsableCommand {
        static var configuration =
            CommandConfiguration(abstract: "Output OpenAPI documentation generator")

        @Option(name: .shortAndLong, help: "A list of relative urls to read")
        var inputs: [String] = ["./Sources"]
        
        @Option(name: .shortAndLong, help: "Relative url to output file")
        var output: String = "./api.json"

        mutating func run() {
            let inputDirectories: [URL] = inputs.map { Path($0).absolute().url }
            let doc = try! DocumentationGenerator.generateOpenAPIDocument(
                readDirectoryUrls: inputDirectories,
                config: .init()
            )
            print(String(data: (try! JSONEncoder().encode(doc)), encoding: .utf8)!)
        }
    }

    struct APIClient: ParsableCommand {
        static var configuration =
            CommandConfiguration(abstract: "Output OpenAPI documentation generator")

        @Option(name: .shortAndLong, help: "A list of relative urls to read")
        var inputs: [String] = ["./Sources"]
        
        @Option(name: .shortAndLong, help: "Relative url to output file")
        var output: String = "./Generated/"

        mutating func run() {
            try! generateAPIClient(inputPaths: inputs, outputPath: output)
            print("Successfully generated API Client Package at \(output)")
        }
    }
}
