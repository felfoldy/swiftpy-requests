//
//  Request.swift
//  swiftpy-requests
//
//  Created by Tibor Felföldy on 2025-10-19.
//

import Foundation
import SwiftPy

/// The Response object, which contains a server's response to an HTTP request.
@Scriptable
@MainActor
final class Response {
    typealias object = PyAPI.Reference

    /// The HTTP status code of the receiver.
    var statusCode: Int?

    /// The URL the response was finally received from.
    var url: String?

    /// The response headers, keyed by their canonical name.
    var headers: [String: String] = [:]

    /// The textual reason phrase of the status code.
    var reason: String?

    /// The charset used to decode the content.
    var encoding: String?

    /// Content of the response, in bytes.
    var content = Data()

    /// Whether the request was answered with a status below 400.
    var ok: Bool {
        guard let statusCode else { return false }
        return statusCode < 400
    }

    /// Content of the response, in unicode.
    var text: String {
        if let text = String(data: content, encoding: stringEncoding) {
            return text
        }
        return String(decoding: content, as: UTF8.self)
    }

    /// Decodes the JSON response body (if any) as a Python object.
    func json() throws(PythonError) -> PyObject? {
        try py.module("json")?.loads?(text)
    }

    /// Raises an HTTPError when the status code is 4xx or 5xx.
    func raiseForStatus() throws(PythonError) {
        guard let statusCode, statusCode >= 400 else { return }

        let kind = statusCode < 500 ? "Client Error" : "Server Error"
        let message = "\(statusCode) \(kind): \(reason ?? "Unknown") for url: \(url ?? "")"

        let error: PythonError? = try py.module("requests.exceptions")?.HTTPError?(message)
        throw error ?? .RuntimeError(message)
    }

    /// Stores everything the received headers carry.
    internal func receive(_ response: HTTPURLResponse) {
        statusCode = response.statusCode
        url = response.url?.absoluteString
        reason = Self.reason(for: response.statusCode)
        encoding = response.textEncodingName

        headers = Dictionary(
            response.allHeaderFields.map { field, value in
                (Self.canonical("\(field)"), "\(value)")
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// The encoding `text` decodes with, falling back to UTF-8.
    private var stringEncoding: String.Encoding {
        guard let encoding else { return .utf8 }

        let charset = CFStringConvertIANACharSetNameToEncoding(encoding as CFString)
        guard charset != kCFStringEncodingInvalidId else { return .utf8 }

        return String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(charset)
        )
    }
}

// MARK: - Header and status formatting

private extension Response {
    /// The header names the token rule below would capitalize incorrectly.
    static let headerOverrides = [
        "etag": "ETag",
        "www-authenticate": "WWW-Authenticate",
        "content-md5": "Content-MD5",
        "te": "TE",
        "dnt": "DNT",
    ]

    /// The reason phrases of the statuses a script is likely to meet.
    static let reasons = [
        200: "OK", 201: "Created", 202: "Accepted", 204: "No Content",
        301: "Moved Permanently", 302: "Found", 303: "See Other",
        304: "Not Modified", 307: "Temporary Redirect", 308: "Permanent Redirect",
        400: "Bad Request", 401: "Unauthorized", 403: "Forbidden",
        404: "Not Found", 405: "Method Not Allowed", 408: "Request Timeout",
        409: "Conflict", 410: "Gone", 418: "I'm a Teapot",
        422: "Unprocessable Entity", 429: "Too Many Requests",
        500: "Internal Server Error", 501: "Not Implemented", 502: "Bad Gateway",
        503: "Service Unavailable", 504: "Gateway Timeout",
    ]

    /// Normalizes header casing, since HTTP/2 hosts send lowercase names.
    static func canonical(_ name: String) -> String {
        let lowercased = name.lowercased()

        if let override = headerOverrides[lowercased] {
            return override
        }

        return lowercased
            .split(separator: "-", omittingEmptySubsequences: false)
            .map(\.capitalized)
            .joined(separator: "-")
    }

    /// The status phrase, in English, since URLSession drops the server's own.
    static func reason(for statusCode: Int) -> String {
        reasons[statusCode]
            ?? HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized
    }
}

extension Response: CustomStringConvertible {
    nonisolated var description: String {
        MainActor.assumeIsolated {
            "<Response [\(statusCode.map(String.init) ?? "None")]>"
        }
    }
}

// MARK: - Transport

/// Collects a task's response and body chunks, and finishes the caller waiting
/// on `run(_:)`.
///
/// Every stored property is touched on the session's serial delegate queue,
/// except the continuation, which is set before `resume()` starts the task.
private final class RequestHandler: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let followsRedirects: Bool
    private let reporter: AsyncTask?
    private var response: HTTPURLResponse?
    private var content = Data()
    private var continuation: CheckedContinuation<(HTTPURLResponse?, Data), any Error>?

    /// The declared body length, and the percentage last reported.
    private var expected: Int64 = 0
    private var percent = 0

    init(followsRedirects: Bool, reporter: AsyncTask?) {
        self.followsRedirects = followsRedirects
        self.reporter = reporter
    }

    /// Runs the task until it completes, and cancels it if the caller is stopped.
    func run(_ task: URLSessionDataTask) async throws -> (HTTPURLResponse?, Data) {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                task.resume()
            }
        } onCancel: {
            task.cancel()
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse
    ) async -> URLSession.ResponseDisposition {
        self.response = response as? HTTPURLResponse

        expected = response.expectedContentLength
        if expected > 0 {
            content.reserveCapacity(Int(expected))
        }

        return .allow
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        content.append(data)

        // Report whole percentages only, or a chunked body floods the console
        // with feedback. A body of unknown length reports nothing, and a
        // compressed one decodes past its declared length, hence the clamp.
        guard let reporter, expected > 0 else { return }

        let received = min(Int(Double(content.count) / Double(expected) * 100), 100)
        guard received != percent else { return }
        percent = received

        Task { @MainActor in reporter.setProgress(Double(received) / 100) }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        // Refusing the redirect hands the 3xx response back to the caller, the
        // way Requests does with `allow_redirects=False`.
        followsRedirects ? request : nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        let continuation = self.continuation
        self.continuation = nil

        if let error {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume(returning: (response, content))
        }
    }
}

@MainActor
final class Request {
    /// The requested URL, including the encoded query.
    let url: String

    private let request: URLRequest
    private let followsRedirects: Bool

    init(_ parameters: RequestParameters) throws(PythonError) {
        let request = try parameters.urlRequest()

        self.request = request
        url = request.url?.absoluteString ?? parameters.url
        followsRedirects = parameters.allowRedirects
    }

    /// Performs the request, raising the matching requests exception on failure.
    func send() async throws -> Response {
        // Read the running task here: the delegate runs outside it and cannot
        // see the task local itself.
        let handler = RequestHandler(
            followsRedirects: followsRedirects,
            reporter: AsyncTask.current
        )

        let task = URLSession.shared.dataTask(with: request)
        task.delegate = handler

        let response = Response()

        do {
            let (httpResponse, content) = try await handler.run(task)

            if let httpResponse {
                response.receive(httpResponse)
            }
            response.content = content
        } catch {
            throw exception(for: error)
        }

        return response
    }

    /// Translates a transport failure into the matching Python exception. A stop
    /// stays a `CancellationError`, so it unwinds without raising into the card.
    private func exception(for error: any Error) -> any Error {
        let urlError = error as? URLError

        if error is CancellationError || urlError?.code == .cancelled {
            return CancellationError()
        }

        let name = switch urlError?.code {
        case .timedOut:
            "Timeout"
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
             .notConnectedToInternet, .networkConnectionLost, .secureConnectionFailed:
            "ConnectionError"
        default:
            "RequestException"
        }

        let message = "\(error.localizedDescription) for url: \(url)"
        let exceptions = py.module("requests.exceptions")
        let raised: PythonError? = try? exceptions?[dynamicMember: name]?(message)
        return raised ?? PythonError.RuntimeError(message)
    }
}
