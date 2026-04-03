//
//  RemoteCallbacks.swift
//  swiftpy-requests
//
//  Created by Tibor Felföldy on 2026-04-02.
//

import SwiftPy

/// Username/Password credentials
@Scriptable
public class UserPass {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

/// RemoteCallbacks(credentials=None)
@Scriptable
public final class RemoteCallbacks: @unchecked Sendable {
    public var credentials: UserPass?

    public init(credentials: UserPass? = nil) {
        self.credentials = credentials
    }
}
