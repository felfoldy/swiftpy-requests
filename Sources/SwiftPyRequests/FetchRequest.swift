//
//  FetchTask.swift
//  swiftpy-requests
//
//  Created by Tibor Felföldy on 2025-10-19.
//

import Foundation
import SwiftPy
import SwiftUI

@MainActor
@Observable
@Scriptable
final class FetchRequest: NSObject {
    enum State {
        case downloading
        case failed
        case completed
    }
    
    let url: String
    var content = Data()

    private(set) var completed: Int64 = 0
    private(set) var total: Int64 = 0
    
    internal var urlTask: Task<Void, Never>?
    internal var state: State = .downloading

    init(url urlString: String) throws {
        self.url = urlString

        guard let url = URL(string: urlString) else {
            throw PythonError.ValueError("Invalid URL: \(urlString)")
        }

        super.init()

        urlTask = Task {
            do {
                let (asyncBytes, response) = try await Foundation.URLSession.shared
                    .bytes(from: url)
                
                let length = response.expectedContentLength
                content.reserveCapacity(Int(length))
                total = length

                for try await byte in asyncBytes {
                    try Task.checkCancellation()

                    content.append(byte)
                    completed = Int64(content.count)
                }
                
                state = .completed
            } catch {
                state = .failed
            }
        }
    }
    
    func task() -> AsyncTask {
        AsyncTask(presenting: self) {
            _ = await self.urlTask?.value
            return self.content
        }
    }
}

extension FetchRequest: ViewRepresentable {
    var representation: ViewRepresentation {
        ViewRepresentation {
            FetchRequestView(request: self)
        }
    }
}

struct FetchRequestView: View {
    @State var request: FetchRequest
    
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
    
    private var imageColor: Color {
        switch request.state {
        case .downloading: .primary
        case .failed: .red
        case .completed: .green
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: imageName)
                    .font(.title)
                    .foregroundStyle(imageColor)
                
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
                        Image(systemName: "x.circle")
                    }
                }
            }

            ProgressView(value: Double(request.completed) / Double(request.total))
                .progressViewStyle(.automatic)
        }
        .overlay(alignment: .bottom) {
            Divider()
        }
        .padding(4)
    }
}

#Preview {
    @Previewable @State var request: FetchRequest = {
        try! FetchRequest(url: "https://raw.githubusercontent.com/felfoldy/SpeechTools/refs/heads/main/Sources/SpeechTools/Language.swift")
    }()
    
    FetchRequestView(request: request)
}

