import SwiftUI
import WebKit

/// SwiftUI wrapper around WKWebView so the provider's player stays integrated in the app.
struct WebView: UIViewRepresentable {
    let url: URL
    /// Bump to force a fresh load of `url` (e.g. a "Try Again" button).
    var reloadToken: Int = 0
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    /// Called on the main thread for every message the player page sends.
    var onMessage: ((PlayerBridgeMessage) -> Void)? = nil

    /// Name of the JS message channel used by the injected bridge script.
    private static let messageHandlerName = "nightflixPlayerEvents"

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, errorMessage: $errorMessage, onMessage: onMessage)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        // Present as Mobile Safari so providers serve their regular mobile player.
        configuration.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"

        let contentController = configuration.userContentController
        contentController.add(
            WeakScriptMessageHandler(context.coordinator),
            name: Self.messageHandlerName
        )
        contentController.addUserScript(
            WKUserScript(
                source: Self.tapShieldScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )
        contentController.addUserScript(
            WKUserScript(
                source: Self.playerBridgeScript,
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
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.backgroundColor = .black
        webView.scrollView.bounces = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.load(url, reloadToken: reloadToken, in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onMessage = onMessage
        context.coordinator.load(url, reloadToken: reloadToken, in: webView)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        // Stop audio immediately when the player closes instead of waiting for
        // the web view to be deallocated.
        webView.stopLoading()
        webView.pauseAllMediaPlayback(completionHandler: nil)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: messageHandlerName)
    }

    /// Keeps the player's controls responsive on pages that also carry pop-up ad scripts.
    ///
    /// Those scripts listen for every tap on `window` and `document` in the capture phase
    /// and cancel it (`preventDefault` + `stopImmediatePropagation`) before trying to open
    /// an ad window. Their frequency cap only starts once that window opens, and the app
    /// never opens it, so the cap never kicks in and every later tap is swallowed too: the
    /// fullscreen, settings and skip buttons stop responding.
    ///
    /// Tap and click listeners that scripts from *other* sites attach to the window or the
    /// document still run, but they can no longer cancel the tap or stop it from reaching
    /// the player. The page's own scripts (any host with the page's brand label, such as
    /// `vidfast` for `vidfast.vc`) are left alone. Runs in every frame, so an embedded
    /// server page gets the same protection against its own ad scripts.
    private static let tapShieldScript = #"""
    (function () {
        "use strict";
        if (!window.EventTarget || !window.Event || !window.WeakMap) { return; }

        var tapEvents = {
            touchstart: true, touchend: true, pointerdown: true, pointerup: true,
            mousedown: true, mouseup: true, click: true
        };
        var otherSite = "#other";

        // `vidfast` for vidfast.vc or www.vidfast.pro (matches WebView.brandLabel(of:)).
        function brandOf(host) {
            var labels = String(host || "").toLowerCase().split(".").filter(Boolean);
            if (labels.length === 0) { return null; }
            return labels.length >= 2 ? labels[labels.length - 2] : labels[0];
        }

        var ownBrand = brandOf(location.hostname);
        if (!ownBrand) { return; }

        // The site of the page script calling in, from the first stack frame with a web
        // URL (user scripts such as this one have none). Blob and data scripts count as
        // another site; null when no page script is on the stack.
        function callerBrand() {
            var stack;
            try { throw new Error(); } catch (error) { stack = String(error.stack || ""); }
            var lines = stack.split("\n");
            for (var i = 0; i < lines.length; i++) {
                if (/\b(?:blob|data):/.test(lines[i])) { return otherSite; }
                var match = /\bhttps?:\/\/([^\/\s:@]+)/.exec(lines[i]);
                if (match) { return brandOf(match[1]) || otherSite; }
            }
            return null;
        }

        function isPageWideTarget(target) {
            return target === window || target === document ||
                target === document.documentElement || (document.body !== null && target === document.body);
        }

        // Events a listener from another site is handling right now.
        var shielded = [];
        function isShielded(event) {
            return shielded.length > 0 && shielded.indexOf(event) !== -1;
        }

        var wrappers = new WeakMap();
        function shieldedListener(listener) {
            var wrapper = wrappers.get(listener);
            if (!wrapper) {
                wrapper = function (event) {
                    shielded.push(event);
                    try {
                        return typeof listener === "function"
                            ? listener.call(this, event)
                            : listener.handleEvent(event);
                    } finally {
                        shielded.pop();
                    }
                };
                wrappers.set(listener, wrapper);
            }
            return wrapper;
        }

        // Patched functions still print as native code, so scripts that look for patches
        // don't route around them.
        var nativeToString = Function.prototype.toString;
        var originals = new WeakMap();
        function disguise(replacement, original) {
            originals.set(replacement, original);
            return replacement;
        }

        var targetPrototype = EventTarget.prototype;
        var nativeAdd = targetPrototype.addEventListener;
        var nativeRemove = targetPrototype.removeEventListener;

        targetPrototype.addEventListener = disguise(function addEventListener(type, listener) {
            if (listener && tapEvents[type] === true && isPageWideTarget(this)) {
                var brand = callerBrand();
                if (brand !== null && brand !== ownBrand) {
                    var args = Array.prototype.slice.call(arguments);
                    args[1] = shieldedListener(listener);
                    return nativeAdd.apply(this, args);
                }
            }
            return nativeAdd.apply(this, arguments);
        }, nativeAdd);

        targetPrototype.removeEventListener = disguise(function removeEventListener(type, listener) {
            var wrapper = listener ? wrappers.get(listener) : undefined;
            if (wrapper) {
                var args = Array.prototype.slice.call(arguments);
                args[1] = wrapper;
                nativeRemove.apply(this, args);
            }
            return nativeRemove.apply(this, arguments);
        }, nativeRemove);

        var eventPrototype = Event.prototype;
        var nativePreventDefault = eventPrototype.preventDefault;
        var nativeStopPropagation = eventPrototype.stopPropagation;
        var nativeStopImmediatePropagation = eventPrototype.stopImmediatePropagation;

        eventPrototype.preventDefault = disguise(function preventDefault() {
            if (!isShielded(this)) { nativePreventDefault.call(this); }
        }, nativePreventDefault);
        eventPrototype.stopPropagation = disguise(function stopPropagation() {
            if (!isShielded(this)) { nativeStopPropagation.call(this); }
        }, nativeStopPropagation);
        eventPrototype.stopImmediatePropagation = disguise(function stopImmediatePropagation() {
            if (!isShielded(this)) { nativeStopImmediatePropagation.call(this); }
        }, nativeStopImmediatePropagation);

        // The legacy spellings: `returnValue = false` and `cancelBubble = true`.
        ["returnValue", "cancelBubble"].forEach(function (name) {
            var descriptor = Object.getOwnPropertyDescriptor(eventPrototype, name);
            if (!descriptor || !descriptor.set || !descriptor.configurable) { return; }
            var setter = descriptor.set;
            Object.defineProperty(eventPrototype, name, {
                configurable: true,
                enumerable: descriptor.enumerable,
                get: descriptor.get,
                set: disguise(function (value) {
                    if (isShielded(this)) { return; }
                    setter.call(this, value);
                }, setter)
            });
        });

        Function.prototype.toString = disguise(function toString() {
            return nativeToString.call(originals.get(this) || this);
        }, nativeToString);
    })();
    """#

    /// Forwards the player's `postMessage` traffic to native code. VidFast posts
    /// `PLAYER_EVENT` envelopes and a `status` object; Videasy-style providers post
    /// flat progress payloads (sometimes as JSON strings). Anything else sharing the
    /// window is ignored. Touches on the page are reported (throttled) so the app can
    /// show its own chrome together with the player's controls.
    private static let playerBridgeScript = """
    (function () {
        var handlers = window.webkit && window.webkit.messageHandlers;
        var channel = handlers && handlers.\(messageHandlerName);
        if (!channel) { return; }

        function post(payload) {
            try { channel.postMessage(payload); } catch (e) {}
        }

        function normalize(raw) {
            var payload = raw;
            if (typeof raw === "string") {
                try { payload = JSON.parse(raw); } catch (e) { return null; }
            }
            if (!payload || typeof payload !== "object") { return null; }
            return payload;
        }

        function shouldForward(payload) {
            if (payload.type === "PLAYER_EVENT") {
                return !!payload.data && typeof payload.data === "object";
            }
            if (payload.event === "status") { return true; }
            var hasPosition = payload.timestamp !== undefined || payload.progress !== undefined;
            var hasIdentity = payload.id !== undefined || payload.type !== undefined;
            return hasPosition && hasIdentity;
        }

        window.addEventListener("message", function (event) {
            var payload = normalize(event.data);
            if (!payload || !shouldForward(payload)) { return; }
            try { post(JSON.parse(JSON.stringify(payload))); } catch (e) {}
        }, false);

        var lastTouch = 0;
        function reportInteraction() {
            var now = Date.now();
            if (now - lastTouch < 350) { return; }
            lastTouch = now;
            post({ type: "NIGHTFLIX_INTERACTION" });
        }
        document.addEventListener("touchstart", reportInteraction, { capture: true, passive: true });
        document.addEventListener("mousedown", reportInteraction, { capture: true, passive: true });
    })();
    """

    /// Works around an embed-player quirk: when the embed is opened with a resume start
    /// time (`startAt`, or `progress` for Videasy-style providers), the player can
    /// re-apply that exact seek on *every* playback tick, which snaps the video back and
    /// makes it loop on the resume second.
    ///
    /// We intercept the `<video>` element's `currentTime` setter and only honor a seek
    /// to the resume value when it's a genuine (re)start:
    ///   * the first resume after load, and
    ///   * after a real jump back toward the start — e.g. iOS reloads the HLS media and
    ///     resets to 0:00 when handing off to the native full-screen player.
    /// The per-tick repeats (which arrive while playback is already at/after the resume
    /// point) are ignored, so playback runs forward normally. Ordinary playback,
    /// scrubbing and ±10s skips are untouched — they never seek to the exact resume value.
    private static let resumeLoopGuardScript = """
    (function () {
        var params = new URLSearchParams(window.location.search);
        var raw = params.get("startAt") || params.get("progress");
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
        var onMessage: ((PlayerBridgeMessage) -> Void)?
        private var requestedURL: URL?
        private var requestedReloadToken: Int?
        /// The provider's "brand" label (e.g. `vidfast` for vidfast.vc), so the page may
        /// hop between the provider's own mirror domains but not to unrelated sites.
        private var allowedBrandLabel: String?

        init(
            isLoading: Binding<Bool>,
            errorMessage: Binding<String?>,
            onMessage: ((PlayerBridgeMessage) -> Void)?
        ) {
            _isLoading = isLoading
            _errorMessage = errorMessage
            self.onMessage = onMessage
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let bridgeMessage = PlayerBridgeMessage(payload: message.body) else { return }

            DispatchQueue.main.async { [weak self] in
                self?.onMessage?(bridgeMessage)
            }
        }

        func load(_ url: URL, reloadToken: Int, in webView: WKWebView) {
            guard requestedURL != url || requestedReloadToken != reloadToken else { return }

            requestedURL = url
            requestedReloadToken = reloadToken
            allowedBrandLabel = Self.brandLabel(of: url.host)
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
            // Never open new windows or tabs (pop-ups / pop-unders).
            guard let targetFrame = navigationAction.targetFrame else {
                decisionHandler(.cancel)
                return
            }

            // Keep the top-level page on the provider: block redirects of the whole
            // player to other sites. Embedded frames (stream servers) stay free.
            if targetFrame.isMainFrame,
               let host = navigationAction.request.url?.host,
               let allowedBrandLabel,
               Self.brandLabel(of: host) != allowedBrandLabel {
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
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

        /// The label just left of the top-level domain: `vidfast` for `vidfast.vc` or
        /// `www.vidfast.pro`, `videasy` for `player.videasy.net`.
        private static func brandLabel(of host: String?) -> String? {
            guard let host else { return nil }

            let labels = host.lowercased().split(separator: ".")
            guard labels.count >= 2 else { return labels.first.map(String.init) }

            return String(labels[labels.count - 2])
        }
    }
}

private extension Error {
    var isNonFatalWebKitNavigationFailure: Bool {
        let error = self as NSError

        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            return true
        }

        // 102 = "Frame load interrupted" (e.g. a navigation we cancelled above).
        return error.domain == "WebKitErrorDomain" && error.code == 102
    }
}
