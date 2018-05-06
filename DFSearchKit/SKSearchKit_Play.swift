//
//  SKSearchKit_Play.swift
//  DFSearchKit
//
//  Created by Darren Ford on 6/5/18.
//  Copyright © 2018 Darren Ford. All rights reserved.
//

import Cocoa

class SKSearchKit_Play: NSObject {

	func doStuff()
	{
		let stopwords: Set = ["all", "and", "its", "it's", "the"]

		//		let properties: [NSObject: AnyObject] = [
		//			"kSKStartTermChars": "", // additional starting-characters for terms
		//			"kSKTermChars": "-_@.'", // additional characters within terms
		//			"kSKEndTermChars": "",   // additional ending-characters for terms
		//			"kSKMinTermLength": 3,
		//			"kSKStopWords": stopwords
		//		]

		let props = [ kSKProximityIndexing: true ]


		let mutableData = NSMutableData()
		let index = SKIndexCreateWithMutableData(mutableData, nil, SKIndexType(kSKIndexInverted.rawValue), props as CFDictionary).takeRetainedValue()

		let fileURL = NSURL(string: "test-help://cases/cases.html")
		let document = SKDocumentCreateWithURL(fileURL).takeRetainedValue()

		let string = "Today I'm feeling kind of blue"
		SKIndexAddDocumentWithText(index, document, string as CFString, true)

		var state: SKDocumentIndexState = SKIndexGetDocumentState( index, document );

		let fileURL1 = NSURL(string: "test-help://nodes/nodes.html")
		let document1 = SKDocumentCreateWithURL(fileURL1).takeRetainedValue()
		let string1 = "Today I'm feeling kind of great!"
		SKIndexAddDocumentWithText(index, document1, string1 as CFString, true)

		let fileURL2 = NSURL(string: "test-help://test/chinese.html")
		let document2 = SKDocumentCreateWithURL(fileURL2).takeRetainedValue()
		let string2 = "子曰：「學而時習之，不亦說乎？有朋自遠方來，不亦樂乎？人不知而不慍，不亦君子乎？」"
		SKIndexAddDocumentWithText(index, document2, string2 as CFString, true)

		SKIndexFlush(index)

		//let query = "kind of great!"
		let query = "feeling great"
		let options = SKSearchOptions( kSKSearchOptionDefault ) // | kSKSearchOptionSpaceMeansOR )
		let search = SKSearchCreate(index, query as CFString, options).takeRetainedValue()

		let limit =  100                // Maximum number of results
		let time: TimeInterval = 10 // Maximum time to get results, in seconds

		var documentIDs: [SKDocumentID] = Array(repeating: 0, count: limit)
		var urls: [Unmanaged<CFURL>?] = Array(repeating: nil, count: limit)
		var scores: [Float] = Array(repeating: 0, count: limit)
		var foundCount = 0

		let hasMoreResults = SKSearchFindMatches(search, limit, &documentIDs, &scores, time, &foundCount)

		SKIndexCopyDocumentURLsForDocumentIDs(index, foundCount, &documentIDs, &urls)

		let results: [NSURL] = zip(urls[0 ..< foundCount], scores).flatMap({
			(cfurl, score) -> NSURL? in
			guard let url = cfurl?.takeRetainedValue() as NSURL?
				else { return nil }

			print("- \(url): \(score)")
			return url
		})
	}


}
