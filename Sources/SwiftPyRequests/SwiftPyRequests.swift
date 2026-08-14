import SwiftPy
import SwiftUI

@MainActor
func request(
    method: String,
    url: String,
    params: [String: Any]?,
    data: PyObject?,
    json: PyObject?,
    headers: [String: String]?,
    timeout: Double?,
    allowRedirects: Bool
) async throws -> Response? {
    try await Request(
        RequestParameters(
            method: method,
            url: url,
            params: params,
            data: data,
            json: json,
            headers: headers,
            timeout: timeout,
            allowRedirects: allowRedirects
        )
    ).task()
}

@MainActor
func get(
    url: String,
    params: [String: Any]?,
    data: PyObject?,
    json: PyObject?,
    headers: [String: String]?,
    timeout: Double?,
    allowRedirects: Bool
) async throws -> Response? {
    try await request(
        method: "GET",
        url: url,
        params: params,
        data: data,
        json: json,
        headers: headers,
        timeout: timeout,
        allowRedirects: allowRedirects
    )
}

@MainActor
func post(
    url: String,
    data: PyObject?,
    json: PyObject?,
    params: [String: Any]?,
    headers: [String: String]?,
    timeout: Double?,
    allowRedirects: Bool
) async throws -> Response? {
    try await request(
        method: "POST",
        url: url,
        params: params,
        data: data,
        json: json,
        headers: headers,
        timeout: timeout,
        allowRedirects: allowRedirects
    )
}

@MainActor
public enum SwiftPyRequests {
    public static func initialize() {
        PyBind.module("requests") { requests in
            requests.class(Response.self)

            // Each verb orders its parameters the way Requests documents them, so
            // positional calls mean the same thing here as they do in Python.
            requests.asyncDef("request(method: str, url: str, params: dict = None, data=None, json=None, headers: dict = None, timeout: float = None, allow_redirects: bool = True) -> Response") { argc, argv in
                PyBind.function(argc, argv, request(method:url:params:data:json:headers:timeout:allowRedirects:))
            }

            requests.asyncDef("get(url: str, params: dict = None, data=None, json=None, headers: dict = None, timeout: float = None, allow_redirects: bool = True) -> Response") { argc, argv in
                PyBind.function(argc, argv, get(url:params:data:json:headers:timeout:allowRedirects:))
            }

            requests.asyncDef("post(url: str, data=None, json=None, params: dict = None, headers: dict = None, timeout: float = None, allow_redirects: bool = True) -> Response") { argc, argv in
                PyBind.function(argc, argv, post(url:data:json:params:headers:timeout:allowRedirects:))
            }
        }
    }
}
