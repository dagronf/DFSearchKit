//
//  DFSearchKitTests.swift
//  DFSearchKitTests
//
//  Created by Darren Ford on 6/5/18.
//  Copyright © 2018 Darren Ford. All rights reserved.
//

import XCTest
@testable import DFSearchKit

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

	func url(_ val: String) -> URL
	{
		return URL(string: val)!
	}

	func testSimpleAdd()
	{
		let indexer = DFSKDataIndex.create()
		XCTAssertNotNil(indexer)

		let d1 = url("doc-url://d1.txt")
		XCTAssertTrue(indexer!.add(d1, text: "Today I am feeling fine!"))
	}

	func testSimpleSearch()
	{
		let indexer = DFSKDataIndex.create()
		XCTAssertNotNil(indexer)

		let d1 = url("doc-url://d1.txt")
		XCTAssertTrue(indexer!.add(d1, text: "Today I am feeling fine!"))

		indexer?.flush()

		let result = indexer!.search("fine")
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
		let dataIndexer = DFSKDataIndex.create()
		guard let indexer = dataIndexer else
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
		let props = DFSKIndex.Properties(proximityIndexing: true)
		let dataIndexer = DFSKDataIndex.create(properties: props)
		guard let indexer = dataIndexer else
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
		let dataIndexer = DFSKDataIndex.create()
		guard let indexer = dataIndexer else
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
		let props = DFSKIndex.Properties(stopWords: ["Caterpillars"])
		let dataIndexer = DFSKDataIndex.create(properties: props)
		guard let indexer = dataIndexer else
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

	func temporary() -> URL
	{
		let directory = NSTemporaryDirectory()
		let fileName = NSUUID().uuidString

		// This returns a URL? even though it is an NSURL class method
		return NSURL.fileURL(withPathComponents: [directory, fileName])! as URL
	}

	func testSimpleCreateWithFile()
	{
		guard let indexer = DFSKFileIndex.create(with: temporary()) else
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
		XCTAssertNil(DFSKFileIndex.load(from: temporary(), writable: true))
	}

	/// Attempt to create an index on a file that already exists
	func testAttemptCreateOnSameFile()
	{
		let file = temporary()
		guard DFSKFileIndex.create(with: file) != nil else
		{
			XCTFail()
			return
		}

		XCTAssertNil(DFSKFileIndex.create(with: file))
	}

	/// Create file index, save and close.  Verify we can open and read
	func testSimpleLoadWithFile()
	{
		// Create a file
		let file = temporary()
		guard let indexer = DFSKFileIndex.create(with: file) else
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
		guard let openIndexer = DFSKFileIndex.load(from: file, writable: true) else
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
		guard let openIndexer2 = DFSKFileIndex.load(from: file, writable: true) else
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
		guard let openIndexer3 = DFSKFileIndex.load(from: file, writable: false) else
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
		let props = DFSKIndex.Properties.init(stopWords: gStopWords)
		guard let indexer = DFSKDataIndex.create(properties: props) else
		{
			XCTFail()
			return
		}

		let text = NSString.init(string: "Caterpillar and gourds!")

		// Write the text to a temporary file and add
		let tempFile = temporary()
		try? text.write(to: tempFile as URL, atomically: true, encoding: String.Encoding.utf8.rawValue)
		XCTAssertTrue(indexer.add(url: tempFile, mimeType: "text/plain"))

		// Load in a pdf, and make sure we can load from it
		let testBundle = Bundle(for: type(of: self))
		let filePath = testBundle.url(forResource: "APACHE_LICENSE", withExtension: "pdf")
		XCTAssertNotNil(filePath)

		XCTAssertTrue(indexer.add(url: filePath!, mimeType: "application/pdf"))

		indexer.flush()

		// Check for terms only in the text
		var result = indexer.search("gourds")
		XCTAssertEqual(1, result.count)
		XCTAssertEqual(result[0].url, tempFile)

		// Check for terms only in the pdf
		result = indexer.search("license")
		XCTAssertEqual(1, result.count)
		XCTAssertEqual(result[0].url, filePath)
		result = indexer.search("Licensor")
		XCTAssertEqual(1, indexer.search("Licensor").count)
		XCTAssertEqual(result[0].url, filePath)

		// Because of our stop words, 'the' and 'and' should not exist at all
		XCTAssertEqual(0, indexer.search("the").count)
		XCTAssertEqual(0, indexer.search("and").count)
	}

	func testTermFrequenciesSimple()
	{
		let props = DFSKIndex.Properties.init(stopWords: [ "the" ])
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
		let props = DFSKIndex.Properties.init(stopWords: gStopWords)
		guard let indexer = DFSKDataIndex.create(properties: props) else
		{
			XCTFail()
			return
		}

		// Load in a pdf, and make sure we can load from it
		let testBundle = Bundle(for: type(of: self))
		let filePath = testBundle.url(forResource: "APACHE_LICENSE", withExtension: "pdf")
		XCTAssertNotNil(filePath)

		XCTAssertTrue(indexer.add(url: filePath!, mimeType: "application/pdf"))
		indexer.flush()

		// Grab the frequencies for the pdf document
		let termFreq = indexer.termsAndCounts(for: filePath!)

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
