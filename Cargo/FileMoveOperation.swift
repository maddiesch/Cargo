//
//  FileCleanupOperation.swift
//  Cargo
//
//  Created by Skylar Schipper on 4/25/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

fileprivate struct Location {
    let url: URL
    let name: String
}

internal final class FileMoveOperation: BaseOperation, OperationObserver {
    private let mutex = Mutex()

    init(_ location: URL) {
        self.location = location
    }

    let location: URL

    private var locations: [Location] = []

    override func execute() {
        let locations = self.mutex.synchronized { self.locations }
        do {
            let mover = try self.fileMover()
            if self.location.isFileURL {
                try FileManager.default.createDirectory(at: self.location, withIntermediateDirectories: true, attributes: nil)
            }
            assert(locations.count > 0)
            try locations.forEach { location in
                try mover.moveFile(atLocation: location.url, toTargetLocation: self.location, fileName: location.name)
                assert(!FileManager.default.fileExists(atPath: location.url.path), "The original file must not exist after \(type(of: mover))")
                Log("File Moved - \(location.name)")
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
                let loc = Location(url: url, name: dl.fileName)
                self.mutex.synchronized {
                    self.locations.append(loc)
                }
            }
        }
    }

    func operationDidStart(_ operation: BaseOperation) {
    }
}
