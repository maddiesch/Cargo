//
//  String.swift
//  Cargo
//
//  Created by Skylar Schipper on 5/3/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

public extension String {
    internal init?(digest: [UInt8]) {
        var string = ""
        for i in 0..<digest.count {
            string += String(format: "%02x", digest[i])
        }
        self.init(string)
    }
}

extension String {
    subscript (i: Int) -> String {
        return self[Range(i ..< i + 1)]
    }

    func substring(from: Int) -> String {
        return self[Range(min(from, self.count) ..< self.count)]
    }

    func substring(to: Int) -> String {
        return self[Range(0 ..< max(0, to))]
    }

    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds:(lower: max(0, min(self.count, r.lowerBound)), upper: min(self.count, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}
