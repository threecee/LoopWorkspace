//
//  HandoffOwnershipBadge.swift
//  LoopWatchApp (watchOS)
//
//  Small SwiftUI pill that reflects current HandoffState. Tap opens a detail
//  view (placeholder for now; B.3 expands).
//

import SwiftUI
import OmniBLE

struct HandoffOwnershipBadge: View {
    let state: HandoffState

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    private var label: String {
        switch state {
        case .phoneDriver: return "PHONE DRIVING"
        case .watchDriver: return "WATCH DRIVING"
        case .handoffPending: return "HANDOFF…"
        case .recovering: return "⚠ RECOVERING"
        }
    }

    private var background: Color {
        switch state {
        case .phoneDriver: return .gray
        case .watchDriver: return .green
        case .handoffPending: return .yellow
        case .recovering: return .red
        }
    }
}
