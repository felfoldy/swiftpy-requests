//
//  GetRequest.swift
//  swiftpy-requests
//
//  Created by Tibor Felföldy on 2025-10-19.
//

import Foundation
import SwiftPy
import SwiftUI
import DebugTools

extension SwiftUI.Image {
    static func from(_ data: Data) -> SwiftUI.Image? {
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        return SwiftUI.Image(uiImage: uiImage)
        #else
        guard let nsImage = NSImage(data: data) else { return nil }
        return SwiftUI.Image(nsImage: nsImage)
        #endif
    }
}

@Scriptable
final class DataImage: ViewRepresentable {
    private let image: Image
    
    init(data: Data) throws {
        guard let image = SwiftUI.Image.from(data) else {
            throw PythonError.ValueError("Invalid image data.")
        }
        
        self.image = image
    }
    
    var view: some View {
        image
    }
}

@MainActor
@Scriptable
/// The :class:`Response <Response>` object, which contains a server's response to an HTTP request.
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
    
    var image: DataImage? {
        try? DataImage(data: content)
    }

    /// Decodes the JSON response body (if any) as a Python object.
    func json() throws -> object? {
        let textRef = text.toStack
        let loads = Interpreter.module("json")?["loads"]
        return try loads?.call([textRef.reference])
    }
}

@MainActor
@Observable
@Scriptable("_GetRequest")
final class GetRequest: NSObject, ViewRepresentable {
    enum State {
        case downloading
        case failed
        case completed
    }
    
    let url: String
    var response: Response?

    private(set) var completed: Int64 = 0
    private(set) var total: Int64 = 0
    
    internal var urlTask: Task<Void, Never>?
    internal var state: State = .downloading
    private let requestURL: URL

    init(url urlString: String) throws {
        self.url = urlString

        guard let url = URL(string: urlString) else {
            throw PythonError.ValueError("Invalid URL: \(urlString)")
        }
        requestURL = url

        super.init()
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
        
        urlTask = Task {
            do {
                let (asyncBytes, response) = try await URLSession.shared
                    .bytes(from: requestURL)
                
                let getRequestResponse = Response()
                self.response = getRequestResponse
                
                // Set response status code.
                if let httpResponse = response as? HTTPURLResponse {
                    getRequestResponse.statusCode = httpResponse.statusCode
                }
                
                // Set response length.
                let length = response.expectedContentLength
                getRequestResponse.content.reserveCapacity(Int(length))
                total = length
                
                var completed: Int64 = 0
                
                for try await byte in asyncBytes {
                    try Task.checkCancellation()

                    getRequestResponse.content.append(byte)
                    completed += 1
                    
                    if completed % 1000 == 0 {
                        self.completed = completed
                    }
                }
                
                self.completed = completed
                
                if getRequestResponse.statusCode == 200 {
                    state = .completed
                } else {
                    state = .failed
                }
            } catch {
                state = .failed
            }
        }
    }
}

struct GetRequestView: View {
    @State var request: GetRequest
    
    private var completed: String {
        request.completed
            .formatted(.byteCount(style: .file))
    }
    
    private var total: String {
        request.total
            .formatted(.byteCount(style: .file))
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
                
                Text("\(completed) of \(total)")
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
        
        Circle()
            .trim(
                from: 0,
                to: Double(request.completed) / Double(request.total)
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

#Preview {
    @Previewable @State var request: GetRequest = {
        try! GetRequest(url: "https://raw.githubusercontent.com/felfoldy/SpeechTools/refs/heads/main/Sources/SpeechTools/Language.swift")
    }()
    
    ScrollView {
        GetRequestView(request: request)
    }
}

