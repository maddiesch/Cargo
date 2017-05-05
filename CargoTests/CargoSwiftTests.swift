//
//  CargoSwiftTests.swift
//  Cargo
//
//  Created by Skylar Schipper on 5/3/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import XCTest
@testable import Cargo

class CargoSwiftTests : XCTestCase {
    let data = "Test Hash String".data(using: .utf8)!

    func testDigestSupport() {
        let hash: [UInt8] = data.withUnsafeBytes {
            return Digest.md5(bytes: $0, length: UInt32(data.count))
        }

        let string = String(digest: hash)

        XCTAssertNotNil(string)
        XCTAssertEqual(string, "9d371fbd7541c50a3dc667cc1d30a962")
    }
}
