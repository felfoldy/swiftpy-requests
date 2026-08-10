import SwiftPy
import SwiftUI

@MainActor
func request(method: String, url: String, headers: [String: String]?, json: [String: Any]?) async throws -> Response? {
    try await Request(url: url, httpMethod: method.uppercased(), headers: headers, json: json).task()
}

@MainActor
func get(url: String, headers: [String: String]?, json: [String: Any]?) async throws -> Response? {
    try await Request(url: url, httpMethod: "GET", headers: headers, json: json).task()
}

@MainActor
func post(url: String, headers: [String: String]?, json: [String: Any]?) async throws -> Response? {
    try await Request(url: url, httpMethod: "POST", headers: headers, json: json).task()
}

@MainActor
public enum SwiftPyRequests {
    public static func initialize() {
        PyBind.module("requests") { requests in
            requests.class(Response.self)

            requests.asyncDef("request(method: str, url: str, headers: dict = None, json: dict = None) -> Response") { argc, argv in
                PyBind.function(argc, argv, request(method:url:headers:json:))
            }

            requests.asyncDef("get(url: str, headers: dict = None, json: dict = None) -> Response") { argc, argv in
                PyBind.function(argc, argv, get(url:headers:json:))
            }

            requests.asyncDef("post(url: str, headers: dict = None, json: dict = None) -> Response") { argc, argv in
                PyBind.function(argc, argv, post(url:headers:json:))
            }
        }
    }
}
