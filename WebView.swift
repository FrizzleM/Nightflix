import SwiftUI
import WebKit

/// SwiftUI wrapper around WKWebView so the player stays integrated in the app.
struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    /// Called on the main thread whenever the embedded player reports a progress event.
    var onPlayerEvent: ((VidkingPlayerEvent) -> Void)? = nil

    /// Name of the JS message channel and the injected listener script.
    private static let messageHandlerName = "nightflixPlayerEvents"

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, errorMessage: $errorMessage, onPlayerEvent: onPlayerEvent)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let contentController = configuration.userContentController
        contentController.add(
            WeakScriptMessageHandler(context.coordinator),
            name: Self.messageHandlerName
        )
        contentController.addUserScript(
            WKUserScript(
                source: Self.progressBridgeScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        contentController.addUserScript(
            WKUserScript(
                source: Self.resumeLoopGuardScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        context.coordinator.load(url, in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onPlayerEvent = onPlayerEvent
        context.coordinator.load(url, in: webView)
    }

    /// Listens for the Vidking player's `postMessage` events on the parent window and
    /// forwards `PLAYER_EVENT` payloads to the native bridge. Mirrors the integration
    /// snippet from the Vidking docs.
    private static let progressBridgeScript = """
    (function () {
        function forward(raw) {
            try {
                var payload = raw;
                if (typeof raw === "string") {
                    try { payload = JSON.parse(raw); } catch (e) { return; }
                }
                if (!payload || payload.type !== "PLAYER_EVENT") { return; }
                window.webkit.messageHandlers.\(messageHandlerName).postMessage(payload);
            } catch (e) {}
        }
        window.addEventListener("message", function (event) { forward(event.data); }, false);
    })();
    """

    /// Works around a Vidking player bug: when the embed is opened with a `progress`
    /// (resume) start time, the player re-applies that exact seek on *every* playback
    /// tick, which snaps the video back and makes it loop on the resume second.
    ///
    /// We intercept the `<video>` element's `currentTime` setter and only honor a seek
    /// to the resume value when it's a genuine (re)start:
    ///   * the first resume after load, and
    ///   * after a real jump back toward the start — e.g. iOS reloads the HLS media and
    ///     resets to 0:00 when handing off to the native full-screen player.
    /// The per-tick repeats (which arrive while playback is already at/after the resume
    /// point) are ignored, so playback runs forward normally. Because those repeats are
    /// suppressed, `currentTime` only ever falls below the furthest-watched mark on a
    /// real reload, which is exactly how we tell the two cases apart. Ordinary playback,
    /// scrubbing and ±10s skips are untouched — they never seek to the exact resume value.
    private static let resumeLoopGuardScript = """
    (function () {
        var params = new URLSearchParams(window.location.search);
        var raw = params.get("progress");
        var resumeTime = raw ? parseFloat(raw) : NaN;
        if (!(resumeTime > 0)) { return; }

        var proto = window.HTMLMediaElement && HTMLMediaElement.prototype;
        var descriptor = proto && Object.getOwnPropertyDescriptor(proto, "currentTime");
        if (!descriptor || !descriptor.get || !descriptor.set) { return; }

        function guard(video) {
            if (!video || video.__nightflixResumeGuarded) { return; }
            video.__nightflixResumeGuarded = true;

            var furthest = 0;        // high-water mark of real playback progress
            var everResumed = false; // has the initial resume seek been applied?

            video.addEventListener("timeupdate", function () {
                var t = descriptor.get.call(video);
                if (t > furthest) { furthest = t; }
            });

            Object.defineProperty(video, "currentTime", {
                configurable: true,
                get: function () { return descriptor.get.call(this); },
                set: function (value) {
                    if (value === resumeTime) {
                        var current = descriptor.get.call(this);
                        if (!everResumed) {
                            everResumed = true;
                            descriptor.set.call(this, Math.max(resumeTime, furthest));
                            return;
                        }
                        // Only re-seek after a real jump back toward the start
                        // (e.g. native full-screen reload), not the buggy repeats.
                        if (current < furthest - 5) {
                            descriptor.set.call(this, Math.max(resumeTime, furthest));
                        }
                        return;
                    }
                    descriptor.set.call(this, value);
                }
            });
        }

        function guardAll() {
            var videos = document.getElementsByTagName("video");
            for (var i = 0; i < videos.length; i++) { guard(videos[i]); }
        }

        guardAll();
        if (window.MutationObserver) {
            new MutationObserver(guardAll).observe(document.documentElement, {
                childList: true,
                subtree: true
            });
        } else {
            var interval = setInterval(guardAll, 200);
            setTimeout(function () { clearInterval(interval); }, 30000);
        }
    })();
    """

    /// Breaks the WKWebView → configuration → userContentController → handler retain
    /// cycle by holding the real handler weakly.
    final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
        weak var delegate: WKScriptMessageHandler?

        init(_ delegate: WKScriptMessageHandler) {
            self.delegate = delegate
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            delegate?.userContentController(userContentController, didReceive: message)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        @Binding private var isLoading: Bool
        @Binding private var errorMessage: String?
        var onPlayerEvent: ((VidkingPlayerEvent) -> Void)?
        private var requestedURL: URL?

        init(
            isLoading: Binding<Bool>,
            errorMessage: Binding<String?>,
            onPlayerEvent: ((VidkingPlayerEvent) -> Void)?
        ) {
            _isLoading = isLoading
            _errorMessage = errorMessage
            self.onPlayerEvent = onPlayerEvent
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let event = VidkingPlayerEvent(payload: message.body) else { return }

            DispatchQueue.main.async { [weak self] in
                self?.onPlayerEvent?(event)
            }
        }

        func load(_ url: URL, in webView: WKWebView) {
            guard requestedURL != url else { return }

            requestedURL = url
            updateState(isLoading: true, errorMessage: nil)
            webView.load(URLRequest(url: url))
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            updateState(isLoading: true, errorMessage: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            updateState(isLoading: false)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.targetFrame == nil {
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleLoadFailure(error, in: webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handleLoadFailure(error, in: webView)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            return nil
        }

        private func handleLoadFailure(_ error: Error, in webView: WKWebView) {
            guard !error.isNonFatalWebKitNavigationFailure else {
                updateState(isLoading: webView.isLoading)
                return
            }

            updateState(isLoading: false, errorMessage: error.localizedDescription)
        }

        private func updateState(isLoading newIsLoading: Bool? = nil, errorMessage newErrorMessage: String? = nil) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                if let newIsLoading {
                    self.isLoading = newIsLoading
                }

                self.errorMessage = newErrorMessage
            }
        }
    }
}

private extension Error {
    var isNonFatalWebKitNavigationFailure: Bool {
        let error = self as NSError

        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            return true
        }

        return error.domain == "WebKitErrorDomain" && error.code == 102
    }
}
