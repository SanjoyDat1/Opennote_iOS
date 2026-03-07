import Foundation

/// Executes code via Judge0 CE API. Supports Python, Java, C++.
enum CodeExecutionService {
    private static let baseURL = "https://ce.judge0.com"

    /// Judge0 language IDs
    enum LanguageId: Int {
        case python = 71
        case java = 62
        case cpp = 54

        init?(from language: String) {
            let normalized = language.lowercased()
            if normalized.contains("python") { self = .python }
            else if normalized.contains("java") { self = .java }
            else if normalized.contains("c++") || normalized.contains("cpp") { self = .cpp }
            else { return nil }
        }
    }

    struct ExecutionResult {
        let stdout: String
        let stderr: String
        let success: Bool
    }

    static func execute(language: String, code: String, stdin: String) async -> ExecutionResult {
        guard let langId = LanguageId(from: language) else {
            return ExecutionResult(stdout: "", stderr: "Unsupported language. Use Python, Java, or C++.", success: false)
        }
        guard let url = URL(string: "\(baseURL)/submissions?base64_encoded=false&wait=true") else {
            return ExecutionResult(stdout: "", stderr: "Invalid API URL", success: false)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "source_code": code,
            "language_id": langId.rawValue,
            "stdin": stdin
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return ExecutionResult(stdout: "", stderr: "Execution service unavailable. Try again later.", success: false)
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return ExecutionResult(stdout: "", stderr: "Invalid response", success: false)
            }
            let stdout = json["stdout"] as? String ?? ""
            var stderr = json["stderr"] as? String ?? ""
            let compileOutput = json["compile_output"] as? String ?? ""
            let status = json["status"] as? [String: Any]
            let statusId = status?["id"] as? Int ?? 0
            let success = statusId == 3
            if !success {
                let desc = status?["description"] as? String ?? ""
                if stderr.isEmpty && !compileOutput.isEmpty { stderr = compileOutput }
                else if stderr.isEmpty { stderr = desc }
            }
            return ExecutionResult(stdout: stdout, stderr: stderr, success: success)
        } catch {
            return ExecutionResult(stdout: "", stderr: error.localizedDescription, success: false)
        }
    }
}
