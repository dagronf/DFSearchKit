//
//  DSSummaryTests.swift
//  DFSearchKitTests
//
//  Created by Darren Ford on 9/6/18.
//  Copyright © 2018 Darren Ford. All rights reserved.
//
//  MIT license
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
//  documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial
//  portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
//  WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
//  OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
//  OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import XCTest
import DFSearchKit

class DFSearchIndexSummaryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

	func testSimpleSummary()
	{
		let testBundle = Bundle(for: type(of: self))
		let filePath = testBundle.url(forResource: "the_school_short_story", withExtension: "txt")
		XCTAssertNotNil(filePath)

		let text = try? String.init(contentsOf: filePath!)

		let summary = DFSummary(text!)

		let count = summary.sentenceCount()
		XCTAssertEqual(91, count)

		let res = summary.sentenceSummary(maxSentences: 5)
		XCTAssertEqual(5, res.count)

		let paraCount = summary.paragraphCount()
		XCTAssertEqual(25, paraCount)

		let paraRes = summary.paragraphSummary(maxParagraphs: 5)
		XCTAssertEqual(5, paraRes.count)
	}

}
