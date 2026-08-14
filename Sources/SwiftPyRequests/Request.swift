//
//  Request.swift
//  swiftpy-requests
//
//  Created by Tibor Felföldy on 2025-10-19.
//

import Foundation
import SwiftPy
import SwiftUI

/// The Response object, which contains a server's response to an HTTP request.
@Scriptable
@MainActor
final class Response {
    typealias object = PyAPI.Reference
    
    /// The HTTP status code of the receiver.
    var statusCode: Int?

    /// Content of the response, in bytes.
    var content = Data()

    /// Content of the response, in unicode.
    var text: String {
        String(data: content, encoding: .utf8) ?? ""
    }

    /// Decodes the JSON response body (if any) as a Python object.
    func json() throws -> PyObject? {
        try py.module("json")?.loads?(text)
    }
}

/// Stops URLSession from following redirects, so the 3xx response is handed back
/// to the caller the way Requests does with `allow_redirects=False`.
final class RedirectBlocker: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        nil
    }
}

@MainActor
@Observable
final class Request: NSObject {
    enum State {
        case downloading
        case failed
        case completed
    }
    
    let url: String
    var response: Response

    private(set) var completed: Int64 = 0
    private(set) var total: Int64?
    
    internal var urlTask: Task<Void, Never>?
    internal var state: State = .downloading
    private let request: URLRequest

    /// Refuses redirects for `allow_redirects=False`; `nil` while they're allowed.
    private let redirectBlocker: RedirectBlocker?

    init(_ parameters: RequestParameters) throws {
        let request = try parameters.urlRequest()

        self.request = request
        // The displayed URL includes the encoded query.
        url = request.url?.absoluteString ?? parameters.url
        redirectBlocker = parameters.allowRedirects ? nil : RedirectBlocker()
        response = Response()
        super.init()

        start()
    }

    func body() -> AnyView {
        AnyView(GetRequestView(request: self))
    }

    func task() async -> Response? {
        _ = await self.urlTask?.value
        return self.response
    }
    
    internal func start() {
        completed = 0
        total = 0
        state = .downloading
        
        urlTask = Task.detached(priority: .background) {
            do {
                let (asyncBytes, response) = try await URLSession.shared
                    .bytes(for: self.request, delegate: self.redirectBlocker)
                
                let getRequestResponse = await self.response
                
                // Set response status code.
                if let httpResponse = response as? HTTPURLResponse {
                    await MainActor.run {
                        getRequestResponse.statusCode = httpResponse.statusCode
                    }
                }
                
                // Set response length.
                let length = response.expectedContentLength
                if length > 0 {
                    await MainActor.run {
                        getRequestResponse.content.reserveCapacity(Int(length))
                        self.total = length
                    }
                }
                
                var completed: Int64 = 0
                var buffer = length > 0 ? Data(capacity: Int(length)) : Data()

                for try await byte in asyncBytes {
                    try Task.checkCancellation()

                    buffer.append(byte)
                    completed += 1
                    
                    if completed % 65536 == 0 {
                        await MainActor.run {
                            self.completed = completed
                        }
                    }
                }

                await MainActor.run {
                    getRequestResponse.content = buffer
                    self.completed = completed
                    
                    if let statusCode = getRequestResponse.statusCode, (200..<300).contains(statusCode) {
                        self.state = .completed
                    } else {
                        self.state = .failed
                    }
                }
            } catch {
                await MainActor.run {
                    self.state = .failed
                }
            }
        }
    }
}

struct GetRequestView: View {
    @State var request: Request
    
    private var completed: String {
        request.completed
            .formatted(.byteCount(style: .file))
    }
    
    private var progressBytes: String {
        let total = request.total?
            .formatted(.byteCount(style: .file))
        
        if let total {
            return "\(completed) of \(total)"
        }
        return completed
    }
    
    private var imageName: String {
        switch request.state {
        case .downloading: "arrow.down.circle"
        case .failed: "exclamationmark.circle"
        case .completed: "checkmark.circle"
        }
    }
    
    private var color: Color {
        switch request.state {
        case .downloading: .purple
        case .failed: .red
        case .completed: .green
        }
    }
    
    var body: some View {
        LogContainerView(tint: color) {
            Image(systemName: "globe")
                .font(.title)
            
            VStack(alignment: .leading) {
                Text(request.url)
                    .lineLimit(1)

                Text(progressBytes)
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if request.state == .downloading {
                Button {
                    request.urlTask?.cancel()
                } label: {
                    Image(systemName: imageName)
                        .frame(width: 40, height: 40)
                        .background(progressView)
                }
            } else {
                Image(systemName: imageName)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
                    .foregroundStyle(color)
            }
        }
        .frame(maxHeight: 44)
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var progressView: some View {
        Circle()
            .stroke(lineWidth: 6)
            .foregroundStyle(.tertiary)
            .padding(4)

        if let total = request.total {
            Circle()
                .trim(
                    from: 0,
                    to: Double(request.completed) / Double(total)
                )
                .stroke(style: StrokeStyle(
                    lineWidth: 6,
                    lineCap: .round
                ))
                .rotationEffect(.degrees(-90))
                .foregroundStyle(color)
                .padding(4)
        }
    }
}

#Preview {
    @Previewable @State var request: Request = {
        try! Request(
            RequestParameters(
                method: "GET",
                url: "https://raw.githubusercontent.com/felfoldy/SpeechTools/refs/heads/main/Sources/SpeechTools/Language.swift"
            )
        )
    }()
    
    ScrollView {
        GetRequestView(request: request)
    }
}

