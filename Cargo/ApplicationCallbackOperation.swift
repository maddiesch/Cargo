//
//  ApplicationCallbackOperation.swift
//  Cargo
//
//  Created by Skylar Schipper on 4/25/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

internal final class ApplicationCallbackOperation: BaseOperation {
    init(_ container: Container) {
        super.init()
        self.container = container
    }
    var block: ((Container) -> (Void))? = nil

    override func execute() {
        guard let container = self.container else {
            self.finish()
            return
        }
        self.block?(container)
        self.block = nil
        self.finish()
    }
}
