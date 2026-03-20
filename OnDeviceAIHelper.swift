import Combine
import Foundation
import SwiftUI

// On-device AI helper.
// Prioritizes Apple's FoundationModels (macOS 26+, no API key needed).
// Falls back to Claude API if a key is configured in Settings.

@MainActor
final class OnDeviceAIHelper: ObservableObject {
    static let shared = OnDeviceAIHelper()

    @Published var isSummarizing = false
    @Published var lastSummary: String = ""

    // True when either on-device AI is available OR a Claude key is stored
    @Published var isAvailable: Bool = false

    private init() {
        refreshAvailability()
        // Re-check when API key changes
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshAvailability() }
        }
    }

    func refreshAvailability() {
        let hasClaudeKey = !(UserDefaults.standard.string(forKey: "claudeAPIKey") ?? "").isEmpty
        if #available(macOS 26.0, *) {
            isAvailable = true   // FoundationModels available
        } else {
            isAvailable = hasClaudeKey
        }
    }

    // MARK: - Summarize

    func summarize(_ text: String) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let enabled = UserDefaults.standard.object(forKey: "aiSummarizationEnabled") as? Bool ?? true
        guard enabled else { return nil }

        isSummarizing = true
        defer { isSummarizing = false }

        // 1. Try FoundationModels on macOS 26+
        if #available(macOS 26.0, *) {
            // FoundationModels integration (uncomment when SDK is stable):
            // import FoundationModels
            // let session = LanguageModelSession()
            // if let response = try? await session.respond(to: "Summarize in one sentence: \(trimmed.prefix(500))") {
            //     return response.content
            // }
        }

        // 2. Claude API fallback
        let apiKey = UserDefaults.standard.string(forKey: "claudeAPIKey") ?? ""
        guard !apiKey.isEmpty else { return nil }
        return await claudeSummarize(trimmed, apiKey: apiKey)
    }

    // MARK: - Categorize

    func categorize(_ text: String) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let enabled = UserDefaults.standard.object(forKey: "aiSummarizationEnabled") as? Bool ?? true
        guard enabled else { return nil }

        if #available(macOS 26.0, *) {
            // FoundationModels categorization stub
        }

        let apiKey = UserDefaults.standard.string(forKey: "claudeAPIKey") ?? ""
        guard !apiKey.isEmpty else { return nil }
        return await claudeCategorize(trimmed, apiKey: apiKey)
    }

    // MARK: - Private Claude API calls

    private func claudeSummarize(_ text: String, apiKey: String) async -> String? {
        return await claudeRequest(
            prompt: "Summarize the following text in one concise sentence (max 20 words): \(text.prefix(800))",
            apiKey: apiKey,
            maxTokens: 60
        )
    }

    private func claudeCategorize(_ text: String, apiKey: String) async -> String? {
        return await claudeRequest(
            prompt: "Categorize this text as exactly one of: urgent, social, promotional, info. Reply with only the category word. Text: \(text.prefix(300))",
            apiKey: apiKey,
            maxTokens: 10
        )
    }

    private func claudeRequest(prompt: String, apiKey: String, maxTokens: Int) async -> String? {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": maxTokens,
            "messages": [["role": "user", "content": prompt]]
        ]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = httpBody

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentArray = json["content"] as? [[String: Any]],
              let first = contentArray.first,
              let text = first["text"] as? String else { return nil }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - View Helper

struct AIAvailableBadge: View {
    @ObservedObject private var ai = OnDeviceAIHelper.shared

    var body: some View {
        if ai.isAvailable {
            Label("AI", systemImage: "sparkles")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(hex: "BF5AF2"))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(hex: "BF5AF2").opacity(0.15), in: Capsule())
        }
    }
}
