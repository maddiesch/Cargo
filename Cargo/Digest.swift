//
//  Digest.swift
//  Cargo
//
//  Created by Skylar Schipper on 5/3/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation
import CommonCrypto

internal enum FingerprintError : Error {
    case createStreamError
    case streamOpenError
    case contextInitFailed
    case readError
    case hashUpdateError
    case failedToFetchFinal
}

internal struct Digest {
    static func md5(bytes: UnsafeRawPointer, length: UInt32) -> [UInt8] {
        var hash = [UInt8].init(repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        CC_MD5(bytes, length, &hash)
        return hash
    }

    static func sha256Fingerprint(fileURL url: URL) throws -> [UInt8] {
        guard let read: CFReadStream = CFReadStreamCreateWithFile(kCFAllocatorDefault, url as CFURL) else {
            throw FingerprintError.createStreamError
        }

        guard CFReadStreamOpen(read) else {
            throw FingerprintError.streamOpenError
        }

        defer {
            CFReadStreamClose(read)
        }

        var context = CC_SHA256_CTX()
        let initCode = withUnsafeMutablePointer(to: &context) {
            return CC_SHA256_Init($0)
        }
        guard initCode == 1 else {
            throw FingerprintError.contextInitFailed
        }

        let chunkSize = 4096
        var hasData = true
        while hasData {
            var buffer = [UInt8].init(repeating: 0, count: chunkSize)
            let count = CFReadStreamRead(read, &buffer, buffer.count)
            switch count {
            case -1:
                throw FingerprintError.readError
            case 0:
                hasData = false
            default:
                guard CC_SHA256_Update(&context, buffer, CC_LONG(count)) == 1 else {
                    throw FingerprintError.hashUpdateError
                }
            }
        }

        var digest = [UInt8].init(repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        guard CC_SHA256_Final(&digest, &context) == 1 else {
            throw FingerprintError.failedToFetchFinal
        }

        return digest
    }
}
