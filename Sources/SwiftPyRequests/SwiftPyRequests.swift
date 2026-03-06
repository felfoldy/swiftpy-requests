import SwiftPy
import SwiftUI

@MainActor
public enum SwiftPyRequests {
    public static func initialize() {
        PyBind.module("requests", [
            Response.self,
        ]) { module in
            module?.bind("get(url: str, headers: dict = None, json: dict = None)") { argc, argv in
                PyAPI.returnOrThrow {
                    let (url, headers, json): (String, [String: String]?, [String: Any]?) = try PyBind.castArgs(argv: argv)
                    return try Request(url: url, httpMethod: "GET", headers: headers, json: json).task()
                }
            }

            module?.bind("post(url: str, headers: dict = None, json: dict = None)") { argc, argv in
                PyAPI.returnOrThrow {
                    let (url, headers, json): (String, [String: String]?, [String: Any]?) = try PyBind.castArgs(argv: argv)
                    return try Request(url: url, httpMethod: "POST", headers: headers, json: json).task()
                }
            }
        }
    }
}
