//
//  URL.swift
//  Cargo
//
//  Created by Skylar Schipper on 5/4/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

internal extension URL {
    var isCargoCache: Bool {
        guard let scheme = self.scheme else {
            return false
        }
        if scheme != "cargo" {
            return false
        }
        guard let host = self.host else {
            return false
        }
        return host == "cache"
    }
}
