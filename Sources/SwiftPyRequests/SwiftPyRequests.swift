import SwiftPy
import SwiftUI

@MainActor
func request(
    method: String,
    url: String,
    params: [String: Any]?,
    data: PyObject?,
    json: PyObject?,
    headers: [String: PyObject]?,
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
) -> @MainActor (String, [String: Any]?, PyObject?, PyObject?, [String: PyObject]?, Double?, Bool) async throws -> Response {
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
) -> @MainActor (String, PyObject?, PyObject?, [String: Any]?, [String: PyObject]?, Double?, Bool) async throws -> Response {
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
    url: The URL to send the request to.
    params: Mapping appended to the URL's query; a list value repeats the key.
    data: A dict (form encoded), str, or bytes request body.
    json: An object sent as an application/json body. Cannot be used with data.
    headers: Header fields to add; these override the inferred Content-Type. A value may be a ``keychain.Secret`` or its ``bearer()``, filled in as the request is sent.
    timeout: Seconds allowed to pass without receiving data.
    """

@MainActor
private func docs(for method: String, followsRedirects: Bool = true, isAsync: Bool = false) -> String {
    """
    Sends a \(method) request and returns the Response.\(isAsync ? " Await the result." : "")

    \(parameterDocs)
    allow_redirects: Whether 3xx responses are followed. \
    Defaults to \(followsRedirects ? "True" : "False").
    """
}

/// Binds the verbs in the order Requests documents their parameters, so a
/// positional call means the same thing here as it does in Python. The same
/// work is bound twice: blocking under `requests`, awaitable under
/// `requests.aio`.
@MainActor
private func bindVerbs(to module: PyModule, isAsync: Bool) {
    func define(
        _ signature: String,
        _ docstring: String,
        awaited: PyAPI.CFunction,
        blocking: PyAPI.CFunction
    ) {
        if isAsync {
            module.asyncDef(signature, docstring: docstring, function: awaited)
        } else {
            module.def(signature, docstring: docstring, function: blocking)
        }
    }

    define(
        "request(method: str, url: str, params: dict = None, data: Any = None, json: Any = None, headers: dict = None, timeout: float = None, allow_redirects: bool = True) -> Response",
        """
        Sends a request with the given method and returns the Response.\(isAsync ? " Await the result." : "")

        method: The HTTP method, for example 'GET' or 'POST'.
        \(parameterDocs)
        allow_redirects: Whether 3xx responses are followed. Defaults to True.
        """,
        awaited: { argc, argv in
            PyBind.function(argc, argv, request(method:url:params:data:json:headers:timeout:allowRedirects:))
        },
        blocking: { argc, argv in
            PyBind.blocking(argc, argv, request(method:url:params:data:json:headers:timeout:allowRedirects:))
        }
    )

    define(
        "get(url: str, params: dict = None, data: Any = None, json: Any = None, headers: dict = None, timeout: float = None, allow_redirects: bool = True) -> Response",
        docs(for: "GET", isAsync: isAsync),
        awaited: { argc, argv in PyBind.function(argc, argv, queryVerb("GET")) },
        blocking: { argc, argv in PyBind.blocking(argc, argv, queryVerb("GET")) }
    )

    define(
        "post(url: str, data: Any = None, json: Any = None, params: dict = None, headers: dict = None, timeout: float = None, allow_redirects: bool = True) -> Response",
        docs(for: "POST", isAsync: isAsync),
        awaited: { argc, argv in PyBind.function(argc, argv, bodyVerb("POST")) },
        blocking: { argc, argv in PyBind.blocking(argc, argv, bodyVerb("POST")) }
    )

    define(
        "put(url: str, data: Any = None, json: Any = None, params: dict = None, headers: dict = None, timeout: float = None, allow_redirects: bool = True) -> Response",
        docs(for: "PUT", isAsync: isAsync),
        awaited: { argc, argv in PyBind.function(argc, argv, bodyVerb("PUT")) },
        blocking: { argc, argv in PyBind.blocking(argc, argv, bodyVerb("PUT")) }
    )

    define(
        "patch(url: str, data: Any = None, json: Any = None, params: dict = None, headers: dict = None, timeout: float = None, allow_redirects: bool = True) -> Response",
        docs(for: "PATCH", isAsync: isAsync),
        awaited: { argc, argv in PyBind.function(argc, argv, bodyVerb("PATCH")) },
        blocking: { argc, argv in PyBind.blocking(argc, argv, bodyVerb("PATCH")) }
    )

    define(
        "delete(url: str, params: dict = None, data: Any = None, json: Any = None, headers: dict = None, timeout: float = None, allow_redirects: bool = True) -> Response",
        docs(for: "DELETE", isAsync: isAsync),
        awaited: { argc, argv in PyBind.function(argc, argv, queryVerb("DELETE")) },
        blocking: { argc, argv in PyBind.blocking(argc, argv, queryVerb("DELETE")) }
    )

    // Requests leaves redirects unfollowed for HEAD.
    define(
        "head(url: str, params: dict = None, data: Any = None, json: Any = None, headers: dict = None, timeout: float = None, allow_redirects: bool = False) -> Response",
        docs(for: "HEAD", followsRedirects: false, isAsync: isAsync),
        awaited: { argc, argv in PyBind.function(argc, argv, queryVerb("HEAD")) },
        blocking: { argc, argv in PyBind.blocking(argc, argv, queryVerb("HEAD")) }
    )
}

@MainActor
public enum SwiftPyRequests {
    public static func initialize() {
        PyBind.module("requests.exceptions", in: .module)

        PyBind.module(
            "requests.aio",
            docs: """
            The requests verbs as awaitables, for sending several at once.

            ```python
            import asyncio, requests

            first, second = await asyncio.gather(
                requests.aio.get(url),
                requests.aio.get(other_url),
            )
            ```
            """
        ) { aio in
            bindVerbs(to: aio, isAsync: true)
        }

        PyBind.module(
            "requests",
            docs: """
            HTTP requests: get, post, put, patch, delete, and head.

            A verb waits for its response, as in Python. ``requests.aio`` has \
            the same verbs to await, for sending several requests at once.
            """
        ) { requests in
            requests.class(Response.self)
            let exceptions = py.module("requests.exceptions")

            requests.RequestException = exceptions?.RequestException
            requests.ConnectionError = exceptions?.ConnectionError
            requests.Timeout = exceptions?.Timeout
            requests.HTTPError = exceptions?.HTTPError
            requests.aio = py.module("requests.aio")

            bindVerbs(to: requests, isAsync: false)
        }
    }
}
