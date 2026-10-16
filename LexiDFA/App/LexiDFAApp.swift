//
//  LexiDFAApp.swift
//  LexiDFA
//
//  Created by Amirali Yazdani on 10/13/26.
//

import SwiftUI

@main
struct LexiDFAApp: App {
    @StateObject private var model = AppModel()
    @AppStorage("lexiDFA.appearanceMode") private var appearanceMode = 0

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .environmentObject(model.editor)
                .environmentObject(model.tracePlayer)
                .tint(.indigo)
                .preferredColorScheme(preferredColorScheme)
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
}
