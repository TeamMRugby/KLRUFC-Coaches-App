
import SwiftUI
import AVKit
import WebKit
import UniformTypeIdentifiers

struct VideoAnalysisView: View {
    // Web player mode
    @State private var pastedURL: String = ""
    @State private var showWeb = false

    // Local analysis mode
    @State private var player: AVPlayer? = nil
    @State private var overlay: TrackingOverlay? = nil
    @State private var showingVideoPicker = false
    @State private var showingOverlayPicker = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Veo & Other Web Players")) {
                    TextField("Paste a Veo/Hudl/Spiideo/YouTube link…", text: $pastedURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    Button("Open Link") {
                        showWeb = true
                    }
                    .disabled(URL(string: pastedURL) == nil)
                    .sheet(isPresented: $showWeb) {
                        if let url = URL(string: pastedURL) {
                            SafariView(url: url)
                        }
                    }
                    Text("Tip: Use the platform's **Share link** so your 10 users can view with their own logins.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(header: Text("Local Clip + Tracking Overlay")) {
                    HStack {
                        Button {
                            showingVideoPicker = true
                        } label: {
                            Label("Pick MP4/MOV", systemImage: "film")
                        }
                        Spacer()
                        Button {
                            showingOverlayPicker = true
                        } label: {
                            Label("Load Overlay JSON", systemImage: "doc.text")
                        }.disabled(player == nil)
                    }

                    if let player {
                        ZStack {
                            VideoPlayer(player: player)
                                .frame(minHeight: 220)

                            if let overlay {
                                TrackingOverlayView(player: player, overlay: overlay)
                            } else {
                                Text("No overlay loaded")
                                    .padding(8)
                                    .background(.ultraThinMaterial, in: Capsule())
                            }
                        }
                        HStack {
                            Button(action: { player.seek(to: .zero); player.play() }) {
                                Label("Play", systemImage: "play.fill")
                            }
                            Button(action: { player.pause() }) {
                                Label("Pause", systemImage: "pause.fill")
                            }
                        }
                    } else {
                        Text("Pick a local video to enable playback and overlays.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let overlay {
                        DisclosureGroup("Overlay meta") {
                            Text("FPS: \(overlay.fps), Players: \(overlay.players.count), Tracks: \(overlay.tracks.count)")
                                .font(.footnote)
                        }
                    }
                }

                Section(header: Text("Format")) {
                    Text("Overlay JSON uses normalized coordinates and seconds-based timestamps. Include `fps`, `players`, `tracks`, and optional `events`. See sample JSON in the ZIP.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Video")
        }
        .fileImporter(isPresented: $showingVideoPicker, allowedContentTypes: [.movie]) { result in
            switch result {
            case .success(let url):
                // Security-scoped access
                _ = url.startAccessingSecurityScopedResource()
                self.player = AVPlayer(url: url)
                url.stopAccessingSecurityScopedResource()
            case .failure:
                break
            }
        }
        .fileImporter(isPresented: $showingOverlayPicker, allowedContentTypes: [UTType.json]) { result in
            guard case .success(let url) = result else { return }
            _ = url.startAccessingSecurityScopedResource()
            if let data = try? Data(contentsOf: url) {
                self.overlay = try? JSONDecoder().decode(TrackingOverlay.self, from: data)
            }
            url.stopAccessingSecurityScopedResource()
        }
    }
}

// MARK: - Web (SFSafariViewController) wrapper

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Overlay model

struct TrackingOverlay: Codable {
    struct PlayerDef: Codable, Identifiable {
        let id: Int
        let color: String? // Hex like "#ff0000"
        let label: String?
    }
    struct TrackPoint: Codable {
        let t: Double // seconds
        let x: Double // 0..1 normalised
        let y: Double // 0..1 normalised
    }
    struct Track: Codable, Identifiable {
        let id: Int
        let points: [TrackPoint]
        var identifiableId: Int? { id }
        var idValue: Int { id }
        var idString: String { String(id) }
    }
    let fps: Double
    let players: [PlayerDef]
    let tracks: [Track]
    let events: [Event]?
    struct Event: Codable {
        let t: Double
        let type: String
        let player_id: Int?
        let note: String?
    }
}

// MARK: - Overlay renderer

struct TrackingOverlayView: View {
    let player: AVPlayer
    let overlay: TrackingOverlay

    @State private var currentTime: Double = 0
    @State private var displayLink: CADisplayLink? = nil

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let t = currentTime
                for track in overlay.tracks {
                    if let p = point(at: t, for: track) {
                        let pos = CGPoint(x: p.x * size.width, y: p.y * size.height)
                        let r: CGFloat = 10
                        let rect = CGRect(x: pos.x - r, y: pos.y - r, width: 2*r, height: 2*r)
                        var path = Path(ellipseIn: rect)
                        var style = GraphicsContext.Shading.color(.red)
                        if let def = overlay.players.first(where: { $0.id == track.id }),
                           let hex = def.color, let uiColor = UIColor(hex: hex) {
                            style = .color(Color(uiColor))
                        }
                        context.fill(path, with: style)
                        // label
                        let label = overlay.players.first(where: { $0.id == track.id })?.label ?? "\(track.id)"
                        context.draw(Text(label).font(.system(size: 10)).foregroundColor(.white), at: pos)
                    }
                }
            }
            .onAppear { startObserving() }
            .onDisappear { stopObserving() }
        }
        .allowsHitTesting(false)
    }

    private func startObserving() {
        stopObserving()
        let link = CADisplayLink(target: DisplayLinkProxy { [weak player] in
            guard let item = player?.currentItem else { return }
            currentTime = item.currentTime().seconds
        }, selector: #selector(DisplayLinkProxy.tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopObserving() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func point(at t: Double, for track: TrackingOverlay.Track) -> (x: CGFloat, y: CGFloat)? {
        // nearest neighbor lookup (simple and fast)
        let pts = track.points
        if pts.isEmpty { return nil }
        var nearest = pts[0]
        var best = abs(pts[0].t - t)
        for p in pts {
            let d = abs(p.t - t)
            if d < best {
                best = d; nearest = p
            }
        }
        return (x: nearest.x, y: nearest.y)
    }
}

private class DisplayLinkProxy {
    let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
    @objc func tick() { action() }
}

// MARK: - Utilities

extension UIColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let val = Int(s, radix: 16) else { return nil }
        let r = CGFloat((val >> 16) & 0xff) / 255.0
        let g = CGFloat((val >> 8) & 0xff) / 255.0
        let b = CGFloat(val & 0xff) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
