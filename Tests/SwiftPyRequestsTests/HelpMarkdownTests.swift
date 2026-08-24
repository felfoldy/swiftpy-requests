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

    init() throws {
        SwiftPyRequests.initialize()
        Interpreter.run("import interpreter")
        Interpreter.run("""
        import help as _help_module
        _get_md = "\\n".join(_help_module._markdown_lines('requests.get'))
        """)
        markdown = try #require(Interpreter.evaluate("_get_md"))
    }

    @Test("opens with the function name, its module, and its summary")
    func titleAndSummary() {
        #expect(markdown.hasPrefix("""
        # get

        `requests`

        Sends a GET request and returns the Response. Await the result.
        """))
    }

    @Test("credits the module a method belongs to, not its class")
    func methodModule() throws {
        Interpreter.run("""
        _method_md = "\\n".join(
            _help_module._markdown_lines('requests.Response.raise_for_status')
        )
        """)
        let method: String = try #require(Interpreter.evaluate("_method_md"))

        #expect(method.hasPrefix("""
        # raise_for_status

        `requests`
        """))
    }

    @Test("links the module where the host takes references")
    func linkedModule() throws {
        Interpreter.run("""
        _help_module._reference_url_prefix = 'pyprompt://reference?v=1&code='
        _linked_md = "\\n".join(_help_module._markdown_lines('requests.get'))
        _help_module._reference_url_prefix = None
        """)
        let linked: String = try #require(Interpreter.evaluate("_linked_md"))

        #expect(linked.contains("[`requests`](pyprompt://reference?v=1&code=requests)"))
    }

    @Test("shows the awaitable signature as a python code block")
    func signature() {
        #expect(markdown.contains("""
        ```python
        async def get(url: str, params: dict = None, data: Any = None, json: Any = None, headers: dict = None, timeout: float = None, allow_redirects: bool = True) -> Response
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
        - `headers`: Header fields to add; these override the inferred Content-Type.
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

/// `help('requests')` lists what the module offers, each function linked to its
/// own documentation rather than stacked into one code block.
@Suite("help('requests')") @MainActor
struct ModuleListingTests {
    let markdown: String

    init() throws {
        SwiftPyRequests.initialize()
        Interpreter.run("import interpreter")
        Interpreter.run("""
        import help as _help_module
        _help_module._reference_url_prefix = 'pyprompt://reference?v=1&code='
        _module_md = "\\n".join(_help_module._markdown_lines('requests'))
        _help_module._reference_url_prefix = None
        """)
        markdown = try #require(Interpreter.evaluate("_module_md"))
    }

    @Test("heads each entry with the name, linked to its own help")
    func entry() {
        #expect(markdown.contains("""
        #### [get](pyprompt://reference?v=1&code=requests.get)

        ```python
        async def get(url: str, params: dict = None, data: Any = None, json: Any = None, headers: dict = None, timeout: float = None, allow_redirects: bool = True) -> Response
        ```

        Sends a GET request and returns the Response. Await the result.
        """))
    }

    @Test("keeps the signature in a code block rather than in the link")
    func signatureIsNotTheLink() {
        // A link long enough to wrap loses its frame and spills over the line,
        // so what is linked is the bare name.
        for line in markdown.split(separator: "\n") where line.hasPrefix("#### [") {
            let linked = line.dropFirst("#### [".count).prefix { $0 != "]" }

            #expect(!linked.isEmpty)
            #expect(!linked.contains("("))
            #expect(!linked.contains(" "))
        }
    }

    @Test("lists the functions in a settled order")
    func sorted() throws {
        let names = ["delete", "get", "head", "patch", "post", "put", "request"]
        let positions = try names.map { name in
            try #require(markdown.range(of: "async def \(name)(")).lowerBound
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
