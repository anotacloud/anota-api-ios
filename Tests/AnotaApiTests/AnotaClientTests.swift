import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import AnotaApi

/// A `URLProtocol` that records the outgoing request and replies with a canned
/// response, so the client can be exercised without a live server.
final class StubURLProtocol: URLProtocol {
    struct Stub {
        var statusCode: Int
        var data: Data
        var headers: [String: String]
    }

    static var stub = Stub(statusCode: 200, data: Data("{}".utf8), headers: ["Content-Type": "application/json"])
    static var lastRequest: URLRequest?
    static var lastBody: Data?

    static func reset() {
        stub = Stub(statusCode: 200, data: Data("{}".utf8), headers: ["Content-Type": "application/json"])
        lastRequest = nil
        lastBody = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        StubURLProtocol.lastRequest = request
        if let body = request.httpBody {
            StubURLProtocol.lastBody = body
        } else if let stream = request.httpBodyStream {
            StubURLProtocol.lastBody = StubURLProtocol.readStream(stream)
        }

        let stub = StubURLProtocol.stub
        let response = HTTPURLResponse(url: request.url!, statusCode: stub.statusCode, httpVersion: "HTTP/1.1", headerFields: stub.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readStream(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

final class AnotaClientTests: XCTestCase {
    private func makeClient() -> AnotaClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        return AnotaClient(apiKey: "anota_sk_test", baseUrl: "https://anota.cloud/api/v1", session: session)
    }

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
    }

    func testListFormsSendsGetWithBearerHeader() async throws {
        StubURLProtocol.stub = .init(statusCode: 200, data: Data("[]".utf8), headers: ["Content-Type": "application/json"])
        _ = try await makeClient().listForms()

        let req = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(req.httpMethod, "GET")
        XCTAssertEqual(req.url?.absoluteString, "https://anota.cloud/api/v1/forms")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer anota_sk_test")
    }

    func testCreateSubmissionSendsJsonBody() async throws {
        _ = try await makeClient().createSubmission(formId: "f_1", answers: ["f_1": "hola"])

        let body = try XCTUnwrap(StubURLProtocol.lastBody)
        let root = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let answers = root?["answers"] as? [String: Any]
        XCTAssertEqual(answers?["f_1"] as? String, "hola")
    }

    func testProblemDetailsResponseRaisesAnotaApiError() async throws {
        StubURLProtocol.stub = .init(
            statusCode: 400,
            data: Data(#"{"detail":"Error: bad"}"#.utf8),
            headers: ["Content-Type": "application/problem+json"]
        )
        do {
            _ = try await makeClient().listForms()
            XCTFail("expected AnotaApiError to be thrown")
        } catch let error as AnotaApiError {
            XCTAssertEqual(error.status, 400)
            XCTAssertEqual(error.message, "Error: bad")
        }
    }

    func testListSubmissionsBuildsQueryString() async throws {
        StubURLProtocol.stub = .init(statusCode: 200, data: Data("[]".utf8), headers: ["Content-Type": "application/json"])
        _ = try await makeClient().listSubmissions(formId: "f_1", page: 2, pageSize: 10, status: "New")

        let req = try XCTUnwrap(StubURLProtocol.lastRequest)
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(req.url), resolvingAgainstBaseURL: false))
        var found: [String: String] = [:]
        for item in components.queryItems ?? [] {
            found[item.name] = item.value
        }
        XCTAssertEqual(found["page"], "2")
        XCTAssertEqual(found["pageSize"], "10")
        XCTAssertEqual(found["status"], "New")
        XCTAssertEqual(components.path, "/api/v1/forms/f_1/submissions")
    }
}
