//
//  Blog_StatusDocument.swift
//  Blog Status
//
//  Created by Jared Currie on 10/21/25.
//

import SwiftUI
import UniformTypeIdentifiers

nonisolated struct Blog_StatusDocument: FileDocument {
    var text: String

    init(text: String = "Hello, world!") {
        self.text = text
    }

    static let readableContentTypes = [
        UTType(importedAs: "com.example.plain-text")
    ]

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}
