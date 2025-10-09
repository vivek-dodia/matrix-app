import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: String // "user" or "assistant"
    let content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: String, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    var isUser: Bool {
        return role == "user"
    }
}

struct ChatRequest: Codable {
    let message: String
    let metrics: String?
    let conversationHistory: [ConversationMessage]?

    struct ConversationMessage: Codable {
        let role: String
        let content: String
    }
}

struct ChatResponse: Codable {
    let message: String
    let usage: Usage?
    let model: String?

    struct Usage: Codable {
        let input_tokens: Int?
        let output_tokens: Int?

        enum CodingKeys: String, CodingKey {
            case input_tokens = "input_tokens"
            case output_tokens = "output_tokens"
        }
    }
}

enum ClaudeError: Error, LocalizedError {
    case invalidURL
    case noResponse
    case invalidResponse
    case networkError(Error)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid backend URL"
        case .noResponse:
            return "No response from server"
        case .invalidResponse:
            return "Invalid response format"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

class ClaudeService {
    static let shared = ClaudeService()

    // Backend URL configured for your Vercel deployment
    private var backendURL = "https://vercel-backend-vivekdodias-projects.vercel.app/api/chat"

    private init() {
        // Load backend URL from UserDefaults if set (allows override in settings)
        if let savedURL = UserDefaults.standard.string(forKey: "backendURL"), !savedURL.isEmpty {
            backendURL = savedURL
        }
    }

    func setBackendURL(_ url: String) {
        backendURL = url
        UserDefaults.standard.set(url, forKey: "backendURL")
    }

    func chat(
        message: String,
        metrics: String? = nil,
        conversationHistory: [ChatMessage] = []
    ) async throws -> String {
        guard let url = URL(string: backendURL) else {
            throw ClaudeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        // Build conversation history
        let history = conversationHistory.map { msg in
            ChatRequest.ConversationMessage(role: msg.role, content: msg.content)
        }

        let chatRequest = ChatRequest(
            message: message,
            metrics: metrics,
            conversationHistory: history.isEmpty ? nil : history
        )

        request.httpBody = try JSONEncoder().encode(chatRequest)

        Logger.shared.log("Sending message to Claude API...", level: .info)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClaudeError.noResponse
            }

            Logger.shared.log("Received response from Claude API (status: \(httpResponse.statusCode))", level: .info)

            if httpResponse.statusCode != 200 {
                if let errorText = String(data: data, encoding: .utf8) {
                    Logger.shared.log("API Error: \(errorText)", level: .error)
                    throw ClaudeError.serverError(errorText)
                }
                throw ClaudeError.serverError("HTTP \(httpResponse.statusCode)")
            }

            let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)

            if let usage = chatResponse.usage {
                Logger.shared.log("Token usage - Input: \(usage.input_tokens ?? 0), Output: \(usage.output_tokens ?? 0)", level: .info)
            }

            return chatResponse.message

        } catch let error as ClaudeError {
            throw error
        } catch {
            Logger.shared.log("Network error: \(error)", level: .error)
            throw ClaudeError.networkError(error)
        }
    }
}
