//
//  DFSKIndex.swift
//  DFSearchKit
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

import Foundation
import CoreServices

class DFSKIndex: NSObject
{
	/// Container for storing the properties to be used when creating a new index
	struct CreateProperties
	{
		init(indexType: SKIndexType = kSKIndexInverted,
			 proximityIndexing: Bool = false,
			 stopWords: Set<String> = [],
			 minTermLength: Int = 0) {
			self.indexType = indexType
			self.proximityIndexing = proximityIndexing
			self.stopWords = stopWords
			self.minTermLength = minTermLength
		}

		/// Returns a CFDictionary object to use for the call to SKIndexCreate
		internal func CFDictionary() -> CFDictionary
		{
			let properties: [CFString: Any] =
				[
					kSKProximityIndexing: self.proximityIndexing,
					kSKStopWords: self.stopWords,
					kSKMinTermLength: self.minTermLength
				]
			return properties as CFDictionary
		}

		/// The type of the index to be created
		var indexType: SKIndexType = kSKIndexInverted
		/// Whether the index should use proximity indexing
		var proximityIndexing: Bool = false
		/// The stop words for the index
		var stopWords: Set<String> = Set<String>()
		/// The minimum size of word to add to the index
		var minTermLength: Int = 0
	}

	private var index: SKIndex?
	
	private lazy var dataExtractorLoaded: Bool = {
		SKLoadDefaultExtractorPlugIns()
		return true
	}()

	/// Stop words for the index
	private(set) lazy var stopWords: Set<String> = {
		var stopWords: Set<String> = []
		if let index = self.index,
			let properties = SKIndexGetAnalysisProperties(self.index),
			let sp = properties.takeUnretainedValue() as? [String:Any]
		{
			stopWords = sp[kSKStopWords as String] as! Set<String>
		}
		return stopWords
	}()

	init(index: SKIndex)
	{
		self.index = index
		super.init()
	}

	deinit
	{
		self.close()
	}

	/// Close the index
	func close()
	{
		if let index = self.index
		{
			SKIndexClose(index)
			self.index = nil
		}
	}
}

// MARK: Add and remove documents and text

extension DFSKIndex
{

	/// Add some text to the index
	///
	/// - Parameters:
	///   - url: The identifying URL for the text
	///   - text: The text to add
	///   - canReplace: if true, can attempt to replace an existing document with the new one.
	/// - Returns: true if the text was successfully added to the index, false otherwise
	func add(_ url: URL, text: String, canReplace: Bool = true) -> Bool
	{
		guard let index = self.index,
			let document = SKDocumentCreateWithURL(url as CFURL) else
		{
			return false
		}

		return SKIndexAddDocumentWithText(index, document.takeUnretainedValue(), text as CFString, canReplace)
	}

	/// Add a file as a document to the index
	///
	/// - Parameters:
	///   - url: The file URL for the document (of the form file:///Users/blahblah....doc.txt)
	///   - mimeType: An optional mimetype.  If nil, attempts to work out the type of file from the content.
	///   - canReplace: if true, can attempt to replace an existing document with the new one.
	/// - Returns: true if the command was successful.
	///				**NOTE** If the document _wasnt_ updated it also returns true!
	func add(url: URL, mimeType: String? = nil, canReplace: Bool = true) -> Bool
	{
		guard self.dataExtractorLoaded,
			let index = self.index,
			let document = SKDocumentCreateWithURL(url as CFURL) else
		{
			return false
		}

		return SKIndexAddDocument(index, document.takeUnretainedValue(), mimeType != nil ? mimeType! as CFString : nil, true)
	}
	
	/// Remove a document from the index
	///
	/// - Parameter url: The identifying URL for the document
	/// - Returns: true if the document was successfully removed, false otherwise.
	/// 		   **NOTE** if the document didn't exist, this returns true as well
	func remove(url: URL) -> Bool
	{
		guard let index = self.index,
			let document = SKDocumentCreateWithURL(url as CFURL) else
		{
			return false
		}
		return SKIndexRemoveDocument(index, document.takeUnretainedValue())
	}
}

// MARK: Terms and documents

extension DFSKIndex
{
	/// Returns all the document URLs loaded into the index
	///
	/// - Returns: An array containing all the document URLs
	func documents() -> [URL]
	{
		guard let index = self.index else
		{
			return []
		}

		var allDocs = Array<(URL, SKDocument, SKDocumentID)>()
		self.addLeafURLs(index: index, inParentDocument: nil, docs: &allDocs)
		return allDocs.map { $0.0 }
	}

	/// Returns an array containing the terms and counts for a specified URL
	///
	/// - Parameter url: The document URL in the index to locate
	/// - Returns: An array of the terms and corresponding counts located in the document.
	///            Returns an empty array if the document cannot be located.
	func termsAndCounts(for url: URL) -> [(term: String, count:Int)]
	{
		guard let index = self.index else
		{
			return []
		}

		var result = Array<(String, Int)>()

		let document = SKDocumentCreateWithURL(url as CFURL).takeUnretainedValue()
		let documentID = SKIndexGetDocumentID(index, document);

		guard let termVals = SKIndexCopyTermIDArrayForDocumentID(index, documentID),
			let terms = termVals.takeUnretainedValue() as? Array<CFIndex>
			else
		{
			return []
		}

		for term in terms
		{
			if let termVal = SKIndexCopyTermStringForTermID(index, term)
			{
				let termString = termVal.takeUnretainedValue() as String
				if !self.stopWords.contains(termString)
				{
					let count = SKIndexGetDocumentTermFrequency(index, documentID, term) as Int
					result.append( (termString, count) )
				}
			}
		}

		return result
	}
}

// MARK: Search

extension DFSKIndex
{

	/// Perform a search
	///
	/// - Parameters:
	///   - query: A string containing the term(s) to be searched for
	///   - limit: The maximum number of results to return
	///   - timeout: How long to wait for a search to complete before stopping
	/// - Returns: An array containing match URLs and their corresponding 'score' (how relevant the match)
	func search(_ query: String, limit: Int = 10, timeout: TimeInterval = 1.0) -> [ (url: URL, score: Float) ]
	{
		guard let index = self.index else
		{
			return []
		}

		let options = SKSearchOptions( kSKSearchOptionDefault )
		let search = SKSearchCreate(index, query as CFString, options).takeRetainedValue()

		var scores: [Float] = Array(repeating: 0.0, count: limit)
		var urls: [Unmanaged<CFURL>?] = Array(repeating: nil, count: limit)
		var documentIDs: [SKDocumentID] = Array(repeating: 0, count: limit)
		var foundCount = 0

		var results: [(URL, Float)] = []

		var moreData = true
		while moreData
		{
			moreData = SKSearchFindMatches(search, limit, &documentIDs, &scores, timeout, &foundCount)
			SKIndexCopyDocumentURLsForDocumentIDs(index, foundCount, &documentIDs, &urls)

			let partialResults = zip(urls[0 ..< foundCount], scores).compactMap({
				(cfurl, score) -> (URL, Float)? in
				guard let url = cfurl?.takeUnretainedValue() as URL?
					else { return nil }
				return (url, score)
			})
			results.append(contentsOf: partialResults)
		}

		return results
	}
}

// MARK: Utilities

extension DFSKIndex
{
	/// Flush any pending commands to the search index. A flush should ALWAYS be called before performing a search
	func flush()
	{
		if let index = self.index
		{
			SKIndexFlush(index)
		}
	}

	/// Reduce the size of the index where possible.
	func compact()
	{
		if let index = self.index
		{
			SKIndexCompact(index)
		}
	}
}

// MARK: Private methods for building document arrays

fileprivate extension DFSKIndex
{
	private func addLeafURLs(index: SKIndex, inParentDocument: SKDocument?, docs: inout Array<(URL, SKDocument, SKDocumentID)>)
	{
		guard let index = self.index else
		{
			return
		}

		var isLeaf = true

		let iterator = SKIndexDocumentIteratorCreate (index, inParentDocument).takeUnretainedValue()
		while let skDocument = SKIndexDocumentIteratorCopyNext(iterator)
		{
			isLeaf = false
			self.addLeafURLs(index: index, inParentDocument: skDocument.takeUnretainedValue(), docs: &docs)
		}

		if isLeaf && inParentDocument != nil && kSKDocumentStateNotIndexed != SKIndexGetDocumentState(index, inParentDocument)
		{
			if let temp = SKDocumentCopyURL(inParentDocument)
			{
				let burl = temp.takeUnretainedValue()
				let bid = SKIndexGetDocumentID(index, inParentDocument)
				docs.append((burl as URL, inParentDocument!, bid))
			}
		}
	}

	fileprivate func allDocuments() -> Array<(URL, SKDocument, SKDocumentID)>
	{
		guard let index = self.index else
		{
			return []
		}

		var allDocs = Array<(URL, SKDocument, SKDocumentID)>()
		self.addLeafURLs(index: index, inParentDocument: nil, docs: &allDocs)
		return allDocs
	}
}
