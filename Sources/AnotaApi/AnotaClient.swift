import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Error thrown for any non-2xx response from the anota API.
///
/// `status` is the HTTP status code; `message` is the server's message, taken
/// from the ASP.NET problem-details `detail` property (falling back to `title`,
/// then the raw response body). Network failures surface as the platform's
/// native `URLError`, not this type.
public struct AnotaApiError: Error {
    public let status: Int
    public let message: String

    public init(status: Int, message: String) {
        self.status = status
        self.message = message
    }
}

/// A thin, dependency-free client over the anota REST API.
///
/// Every method returns the server's JSON parsed by `JSONSerialization` into a
/// generic value (`[String: Any]`, `[Any]`, or `NSNull` for empty bodies).
public final class AnotaClient {
    private let apiKey: String
    private let baseUrl: String
    private let session: URLSession

    /// - Parameters:
    ///   - apiKey: an API key from https://anota.cloud/api-keys (looks like `anota_sk_…`).
    ///   - baseUrl: override the API base URL (trailing slashes are trimmed).
    ///   - session: inject a `URLSession` (used by tests); defaults to `.shared`.
    public init(apiKey: String, baseUrl: String = "https://anota.cloud/api/v1", session: URLSession = .shared) {
        precondition(!apiKey.isEmpty, "apiKey is required (create one at https://anota.cloud/api-keys)")
        self.apiKey = apiKey
        var trimmed = baseUrl
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        self.baseUrl = trimmed
        self.session = session
    }

    private func request(
        _ method: String,
        _ path: String,
        body: [String: Any]? = nil,
        query: [String: String?] = [:]
    ) async throws -> Any {
        guard var components = URLComponents(string: baseUrl + path) else {
            throw AnotaApiError(status: 0, message: "Invalid URL: \(baseUrl + path)")
        }
        let items = query.compactMap { key, value in value.map { URLQueryItem(name: key, value: $0) } }
        if !items.isEmpty { components.queryItems = items }
        guard let url = components.url else {
            throw AnotaApiError(status: 0, message: "Invalid URL: \(baseUrl + path)")
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if let body = body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw AnotaApiError(status: 0, message: "No HTTP response")
        }
        if !(200...299).contains(http.statusCode) {
            var message = String(data: data, encoding: .utf8) ?? ""
            if let problem = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let detail = problem["detail"] as? String {
                    message = detail
                } else if let title = problem["title"] as? String {
                    message = title
                }
            }
            throw AnotaApiError(status: http.statusCode, message: message)
        }
        if data.isEmpty { return NSNull() }
        return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    /// Percent-encode a path segment, mirroring JavaScript's `encodeURIComponent`.
    private func escape(_ segment: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.!~*'()")
        return segment.addingPercentEncoding(withAllowedCharacters: allowed) ?? segment
    }

    // MARK: - Forms

    public func listForms() async throws -> Any {
        try await request("GET", "/forms")
    }

    public func createForm(title: String, fields: [[String: Any]], description: String? = nil) async throws -> Any {
        var body: [String: Any] = ["title": title, "fields": fields]
        if let description = description { body["description"] = description }
        return try await request("POST", "/forms", body: body)
    }

    public func getForm(formId: String) async throws -> Any {
        try await request("GET", "/forms/\(formId)")
    }

    public func addFields(formId: String, fields: [[String: Any]]) async throws -> Any {
        try await request("POST", "/forms/\(formId)/fields", body: ["fields": fields])
    }

    public func editField(formId: String, fieldId: String, field: [String: Any]) async throws -> Any {
        try await request("PATCH", "/forms/\(formId)/fields/\(escape(fieldId))", body: ["field": field])
    }

    public func deleteField(formId: String, fieldId: String) async throws -> Any {
        try await request("DELETE", "/forms/\(formId)/fields/\(escape(fieldId))")
    }

    public func publishForm(formId: String) async throws -> Any {
        try await request("POST", "/forms/\(formId)/publish")
    }

    public func renameForm(formId: String, title: String) async throws -> Any {
        try await request("PATCH", "/forms/\(formId)", body: ["title": title])
    }

    public func setPdfTemplate(formId: String, key: String) async throws -> Any {
        try await request("PUT", "/forms/\(formId)/pdf-template", body: ["key": key])
    }

    public func deleteForm(formId: String) async throws -> Any {
        try await request("DELETE", "/forms/\(formId)")
    }

    public func cloneForm(formId: String) async throws -> Any {
        try await request("POST", "/forms/\(formId)/clone")
    }

    // MARK: - Logic rules

    public func addLogicRules(formId: String, rules: [[String: Any]]) async throws -> Any {
        try await request("POST", "/forms/\(formId)/logic-rules", body: ["rules": rules])
    }

    public func editLogicRule(formId: String, ruleId: String, rule: [String: Any]) async throws -> Any {
        try await request("PUT", "/forms/\(formId)/logic-rules/\(escape(ruleId))", body: ["rule": rule])
    }

    public func deleteLogicRule(formId: String, ruleId: String) async throws -> Any {
        try await request("DELETE", "/forms/\(formId)/logic-rules/\(escape(ruleId))")
    }

    // MARK: - Submissions

    public func listSubmissions(formId: String, page: Int = 1, pageSize: Int = 25, status: String? = nil) async throws -> Any {
        try await request("GET", "/forms/\(formId)/submissions", query: [
            "page": String(page),
            "pageSize": String(pageSize),
            "status": status
        ])
    }

    public func getSubmission(submissionId: String) async throws -> Any {
        try await request("GET", "/submissions/\(submissionId)")
    }

    public func createSubmission(formId: String, answers: [String: Any]) async throws -> Any {
        try await request("POST", "/forms/\(formId)/submissions", body: ["answers": answers])
    }

    public func setSubmissionStatus(submissionId: String, status: String) async throws -> Any {
        try await request("PATCH", "/submissions/\(submissionId)/status", body: ["status": status])
    }

    public func deleteSubmission(submissionId: String) async throws -> Any {
        try await request("DELETE", "/submissions/\(submissionId)")
    }

    public func submissionStats(formId: String) async throws -> Any {
        try await request("GET", "/forms/\(formId)/stats")
    }

    // MARK: - Templates

    public func listTemplates(language: String = "es") async throws -> Any {
        try await request("GET", "/templates", query: ["language": language])
    }

    public func createFormFromTemplate(templateId: String) async throws -> Any {
        try await request("POST", "/forms/from-template/\(templateId)")
    }

    // MARK: - Webhooks

    public func listWebhooks(formId: String) async throws -> Any {
        try await request("GET", "/forms/\(formId)/webhooks")
    }

    public func addWebhook(formId: String, url: String) async throws -> Any {
        try await request("POST", "/forms/\(formId)/webhooks", body: ["url": url])
    }

    public func deleteWebhook(formId: String, webhookId: String) async throws -> Any {
        try await request("DELETE", "/forms/\(formId)/webhooks/\(webhookId)")
    }
}
