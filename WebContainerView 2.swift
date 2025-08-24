
import SwiftUI
import WebKit
import SafariServices

struct WebContainerView: View {
    @AppStorage("baseURL") private var baseURL: String = ""
    let viewName: String

    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = true
    @State private var progress: Double = 0.0
    @State private var webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())

    private func composedURL() -> URL? {
        guard let base = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)
        else { return nil }
        var items = comps.queryItems ?? []
        items.append(URLQueryItem(name: "view", value: viewName))
        comps.queryItems = items
        return comps.url
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .padding(.vertical, 2)
            }

            WebViewRepresentable(webView: $webView,
                                 onStateChange: { back, forward, loading, prog in
                                     self.canGoBack = back
                                     self.canGoForward = forward
                                     self.isLoading = loading
                                     self.progress = prog
                                 })
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button(action: { webView.goBack() }) {
                    Image(systemName: "chevron.backward")
                }.disabled(!canGoBack)

                Button(action: { webView.reload() }) {
                    Image(systemName: "arrow.clockwise")
                }

                Button(action: { webView.goForward() }) {
                    Image(systemName: "chevron.forward")
                }.disabled(!canGoForward)

                Spacer()

                Button(action: openInSafari) {
                    Image(systemName: "safari")
                }.disabled(webView.url == nil)
            }
        }
        .onAppear {
            configure(webView: webView)
            if let url = composedURL() {
                webView.load(URLRequest(url: url))
            }
        }
        .navigationTitle(viewName.capitalized)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func configure(webView: WKWebView) {
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "RugbyCoachKit/1.0"
        // Add pull-to-refresh
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(handleRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh
    }

    @objc private func handleRefresh(_ sender: UIRefreshControl) {
        webView.reload()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            sender.endRefreshing()
        }
    }

    private func openInSafari() {
        guard let url = webView.url else { return }
        UIApplication.shared.open(url)
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    @Binding var webView: WKWebView

    let onStateChange: (_ canGoBack: Bool, _ canGoForward: Bool, _ isLoading: Bool, _ progress: Double) -> Void

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self, onStateChange: onStateChange)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: WebViewRepresentable
        let onStateChange: (_ canGoBack: Bool, _ canGoForward: Bool, _ isLoading: Bool, _ progress: Double) -> Void

        init(_ parent: WebViewRepresentable, onStateChange: @escaping (_ canGoBack: Bool, _ canGoForward: Bool, _ isLoading: Bool, _ progress: Double) -> Void) {
            self.parent = parent
            self.onStateChange = onStateChange
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == "estimatedProgress",
               let webView = object as? WKWebView {
                onStateChange(webView.canGoBack, webView.canGoForward, webView.isLoading, webView.estimatedProgress)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            onStateChange(webView.canGoBack, webView.canGoForward, true, webView.estimatedProgress)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onStateChange(webView.canGoBack, webView.canGoForward, false, 1.0)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onStateChange(webView.canGoBack, webView.canGoForward, false, webView.estimatedProgress)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Open target=_blank in current webview
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
