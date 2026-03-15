import SwiftUI
import WebKit

// MARK: - NotchBrowserView

struct NotchBrowserView: View {
    @AppStorage("browserHomepage") private var homepage = "https://www.youtube.com"
    @AppStorage("browserSearchEngine") private var searchEngine = "google"
    @AppStorage("browserMobileMode") private var mobileMode = true

    @State private var urlString: String = ""
    @State private var isLoading: Bool = false
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var pageTitle: String = ""
    @State private var loadProgress: Double = 0
    @State private var webViewCoordinator: BrowserWebViewCoordinator?
    @State private var isEditingURL: Bool = false

    let onPopOut: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            browserNavBar

            // Loading progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    if isLoading {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * loadProgress, height: 2)
                            .animation(.easeInOut(duration: 0.2), value: loadProgress)
                    }
                }
            }
            .frame(height: 2)

            BrowserWebView(
                urlString: $urlString,
                isLoading: $isLoading,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                pageTitle: $pageTitle,
                loadProgress: $loadProgress,
                coordinator: $webViewCoordinator,
                mobileMode: mobileMode,
                initialURL: homepage
            )
        }
    }

    private var searchURLTemplate: String {
        switch searchEngine {
        case "duckduckgo": return "https://duckduckgo.com/?q="
        case "bing": return "https://www.bing.com/search?q="
        case "youtube": return "https://m.youtube.com/results?search_query="
        default: return "https://www.google.com/search?q="
        }
    }

    private var browserNavBar: some View {
        HStack(spacing: 6) {
            // Back button
            Button(action: { webViewCoordinator?.goBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(canGoBack ? .white : .white.opacity(0.25))
            }
            .buttonStyle(.plain)
            .disabled(!canGoBack)

            // Forward button
            Button(action: { webViewCoordinator?.goForward() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(canGoForward ? .white : .white.opacity(0.25))
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)

            // Home button
            Button(action: {
                urlString = homepage
                webViewCoordinator?.load(url: homepage)
            }) {
                Image(systemName: "house.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Home")

            // URL field
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }

                if isEditingURL {
                    TextField("Search or URL...", text: $urlString)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                        .onSubmit {
                            loadURL()
                            isEditingURL = false
                        }
                } else {
                    Text(pageTitle.isEmpty ? (urlString.isEmpty ? "Search or URL..." : urlString) : pageTitle)
                        .font(.system(size: 11))
                        .foregroundStyle(pageTitle.isEmpty && urlString.isEmpty ? .white.opacity(0.4) : .white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isEditingURL = true
                        }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )

            // Refresh / Stop
            Button(action: {
                if isLoading { webViewCoordinator?.stopLoading() }
                else { webViewCoordinator?.reload() }
            }) {
                Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)

            // Pop out button
            if let onPopOut = onPopOut {
                Button(action: { onPopOut(urlString) }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func loadURL() {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            webViewCoordinator?.load(url: trimmed)
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            let fullURL = "https://\(trimmed)"
            urlString = fullURL
            webViewCoordinator?.load(url: fullURL)
        } else {
            let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            let searchURL = "\(searchURLTemplate)\(query)"
            urlString = searchURL
            webViewCoordinator?.load(url: searchURL)
        }
    }
}

// MARK: - BrowserWebView (NSViewRepresentable)

struct BrowserWebView: NSViewRepresentable {
    @Binding var urlString: String
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var pageTitle: String
    @Binding var loadProgress: Double
    @Binding var coordinator: BrowserWebViewCoordinator?

    var mobileMode: Bool
    var initialURL: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.autoresizingMask = [.width, .height]

        // Always use desktop Safari user agent — mobile YouTube player
        // doesn't work in macOS WKWebView (playback errors).
        // Desktop YouTube works perfectly and is responsive at small sizes.
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.setValue(false, forKey: "drawsBackground") // transparent bg

        context.coordinator.webView = webView

        // Observe estimatedProgress for loading bar
        context.coordinator.progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { webView, _ in
            DispatchQueue.main.async {
                self.loadProgress = webView.estimatedProgress
            }
        }

        // Load initial URL (use homepage from settings)
        if let url = URL(string: initialURL) {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Frame is managed by SwiftUI, no manual update needed
    }

    func makeCoordinator() -> BrowserWebViewCoordinator {
        let coord = BrowserWebViewCoordinator(self)
        DispatchQueue.main.async { self.coordinator = coord }
        return coord
    }
}

// MARK: - BrowserWebViewCoordinator

class BrowserWebViewCoordinator: NSObject, WKNavigationDelegate {
    var parent: BrowserWebView
    weak var webView: WKWebView?
    var progressObservation: NSKeyValueObservation?

    init(_ parent: BrowserWebView) {
        self.parent = parent
    }

    deinit {
        progressObservation?.invalidate()
    }

    func load(url: String) {
        guard let url = URL(string: url) else { return }
        webView?.load(URLRequest(url: url))
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }
    func stopLoading() { webView?.stopLoading() }

    nonisolated func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        DispatchQueue.main.async {
            self.parent.isLoading = true
            self.parent.loadProgress = 0
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.async {
            self.parent.isLoading = false
            self.parent.loadProgress = 1.0
            self.parent.canGoBack = webView.canGoBack
            self.parent.canGoForward = webView.canGoForward
            self.parent.pageTitle = webView.title ?? ""
            self.parent.urlString = webView.url?.absoluteString ?? self.parent.urlString
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async {
            self.parent.isLoading = false
            self.parent.loadProgress = 0
            self.parent.canGoBack = webView.canGoBack
            self.parent.canGoForward = webView.canGoForward
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async {
            self.parent.isLoading = false
            self.parent.loadProgress = 0
            self.parent.canGoBack = webView.canGoBack
            self.parent.canGoForward = webView.canGoForward
        }
    }

    // Allow navigation to new pages
    nonisolated func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
}

// MARK: - NotchInlineBrowserView

struct NotchInlineBrowserView: View {
    @ObservedObject var notchState: NotchState

    @State private var isHoveringChrome = false
    @State private var resizeStartWidth: CGFloat?
    @State private var isHoveringResizeHandle = false

    private let minWidth: CGFloat = 360
    private let maxWidth: CGFloat = 960
    private let aspectRatio: CGFloat = 16.0 / 9.0

    var body: some View {
        VStack(spacing: 8) {
            // Chrome bar
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.blue.opacity(0.95))
                        .frame(width: 8, height: 8)
                    Text("Browser")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Pinned")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer(minLength: 8)

                Button(action: closeBrowser) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 22, height: 22)
                        .background(.white.opacity(isHoveringChrome ? 0.12 : 0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Close browser")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            // Browser content
            NotchBrowserView(onPopOut: { url in
                // Pop out to floating video panel if it's a YouTube URL
                if let videoID = YouTubeURLParser.extractVideoID(from: url) {
                    VideoWindowManager.shared.showVideo(videoID: videoID)
                } else {
                    // For non-YouTube URLs, open in default browser
                    if let openURL = URL(string: url) {
                        NSWorkspace.shared.open(openURL)
                    }
                }
            })
            .frame(width: notchState.youtubePlayerWidth, height: notchState.youtubePlayerHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                resizeHandle
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.96), Color(red: 0.08, green: 0.08, blue: 0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.32), radius: 20, y: 10)
        .onHover { hovering in
            isHoveringChrome = hovering
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            notchState.isExpanded = true
        }
    }

    private var resizeHandle: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.black.opacity(isHoveringResizeHandle ? 0.88 : 0.72))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                .overlay(alignment: .topLeading) {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 12))
                        path.addLine(to: CGPoint(x: 12, y: 0))
                    }
                    .stroke(.white.opacity(0.28), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                .padding(.trailing, 8)
                .padding(.bottom, 8)
        }
        .frame(width: 56, height: 56, alignment: .bottomTrailing)
        .contentShape(Rectangle())
        .gesture(resizeGesture)
        .onHover { hovering in
            isHoveringResizeHandle = hovering
        }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if resizeStartWidth == nil {
                    resizeStartWidth = notchState.youtubePlayerWidth
                }

                let baseWidth = resizeStartWidth ?? notchState.youtubePlayerWidth
                let widthDelta = max(value.translation.width, value.translation.height * aspectRatio)
                let newWidth = min(max(baseWidth + widthDelta, minWidth), maxWidth)

                withAnimation(.interactiveSpring()) {
                    notchState.youtubePlayerWidth = newWidth
                    notchState.youtubePlayerHeight = newWidth / aspectRatio
                }
            }
            .onEnded { _ in
                resizeStartWidth = nil
            }
    }

    private func closeBrowser() {
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
            notchState.isShowingInlineBrowser = false
            notchState.activeDeckCard = .youtube
            if !notchState.isHovered {
                notchState.isExpanded = false
            }
        }
    }
}
