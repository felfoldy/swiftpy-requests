import SwiftPy
import SwiftUI

@MainActor
func get(url: String, headers: [String: String]?, json: [String: Any]?) throws -> AsyncTask {
    try Request(url: url, httpMethod: "GET", headers: headers, json: json).task()
}

@MainActor
func post(url: String, headers: [String: String]?, json: [String: Any]?) throws -> AsyncTask {
    try Request(url: url, httpMethod: "POST", headers: headers, json: json).task()
}

@MainActor
public enum SwiftPyRequests {
    public static func initialize() {
        PyBind.module("requests") { requests in
            requests.class(Response.self)

            requests.def("get(url: str, headers: dict = None, json: dict = None) -> Response") { argc, argv in
                PyBind.function(argc, argv, get(url:headers:json:))
            }

            requests.def("post(url: str, headers: dict = None, json: dict = None)") { argc, argv in
                PyBind.function(argc, argv, post(url:headers:json:))
            }
        }
    }
}
