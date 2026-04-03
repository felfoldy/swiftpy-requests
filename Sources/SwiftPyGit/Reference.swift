//
//  Reference.swift
//  swiftpy-requests
//
//  Created by Tibor Felföldy on 2026-04-03.
//

import SwiftPy
import libgit2

@Scriptable
public final class Object {
    internal let pointer: OpaquePointer
    
    internal init(pointer: OpaquePointer) {
        self.pointer = pointer
    }
    
    deinit {
        git_object_free(pointer)
    }
}

@Scriptable
public final class Reference {
    internal let pointer: OpaquePointer
    internal let repoPointer: OpaquePointer

    /// Get the OID pointed to by a direct reference.
    var target: Object? {
        guard let id = git_reference_target(pointer) else {
            return nil
        }
        var objectPointer: OpaquePointer?
        let status = git_object_lookup(&objectPointer, repoPointer, id, GIT_OBJECT_ANY)
        guard status == 0, let objectPointer else {
            return nil
        }
        return Object(pointer: objectPointer)
    }

    internal init(pointer: OpaquePointer, repoPointer: OpaquePointer) {
        self.pointer = pointer
        self.repoPointer = repoPointer
    }

    deinit {
        git_reference_free(pointer)
    }
}
