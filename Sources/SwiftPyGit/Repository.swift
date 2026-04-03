//
//  Repository.swift
//  swiftpy-requests
//
//  Created by Tibor Felföldy on 2026-04-02.
//

import SwiftPy
import Foundation
import libgit2

@Scriptable(convertsToSnakeCase: false)
final class ResetMode {
    static let HARD = "hard"
    static let SOFT = "soft"
    static let MIXED = "mixed"
}

/// A representation of a Git repository.
@Scriptable
public final class Repository: @unchecked Sendable {
    var remotes: Remotes {
        Remotes(pointer: pointer)
    }
    
    internal let pointer: OpaquePointer

    /// Open a git repository.
    public convenience init(path: String) throws {
        let path = try Path(path: path).url.path
        let pointer = try git.openRepository(path: path)
        self.init(pointer: pointer)
    }

    internal init(pointer: OpaquePointer) {
        self.pointer = pointer
    }

    /// Lookup a reference by name in a repository.
    public func lookupReference(name: String) throws -> Reference {
        let pointer = try git.referenceLookup(repo: self.pointer, name: name)
        return Reference(pointer: pointer, repoPointer: self.pointer)
    }

    /// Sets the current head to the specified commit oid and optionally resets the index and working tree to match.
    public func reset(target: Object, mode: String) throws {
        let resetType = switch mode {
        case "hard": GIT_RESET_HARD
        case "soft": GIT_RESET_SOFT
        default: GIT_RESET_MIXED
        }
        try git.reset(repo: pointer, target: target.pointer, resetType: resetType)
    }

    deinit {
        git_repository_free(pointer)
    }
}

public extension Repository {
    static func clone(
        url: String,
        path: String,
        callbacks: RemoteCallbacks? = nil
    ) async throws -> Repository {
        var options = git.cloneOptions
        if let callbacks {
            let callbacksPointer = Unmanaged.passRetained(callbacks)
                .toOpaque()
            options.fetch_opts.callbacks.payload = callbacksPointer
        }
        let path = try Path(path: path).url.path
        let pointer = try await git.cloneRepository(
            url: url,
            localPath: path,
            options: options
        )
        return Repository(pointer: pointer)
    }
}
