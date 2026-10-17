//
//  ExceptionTests.swift
//  swiftpy-requests
//

import Testing
import SwiftPy
import SwiftPyRequests

@Suite @MainActor
struct ExceptionTests {
    init() {
        SwiftPyRequests.initialize()
    }

    @Test func anUnreachableHostRaisesConnectionError() async {
        // Nothing listens on the discard port, so this fails without the network.
        await Interpreter.run("""
        import requests
        try:
            await requests.aio.get("http://127.0.0.1:9", timeout=5)
            _raised = None
        except requests.RequestException as error:
            _raised = (type(error) is requests.ConnectionError, isinstance(error, requests.exceptions.RequestException))
        """)
        #expect(Interpreter.evaluate("repr(_raised)") == "(True, True)")
    }
}
