//
//  FileMover.swift
//  Cargo
//
//  Created by Skylar Schipper on 4/26/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

protocol FileMover {
    func moveFile(atLocation url: URL, toTargetLocation target: URL, fileName: String) throws
}

final class BasicFileMover : FileMover {
    func moveFile(atLocation url: URL, toTargetLocation target: URL, fileName: String) throws {
        let final = target.appendingPathComponent(fileName)
        try FileManager.default.moveItem(at: url, to: final)
    }
}

final class CacheFileMover : FileMover {
    public let cacheKey: String
    public let isVisible: Bool

    public init(cacheKey: String, isVisible: Bool) {
        self.cacheKey = cacheKey
        self.isVisible = isVisible
    }

    func moveFile(atLocation url: URL, toTargetLocation target: URL, fileName: String) throws {
        try Cache.shared.prepareIfNeeded()
        try Cache.shared.move(fileAtLocation: url, intoCacheForKey: self.cacheKey, withName: fileName, isVisible: self.isVisible)
    }
}
