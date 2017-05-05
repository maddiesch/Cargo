//
//  SessionDelegator.swift
//  Cargo
//
//  Created by Skylar Schipper on 4/25/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

internal final class SessionDelegator : NSObject, URLSessionDownloadDelegate {
    let mutex = Mutex()

    private var taskMap: [Int: DownloadOperation] = [:]

    internal func add(taskIdentifier id: Int, operation op: DownloadOperation) {
        self.mutex.synchronized {
            self.taskMap[id] = op
        }
    }

    internal func remove(taskIdentifer id: Int) {
        self.mutex.synchronized {
            self.taskMap.removeValue(forKey: id)
        }
    }

    private func operation(forID id: Int) -> DownloadOperation? {
        return self.mutex.synchronized {
            return self.taskMap[id]
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let op = self.operation(forID: task.taskIdentifier) {
            self.remove(taskIdentifer: task.taskIdentifier)
            op.finish(error)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let op = self.operation(forID: downloadTask.taskIdentifier) {
            do {
                let tmp = NSTemporaryDirectory().appending("cargo-\(UUID().uuidString).tmp")
                let url = URL(fileURLWithPath: tmp)
                try FileManager.default.moveItem(at: location, to: url)
                op.finished(downloadingFileAtLocation: url)
            } catch {
                op.finish(error)
            }
        }
        self.remove(taskIdentifer: downloadTask.taskIdentifier)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if let op = self.operation(forID: downloadTask.taskIdentifier) {
            guard let container = op.container else {
                return
            }
            container.updateProgress(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite, op: op)
        }
    }
}
