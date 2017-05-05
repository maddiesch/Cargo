//
//  MultiDownloadOperation.swift
//  Cargo
//
//  Created by Skylar Schipper on 4/25/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

internal final class MultiDownloadOperation: BaseOperation, OperationObserver {
    override func execute() {
        self.finish()
    }

    func operationDidStart(_ operation: BaseOperation) {
    }

    func operation(_ operation: BaseOperation, didCompleteWithError error: Error?) {
    }
}
