//
//  FileCleanupOperation.swift
//  Cargo
//
//  Created by Skylar Schipper on 4/25/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

typealias Location = (URL, String)

internal final class FileMoveOperation: BaseOperation, OperationObserver {
    let mutex = Mutex()

    init(_ location: URL) {
        self.location = location
    }

    let location: URL

    var locations: [Location] = []

    override func execute() {
        let locations = self.mutex.synchronized { self.locations }
        do {
            let mover = self.fileMover()
            if self.location.isFileURL {
                try FileManager.default.createDirectory(at: self.location, withIntermediateDirectories: true, attributes: nil)
            }
            try locations.forEach { url, name in
                try mover.moveFile(atLocation: url, toTargetLocation: self.location, fileName: name)
                try? FileManager.default.removeItem(at: url)
            }
            Log("File Moved \(location.lastPathComponent)")
            self.finish()
        } catch {
            self.finish(error)
        }
    }

    func fileMover() -> FileMover {
        if self.location.isCargoCache {
            let parts = self.location.path.components(separatedBy: "/").filter { $0.characters.count > 0 }
            if let key = parts.first {
                return CacheFileMover(cacheKey: key)
            }
            assert(false, "Missing cache key.  Can't save file into cache without one")
        }
        return BasicFileMover()
    }

    func operation(_ operation: BaseOperation, didCompleteWithError error: Error?) {
        if let dl = operation as? DownloadOperation {
            if let url = dl.location {
                self.mutex.synchronized {
                    let loc: Location = (url, dl.fileName)
                    self.locations.append(loc)
                }
            }
        }
    }

    func operationDidStart(_ operation: BaseOperation) {
    }
}
