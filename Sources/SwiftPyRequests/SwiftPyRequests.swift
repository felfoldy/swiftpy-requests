import SwiftPy

@MainActor
public enum SwiftPyRequests {
    public static func initialize() {
        Interpreter.bindModule("requests", [FetchTask.self])
    }
}
