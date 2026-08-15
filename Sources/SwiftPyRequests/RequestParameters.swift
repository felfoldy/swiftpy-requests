//
//  RequestParameters.swift
//  swiftpy-requests
//
//  Created by Tibor Felföldy on 2026-08-14.
//

import Foundation
import SwiftPy

/// The everyday Requests call parameters, resolved into a single `URLRequest`.
///
/// Bodies are encoded up front, on the main actor, so no Python object has to be
/// touched once the transport starts awaiting.
@MainActor
struct RequestParameters {
    let method: String
    let url: String
    let params: [String: Any]?
    let data: PyObject?
    let json: PyObject?
    let headers: [String: String]?
    let timeout: Double?
    let allowRedirects: Bool

    init(
        method: String,
        url: String,
        params: [String: Any]? = nil,
        data: PyObject? = nil,
        json: PyObject? = nil,
        headers: [String: String]? = nil,
        timeout: Double? = nil,
        allowRedirects: Bool = true
    ) {
        self.method = method.uppercased()
        self.url = url
        self.params = params
        // A `None` body arrives as a real Python object; treat it as absent so
        // `data` and `json` can be told apart from an omitted argument.
        self.data = data.flatMap { $0.reference.isNone ? nil : $0 }
        self.json = json.flatMap { $0.reference.isNone ? nil : $0 }
        self.headers = headers
        self.timeout = timeout
        self.allowRedirects = allowRedirects
    }

    /// Builds the request with its query, body, headers, and timeout applied.
    func urlRequest() throws(PythonError) -> URLRequest {
        if data != nil && json != nil {
            throw PythonError.ValueError("Cannot pass both data and json")
        }

        guard var components = URLComponents(string: url) else {
            throw PythonError.ValueError("Invalid URL: \(url)")
        }

        // `params` extends whatever query the URL already carries.
        if let query = Self.urlEncoded(params) {
            let existing = components.percentEncodedQuery
            components.percentEncodedQuery = [existing, query]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: "&")
        }

        guard let url = components.url else {
            throw PythonError.ValueError("Invalid URL: \(self.url)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        if let body = try body() {
            request.httpBody = body.content
            if let contentType = body.contentType {
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
        }

        // Explicit headers are applied last so they can override the content
        // type inferred from the body.
        for (field, value) in headers ?? [:] {
            request.setValue(value, forHTTPHeaderField: field)
        }

        if let timeout {
            // An idle timeout: it resets for as long as bytes keep arriving, so
            // slow but steady downloads don't fail.
            request.timeoutInterval = timeout
        }

        return request
    }
}

// MARK: - Body encoding

private extension RequestParameters {
    struct Body {
        let content: Data
        let contentType: String?
    }

    /// Encodes `json` or `data` into the request body.
    ///
    /// `data` accepts the three shapes Requests does: a mapping is form encoded,
    /// a string is sent as UTF-8 text, and bytes are sent verbatim.
    func body() throws(PythonError) -> Body? {
        if let json {
            guard let text: String = try py.module("json")?.dumps?(json) else {
                throw PythonError.ValueError("Could not serialize json")
            }
            return Body(content: Data(text.utf8), contentType: "application/json")
        }

        guard let data else { return nil }

        if let fields = [String: Any](data) {
            let encoded = Self.urlEncoded(fields) ?? ""
            return Body(
                content: Data(encoded.utf8),
                contentType: "application/x-www-form-urlencoded"
            )
        }

        if let text = String(data) {
            return Body(content: Data(text.utf8), contentType: nil)
        }

        if let content = Data(data) {
            return Body(content: content, contentType: nil)
        }

        throw PythonError.TypeError("data must be a dict, str or bytes")
    }
}

// MARK: - Form encoding

private extension RequestParameters {
    /// The unreserved set from RFC 3986. Everything else is escaped, so values
    /// containing `+`, `&`, or spaces survive a round trip intact.
    static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    /// Encodes a mapping as `key=value` pairs for a query string or form body.
    ///
    /// Returns `nil` when there is nothing to encode. Keys are sorted because
    /// the Swift dictionary the bridge produces has no meaningful order.
    static func urlEncoded(_ fields: [String: Any]?) -> String? {
        guard let fields, !fields.isEmpty else { return nil }

        let pairs = fields
            .sorted { $0.key < $1.key }
            .flatMap { key, value in
                encodedValues(of: value).map { value in
                    "\(percentEncoded(key))=\(percentEncoded(value))"
                }
            }

        return pairs.isEmpty ? nil : pairs.joined(separator: "&")
    }

    /// Flattens one field value into the strings it contributes: a list expands
    /// into repeated keys and `None` drops out entirely.
    static func encodedValues(of value: Any) -> [String] {
        switch value {
        case let list as [Any?]:
            return list.compactMap { $0 }.flatMap(encodedValues(of:))
        case let bool as Bool:
            // Requests sends Python's spelling of a bool.
            return [bool ? "True" : "False"]
        case let string as String:
            return [string]
        case let int as Int:
            return [String(int)]
        case let double as Double:
            return [String(double)]
        default:
            return [String(describing: value)]
        }
    }

    static func percentEncoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value
    }
}
