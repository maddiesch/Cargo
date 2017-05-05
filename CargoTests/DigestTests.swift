//
//  DigestTests.swift
//  Cargo
//
//  Created by Skylar Schipper on 5/4/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import XCTest
@testable import Cargo

class DigestTests: XCTestCase {
    func testFileFingerprintMed() {
        let path = Bundle(for: DigestTests.self).url(forResource: "test-file-med", withExtension: nil)!
        let hash = try! Digest.sha256Fingerprint(fileURL: path)
        let digest = String(digest: hash)!
        XCTAssertEqual(digest, "080acf35a507ac9849cfcba47dc2ad83e01b75663a516279c8b9d243b719643e")
    }
}
