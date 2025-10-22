//
//  Blog_StatusApp.swift
//  Blog Status
//
//  Created by Jared Currie on 10/21/25.
//

import SwiftUI

@main
struct Blog_StatusApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: Blog_StatusDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
