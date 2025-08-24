
import SwiftUI

struct PlayerRosterEditor: View {
    @Binding var overlay: TrackingOverlay?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if overlay == nil {
                Text("Load an overlay to edit player labels and colours.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Player Labels & Colours").font(.headline)
                if var ov = overlay {
                    ForEach(ov.players.indices, id: \.self) { i in
                        HStack {
                            Text("#\(ov.players[i].id)").font(.monospacedDigit(.body)())
                            TextField("Label", text: Binding(
                                get: { ov.players[i].label ?? "" },
                                set: { new in
                                    var players = ov.players
                                    players[i] = TrackingOverlay.PlayerDef(id: players[i].id, color: players[i].color, label: new)
                                    overlay = TrackingOverlay(fps: ov.fps, players: players, tracks: ov.tracks, events: ov.events)
                                }
                            ))
                            Spacer()
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: ov.players[i].color ?? "#ff0000") ?? .red },
                                set: { col in
                                    var players = ov.players
                                    players[i] = TrackingOverlay.PlayerDef(id: players[i].id, color: col.toHex(), label: players[i].label)
                                    overlay = TrackingOverlay(fps: ov.fps, players: players, tracks: ov.tracks, events: ov.events)
                                }
                            ))
                            .labelsHidden()
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let val = Int(s, radix: 16) else { return nil }
        let r = Double((val >> 16) & 0xff) / 255.0
        let g = Double((val >> 8) & 0xff) / 255.0
        let b = Double(val & 0xff) / 255.0
        self = Color(red: r, green: g, blue: b)
    }

    func toHex() -> String {
        // Very lightweight conversion using UIColor bridging
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green=&g, blue=&b, alpha=&a)
        let ri = Int(r * 255.0 + 0.5)
        let gi = Int(g * 255.0 + 0.5)
        let bi = Int(b * 255.0 + 0.5)
        return String(format: "#%02x%02x%02x", ri, gi, bi)
        #else
        return "#ffffff"
        #endif
    }
}
