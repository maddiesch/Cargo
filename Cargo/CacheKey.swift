//
//  CacheKey.swift
//  Cargo
//
//  Created by Skylar Schipper on 5/3/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

struct CacheKey {
    let prefix: String
    let key: String

    init(rawKey: String) throws {
        let value = try CacheKey.normailize(rawKey)
        self.key = value
        self.prefix = value.substring(to: 1)
    }

    func location(_ base: URL) -> URL {
        return base.appendingPathComponent(self.prefix).appendingPathComponent(self.key)
    }

    static func normailize(_ key: String) throws -> String {
        guard let data = key.data(using: .utf8) else {
            throw CacheError(.invalidFormat, "Can't cache item", "Key isn't valid UTF-8 string")
        }
        let digest = data.withUnsafeBytes {
            return Digest.md5(bytes: $0, length: UInt32(data.count))
        }
        guard let hex = String(digest: digest) else {
            throw CacheError(.convertFailed, "Can't cache item", "Failed to create the cache key from digest")
        }
        return hex
    }
}
