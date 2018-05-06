//
//  DFSearchKitTests.swift
//  DFSearchKitTests
//
//  Created by Darren Ford on 6/5/18.
//  Copyright © 2018 Darren Ford. All rights reserved.
//

import XCTest
@testable import DFSearchKit

class DFSearchKitTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

	func testSimpleAdd() {
		let indexer = DFSKIndexer()
		XCTAssertTrue(indexer.add(document: NSURL(string: "doc-url://d1.txt")!,
								  text: "Today I am feeling fine!"))
	}

    func testSimpleSearch() {
		let indexer = DFSKIndexer()
		XCTAssertTrue(indexer.add(document: NSURL(string: "doc-url://d1.txt")!,
								  text: "Today I am feeling fine!"))
		indexer.flush()

		let result = indexer.search("fine")
		XCTAssertTrue(result.count == 1)
    }

	func testTwoSearch() {
		let indexer = DFSKIndexer()
		XCTAssertTrue(indexer.add(document: NSURL(string: "doc-url://d1.txt")!,
								  text: "Today I am feeling fine, thankyou!"))
		XCTAssertTrue(indexer.add(document: NSURL(string: "doc-url://d2.txt")!,
								  text: "Today I am feeling blue!"))
		indexer.flush()

		var result = indexer.search("fine")
		XCTAssertTrue(result.count == 1)
		XCTAssertEqual(result[0].0.urlID, NSURL(string: "doc-url://d1.txt")!)

		result = indexer.search("Feeling")
		XCTAssertTrue(result.count == 2)

		result = indexer.search("Feeling blue")
		XCTAssertTrue(result.count == 1)
		XCTAssertEqual(result[0].0.urlID, NSURL(string: "doc-url://d2.txt")!)
	}

	func testProximitySearch() {

		let indexer = DFSKIndexer(proximityIndexing: true)
		XCTAssertTrue(indexer.add(document: NSURL(string: "doc-url://d1.txt")!,
								  text: "Today I am feeling fine, thankyou!"))
		XCTAssertTrue(indexer.add(document: NSURL(string: "doc-url://d2.txt")!,
								  text: "Today I am feeling blue!"))
		indexer.flush()

		var result = indexer.search("Feeling thankyou")
		XCTAssertTrue(result.count == 1)
		XCTAssertEqual(result[0].0.urlID, NSURL(string: "doc-url://d1.txt")!)

		result = indexer.search("Today blue")
		XCTAssertTrue(result.count == 1)
		XCTAssertEqual(result[0].0.urlID, NSURL(string: "doc-url://d2.txt")!)
	}

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
