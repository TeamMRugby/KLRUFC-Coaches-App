
import SwiftUI

struct RootView: View {
    @AppStorage("baseURL") private var baseURL: String = ""

    var body: some View {
        TabView {
            WebContainerView(viewName: "dashboard")
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.doc.horizontal")
                }

            WebContainerView(viewName: "availability")
                .tabItem {
                    Label("Availability", systemImage: "person.3.sequence")
                }

            WebContainerView(viewName: "teamsheet")
                .tabItem {
                    Label("Teamsheet", systemImage: "list.bullet.rectangle")
                }

            WebContainerView(viewName: "pitch")
                .tabItem {
                    Label("Pitch", systemImage: "rectangle.3.group.bubble.left")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onAppear {
            // First run helper: open Settings if no URL saved yet
            if baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // No-op: user can tap Settings. You can also present a modal here if desired.
            }
        }
    }
}

#Preview {
    RootView()
}
