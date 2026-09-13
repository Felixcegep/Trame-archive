import XCTest
@testable import GymTracker

@MainActor
final class GoogleDriveAPIClientTests: XCTestCase {
    private var tokenStore: GoogleDriveTokenStore!
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        GoogleDriveURLProtocolStub.reset()
        tokenStore = GoogleDriveTokenStore(
            service: "felix.GymTracker.googleDriveOAuth.apiTests.\(UUID().uuidString)",
            account: "credentials"
        )
        tokenStore.delete()
        try? tokenStore.save(
            GoogleDriveCredentials(
                accessToken: "test-access",
                refreshToken: "test-refresh",
                expiresAt: Date.distantFuture,
                tokenType: "Bearer",
                accountEmail: "user@example.com"
            )
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GoogleDriveURLProtocolStub.self]
        session = URLSession(configuration: configuration)
    }

    override func tearDown() {
        GoogleDriveURLProtocolStub.reset()
        tokenStore.delete()
        tokenStore = nil
        session = nil
        super.tearDown()
    }

    func testFindBackupFileParsesFirstFile() async throws {
        GoogleDriveURLProtocolStub.handler = { request in
            XCTAssertTrue(request.url?.absoluteString.contains("/drive/v3/files") == true)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access")
            let body = Data(
                #"{"files":[{"id":"file-1","name":"TrameBackup.json","md5Checksum":"abc123"}]}"#.utf8
            )
            return (200, body)
        }
        let client = makeClient()
        let file = try await client.findBackupFile()
        XCTAssertEqual(file?.id, "file-1")
        XCTAssertEqual(file?.name, "TrameBackup.json")
        XCTAssertEqual(file?.md5Checksum, "abc123")
    }

    func testDownloadFileReturnsBody() async throws {
        let payload = Data("backup-body".utf8)
        GoogleDriveURLProtocolStub.handler = { request in
            XCTAssertTrue(request.url?.absoluteString.contains("alt=media") == true)
            XCTAssertTrue(request.url?.absoluteString.contains("/files/file-1") == true)
            return (200, payload)
        }
        let client = makeClient()
        let data = try await client.downloadFile(id: "file-1")
        XCTAssertEqual(data, payload)
    }

    func testUnauthorizedStatusThrowsLocalizedError() async {
        GoogleDriveURLProtocolStub.handler = { _ in
            (401, Data(#"{"error":{"message":"Invalid Credentials"}}"#.utf8))
        }
        let client = makeClient()
        do {
            _ = try await client.downloadFile(id: "file-1")
            XCTFail("Expected 401 to throw")
        } catch GoogleDriveAPIError.unauthorized {
            let description = GoogleDriveAPIError.unauthorized.errorDescription
            XCTAssertEqual(description, "Link Google Drive again to continue.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeClient() -> GoogleDriveAPIClient {
        let oauth = GoogleDriveOAuthClient(tokenStore: tokenStore, session: session)
        return GoogleDriveAPIClient(oauth: oauth, session: session)
    }
}

private final class GoogleDriveURLProtocolStub: URLProtocol {
    private static let lock = NSLock()
    private static var _handler: (@Sendable (URLRequest) -> (Int, Data))?
    private static var _requests: [URLRequest] = []

    static var handler: (@Sendable (URLRequest) -> (Int, Data))? {
        get { lock.withLock { _handler } }
        set { lock.withLock { _handler = newValue } }
    }

    static var requests: [URLRequest] {
        lock.withLock { _requests }
    }

    static func reset() {
        lock.withLock {
            _handler = nil
            _requests = []
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let handler: (@Sendable (URLRequest) -> (Int, Data))?
        Self.lock.lock()
        Self._requests.append(request)
        handler = Self._handler
        Self.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let (status, data) = handler(request)
        let url = request.url ?? URL(string: "https://www.googleapis.com/")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
