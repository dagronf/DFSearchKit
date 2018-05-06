//
//  DFSKIndex.swift
//  DFSearchKit
//
//  Created by Darren Ford on 6/5/18.
//  Copyright © 2018 Darren Ford. All rights reserved.
//

import Cocoa
import CoreServices

class DFSKDocument: NSObject {
	fileprivate let document: SKDocument
	let urlID: NSURL
	let properties: Dictionary<String, String>
	
	init(urlID: NSURL, properties: Dictionary<String, String> = [:] ) {
		self.urlID = urlID
		self.properties = properties
		self.document = SKDocumentCreateWithURL(urlID).takeRetainedValue()
		super.init()
	}
}

class DFSKIndex: NSObject {

	let data = NSMutableData()
	private var index: SKIndex?

	fileprivate var proximityIndexing: Bool = false
	fileprivate var indexType: SKIndexType = kSKIndexInverted

	fileprivate func configure() -> Bool {
		let properties: [String: Any?] = [ kSKProximityIndexing as String: self.proximityIndexing ]
		self.index = SKIndexCreateWithMutableData(self.data, nil, self.indexType, properties as CFDictionary).takeUnretainedValue()
		return true
	}

	fileprivate func add(document: DFSKDocument, text: String) -> Bool {
		return SKIndexAddDocumentWithText(self.index!, document.document, text as CFString, true)
	}

	fileprivate func flush() {
		SKIndexFlush(self.index)
	}

	fileprivate func search(_ query: String, limit: Int = 10, timeout: TimeInterval = 1.0) -> [ (NSURL, Float) ] {

		let options = SKSearchOptions( kSKSearchOptionDefault )
		let search = SKSearchCreate(self.index, query as CFString, options).takeRetainedValue()

		var scores: [Float] = Array(repeating: 0.0, count: limit)
		var urls: [Unmanaged<CFURL>?] = Array(repeating: nil, count: limit)
		var documentIDs: [SKDocumentID] = Array(repeating: 0, count: limit)
		var foundCount = 0

		SKSearchFindMatches(search, limit, &documentIDs, &scores, timeout, &foundCount)

		SKIndexCopyDocumentURLsForDocumentIDs(self.index, foundCount, &documentIDs, &urls)

		let results: [(NSURL, Float)] = zip(urls[0 ..< foundCount], scores).compactMap({
			(cfurl, score) -> (NSURL, Float)? in
			guard let url = cfurl?.takeRetainedValue() as NSURL?
				else { return nil }
			return (url, score)
		})

		return results
	}
}

class DFSKIndexer: NSObject
{
	private(set) var documents = Array<DFSKDocument>()
	private let index: DFSKIndex

	init(indexType: SKIndexType = kSKIndexInverted,
		 proximityIndexing: Bool = false,
		 stopWords: [String] = []) {

		self.index = DFSKIndex()
		self.index.proximityIndexing = proximityIndexing
		self.index.indexType = indexType
		_ = self.index.configure()
		super.init()
	}

	func add(document withURL: NSURL, text: String, properties: Dictionary<String, String> = [:]) -> Bool {

		let doc = DFSKDocument(urlID: withURL, properties: properties)
		if index.add(document: doc, text: text) {
			self.documents.append(doc)
			return true
		}
		return false
	}

	func flush() {
		self.index.flush()
	}

	func search(_ query: String, limit: Int = 10, timeout: TimeInterval = 1.0) -> [ (DFSKDocument, Float) ] {

		let results = self.index.search(query, limit: limit, timeout: timeout)

		var docs = [(DFSKDocument, Float)]()
		for result in results {
			if let match = self.documents.first(where: { $0.urlID == result.0 } ) {
				docs.append( (match, result.1) )
			}
		}
		return docs
	}
}
