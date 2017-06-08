//
//  DownloadOperation.swift
//  Cargo
//
//  Created by Skylar Schipper on 4/25/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

internal final class DownloadOperation: BaseOperation {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default

        let session = URLSession(configuration: config, delegate: SessionDelegator(), delegateQueue: OperationQueue())

        return session
    }()

    internal private(set) var location: URL? = nil

    let url: URL
    let fileName: String
    let fileID: Int64

    init(url: URL, fileName: String, fileID: Int64) {
        self.url = url
        self.fileName = fileName
        self.fileID = fileID
    }

    override func execute() {
        let task = DownloadOperation.session.downloadTask(with: self.url)
        Log("Download > \(self.url.lastPathComponent)")
        if let delegator = DownloadOperation.session.delegate as? SessionDelegator {
            delegator.add(taskIdentifier: task.taskIdentifier, operation: self)
        }
        task.resume()
    }

    internal func finished(downloadingFileAtLocation location: URL) {
        self.location = location
        self.finish()
    }

    override func operation(completedWithError error: Error?) {
        super.operation(completedWithError: error)
        self.container?.updateDownloadFinished(self)
    }
}
