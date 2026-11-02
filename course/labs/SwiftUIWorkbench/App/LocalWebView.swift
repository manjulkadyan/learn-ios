import SwiftUI
import WebKit

struct WebCommand: Equatable {
    var id = 0
    var clear = false
}

struct LocalWebView: UIViewRepresentable {
    let document: Int
    let command: WebCommand
    @Binding var status: String
    func makeCoordinator() -> Coordinator { Coordinator(status: $status) }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(WeakScriptHandler(context.coordinator), name: "workbench")
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        context.coordinator.webView = view
        context.coordinator.lastCommand = command.id
        context.coordinator.load(document: document)
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.status = $status
        if context.coordinator.document != document { context.coordinator.load(document: document) }
        if context.coordinator.lastCommand != command.id {
            context.coordinator.lastCommand = command.id
            context.coordinator.changeCookies(clear: command.clear)
        }
    }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        coordinator.active = false
        coordinator.nonce = ""
        view.stopLoading()
        view.navigationDelegate = nil
        view.uiDelegate = nil
        view.configuration.userContentController.removeScriptMessageHandler(forName: "workbench")
        view.configuration.userContentController.removeAllUserScripts()
        coordinator.webView = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var status: Binding<String>
        weak var webView: WKWebView?
        var document = -1
        var lastCommand = 0
        var nonce = ""
        var active = true
        init(status: Binding<String>) { self.status = status }
        func load(document: Int) {
            guard let webView else { return }
            self.document = document
            nonce = UUID().uuidString
            let scripts = webView.configuration.userContentController
            scripts.removeAllUserScripts()
            scripts.addUserScript(WKUserScript(source: "window.workbenchAck = function() { window.webkit.messageHandlers.workbench.postMessage({action: 'ack', nonce: '\(nonce)'}); };",
                injectionTime: .atDocumentEnd, forMainFrameOnly: true))
            webView.loadHTMLString("""
                <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
                <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'none'; img-src 'none'">
                <style>body { font: -apple-system-body; padding: 16px; } button { font: inherit; padding: 12px; }</style></head>
                <body><p>Local synthetic document \(document)</p><button onclick="window.workbenchAck()">Acknowledge locally</button>
                <p>No remote resources, requests, provider, or native command evaluator.</p></body></html>
                """, baseURL: nil)
        }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Only our loadHTMLString about:blank document. No popups, schemes, or remote navigation.
            let local = action.request.url?.absoluteString == "about:blank"
            decisionHandler(local && action.targetFrame?.isMainFrame == true ? .allow : .cancel)
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard active, message.webView === webView, message.frameInfo.isMainFrame,
                  message.frameInfo.securityOrigin.host.isEmpty,
                  webView?.url?.absoluteString == "about:blank",
                  message.name == "workbench", let body = message.body as? [String: String],
                  body.count == 2, body["action"] == "ack", body["nonce"] == nonce else { return }
            status.wrappedValue = "Accepted one narrow message from the current local document"
        }
        func changeCookies(clear: Bool) {
            guard let webView else { return }
            let ticket = nonce
            let commandTicket = lastCommand
            let store = webView.configuration.websiteDataStore.httpCookieStore
            if clear {
                store.getAllCookies { [weak self] cookies in
                    guard let self, self.active, self.nonce == ticket, self.lastCommand == commandTicket else { return }
                    let group = DispatchGroup()
                    for cookie in cookies { group.enter(); store.delete(cookie) { group.leave() } }
                    group.notify(queue: .main) { [weak self] in
                        guard let self, self.active, self.nonce == ticket, self.lastCommand == commandTicket else { return }
                        self.status.wrappedValue = "All cookies removed from this ephemeral web store"
                    }
                }
            } else if let cookie = HTTPCookie(properties: [.name: "fixture", .value: "synthetic", .domain: "workbench.invalid",
                                                          .path: "/", .secure: "TRUE"]) {
                store.setCookie(cookie) { [weak self] in
                    guard let self, self.active, self.nonce == ticket, self.lastCommand == commandTicket else { return }
                    self.status.wrappedValue = "Synthetic cookie installed after completion; no navigation follows"
                }
            }
        }
    }
}

private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
