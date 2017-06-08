//
//  Container.swift
//  Cargo
//
//  Created by Skylar Schipper on 4/25/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

/// The container for downloading all the files.
@objc(CARContainer)
public final class Container: NSObject {
    private let mutex = Mutex()

    /// A user displayable name for the container
    public let name: String

    /// A global ID for the container
    @objc(containerID)
    public let id: UUID = UUID()

    public private(set) weak var manager: Manager? = nil

    /// The directory where the files will be saved.
    ///
    /// If this is a file url downloaded files will be moved into that directory
    /// If it is cargo://cache/<cache key> then files will be moved into the managed cache
    public let location: URL

    // MARK: - Progress Tracking
    public var totalDownloads: Int {
        return self.mutex.synchronized { self._totalDownloads }
    }
    private var _totalDownloads: Int = 0

    public var completedDownloads: Int {
        return self.mutex.synchronized { self._completedDownloads }
    }
    private var _completedDownloads: Int = 0

    /// Create a new Container with the passed destination
    ///
    /// - Parameters:
    ///   - location: The directory where files will be saved.
    ///   - name: The human displayable name for the container
    public init(location: URL, name: String) {
        self.location = location
        self.name = name
    }

    /// All errors collected from the container processing
    public var allErrors: [Error]? {
        return self.mutex.synchronized {
            if self.errors.count == 0 {
                return nil
            }
            return self.errors
        }
    }

    internal func addError(_ error: Error?) {
        guard let e = error else {
            return
        }
        self.mutex.synchronized {
            self.errors.append(e)
        }
    }

    private var errors: [Error] = []

    // MARK: - URLs
    private var files: Set<RemoteFile> = []

    /// Get all files added to this container
    public var allFiles: [RemoteFile] {
        return self.mutex.synchronized { return Array(self.files) }
    }

    /// Add a file to be downloaded by the container
    ///
    /// - Parameters:
    ///   - url: The remote url to fetch
    ///   - fileName: The target file name.  E.G. `image-1.png`
    /// - Returns: The File ID for the added remote file
    @objc(addURL:fileName:)
    @discardableResult
    public func add(url: URL, fileName: String) -> Int64 {
        let file = RemoteFile(url: url, fileName: fileName)
        self.add(file: file)
        return file.id
    }

    /// Add a RemoteFile
    ///
    /// - Parameter file: The file to fetch
    @objc(addFile:)
    public func add(file: RemoteFile) {
        self.mutex.synchronized {
            self.files.insert(file)
        }
    }

    // MARK: - Completion
    /// An optional completion block what will be called once all downloads are finished.
    public var completion: ((Container) -> (Void))? = nil

    // MARK: - Scheduling
    /// Is the Container scheduled
    public var isScheduled: Bool {
        return self.mutex.synchronized { return self._isScheduled }
    }

    private var _isScheduled: Bool = false

    internal func schedule(withManager manager: Manager, inQueue queue: OperationQueue) throws {
        try self.mutex.synchronized {
            try self._schedule(queue)
            self.manager = manager
            self._isScheduled = true
        }
    }

    private func _schedule(_ queue: OperationQueue) throws {
        let callback = ApplicationCallbackOperation(self)
        callback.container = self
        callback.block = self.completion

        self.files.forEach { file in
            let download = DownloadOperation(url: file.url, fileName: file.fileName, fileID: file.id)
            download.container = self

            let move = FileMoveOperation(self.location)
            move.container = self

            download.observers.addObserver(move)

            move.addDependency(download)
            callback.addDependency(move)

            queue.addOperation(move)
            queue.addOperation(download)
            _totalDownloads += 1
        }

        queue.addOperation(callback)
    }

    // MARK: - Progress
    internal func updateProgress(_ bytesWritten: Int64, _ totalBytesWritten: Int64, _ totalBytesExpected: Int64, op: DownloadOperation) {
        guard let manager = self.manager else {
            return
        }
        let progress = Progress(bytesWritten, totalBytesWritten, totalBytesExpected, op.fileName, op.fileID)
        manager.forEachObserver {
            $0.manager?(manager, didProgress: progress, forContainer: self)
        }
    }

    internal func updateDownloadFinished(_ dl: DownloadOperation) {
        self.mutex.synchronized {
            self._completedDownloads += 1
        }
        guard let manager = self.manager else {
            return
        }
        let fileID = dl.fileID
        manager.forEachObserver {
            $0.manager?(manager, completedDownload: fileID, forContainer: self)
        }
    }
}
