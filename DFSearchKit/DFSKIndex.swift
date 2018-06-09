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

/// Provide the equivalent of @synchronised on objc
private func synchronized<T>(_ lock: AnyObject, _ body: () throws -> T) rethrows -> T {
	objc_sync_enter(lock)
	defer { objc_sync_exit(lock) }
	return try body()
}

open class DFSKIndex: NSObject
{
	/// Container for storing the properties to be used when creating a new index
	public struct CreateProperties
	{
		public init(indexType: SKIndexType = kSKIndexInverted,
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

	fileprivate func rawIndex() -> SKIndex?
	{
		return index
	}
	
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
	open func close()
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

	/// Returns the mime type for the url, or nil if the mime type couldn't be ascertained from the extension
	///
	/// - Parameter url: the url to detect the mime type for
	/// - Returns: the mime type of the url if able to detect, nil otherwise
	private func detectMimeType(_ url: URL) -> String?
	{
		if let UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
														   url.pathExtension as CFString,
														   nil)?.takeUnretainedValue(),
			let mimeType = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType)?.takeUnretainedValue()
		{
			return mimeType as String
		}
		return nil
	}

	/// Add some text to the index
	///
	/// - Parameters:
	///   - url: The identifying URL for the text
	///   - text: The text to add
	///   - canReplace: if true, can attempt to replace an existing document with the new one.
	/// - Returns: true if the text was successfully added to the index, false otherwise
	open func add(_ url: URL, text: String, canReplace: Bool = true) -> Bool
	{
		guard let index = self.index,
			let document = SKDocumentCreateWithURL(url as CFURL) else
		{
			return false
		}

		return synchronized(self) {
			SKIndexAddDocumentWithText(index, document.takeUnretainedValue(), text as CFString, canReplace)
		}
	}

	/// Add a file as a document to the index
	///
	/// - Parameters:
	///   - url: The file URL for the document (of the form file:///Users/blahblah....doc.txt)
	///   - mimeType: An optional mimetype.  If nil, attempts to work out the type of file from the extension.
	///   - canReplace: if true, can attempt to replace an existing document with the new one.
	/// - Returns: true if the command was successful.
	///				**NOTE** If the document _wasnt_ updated it also returns true!
	open func add(url: URL, mimeType: String? = nil, canReplace: Bool = true) -> Bool
	{
		guard self.dataExtractorLoaded,
			let index = self.index,
			let document = SKDocumentCreateWithURL(url as CFURL) else
		{
			return false
		}

		// Try to detect the mime type if it wasn't specified
		let mime = mimeType ?? self.detectMimeType(url)

		return synchronized(self) {
			SKIndexAddDocument(index, document.takeUnretainedValue(), mime as CFString?, true)
		}
	}

	/// Recursively add the files contained within a folder to the search index
	///
	/// - Parameters:
	///   - folderURL: The folder to be indexed.
	///   - canReplace: If the document already exists within the index, can it be replaced?
	/// - Returns: The URLs of documents added to the index.  If folderURL isn't a folder, returns empty
	open func addFolderContent(folderURL: URL, canReplace: Bool = true) -> [URL]
	{
		let fileManager = FileManager.default

		var isDir: ObjCBool = false
		guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDir),
			isDir.boolValue == true else
		{
			return []
		}

		var addedUrls: [URL] = []
		let enumerator = FileManager.default.enumerator(at: folderURL, includingPropertiesForKeys: nil)
		while let fileURL = enumerator?.nextObject() as? URL
		{
			if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDir),
				isDir.boolValue == false,
				self.add(url: fileURL)
			{
				addedUrls.append(fileURL)
			}
		}
		return addedUrls
	}
	
	/// Remove a document from the index
	///
	/// - Parameter url: The identifying URL for the document
	/// - Returns: true if the document was successfully removed, false otherwise.
	/// 		   **NOTE** if the document didn't exist, this returns true as well
	open func remove(url: URL) -> Bool
	{
		guard let index = self.index,
			let document = SKDocumentCreateWithURL(url as CFURL) else
		{
			return false
		}

		return synchronized(self) {
			SKIndexRemoveDocument(index, document.takeUnretainedValue())
		}
	}

	open func remove(urls: [URL])
	{
		urls.forEach { _ = self.remove(url: $0) }
	}

	/// Returns the indexing state for the specified URL.
	open func documentState(_ url: URL) -> SKDocumentIndexState
	{
		if let index = self.index,
			let document = SKDocumentCreateWithURL(url as CFURL)
		{
			return SKIndexGetDocumentState(index, document.takeUnretainedValue())
		}
		return kSKDocumentStateNotIndexed
	}

	/// Returns true if the document represented by url has been indexed, false otherwise.
	open func documentIndexed(_ url: URL) -> Bool
	{
		if let index = self.index,
			let document = SKDocumentCreateWithURL(url as CFURL)
		{
			return SKIndexGetDocumentState(index, document.takeUnretainedValue()) == kSKDocumentStateIndexed
		}
		return false
	}

	fileprivate func documentIndexed(_ document: SKDocument) -> Bool
	{
		if let index = self.index,
			SKIndexGetDocumentState(index, document) == kSKDocumentStateIndexed
		{
			return true
		}
		return false
	}

	/// Returns the document associated with url IF the document has been indexed, nil otherwise
	fileprivate func indexedDocument(_ url: URL) -> SKDocument?
	{
		if let document = SKDocumentCreateWithURL(url as CFURL),
			self.documentIndexed(document.takeUnretainedValue())
		{
			return document.takeUnretainedValue()
		}
		return nil
	}
}

// MARK: Set/Get additional properties for document

extension DFSKIndex
{
	/// Sets additional properties for the document which are retained in the index.
	///
	/// Document must have been indexed for setting of properties to take effect.
	///
	/// - Parameters:
	///   - url: The identifying URL for the document
	///   - properties: The properties to store in the
	/// - Returns: `true` if the properties were set, `false` otherwise
	open func setDocumentProperties(_ url: URL, properties: [String: Any]) -> Bool
	{
		if let index = self.index,
			let document = self.indexedDocument(url)
		{
			synchronized(self) {
				SKIndexSetDocumentProperties(index, document, properties as CFDictionary)
			}
			return true
		}
		return false
	}

	/// Returns additional properties for the document
	open func documentProperties(_ url: URL) -> [String: Any]
	{
		guard let index = self.index,
			let document = SKDocumentCreateWithURL(url as CFURL),
			SKIndexGetDocumentState(index, document.takeUnretainedValue()) == kSKDocumentStateIndexed else
		{
			return [:]
		}

		let cfprops = SKIndexCopyDocumentProperties(index, document.takeUnretainedValue())
		return cfprops?.takeUnretainedValue() as! [String: Any]
	}
}

// MARK: Terms and documents

extension DFSKIndex
{
	/// Returns all the document URLs loaded into the index
	///
	/// - Returns: An array containing all the document URLs
	open func documents() -> [URL]
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
	open func termsAndCounts(for url: URL) -> [(term: String, count:Int)]
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

// MARK: Progressive search

extension DFSKIndex
{
	public struct SearchResult
	{
		public let url: URL
		public let score: Float
	}

	/// Start a progressive search
	open func progressiveSearch(_ index: DFSKIndex,
						   query: String,
						   options: SKSearchOptions = SKSearchOptions(kSKSearchOptionDefault)) -> ProgressiveSearch
	{
		return ProgressiveSearch(index, query: query, options: options)
	}

	open class ProgressiveSearch
	{
		private let options: SKSearchOptions
		private let search: SKSearch
		private let index: DFSKIndex
		private let query: String

		fileprivate init(_ index: DFSKIndex, query: String, options: SKSearchOptions)
		{
			self.query = query
			self.index = index
			self.options = options
			self.search = SKSearchCreate(index.rawIndex(), query as CFString, options).takeRetainedValue()
		}

		/// Cancels an active search
		open func cancel()
		{
			SKSearchCancel(search)
		}

		/// Get the next chunk of results
		open func next(_ limit: Int = 10, timeout: TimeInterval = 1.0) -> (moreResults: Bool, results: [ SearchResult ])
		{
			guard index.rawIndex() != nil else
			{
				// If the index has been closed, then no results for you good sir!
				return (false, [])
			}

			var scores: [Float] = Array(repeating: 0.0, count: limit)
			var urls: [Unmanaged<CFURL>?] = Array(repeating: nil, count: limit)
			var documentIDs: [SKDocumentID] = Array(repeating: 0, count: limit)
			var foundCount = 0

			let hasMore = SKSearchFindMatches(self.search, limit, &documentIDs, &scores, timeout, &foundCount)
			SKIndexCopyDocumentURLsForDocumentIDs(index.rawIndex()!, foundCount, &documentIDs, &urls)

			let partialResults: [ SearchResult ] = zip(urls[0 ..< foundCount], scores).compactMap({
				(cfurl, score) -> (SearchResult)? in
				guard let url = cfurl?.takeUnretainedValue() as URL?
					else { return nil }
				return SearchResult(url: url, score: score)
			})

			return (hasMore, partialResults)
		}
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
	open func search(_ query: String,
				limit: Int = 10,
				timeout: TimeInterval = 1.0,
				options: SKSearchOptions = SKSearchOptions(kSKSearchOptionDefault)) -> [ SearchResult ]
	{
		let search = self.progressiveSearch(self, query: query, options: options)

		var results: [ SearchResult ] = []
		var hasMoreResults = true
		repeat
		{
			let result = search.next(limit, timeout: timeout)
			results.append(contentsOf: result.results)
			hasMoreResults = result.moreResults
		}
			while hasMoreResults

		return results
	}
}

// MARK: Utilities

extension DFSKIndex
{
	/// Flush any pending commands to the search index. A flush should ALWAYS be called before performing a search
	open func flush()
	{
		if let index = self.index
		{
			SKIndexFlush(index)
		}
	}

	/// Reduce the size of the index where possible.
	open func compact()
	{
		if let index = self.index
		{
			SKIndexCompact(index)
		}
	}

	/// Remove any documents that have no search terms
	open func prune(progress: ((Int, Int) -> Void)?) -> Int
	{
		let urls = self.documents()
		let totalCount = urls.count
		var pruneCount = 0
		for url in urls
		{
			let terms = self.termsAndCounts(for: url)
			if terms.count == 0
			{
				_ = self.remove(url: url)
				pruneCount += 1
				progress?(totalCount, pruneCount)
			}
		}
		return pruneCount
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
