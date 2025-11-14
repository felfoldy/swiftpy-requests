import SwiftPy
import SwiftUI

@MainActor
public enum SwiftPyRequests {
    public static func initialize() {
        Interpreter.bindModule("requests", [
            GetRequest.self,
            Response.self,
        ]) { module in
            module?.bind("get(url: str)") { argc, argv in
                PyAPI.returnOrThrow {
                    guard argc == 1, let url = String(argv) else {
                        throw PythonError.ValueError("Expected a string")
                    }
                    return try GetRequest(url: url).task()
                }
            }
        }
    }
}
