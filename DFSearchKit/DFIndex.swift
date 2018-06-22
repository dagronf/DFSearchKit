//
//  DFIndex.swift
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

import CoreServices
import Foundation

/// Provide the equivalent of @synchronised on objc
private func synchronized<T>(_ lock: AnyObject, _ body: () throws -> T) rethrows -> T
{
	objc_sync_enter(lock)
	defer { objc_sync_exit(lock) }
	return try body()
}

/// The type of index to create. Maps directly onto SKIndexType
@objc public enum DFIndexType: UInt32
{
	/// Unknown index type (kSKIndexUnknown)
	case unknown = 0
	/// Inverted index, mapping terms to documents (kSKIndexInverted)
	case inverted = 1
	/// Vector index, mapping documents to terms (kSKIndexVector)
	case vector = 2
	/// Index type with all the capabilities of an inverted and a vector index (kSKIndexInvertedVector)
	case invertedVector = 3
}

/// Indexer using SKIndex as the core
@objc public class DFIndex: NSObject
{
	/// Container for storing the properties to be used when creating a new index
	@objc(DFIndexCreateProperties)
	public class CreateProperties: NSObject
	{
		/// Create a properties object with the specified creation parameters
		///
		/// - Parameters:
		///   - indexType: The type of index
		///   - proximityIndexing: A Boolean flag indicating whether or not Search Kit should use proximity indexing
		///   - stopWords: A set of stopwords — words not to index
		///   - minTermLength: The minimum term length to index (defaults to 1)
		@objc public init(
			indexType: DFIndexType = .inverted,
			proximityIndexing: Bool = false,
			stopWords: Set<String> = [],
			minTermLength: Int = 1
		)
		{
			self.indexType = SKIndexType(indexType.rawValue)
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
					kSKMinTermLength: self.minTermLength,
				]
			return properties as CFDictionary
		}

		/// The type of the index to be created
		private(set) var indexType: SKIndexType = kSKIndexInverted
		/// Whether the index should use proximity indexing
		private(set) var proximityIndexing: Bool = false
		/// The stop words for the index
		private(set) var stopWords: Set<String> = Set<String>()
		/// The minimum size of word to add to the index
		private(set) var minTermLength: Int = 1
	}

	fileprivate var index: SKIndex?

	private lazy var dataExtractorLoaded: Bool = {
		SKLoadDefaultExtractorPlugIns()
		return true
	}()

	/// Stop words for the index
	private(set) lazy var stopWords: Set<String> = {
		var stopWords: Set<String> = []
		if let index = self.index,
			let properties = SKIndexGetAnalysisProperties(self.index),
			let sp = properties.takeUnretainedValue() as? [String: Any]
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
	@objc public func close()
	{
		if let index = self.index
		{
			SKIndexClose(index)
			self.index = nil
		}
	}
}

// MARK: Add and remove documents and text

extension DFIndex
{
	/// Add some text to the index
	///
	/// - Parameters:
	///   - url: The identifying URL for the text
	///   - text: The text to add
	///   - canReplace: if true, can attempt to replace an existing document with the new one.
	/// - Returns: true if the text was successfully added to the index, false otherwise
	@objc public func add(_ url: URL, text: String, canReplace: Bool = true) -> Bool
	{
		guard let index = self.index,
			let document = SKDocumentCreateWithURL(url as CFURL) else
		{
			return false
		}

		return synchronized(self)
		{
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
	/// 				**NOTE** If the document _wasnt_ updated it also returns true!
	@objc public func add(url: URL, mimeType: String? = nil, canReplace: Bool = true) -> Bool
	{
		guard self.dataExtractorLoaded,
			let index = self.index,
			let document = SKDocumentCreateWithURL(url as CFURL) else
		{
			return false
		}

		// Try to detect the mime type if it wasn't specified
		let mime = mimeType ?? self.detectMimeType(url)

		return synchronized(self)
		{
			SKIndexAddDocument(index, document.takeUnretainedValue(), mime as CFString?, true)
		}
	}

	/// Recursively add the files contained within a folder to the search index
	///
	/// - Parameters:
	///   - folderURL: The folder to be indexed.
	///   - canReplace: If the document already exists within the index, can it be replaced?
	/// - Returns: The URLs of documents added to the index.  If folderURL isn't a folder, returns empty
	@objc public func addFolderContent(folderURL: URL, canReplace: Bool = true) -> [URL]
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
	@objc public func remove(url: URL) -> Bool
	{
		let document = SKDocumentCreateWithURL(url as CFURL).takeUnretainedValue()
		return self.remove(document: document)
	}

	@objc public func remove(urls: [URL])
	{
		urls.forEach { _ = self.remove(url: $0) }
	}

	/// Returns the indexing state for the specified URL.
	@objc public func documentState(_ url: URL) -> SKDocumentIndexState
	{
		if let index = self.index,
			let document = SKDocumentCreateWithURL(url as CFURL)
		{
			return SKIndexGetDocumentState(index, document.takeUnretainedValue())
		}
		return kSKDocumentStateNotIndexed
	}
}

extension DFIndex
{
	/// Returns true if the document represented by url has been indexed, false otherwise.
	@objc public func documentIndexed(_ url: URL) -> Bool
	{
		if let index = self.index,
			let document = SKDocumentCreateWithURL(url as CFURL)
		{
			return SKIndexGetDocumentState(index, document.takeUnretainedValue()) == kSKDocumentStateIndexed
		}
		return false
	}
}

// MARK: Set/Get additional properties for document

extension DFIndex
{
	/// Sets additional properties for the document which are retained in the index.
	///
	/// Document must have been indexed for setting of properties to take effect.
	///
	/// - Parameters:
	///   - url: The identifying URL for the document
	///   - properties: The properties to store in the
	/// - Returns: `true` if the properties were set, `false` otherwise
	@objc public func setDocumentProperties(_ url: URL, properties: [String: Any]) -> Bool
	{
		if let index = self.index,
			let document = self.indexedDocument(for: url)
		{
			synchronized(self)
			{
				SKIndexSetDocumentProperties(index, document, properties as CFDictionary)
			}
			return true
		}
		return false
	}

	/// Returns additional properties for the document
	@objc public func documentProperties(_ url: URL) -> [String: Any]
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

extension DFIndex
{
	/// A class to contain a term and the count of times it appears
	@objc(DFIndexTermCount)
	public class TermCount: NSObject
	{
		@objc public init(term: String, count: Int)
		{
			self.term = term
			self.count = count
			super.init()
		}

		@objc public let term: String
		@objc public let count: Int
	}

	@objc(DFIndexTermState)
	public enum TermState: Int
	{
		case all = 0
		case empty = 1
		case notEmpty = 2
	}

	/// Returns all the document URLs loaded into the index matching the specified term state
	///
	/// - Parameter termState: Only return documents matching the specified document state
	/// - Returns: An array containing all the document URLs
	@objc public func documents(termState: TermState = .all) -> [URL]
	{
		return self.fullDocuments(termState: termState).map { $0.0 }
	}

	/// Returns the number of terms for the specified document url
	@objc public func termCount(for url: URL) -> Int
	{
		if let index = self.index,
			let document = SKDocumentCreateWithURL(url as CFURL)
		{
			let documentID = SKIndexGetDocumentID(index, document.takeUnretainedValue())
			return SKIndexGetDocumentTermCount(index, documentID)
		}
		return 0
	}

	/// Is the specified document empty (ie. it has no terms)
	@objc public func isEmpty(for url: URL) -> Bool
	{
		return self.termCount(for: url) > 0
	}

	/// Returns an array containing the terms and counts for a specified URL
	///
	/// - Parameter url: The document URL in the index to locate
	/// - Returns: An array of the terms and corresponding counts located in the document.
	///            Returns an empty array if the document cannot be located.
	@objc public func terms(for url: URL) -> [TermCount]
	{
		guard let index = self.index else
		{
			return []
		}

		var result = [TermCount]()

		let document = SKDocumentCreateWithURL(url as CFURL).takeUnretainedValue()
		let documentID = SKIndexGetDocumentID(index, document)

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
					result.append(TermCount(term: termString, count: count))
				}
			}
		}

		return result
	}
}

// MARK: Progressive search

extension DFIndex
{
	@objc(DFIndexSearchResult)
	public class SearchResult: NSObject
	{
		public init(url: URL, score: Float)
		{
			self.url = url
			self.score = score
			super.init()
		}

		@objc public let url: URL
		@objc public let score: Float
	}

	/// Start a progressive search
	@objc public func progressiveSearch(
		query: String,
		options: SKSearchOptions = SKSearchOptions(kSKSearchOptionDefault)
	) -> ProgressiveSearch
	{
		return ProgressiveSearch(self, query: query, options: options)
	}

	@objc(DFIndexProgressiveSearch)
	public class ProgressiveSearch: NSObject
	{
		/// Progressive search result.
		@objc(DFIndexProgressiveSearchResults)
		public class Results: NSObject
		{
			@objc public init(moreResultsAvailable: Bool, results: [SearchResult])
			{
				self.moreResultsAvailable = moreResultsAvailable
				self.results = results
				super.init()
			}

			@objc public let moreResultsAvailable: Bool
			@objc public let results: [SearchResult]
		}

		private let options: SKSearchOptions
		private let search: SKSearch
		private let index: DFIndex
		private let query: String

		fileprivate init(_ index: DFIndex, query: String, options: SKSearchOptions)
		{
			self.query = query
			self.index = index
			self.options = options
			self.search = SKSearchCreate(index.index, query as CFString, options).takeRetainedValue()
		}

		/// Cancels an active search
		@objc public func cancel()
		{
			SKSearchCancel(self.search)
		}

		/// Get the next chunk of results
		@objc public func next(_ limit: Int = 10, timeout: TimeInterval = 1.0) -> (ProgressiveSearch.Results)
		{
			guard self.index.index != nil else
			{
				// If the index has been closed, then no results for you good sir!
				return Results(moreResultsAvailable: false, results: [])
			}

			var scores: [Float] = Array(repeating: 0.0, count: limit)
			var urls: [Unmanaged<CFURL>?] = Array(repeating: nil, count: limit)
			var documentIDs: [SKDocumentID] = Array(repeating: 0, count: limit)
			var foundCount = 0

			let hasMore = SKSearchFindMatches(self.search, limit, &documentIDs, &scores, timeout, &foundCount)
			SKIndexCopyDocumentURLsForDocumentIDs(self.index.index, foundCount, &documentIDs, &urls)

			let partialResults: [SearchResult] = zip(urls[0 ..< foundCount], scores).compactMap({
				(cfurl, score) -> SearchResult? in
				guard let url = cfurl?.takeUnretainedValue() as URL?
				else { return nil }
				return SearchResult(url: url, score: score)
			})

			return Results(moreResultsAvailable: hasMore, results: partialResults)
		}
	}
}

// MARK: Search

extension DFIndex
{
	/// Perform a search
	///
	/// - Parameters:
	///   - query: A string containing the term(s) to be searched for
	///   - limit: The maximum number of results to return
	///   - timeout: How long to wait for a search to complete before stopping
	/// - Returns: An array containing match URLs and their corresponding 'score' (how relevant the match)
	@objc public func search(
		_ query: String,
		limit: Int = 10,
		timeout: TimeInterval = 1.0,
		options: SKSearchOptions = SKSearchOptions(kSKSearchOptionDefault)
	) -> [SearchResult]
	{
		let search = self.progressiveSearch(query: query, options: options)

		var results: [SearchResult] = []
		var moreResultsAvailable = true
		repeat
		{
			let result = search.next(limit, timeout: timeout)
			results.append(contentsOf: result.results)
			moreResultsAvailable = result.moreResultsAvailable
		}
		while moreResultsAvailable

		return results
	}
}

// MARK: Utilities

extension DFIndex
{
	/// Flush any pending commands to the search index. A flush should ALWAYS be called before performing a search
	@objc public func flush()
	{
		if let index = self.index
		{
			SKIndexFlush(index)
		}
	}

	/// Reduce the size of the index where possible.
	@objc public func compact()
	{
		if let index = self.index
		{
			SKIndexCompact(index)
		}
	}

	/// Remove any documents that have no search terms
	@objc public func prune(progress: ((Int, Int) -> Void)?) -> Int
	{
		let allDocs = self.fullDocuments(termState: .empty)
		let totalCount = allDocs.count
		var pruneCount = 0
		for docID in allDocs
		{
			_ = self.remove(document: docID.1)
			pruneCount += 1
			progress?(totalCount, pruneCount)
		}
		return pruneCount
	}
}

// MARK: Private methods

private extension DFIndex
{
	typealias DocumentID = (URL, SKDocument, SKDocumentID)

	/// Returns the mime type for the url, or nil if the mime type couldn't be ascertained from the extension
	///
	/// - Parameter url: the url to detect the mime type for
	/// - Returns: the mime type of the url if able to detect, nil otherwise
	private func detectMimeType(_ url: URL) -> String?
	{
		if let UTI = UTTypeCreatePreferredIdentifierForTag(
			kUTTagClassFilenameExtension,
			url.pathExtension as CFString,
			nil
		)?.takeUnretainedValue(),
			let mimeType = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType)?.takeUnretainedValue()
		{
			return mimeType as String
		}
		return nil
	}

	/// Remove the specified document from the index
	private func remove(document: SKDocument) -> Bool
	{
		if let index = self.index
		{
			return synchronized(self)
			{
				SKIndexRemoveDocument(index, document)
			}
		}
		return false
	}

	/// Returns the number of terms for the specified document
	private func termCount(for document: SKDocumentID) -> Int
	{
		assert(self.index != nil)
		return SKIndexGetDocumentTermCount(self.index!, document)
	}

	/// Is the specified document empty (ie. it has no terms)
	private func isEmpty(for document: SKDocumentID) -> Bool
	{
		assert(self.index != nil)
		return self.termCount(for: document) == 0
	}

	/// Is the specfied document indexed?
	private func documentIndexed(_ document: SKDocument) -> Bool
	{
		if let index = self.index,
			SKIndexGetDocumentState(index, document) == kSKDocumentStateIndexed
		{
			return true
		}
		return false
	}

	/// Returns the document associated with url IF the document has been indexed, nil otherwise
	private func indexedDocument(for url: URL) -> SKDocument?
	{
		if let document = SKDocumentCreateWithURL(url as CFURL),
			self.documentIndexed(document.takeUnretainedValue())
		{
			return document.takeUnretainedValue()
		}
		return nil
	}

	/// Recurse through the children of a document and return an array containing all the documentids
	private func addLeafURLs(index: SKIndex, inParentDocument: SKDocument?, docs: inout Array<DocumentID>)
	{
		guard let index = self.index else
		{
			return
		}

		var isLeaf = true

		let iterator = SKIndexDocumentIteratorCreate(index, inParentDocument).takeUnretainedValue()
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

	/// Return an array of all the documents contained within the index
	///
	/// - Parameter termState: the termstate of documents to be returned (eg. all, empty only, non-empty only)
	/// - Returns: An array containing all the documents matching the termstate
	private func fullDocuments(termState: TermState = .all) -> [DocumentID]
	{
		guard let index = self.index else
		{
			return []
		}

		var allDocs = Array<DocumentID>()
		self.addLeafURLs(index: index, inParentDocument: nil, docs: &allDocs)

		switch termState
		{
		case .notEmpty:
			allDocs = allDocs.filter { !self.isEmpty(for: $0.2) }
			break
		case .empty:
			allDocs = allDocs.filter { self.isEmpty(for: $0.2) }
			break
		default:
			break
		}
		return allDocs
	}
}
