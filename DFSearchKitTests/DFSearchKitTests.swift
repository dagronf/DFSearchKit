//
//  DFSearchKitTests.swift
//  DFSearchKitTests
//
//  Created by Darren Ford on 6/5/18.
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
@testable import DFSearchKit

class TempFile
{
	let fileURL: URL = {
		let directory = NSTemporaryDirectory()
		let fileName = NSUUID().uuidString

		// This returns a URL? even though it is an NSURL class method
		return NSURL.fileURL(withPathComponents: [directory, fileName])! as URL
	}()

	deinit
	{
		try? FileManager.default.removeItem(at: fileURL)
	}
}

class DFSearchKitTests: XCTestCase
{
	override func setUp()
	{
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}

	override func tearDown()
	{
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}

	func testSimpleAdd()
	{
		let indexer = DFSKDataIndex.create()
		XCTAssertNotNil(indexer)

		let d1 = url("doc-url://d1.txt")
		XCTAssertTrue(indexer!.add(d1, text: "Today I am feeling fine!"))
	}

	func testSimpleAddWithNoReplace()
	{
		guard let indexer = DFSKDataIndex.create() else
		{
			XCTFail()
			return
		}

		let d1 = url("doc-url://d1.txt")
		XCTAssertTrue(indexer.add(d1, text: "Today I am feeling fine!"))
		indexer.flush()
		XCTAssertEqual(1, indexer.search("fine").count)

		// Verify doc exists
		let docs = indexer.documents()
		XCTAssertTrue(docs.contains(d1))

		// Now, verify that adding a new document with the same url without replace support doesn't update the index
		// The apple api SKIndexAddDocument doesn't return false if the document can't be updated.  Dunno why
		XCTAssertTrue(indexer.add(d1, text: "Today I am feeling blue!", canReplace: false))
		indexer.flush()
		XCTAssertEqual(0, indexer.search("Blue").count)
	}

	func testSimpleSearch()
	{
		guard let indexer = DFSKDataIndex.create() else
		{
			XCTFail()
			return
		}

		let d1 = url("doc-url://d1.txt")
		XCTAssertTrue(indexer.add(d1, text: "Today I am feeling fine!"))

		indexer.flush()

		let result = indexer.search("fine")
		XCTAssertEqual(1, result.count)
		XCTAssertEqual(d1, result[0].url)
	}

	func testSimpleRemove()
	{
		let dataIndexer = DFSKDataIndex.create()
		guard let indexer = dataIndexer else
		{
			XCTFail()
			return
		}

		let d1 = url("doc-url://d1.txt")
		XCTAssertTrue(indexer.add(d1, text: "Today I am feeling fine!"))
		let d2 = url("doc-url://d2.txt")
		XCTAssertTrue(indexer.add(d2, text: "Blue and I dont feel fine"))

		indexer.flush()

		var docs = indexer.documents()
		XCTAssertTrue(docs.contains(d1))
		XCTAssertTrue(docs.contains(d2))

		XCTAssertEqual(1, indexer.search("feeling").count)
		XCTAssertEqual(2, indexer.search("fine").count)
		XCTAssertEqual(1, indexer.search("Blue").count)

		XCTAssertTrue(indexer.remove(url: d2))
		indexer.flush()

		docs = indexer.documents()
		XCTAssertTrue(docs.contains(d1))
		XCTAssertFalse(docs.contains(d2))

		XCTAssertEqual(1, indexer.search("feeling").count)
		XCTAssertEqual(1, indexer.search("fine").count)
		XCTAssertEqual(0, indexer.search("Blue").count)
	}

	func testTwoSearch()
	{
		guard let indexer = DFSKDataIndex.create() else
		{
			XCTFail()
			return
		}

		let d1 = url("doc-url://d1.txt")
		XCTAssertTrue(indexer.add(d1, text: "Today I am feeling fine, thankyou!"))
		
		let d2 = url("doc-url://d2.txt")
		XCTAssertTrue(indexer.add(d2, text: "Today I am feeling blue!"))
		indexer.flush()

		var result = indexer.search("fine")
		XCTAssertTrue(result.count == 1)
		XCTAssertEqual(result[0].url, d1)

		result = indexer.search("Feeling")
		XCTAssertTrue(result.count == 2)

		result = indexer.search("Feeling blue")
		XCTAssertTrue(result.count == 1)
		XCTAssertEqual(result[0].url, d2)
	}

	func testProximitySearch()
	{
		let props = DFSKIndex.CreateProperties(proximityIndexing: true)
		guard let indexer = DFSKDataIndex.create(properties: props) else
		{
			XCTFail()
			return
		}

		let d1 = url("doc-url://d1.txt")
		XCTAssertTrue(indexer.add(d1, text: "Today I am feeling fine, thankyou!"))
		let d2 = url("doc-url://d2.txt")
		XCTAssertTrue(indexer.add(d2, text: "Today I am feeling blue!"))
		indexer.flush()

		var result = indexer.search("Feeling thankyou")
		XCTAssertEqual(1, result.count)
		XCTAssertEqual(result[0].url, d1)

		result = indexer.search("Today blue")
		XCTAssertTrue(result.count == 1)
		XCTAssertEqual(result[0].url, d2)
	}

	func testSimpleSaveLoad()
	{
		guard let indexer = DFSKDataIndex.create() else
		{
			XCTFail()
			return
		}

		let d1 = url("doc-url://d1.txt")
		XCTAssertTrue(indexer.add(d1, text: "Today I am feeling fine, time for lunch!"))
		let d2 = url("doc-url://d2.txt")
		XCTAssertTrue(indexer.add(d2, text: "Caterpillars ate my lunch"))

		indexer.flush()

		var result = indexer.search("feeling")
		XCTAssertEqual(1, result.count)
		XCTAssertEqual(result[0].url, d1)
		result = indexer.search("caterpillars")
		XCTAssertTrue(result.count == 1)
		XCTAssertEqual(result[0].url, d2)
		result = indexer.search("lunch")
		XCTAssertTrue(result.count == 2)

		// Save to data
		let saveData = indexer.save()
		XCTAssertNotNil(saveData)
		indexer.close()

		// Load from the data
		let saveIndex2 = DFSKDataIndex.load(from: saveData!)
		guard let index2 = saveIndex2 else
		{
			XCTFail()
			return
		}

		result = index2.search("feeling")
		XCTAssertEqual(1, result.count)
		result = index2.search("caterpillars")
		XCTAssertEqual(1, result.count)
		result = index2.search("lunch")
		XCTAssertEqual(2, result.count)
	}

	func testSimpleStopWords()
	{
		let props = DFSKIndex.CreateProperties(stopWords: ["Caterpillars"])
		guard let indexer = DFSKDataIndex.create(properties: props) else
		{
			XCTFail()
			return
		}

		let d1 = url("doc-url://d1.txt")
		XCTAssertTrue(indexer.add(d1, text: "Today I am feeling fine, time for lunch!"))
		let d2 = url("doc-url://d2.txt")
		XCTAssertTrue(indexer.add(d2, text: "Caterpillars ate my lunch"))

		indexer.flush()

		var result = indexer.search("caterpillars")
		XCTAssertEqual(0, result.count)
		result = indexer.search("lunch")
		XCTAssertEqual(2, result.count)
		result = indexer.search("feeling")
		XCTAssertTrue(result.count == 1)
		XCTAssertEqual(result[0].url, d1)
	}

	func testSimpleBadData()
	{
		let str: NSString = NSString.init(string: "hello")
		guard let data = str.data(using: String.Encoding.utf8.rawValue) else
		{
			XCTFail()
			return
		}
		XCTAssertNil(DFSKDataIndex.load(from: data))
	}

	func testSimpleCreateWithFile()
	{
		let file = TempFile()
		guard let indexer = DFSKFileIndex.create(with: file.fileURL) else
		{
			XCTFail()
			return
		}

		let d1 = url("doc-url://d1.txt")
		XCTAssertTrue(indexer.add(d1, text: "Today I am feeling fine, thankyou!"))
		let d2 = url("doc-url://d2.txt")
		XCTAssertTrue(indexer.add(d2, text: "Today I am feeling blue!"))
		indexer.flush()

		var result = indexer.search("fine")
		XCTAssertTrue(result.count == 1)
		XCTAssertEqual(result[0].url, d1)

		result = indexer.search("Feeling")
		XCTAssertTrue(result.count == 2)

		result = indexer.search("Feeling blue")
		XCTAssertTrue(result.count == 1)
		XCTAssertEqual(result[0].url, d2)
	}

	/// Attempt to load from a non-existent file
	func testSimpleLoadWithFileFailure()
	{
		let file = TempFile()
		XCTAssertNil(DFSKFileIndex.open(from: file.fileURL, writable: true))
	}

	/// Attempt to create an index on a file that already exists
	func testAttemptCreateOnSameFile()
	{
		let file = TempFile()
		guard DFSKFileIndex.create(with: file.fileURL) != nil else
		{
			XCTFail()
			return
		}

		XCTAssertNil(DFSKFileIndex.create(with: file.fileURL))
	}

	/// Create file index, save and close.  Verify we can open and read
	func testSimpleLoadWithFile()
	{
		// Create a file
		let file = TempFile()
		guard let indexer = DFSKFileIndex.create(with: file.fileURL) else
		{
			XCTFail()
			return
		}

		// Add documents
		let d1 = url("doc-url://d1.txt")
		XCTAssertTrue(indexer.add(d1, text: "Today I am feeling fine, thankyou!"))
		let d2 = url("doc-url://d2.txt")
		XCTAssertTrue(indexer.add(d2, text: "Today I am feeling blue!"))

		indexer.flush()
		XCTAssertEqual(2, indexer.search("Today").count)
		XCTAssertEqual(1, indexer.search("BLUE").count)

		// Save and close
		indexer.save();
		indexer.close();

		// Check to see we can't add after we close
		let d3 = url("doc-url://d3.txt")
		XCTAssertFalse(indexer.add(d3, text: "Noodles and blue caterpillars!"))

		// Open again
		guard let openIndexer = DFSKFileIndex.open(from: file.fileURL, writable: true) else
		{
			XCTFail()
			return
		}

		// Check existing searchs still work
		var result = openIndexer.search("fine")
		XCTAssertTrue(result.count == 1)
		XCTAssertEqual(result[0].url, d1)

		result = openIndexer.search("Feeling")
		XCTAssertEqual(2, result.count)

		result = openIndexer.search("Feeling blue")
		XCTAssertEqual(1, result.count)
		XCTAssertEqual(result[0].url, d2)

		// Try adding a document, see if it survives a save
		let d4 = url("doc-url://d4.txt")
		XCTAssertTrue(openIndexer.add(d4, text: "Noodles and blue caterpillars!"))

		// Save and close
		openIndexer.save()
		openIndexer.close()

		// Open again, check that our changes have saved correctly
		guard let openIndexer2 = DFSKFileIndex.open(from: file.fileURL, writable: true) else
		{
			XCTFail()
			return
		}

		result = openIndexer2.search("Noodles")
		XCTAssertTrue(result.count == 1)
		XCTAssertEqual(result[0].url, d4)

		result = openIndexer2.search("blue")
		XCTAssertTrue(result.count == 2)

		openIndexer2.save()
		openIndexer2.close()

		// Attempt open in read-only mode, attempt to write
		guard let openIndexer3 = DFSKFileIndex.open(from: file.fileURL, writable: false) else
		{
			XCTFail()
			return
		}

		let d5 = url("doc-url://d5.txt")
		XCTAssertTrue(openIndexer3.add(d5, text: "Chocolate caterpillars!"))
		openIndexer3.flush()

		// We shouldn't be able to find the new terms
		XCTAssertEqual(0, openIndexer3.search("chocolate").count)
		XCTAssertEqual(1, openIndexer3.search("Noodles").count)

		// Caterpillar appeared in the first load
		XCTAssertEqual(1, openIndexer3.search("caterpillars").count)
	}

	func testLoadDocumentFromFile()
	{
		let props = DFSKIndex.CreateProperties.init(stopWords: gStopWords)
		guard let indexer = DFSKDataIndex.create(properties: props) else
		{
			XCTFail()
			return
		}

		let text = NSString.init(string: "Caterpillar and gourds!")

		// Write the text to a temporary file and add
		let tempFile = TempFile()
		try? text.write(to: tempFile.fileURL as URL, atomically: true, encoding: String.Encoding.utf8.rawValue)
		XCTAssertTrue(indexer.add(url: tempFile.fileURL, mimeType: "text/plain"))

		// Load in a pdf, and make sure we can load from it
		let apacheURL = self.addApacheLicenseFile(indexer: indexer, canReplace: true)
		XCTAssertTrue(indexer.add(url: apacheURL, mimeType: "application/pdf"))
		indexer.flush()

		let docs = indexer.documents()
		XCTAssertTrue(docs.contains(apacheURL))

		// Check for terms only in the text
		var result = indexer.search("gourds")
		XCTAssertEqual(1, result.count)
		XCTAssertEqual(result[0].url, tempFile.fileURL)

		// Check for terms only in the pdf
		result = indexer.search("license")
		XCTAssertEqual(1, result.count)
		XCTAssertEqual(result[0].url, apacheURL)
		result = indexer.search("Licensor")
		XCTAssertEqual(1, indexer.search("Licensor").count)
		XCTAssertEqual(result[0].url, apacheURL)

		// Because of our stop words, 'the' and 'and' should not exist at all
		XCTAssertEqual(0, indexer.search("the").count)
		XCTAssertEqual(0, indexer.search("and").count)
	}

	func testTermFrequenciesSimple()
	{
		let props = DFSKIndex.CreateProperties.init(stopWords: [ "the" ])
		guard let indexer = DFSKDataIndex.create(properties: props) else
		{
			XCTFail()
			return
		}

		let d1 = url("doc-url://d1.txt")
		XCTAssertTrue(indexer.add(d1, text: "cat dog dog the fish fish fish"))

		indexer.flush()

		// Make sure we can't find 'the'
		XCTAssertEqual(0, indexer.search("the").count)
		XCTAssertEqual(1, indexer.search("cat").count)
		XCTAssertEqual(1, indexer.search("dog").count)
		XCTAssertEqual(1, indexer.search("fish").count)

		// Terms and counts
		let termFreq = indexer.termsAndCounts(for: d1)
		XCTAssertEqual(3, termFreq.count)

		var term = termFreq.filter({ $0.term == "cat" })
		XCTAssertEqual(1, term.count)
		XCTAssertEqual(1, term.first?.count)
		term = termFreq.filter({ $0.term == "dog" })
		XCTAssertEqual(1, term.count)
		XCTAssertEqual(2, term.first?.count)
		term = termFreq.filter({ $0.term == "fish" })
		XCTAssertEqual(1, term.count)
		XCTAssertEqual(3, term.first?.count)
	}

	func testTermFrequenciesComplex()
	{
		let props = DFSKIndex.CreateProperties.init(stopWords: gStopWords)
		guard let indexer = DFSKDataIndex.create(properties: props) else
		{
			XCTFail()
			return
		}

		// Load in a pdf, and make sure we can load from it
		let filePath = self.addApacheLicenseFile(indexer: indexer, canReplace: true)
		indexer.flush()

		// Grab the frequencies for the pdf document
		let termFreq = indexer.termsAndCounts(for: filePath)

		// Check that some of the terms exist
		var theTerm = termFreq.filter { $0.term == "licensor" }
		XCTAssertEqual(1, theTerm.count)
		XCTAssertEqual(10, theTerm[0].count)

		// Stop words should have remove the 'and'
		theTerm = termFreq.filter { $0.term == "and" }
		XCTAssertEqual(0, theTerm.count)

		// Stop words should have removed 'the'
		theTerm = termFreq.filter { $0.term == "the" }
		XCTAssertEqual(0, theTerm.count)
	}
}

// MARK: Utilities

extension DFSearchKitTests
{
	func url(_ val: String) -> URL
	{
		return URL(string: val)!
	}

	func addApacheLicenseFile(indexer: DFSKIndex, canReplace: Bool) -> URL
	{
		let testBundle = Bundle(for: type(of: self))
		let filePath = testBundle.url(forResource: "APACHE_LICENSE", withExtension: "pdf")
		XCTAssertNotNil(filePath)

		XCTAssertTrue(indexer.add(url: filePath!, mimeType: "application/pdf", canReplace: canReplace))
		return filePath!
	}
}
