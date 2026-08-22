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
) async throws -> Response {
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
    ).send()
}

// MARK: - Verbs

/// A verb that leads with its query, as in `requests.get(url, params=None, …)`.
@MainActor
private func queryVerb(
    _ method: String
) -> @MainActor (String, [String: Any]?, PyObject?, PyObject?, [String: String]?, Double?, Bool) async throws -> Response {
    { url, params, data, json, headers, timeout, allowRedirects in
        try await request(
            method: method,
            url: url,
            params: params,
            data: data,
            json: json,
            headers: headers,
            timeout: timeout,
            allowRedirects: allowRedirects
        )
    }
}

/// A verb that leads with its body, as in `requests.post(url, data=None, json=None, …)`.
@MainActor
private func bodyVerb(
    _ method: String
) -> @MainActor (String, PyObject?, PyObject?, [String: Any]?, [String: String]?, Double?, Bool) async throws -> Response {
    { url, data, json, params, headers, timeout, allowRedirects in
        try await request(
            method: method,
            url: url,
            params: params,
            data: data,
            json: json,
            headers: headers,
            timeout: timeout,
            allowRedirects: allowRedirects
        )
    }
}

// MARK: - Documentation

/// The parameter reference every verb shares, so `help()` explains all of them.
private let parameterDocs = """
    params: Mapping appended to the URL's query; a list value repeats the key.
    data: A dict (form encoded), str, or bytes request body.
    json: An object sent as an application/json body. Cannot be used with data.
    headers: Header fields to add; these override the inferred Content-Type.
    timeout: Seconds allowed to pass without receiving data.
    """

@MainActor
private func docs(for method: String, followsRedirects: Bool = true) -> String {
    """
    Sends a \(method) request and returns the Response. Await the result.

    \(parameterDocs)
    allow_redirects: Whether 3xx responses are followed. \
    Defaults to \(followsRedirects ? "True" : "False").
    """
}

@MainActor
public enum SwiftPyRequests {
    public static func initialize() {
        PyBind.module("requests.exceptions", in: .module)

        PyBind.module(
            "requests",
            docs: "Awaitable HTTP requests: get, post, put, patch, delete, and head."
        ) { requests in
            requests.class(Response.self)
            let exceptions = py.module("requests.exceptions")

            requests.RequestException = exceptions?.RequestException
            requests.ConnectionError = exceptions?.ConnectionError
            requests.Timeout = exceptions?.Timeout
            requests.HTTPError = exceptions?.HTTPError

            // Each verb orders its parameters the way Requests documents them, so
            // positional calls mean the same thing here as they do in Python.
            requests.asyncDef(
                "request(method: str, url: str, params: dict = None, data=None, json=None, headers: dict = None, timeout: float = None, allow_redirects: bool = True) -> Response",
                docstring: """
                Sends a request with the given method and returns the Response. Await the result.

                method: The HTTP method, for example 'GET' or 'POST'.
                \(parameterDocs)
                allow_redirects: Whether 3xx responses are followed. Defaults to True.
                """
            ) { argc, argv in
                PyBind.function(argc, argv, request(method:url:params:data:json:headers:timeout:allowRedirects:))
            }

            requests.asyncDef(
                "get(url: str, params: dict = None, data=None, json=None, headers: dict = None, timeout: float = None, allow_redirects: bool = True) -> Response",
                docstring: docs(for: "GET")
            ) { argc, argv in
                PyBind.function(argc, argv, queryVerb("GET"))
            }

            requests.asyncDef(
                "post(url: str, data=None, json=None, params: dict = None, headers: dict = None, timeout: float = None, allow_redirects: bool = True) -> Response",
                docstring: docs(for: "POST")
            ) { argc, argv in
                PyBind.function(argc, argv, bodyVerb("POST"))
            }

            requests.asyncDef(
                "put(url: str, data=None, json=None, params: dict = None, headers: dict = None, timeout: float = None, allow_redirects: bool = True) -> Response",
                docstring: docs(for: "PUT")
            ) { argc, argv in
                PyBind.function(argc, argv, bodyVerb("PUT"))
            }

            requests.asyncDef(
                "patch(url: str, data=None, json=None, params: dict = None, headers: dict = None, timeout: float = None, allow_redirects: bool = True) -> Response",
                docstring: docs(for: "PATCH")
            ) { argc, argv in
                PyBind.function(argc, argv, bodyVerb("PATCH"))
            }

            requests.asyncDef(
                "delete(url: str, params: dict = None, data=None, json=None, headers: dict = None, timeout: float = None, allow_redirects: bool = True) -> Response",
                docstring: docs(for: "DELETE")
            ) { argc, argv in
                PyBind.function(argc, argv, queryVerb("DELETE"))
            }

            // Requests leaves redirects unfollowed for HEAD.
            requests.asyncDef(
                "head(url: str, params: dict = None, data=None, json=None, headers: dict = None, timeout: float = None, allow_redirects: bool = False) -> Response",
                docstring: docs(for: "HEAD", followsRedirects: false)
            ) { argc, argv in
                PyBind.function(argc, argv, queryVerb("HEAD"))
            }
        }
    }
}
