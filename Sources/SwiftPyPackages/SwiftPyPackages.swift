//
//  SwiftPyPackages.swift
//  swiftpy-requests
//
//  Created by Tibor Felföldy on 2026-04-03.
//

import SwiftPy
import SwiftPyGit
import SwiftPyRequests

@MainActor
public func initialize() {
    SwiftPyGit.initialize()
    SwiftPyRequests.initialize()

    Interpreter.bundles.append(.module)
}
