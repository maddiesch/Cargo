//
//  Logger.swift
//  Cargo
//
//  Created by Skylar Schipper on 6/8/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

internal func Log(_ msg: @autoclosure () -> String) {
    #if DEBUG
        print("Cargo: \(msg())")
    #endif
}
