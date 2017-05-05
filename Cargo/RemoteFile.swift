//
//  RemoteFile.swift
//  Cargo
//
//  Created by Skylar Schipper on 4/26/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

/// A remote file to fetch from a server
@objc(CARRemoteFile)
public final class RemoteFile: NSObject {
    /// The remote URL of the file
    public let url: URL

    /// The file name for the downloaded file
    public let fileName: String

    /// An ID for the file being downloaded
    @objc(fileID)
    public let id: Int64

    /// Create a new remote file
    ///
    /// - Parameters:
    ///   - url: The URL
    ///   - fileName: The filename
    public init(url: URL, fileName: String) {
        self.id = AtomicCounter.next
        self.url = url
        self.fileName = fileName
    }
}
