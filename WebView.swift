import SwiftUI
import WebKit

/// SwiftUI wrapper around WKWebView so the player stays integrated in the app.
struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, errorMessage: $errorMessage)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

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
        context.coordinator.load(url, in: webView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        @Binding private var isLoading: Bool
        @Binding private var errorMessage: String?
        private var requestedURL: URL?

        init(isLoading: Binding<Bool>, errorMessage: Binding<String?>) {
            _isLoading = isLoading
            _errorMessage = errorMessage
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
