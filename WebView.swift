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
