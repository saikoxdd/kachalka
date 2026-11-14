import SwiftUI
import WebKit
import UIKit
import UserNotifications
import AudioToolbox

// Качалка - нативная оболочка. Весь интерфейс и логика в index.html (лежит внутри приложения, интернет не нужен).
// Данные хранятся в файле Documents/kachalka-store.json - он попадает в резервную копию iCloud.

private let bgColor = UIColor(red: 14/255, green: 15/255, blue: 17/255, alpha: 1)

struct ContentView: View {
    var body: some View {
        GymWebView()
            .ignoresSafeArea()
            .background(Color(bgColor))
            .preferredColorScheme(.dark)
    }
}

// MARK: - Хранилище на телефоне

final class GymStore {
    static let shared = GymStore()
    private(set) var data: [String: String] = [:]
    private let fileURL: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("kachalka-store.json")

    init() {
        if let raw = try? Data(contentsOf: fileURL),
           let obj = try? JSONSerialization.jsonObject(with: raw) as? [String: String] {
            data = obj
        }
    }

    func set(_ key: String, _ value: String?) {
        if let value { data[key] = value } else { data.removeValue(forKey: key) }
        if let raw = try? JSONSerialization.data(withJSONObject: data) {
            try? raw.write(to: fileURL, options: .atomic)
        }
    }

    var json: String {
        guard let raw = try? JSONSerialization.data(withJSONObject: data),
              let str = String(data: raw, encoding: .utf8) else { return "{}" }
        return str
    }
}

// MARK: - WebView

struct GymWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let content = WKUserContentController()
        let boot = "window.__nativeStore = \(GymStore.shared.json);"
        content.addUserScript(WKUserScript(source: boot, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        for name in ["store", "haptic", "share", "notify", "notifyCancel", "sound", "awake", "live"] {
            content.add(context.coordinator, name: name)
        }

        let config = WKWebViewConfiguration()
        config.userContentController = content

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = bgColor
        webView.scrollView.backgroundColor = bgColor
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.webView = webView

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler, WKUIDelegate {
        weak var webView: WKWebView?

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "store":
                guard let body = message.body as? [String: Any], let key = body["k"] as? String else { return }
                GymStore.shared.set(key, body["v"] as? String)
            case "haptic":
                if (message.body as? String) == "ok" {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            case "share":
                if let text = message.body as? String { shareBackup(text) }
            case "notify":
                // уведомление об окончании отдыха - сработает, даже если приложение свёрнуто
                guard let body = message.body as? [String: Any], let sec = body["sec"] as? Double, sec >= 1 else { return }
                let text = (body["body"] as? String) ?? "Пора на следующий подход"
                let center = UNUserNotificationCenter.current()
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    guard granted else { return }
                    let content = UNMutableNotificationContent()
                    content.title = "Отдых окончен"
                    content.body = text
                    content.sound = .default
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: sec, repeats: false)
                    center.removePendingNotificationRequests(withIdentifiers: ["rest"])
                    center.add(UNNotificationRequest(identifier: "rest", content: content, trigger: trigger))
                }
            case "notifyCancel":
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest"])
            case "sound":
                AudioServicesPlaySystemSound(1005)
            case "live":
                // Live Activity: секундомер тренировки и отсчёт отдыха на Dynamic Island
                if #available(iOS 16.2, *) { LiveWorkout.handle(message.body) }
            case "awake":
                // во время тренировки экран не гаснет
                UIApplication.shared.isIdleTimerDisabled = (message.body as? Bool) ?? false
            default:
                break
            }
        }

        private func topController() -> UIViewController? {
            var top = webView?.window?.rootViewController
            while let next = top?.presentedViewController { top = next }
            return top
        }

        private func shareBackup(_ text: String) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("kachalka-\(formatter.string(from: Date())).json")
            try? text.write(to: url, atomically: true, encoding: .utf8)
            guard let top = topController() else { return }
            let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            sheet.popoverPresentationController?.sourceView = webView
            top.present(sheet, animated: true)
        }

        // confirm() из JS - нативный диалог (без этого WKWebView молча отвечает "нет")
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            guard let top = topController() else { completionHandler(false); return }
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "Да", style: .destructive) { _ in completionHandler(true) })
            top.present(alert, animated: true)
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            guard let top = topController() else { completionHandler(); return }
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
            top.present(alert, animated: true)
        }
    }
}
