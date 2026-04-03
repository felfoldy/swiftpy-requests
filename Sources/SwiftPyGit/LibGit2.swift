//
//  LibGit2.swift
//  swiftpy-requests
//
//  Created by Tibor Felföldy on 2026-04-02.
//

@preconcurrency import libgit2
import SwiftPy

let git = LibGit2.shared

extension git_clone_options: @retroactive @unchecked Sendable {}
extension git_fetch_options: @retroactive @unchecked Sendable {}

struct LibGit2 {
    static let shared = LibGit2()

    private init() {
        precondition(git_libgit2_init() >= 0)
    }

    var cloneOptions: git_clone_options {
        var options = git_clone_options()
        git_clone_options_init(&options, UInt32(GIT_CLONE_OPTIONS_VERSION))
        options.fetch_opts.callbacks.credentials = credentials_cb
        return options
    }

    var fetchOptions: git_fetch_options {
        var options = git_fetch_options()
        git_fetch_options_init(&options, UInt32(GIT_FETCH_OPTIONS_VERSION))
        options.callbacks.credentials = credentials_cb
        return options
    }

    func openRepository(path: String) throws(PythonError) -> OpaquePointer {
        var pointer: OpaquePointer?
        let status = git_repository_open(&pointer, path)
        guard let pointer, status == 0 else {
            throw .RuntimeError("Failed to open repository with error code: \(status)")
        }
        return pointer
    }
    
    func cloneRepository(url: String, localPath: String, options: git_clone_options) async throws(PythonError) -> OpaquePointer {
        let (status, out) = await withCheckedContinuation { continuation in
            var options = options
            var out: OpaquePointer?
            let status = git_clone(&out, url, localPath, &options)
            continuation.resume(returning: (status, out))
        }

        guard let out, status >= 0 else {
            throw .RuntimeError("Failed to clone repository: \(url)")
        }

        return out
    }
    
    func referenceLookup(repo: OpaquePointer, name: String) throws(PythonError) -> OpaquePointer {
        var pointer: OpaquePointer?
        let status = git_reference_lookup(&pointer, repo, name)
        guard let pointer, status == 0 else {
            throw .RuntimeError("Failed to lookup reference with error code: \(status)")
        }
        return pointer
    }
    
    func reset(repo: OpaquePointer, target: OpaquePointer, resetType: git_reset_t) throws(PythonError) {
        let status = git_reset(repo, target, resetType, nil)
        guard status == 0 else {
            throw .RuntimeError("Failed to reset with error code: \(status)")
        }
    }
    
    func remoteFetch(remote: OpaquePointer, options: git_fetch_options) async throws(PythonError) {
        let status = await withCheckedContinuation { continuation in
            var options = options
            let status = git_remote_fetch(remote, nil, &options, nil)
            continuation.resume(returning: status)
        }
        
        if status != 0 {
            throw .RuntimeError("Failed to fetch remote with error code: \(status)")
        }
    }
    
    func remoteLookup(repoPointer: OpaquePointer, name: String) throws(PythonError) -> OpaquePointer {
        var pointer: OpaquePointer?
        let status = git_remote_lookup(&pointer, repoPointer, name)
        guard status == 0, let pointer else {
            throw .RuntimeError("Failed to lookup remote \(name)")
        }
        return pointer
    }
}

private let credentials_cb: git_credential_acquire_cb = { (out, url, username_from_url, allowed_types, payload) in
    guard let payload else {
        return GIT_EUSER.rawValue
    }

    let callbacks = Unmanaged<RemoteCallbacks>
        .fromOpaque(payload)
        .takeUnretainedValue()

    guard let userpass = callbacks.credentials else {
        return GIT_EUSER.rawValue
    }

    return git_credential_userpass_plaintext_new(
        out,
        userpass.username,
        userpass.password
    )
}
