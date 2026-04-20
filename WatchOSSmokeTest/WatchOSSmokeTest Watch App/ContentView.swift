//
//  ContentView.swift
//  WatchOSSmokeTest Watch App
//
//  Created by Carl Christensen on 20/04/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("WatchOS Smoke Test")
                    .font(.headline)
                Text(smokeTestLoopKit())
                    .font(.caption)
                Text(smokeTestAlgorithm())
                    .font(.caption)
                Text(smokeTestOmniBLE())
                    .font(.caption)
                Text(smokeTestG7())
                    .font(.caption)
                Text("All linked.")
                    .bold()
                    .foregroundStyle(.green)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
