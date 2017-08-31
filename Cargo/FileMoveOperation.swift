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
            let mover = try self.fileMover()
            if self.location.isFileURL {
                try FileManager.default.createDirectory(at: self.location, withIntermediateDirectories: true, attributes: nil)
            }
            try locations.forEach { url, name in
                try mover.moveFile(atLocation: url, toTargetLocation: self.location, fileName: name)
                assert(!FileManager.default.fileExists(atPath: url.path), "The original file must not exist after \(type(of: mover))")
                Log("File Moved - \(name)")
            }
            self.finish()
        } catch {
            self.finish(error)
        }
    }

    func fileMover() throws -> FileMover {
        if self.location.isCargoCache {
            guard let components = URLComponents(url: self.location, resolvingAgainstBaseURL: false) else {
                throw CacheError(.invalidURL, "The cargo cache URL seems to be invalid")
            }
            let parts = components.path.components(separatedBy: "/").filter { $0.characters.count > 0 }
            let isVisible = components.queryItems?.first { $0.name == "isVisible" }?.value ?? "true"

            if let key = parts.first {
                return CacheFileMover(cacheKey: key, isVisible: isVisible == "true")
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
