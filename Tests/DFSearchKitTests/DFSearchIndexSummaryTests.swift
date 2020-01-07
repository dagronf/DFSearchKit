//
//  DSSummaryTests.swift
//  DFSearchKitTests
//
//  Created by Darren Ford on 9/6/18.
//  Copyright © 2019 Darren Ford. All rights reserved.
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

import DFSearchKit
import XCTest

class DFSearchIndexSummaryTests: XCTestCase {

	fileprivate func bundleResourceURL(forResource name: String, withExtension ext: String) -> URL {
		let thisSourceFile = URL(fileURLWithPath: #file)
		var thisDirectory = thisSourceFile.deletingLastPathComponent()
		thisDirectory = thisDirectory.appendingPathComponent("Resources")
		thisDirectory = thisDirectory.appendingPathComponent(name + "." + ext)
		return thisDirectory
	}

	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}

	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}

	func testSmallTextSampleSummary() {
		// HEART OF DARKNESS
		// By Joseph Conrad
		let text =
			"""
			The Nellie, a cruising yawl, swung to her anchor without a flutter of the sails, and was at rest. The flood had made, the wind was nearly calm, and being bound down the river, the only thing for it was to come to and wait for the turn of the tide.
			The sea-reach of the Thames stretched before us like the beginning of an interminable waterway. In the offing the sea and the sky were welded together without a joint, and in the luminous space the tanned sails of the barges drifting up with the tide seemed to stand still in red clusters of canvas sharply peaked, with gleams of varnished sprits. A haze rested on the low shores that ran out to sea in vanishing flatness. The air was dark above Gravesend, and farther back still seemed condensed into a mournful gloom, brooding motionless over the biggest, and the greatest, town on earth.
			The Director of Companies was our captain and our host. We four affectionately watched his back as he stood in the bows looking to seaward. On the whole river there was nothing that looked half so nautical. He resembled a pilot, which to a seaman is trustworthiness personified. It was difficult to realize his work was not out there in the luminous estuary, but behind him, within the brooding gloom.
			"""

		let summary = DFSearchIndex.Summarizer(text)

		let paraCount = summary.paragraphCount()
		XCTAssertEqual(3, paraCount)

		var paraSummary = summary.paragraphSummary(maxParagraphs: 1)
		XCTAssertEqual(1, paraSummary.count)

		paraSummary = summary.paragraphSummary(maxParagraphs: 3)
		XCTAssertEqual(3, paraSummary.count)

		let count = summary.sentenceCount()
		XCTAssertEqual(11, count)

		let sentenceSummaries = summary.sentenceSummary()
		XCTAssertEqual(11, sentenceSummaries.count)
	}

	func testSimpleSummary() {
		let filePath = bundleResourceURL(forResource: "the_school_short_story", withExtension: "txt")

		guard let text = try? String(contentsOf: filePath) else {
			XCTAssert(false, "Couldn't open support file")
			return
		}

		let summary = DFSearchIndex.Summarizer(text)

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
