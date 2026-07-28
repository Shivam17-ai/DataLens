import Foundation

// MARK: - Groq API Message Structure

struct GroqMessage: Codable, Equatable {
    let role: String // "system", "user", "assistant"
    let content: String
}

// MARK: - Groq API Error Types

enum GroqError: LocalizedError {
    case invalidApiKey
    case rateLimitExceeded
    case networkError(String)
    case parsingError(String)
    case serverError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidApiKey:
            return "Invalid API Key. Please check your Groq API key in settings."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please wait a moment before trying again."
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .parsingError(let msg):
            return "Failed to parse API response: \(msg)"
        case .serverError(let code, let msg):
            return "Server error (\(code)): \(msg)"
        }
    }
}

// MARK: - GroqService

/// Pure HTTP and Server-Sent Events (SSE) streaming client for Groq Cloud API
final class GroqService: NSObject, URLSessionDataDelegate {

    static let shared = GroqService()

    private let baseURL = "https://api.groq.com/openai/v1/chat/completions"
    private let defaultModel = "llama3-70b-8192"

    private override init() {
        super.init()
    }

    // MARK: - Non-Streaming Request (with Retries)

    func sendMessage(
        messages: [GroqMessage],
        systemPrompt: String,
        apiKey: String,
        model: String = "llama3-70b-8192",
        maxRetries: Int = 3
    ) async throws -> String {

        var payloadMessages = [GroqMessage(role: "system", content: systemPrompt)]
        payloadMessages.append(contentsOf: messages)

        let body: [String: Any] = [
            "model": model,
            "messages": payloadMessages.map { ["role": $0.role, "content": $0.content] },
            "temperature": 0.7,
            "max_tokens": 4096
        ]

        let requestData = try JSONSerialization.data(withJSONObject: body)

        var lastError: Error = GroqError.networkError("Unknown error")

        for attempt in 1...maxRetries {
            do {
                var request = URLRequest(url: URL(string: baseURL)!)
                request.httpMethod = "POST"
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 30
                request.httpBody = requestData

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GroqError.networkError("Invalid response type")
                }

                if httpResponse.statusCode == 401 {
                    throw GroqError.invalidApiKey
                } else if httpResponse.statusCode == 429 {
                    throw GroqError.rateLimitExceeded
                } else if !(200...299).contains(httpResponse.statusCode) {
                    let errBody = String(data: data, encoding: .utf8) ?? ""
                    throw GroqError.serverError(httpResponse.statusCode, errBody)
                }

                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let first = choices.first,
                   let message = first["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    return content
                } else {
                    throw GroqError.parsingError("Could not extract message content from JSON")
                }

            } catch let err as GroqError {
                if case .invalidApiKey = err { throw err }
                if case .rateLimitExceeded = err { throw err }
                lastError = err
            } catch {
                lastError = GroqError.networkError(error.localizedDescription)
            }

            if attempt < maxRetries {
                try await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000) // exponential delay
            }
        }

        throw lastError
    }

    // MARK: - Streaming SSE Request

    func streamMessage(
        messages: [GroqMessage],
        systemPrompt: String,
        apiKey: String,
        model: String = "llama3-70b-8192",
        onChunk: @escaping (String) -> Void
    ) async throws {

        var payloadMessages = [GroqMessage(role: "system", content: systemPrompt)]
        payloadMessages.append(contentsOf: messages)

        let body: [String: Any] = [
            "model": model,
            "messages": payloadMessages.map { ["role": $0.role, "content": $0.content] },
            "temperature": 0.7,
            "max_tokens": 4096,
            "stream": true
        ]

        let requestData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = requestData

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqError.networkError("Invalid response type")
        }

        if httpResponse.statusCode == 401 {
            throw GroqError.invalidApiKey
        } else if httpResponse.statusCode == 429 {
            throw GroqError.rateLimitExceeded
        } else if !(200...299).contains(httpResponse.statusCode) {
            throw GroqError.serverError(httpResponse.statusCode, "Streaming request failed")
        }

        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "data: [DONE]" { continue }

            if trimmed.hasPrefix("data: ") {
                let jsonString = String(trimmed.dropFirst(6))
                if let data = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let first = choices.first,
                   let delta = first["delta"] as? [String: Any],
                   let chunk = delta["content"] as? String {
                    onChunk(chunk)
                }
            }
        }
    }
}
