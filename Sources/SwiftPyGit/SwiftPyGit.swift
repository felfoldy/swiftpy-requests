//
//  SwiftPyGit.swift
//  swiftpy-requests
//
//  Created by Tibor Felföldy on 2026-04-02.
//

import SwiftPy
import libgit2

@MainActor
public struct SwiftPyGit {
    public static func initialize() {
        PyBind.module("pygit2", [
            Repository.self,
            Remotes.self,
            Remote.self,
            RemoteCallbacks.self,
            UserPass.self,
            Reference.self,
            Object.self,
        ]) { pygit2 in
            pygit2?.bind(
                "clone_repository(url: str, path: Path, callbacks: RemoteCallbacks | None = None) -> AsyncTask[Repository]",
                docstring: "Clones a new Git repository from url in the given path.",
            ) { argc, argv in
                PyBind.function(argc, argv, Repository.clone(url:path:callbacks:))
            }
        }
    }
}
