//
//  ContentView.swift
//  Blog Status
//
//  Created by Jared Currie on 10/21/25.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: Blog_StatusDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(Blog_StatusDocument()))
}
