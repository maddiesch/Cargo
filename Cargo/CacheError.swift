//
//  CacheError.swift
//  Cargo
//
//  Created by Skylar Schipper on 5/3/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

let kCacheErrorMetadata = "CARCacheErrorMetadata"

struct CacheError : CustomNSError {
    enum Code : Int {
        case generic
        case invalidFormat
        case convertFailed
        case fingerprintFailed
        case fileNotFound
    }

    let message: String
    let code: Code
    let reason: String?
    let error: Error?
    let metadata: [String: Any]?

    init(_ code: Code, _ message: String, _ reason: String? = nil, _ error: Error? = nil, _ metadata: [String: Any]? = nil) {
        self.code = code
        self.message = message
        self.reason = reason
        self.error = error
        self.metadata = metadata
    }

    // MARK: - Custom Error
    public static var errorDomain: String {
        return "com.skylarsch.CargoCacheError"
    }

    public var errorCode: Int {
        return self.code.rawValue
    }

    public var errorUserInfo: [String : Any] {
        var userInfo: [String : Any] = [
            NSLocalizedDescriptionKey: self.message
        ]

        if let error = self.error {
            userInfo[NSUnderlyingErrorKey] = error
        }

        if let reason = self.reason {
            userInfo[NSLocalizedFailureReasonErrorKey] = reason
        }

        if let meta = self.metadata {
            userInfo[kCacheErrorMetadata] = meta
        }

        return userInfo
    }
}
