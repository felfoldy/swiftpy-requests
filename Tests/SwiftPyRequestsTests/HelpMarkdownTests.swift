//
//  HelpMarkdownTests.swift
//  swiftpy-requests
//

import Testing
import SwiftPy
import SwiftPyRequests

/// `help('requests.get')` is the reference for how a function's documentation
/// reads, so it is checked against the real module here rather than a fixture.
@Suite("help('requests.get')") @MainActor
struct HelpMarkdownTests {
    let markdown: String

    init() async throws {
        SwiftPyRequests.initialize()
        await Interpreter.run("import interpreter")
        await Interpreter.run("""
        import interpreter.help as _help_module
        _get_md = "\\n".join(_help_module._markdown_lines('requests.get'))
        """)
        markdown = try #require(Interpreter.evaluate("_get_md"))
    }

    @Test("opens with its parent, syntax, and summary")
    func parentSyntaxAndSummary() {
        #expect(markdown.hasPrefix("""
        ``requests``

        ```python
        def get(
            url: str,
            params: dict = None,
            data: Any = None,
            json: Any = None,
            headers: dict = None,
            timeout: float = None,
            allow_redirects: bool = True,
        ) -> Response
        ```

        Sends a GET request and returns the Response.
        """))
    }

    @Test("references the class that owns a method")
    func methodParent() async throws {
        await Interpreter.run("""
        _method_md = "\\n".join(
            _help_module._markdown_lines('requests.Response.raise_for_status')
        )
        """)
        let method: String = try #require(Interpreter.evaluate("_method_md"))

        #expect(method.hasPrefix("""
        ``requests/Response``

        ```python
        def raise_for_status(self) -> None
        ```
        """))
    }

    @Test("shows the signature as a python code block")
    func signature() {
        #expect(markdown.contains("""
        ```python
        def get(
            url: str,
            params: dict = None,
            data: Any = None,
            json: Any = None,
            headers: dict = None,
            timeout: float = None,
            allow_redirects: bool = True,
        ) -> Response
        ```
        """))
        // The trailing colon belongs to a source stub, not to a signature.
        #expect(!markdown.contains("-> Response:"))
    }

    @Test("lists every documented parameter in order")
    func parameters() {
        #expect(markdown.contains("""
        ## Parameters

        - `url`: The URL to send the request to.
        - `params`: Mapping appended to the URL's query; a list value repeats the key.
        - `data`: A dict (form encoded), str, or bytes request body.
        - `json`: An object sent as an application/json body. Cannot be used with data.
        - `headers`: Header fields to add; these override the inferred Content-Type. A value may be a ``keychain.Secret`` or its ``bearer()``, filled in as the request is sent.
        - `timeout`: Seconds allowed to pass without receiving data.
        - `allow_redirects`: Whether 3xx responses are followed. Defaults to True.
        """))
    }

    @Test("documents the required url parameter")
    func urlParameter() {
        #expect(markdown.contains("- `url`: The URL to send the request to."))
    }

    @Test("has no discussion, the docstring being summary and parameters")
    func noDiscussion() {
        #expect(!markdown.contains("## Discussion"))
    }

    @Test("is not the plain stub it used to be")
    func isNotAStub() {
        #expect(!markdown.hasPrefix("```python"))
    }
}

/// `help('requests')` lists what the module offers, each function referencing
/// its own documentation rather than stacked into one code block.
@Suite("help('requests')") @MainActor
struct ModuleListingTests {
    let markdown: String

    init() async throws {
        SwiftPyRequests.initialize()
        await Interpreter.run("import interpreter")
        await Interpreter.run("""
        import interpreter.help as _help_module
        _module_md = "\\n".join(_help_module._markdown_lines('requests'))
        """)
        markdown = try #require(Interpreter.evaluate("_module_md"))
    }

    @Test("heads each entry with the name, referencing its own help")
    func entry() {
        #expect(markdown.contains("""
        ### ``requests/get(url, params, data, json, headers, timeout, allow_redirects)``

        ```python
        def get(url: str, params: dict = None, data: Any = None, json: Any = None, headers: dict = None, timeout: float = None, allow_redirects: bool = True) -> Response
        ```

        Sends a GET request and returns the Response.
        """))
    }

    @Test("keeps the signature in a code block rather than in the reference")
    func signatureIsNotTheReference() {
        // The reference carries parameter names for recognition, while types
        // and defaults remain in the declaration below it.
        for line in markdown.split(separator: "\n") where line.hasPrefix("### ``") {
            let shown = line
                .dropFirst("### ``".count)
                .prefix { $0 != "`" }
                .split(separator: "/")
                .last ?? ""

            #expect(!shown.isEmpty)
            #expect(shown.contains("("))
            #expect(!shown.contains(":"))
            #expect(!shown.contains("="))
        }
    }

    @Test("lists the functions in a settled order")
    func sorted() throws {
        let names = ["delete", "get", "head", "patch", "post", "put", "request"]
        let positions = try names.map { name in
            try #require(markdown.range(of: "def \(name)(")).lowerBound
        }

        #expect(positions == positions.sorted())
    }

    @Test("no longer stacks the functions into one code block")
    func notOneCodeBlock() {
        #expect(!markdown.contains("""
        ## Functions

        ```python
        """))
    }
}

/// The awaitable verbs moved to `requests.aio`; the blocking ones under
/// `requests` are what a cell calls directly.
@Suite("requests.aio") @MainActor
struct AsyncModuleTests {
    init() async throws {
        SwiftPyRequests.initialize()
        await Interpreter.run("import interpreter")
        await Interpreter.run("""
        import interpreter.help as _help_module
        _aio_md = "\\n".join(_help_module._markdown_lines('requests.aio.get'))
        """)
    }

    @Test("documents the awaitable form")
    func awaitableSignature() throws {
        let markdown: String = try #require(Interpreter.evaluate("_aio_md"))

        #expect(markdown.contains("async def get("))
        #expect(markdown.contains("Await the result."))
    }

    @Test("reaches the module as an attribute of requests")
    func reachableFromRequests() async {
        await Interpreter.run("import requests")

        #expect(Interpreter.evaluate("requests.aio.__name__") == "requests.aio")
    }
}
