//
//  Progress.swift
//  Cargo
//
//  Created by Skylar Schipper on 4/27/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

@objc(CARProgress)
public final class Progress : NSObject {
    let bytesWritten: Int64
    let totalBytesWritten: Int64
    let totalBytesExpectedToWrite: Int64

    public let fileName: String
    public let fileID: Int64

    public let progress: Float

    init(_ written: Int64, _ totalWritten: Int64, _ expected: Int64, _ name: String, _ fileID: Int64) {
        self.bytesWritten = written
        self.totalBytesWritten = totalWritten
        self.totalBytesExpectedToWrite = expected
        self.fileName = name
        self.fileID = fileID
        if expected > 0 {
            self.progress = Float(Double(totalWritten) / Double(expected))
        } else {
            self.progress = 0.0
        }
    }
}
