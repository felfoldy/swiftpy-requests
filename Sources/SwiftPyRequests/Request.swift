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
    func json() throws -> object? {
        let textRef = text.retained
        let loads = Interpreter.module("json")?["loads"]
        return try loads?.call([textRef.reference])
    }
}

@MainActor
@Observable
final class Request: NSObject, ViewRepresentable {
    enum State {
        case downloading
        case failed
        case completed
    }
    
    let url: String
    var response: Response?

    private(set) var completed: Int64 = 0
    private(set) var total: Int64?
    
    internal var urlTask: Task<Void, Never>?
    internal var state: State = .downloading
    private var request: URLRequest

    init(url urlString: String, httpMethod: String, headers: [String: String]?, json: [String: Any]?) throws {
        self.url = urlString

        guard let url = URL(string: urlString) else {
            throw PythonError.ValueError("Invalid URL: \(urlString)")
        }
        request = URLRequest(url: url)
        super.init()
        
        // Setup request.
        request.httpMethod = httpMethod

        if let headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        if let json {
            let jsonData = try JSONSerialization.data(withJSONObject: json)
            request.httpBody = jsonData
        }
        start()
    }
    
    var view: some View {
        GetRequestView(request: self)
    }
    
    func task() -> AsyncTask {
        AsyncTask(presenting: self) {
            _ = await self.urlTask?.value
            return self.response
        }
    }
    
    internal func start() {
        completed = 0
        total = 0
        state = .downloading
        
        urlTask = Task.detached(priority: .background) {
            do {
                let (asyncBytes, response) = try await URLSession.shared
                    .bytes(for: self.request)
                
                let getRequestResponse = await Response()
                await MainActor.run {
                    self.response = getRequestResponse
                }
                
                
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
            url: "https://raw.githubusercontent.com/felfoldy/SpeechTools/refs/heads/main/Sources/SpeechTools/Language.swift",
            httpMethod: "GET",
            headers: nil,
            json: nil,
        )
    }()
    
    ScrollView {
        GetRequestView(request: request)
    }
}

