//
//  Remote.swift
//  swiftpy-requests
//
//  Created by Tibor Felföldy on 2026-04-02.
//

import SwiftPy
import libgit2

/// Git's idea of a remote repository.
@Scriptable
public class Remote {
    let name: String
    let url: String
    
    internal let pointer: OpaquePointer
    internal let repoPointer: OpaquePointer
    
    internal init?(pointer: OpaquePointer) {
        self.pointer = pointer
        name = String(cString: git_remote_name(pointer))
        url = String(cString: git_remote_url(pointer))
        guard let repoPointer = git_remote_owner(pointer) else {
            return nil
        }
        self.repoPointer = repoPointer
    }

    deinit {
        git_remote_free(pointer)
    }
    
    public func fetch(callbacks: RemoteCallbacks? = nil) async throws(PythonError) {
        var options = git.fetchOptions
        if let callbacks {
            options.callbacks.payload = Unmanaged.passRetained(callbacks)
                .toOpaque()
        }
        try await git.remoteFetch(remote: pointer, options: options)
    }
}

@Scriptable
public final class Remotes {
    internal let repoPointer: OpaquePointer

    internal init(pointer: OpaquePointer) {
        self.repoPointer = pointer
    }
    
    func __getitem__(name: String) throws(PythonError) -> Remote? {
        let pointer = try git.remoteLookup(
            repoPointer: repoPointer,
            name: name
        )
        return Remote(pointer: pointer)
    }
}

public extension Remotes {
    subscript(_ name: String) -> Remote? {
        try? __getitem__(name: name)
    }
}
