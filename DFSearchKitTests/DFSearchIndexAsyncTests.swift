//
//  DFIndexAsyncTests.swift
//  DFSearchKitTests
//
//  Created by Darren Ford on 22/6/18.
//  Copyright © 2019 Darren Ford. All rights reserved.
//

import XCTest
@testable import DFSearchKit

class SpyDelegate: DFSearchIndexAsyncControllerProtocol
{
	func queueDidEmpty(_ indexer: DFSearchIndex.AsyncController)
	{
	}

	func queueDidChange(_ indexer: DFSearchIndex.AsyncController, count: Int)
	{
	}
}

class DFSearchIndexAsyncTests: XCTestCase {

	func testAsync() {
		guard let indexer = DFSearchIndex.Memory.Create() else {
			XCTFail()
			return
		}

		let testBundle = Bundle(for: type(of: self))
		let filePath = testBundle.url(forResource: "APACHE_LICENSE", withExtension: "pdf")!
		let txtPath = testBundle.url(forResource: "the_school_short_story", withExtension: "txt")!

		let spyDelegate = SpyDelegate()
		let asyncController = DFSearchIndex.AsyncController(index: indexer, delegate: spyDelegate)

		// MARK: Add async

		let fileTask = DFSearchIndex.AsyncController.FilesTask([filePath, txtPath])

		let addExpectation = self.expectation(description: "AsyncAdd")
		asyncController.addURLs(async: fileTask, flushWhenComplete: true, complete: { task in
			if task.urls == [filePath, txtPath] {
				addExpectation.fulfill()
			}
		})

		waitForExpectations(timeout: 1) { error in
			if let error = error {
				XCTFail("waitForExpectationsWithTimeout errored: \(error)")
			}
		}

		var result = indexer.search("apache")
		XCTAssertEqual(1, result.count)
		XCTAssertEqual(filePath, result[0].url)

		result = indexer.search("grappled")
		XCTAssertEqual(1, result.count)
		XCTAssertEqual(txtPath, result[0].url)

		// MARK: Remove async

		let removeExpectation = self.expectation(description: "AsyncRemove")
		let removeTask = DFSearchIndex.AsyncController.FilesTask([txtPath])
		asyncController.removeURLs(async: removeTask, complete: { task in
			if task.urls == [txtPath] {
				removeExpectation.fulfill()
			}
		})

		waitForExpectations(timeout: 1) { error in
			if let error = error {
				XCTFail("waitForExpectationsWithTimeout errored: \(error)")
			}
		}

		indexer.flush()

		result = indexer.search("apache")
		XCTAssertEqual(1, result.count)
		XCTAssertEqual(filePath, result[0].url)

		result = indexer.search("grappled")
		XCTAssertEqual(0, result.count)
	}

	func testAsyncCancel() {
		guard let indexer = DFSearchIndex.Memory.Create() else {
			XCTFail()
			return
		}

		let spyDelegate = SpyDelegate()
		let asyncController = DFSearchIndex.AsyncController(index: indexer, delegate: spyDelegate)

		var tasks: [DFSearchIndex.AsyncController.TextTask] = []
		for count in 0 ..< 2500
		{
			let urlstr = "doc-url://d\(count).txt"
			let d1 = DFUtils.url(urlstr)
			tasks.append(DFSearchIndex.AsyncController.TextTask(url: d1, text: "cat dog fish"))
		}

		let completeExpectation = self.expectation(description: "completeExpectation")
		let cancelExpectation = self.expectation(description: "cancelExpectation")

		asyncController.addText(async: tasks) { _ in
			/// We should always receive the complete notification, even if we're cancelled
			completeExpectation.fulfill()
		}

		asyncController.cancelCurrent {
			/// We have been cancelled
			cancelExpectation.fulfill()
		}

		waitForExpectations(timeout: 10) { error in
			if let error = error {
				XCTFail("waitForExpectationsWithTimeout errored: \(error)")
			}
		}

		indexer.flush()

		/// We shouldn't have 2500 of these as we cancelled (this is a dodgy test)
		XCTAssertNotEqual(2500, indexer.search("dog").count)
	}
}
