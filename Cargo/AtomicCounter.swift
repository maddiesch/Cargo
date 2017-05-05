//
//  AtomicCounter.swift
//  Cargo
//
//  Created by Skylar Schipper on 5/3/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

internal class AtomicCounter {
    private static let shared = AtomicCounter()

    private let mutex = Mutex()

    private var counter: Int64 = 0

    class var next: Int64 {
        return AtomicCounter.shared.nextValue()
    }

    class var current: Int64 {
        return AtomicCounter.shared.currentValue()
    }

    private func nextValue() -> Int64 {
        return self.mutex.synchronized {
            self.counter += 1
            return self.counter
        }
    }

    private func currentValue() -> Int64 {
        return self.mutex.synchronized {
            return self.counter
        }
    }
}
