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
        PyBind.module("pygit2") { module in
            module.classes(
                Repository.self,
                Remotes.self,
                Remote.self,
                RemoteCallbacks.self,
                UserPass.self,
                Reference.self,
                Object.self,
                ResetMode.self,
            )

            module.def(
                "clone_repository(url: str, path: Path, callbacks: RemoteCallbacks | None = None) -> Repository",
                docstring: "Clones a new Git repository from url in the given path."
            ) { argc, argv in
                PyBind.function(argc, argv, Repository.clone)
            }
        }
    }
}
