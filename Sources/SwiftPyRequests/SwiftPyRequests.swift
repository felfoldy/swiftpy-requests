import SwiftPy

@MainActor
public enum SwiftPyRequests {
    public static func initialize() {
        Interpreter.bundles.append(.module)
        Interpreter.bindModule("requests", [FetchRequest.self])
    }
}
