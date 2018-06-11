//
//  DFSKAsyncIndexer.swift
//  DFSearchKitTests
//
//  Created by Darren Ford on 11/6/18.
//  Copyright © 2018 Darren Ford. All rights reserved.
//

import Foundation

/// Protocol for notifying when the operation queue changes state
public protocol DFSKIndexAsyncControllerProtocol
{
	/// The queue is now empty
	func queueDidEmpty(_ indexer: DFSKIndexAsyncController)
	/// The queue's operation count did change
	func queueDidChange(_ indexer: DFSKIndexAsyncController, count: Int)
}

/// A controller for a DFSKIndex object that supports asynchronous calls to the index
public class DFSKIndexAsyncController: NSObject
{
	public let index: DFSKIndex
	let delegate: DFSKIndexAsyncControllerProtocol

	/// Queue for handling async modifications to the index
	fileprivate let modifyQueue = OperationQueue()

	public init(index: DFSKIndex, delegate: DFSKIndexAsyncControllerProtocol)
	{
		self.index = index
		self.delegate = delegate
		super.init()

		self.modifyQueue.maxConcurrentOperationCount = 6
		self.modifyQueue.addObserver(self, forKeyPath: "operations", options: .new, context: nil)
	}

	deinit
	{
		self.modifyQueue.removeObserver(self, forKeyPath: "operations")
	}

	open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?)
	{
		if keyPath == "operations"
		{
			if self.modifyQueue.operations.count == 0 {
				self.delegate.queueDidEmpty(self)
			}
			self.delegate.queueDidChange(self, count: self.modifyQueue.operationCount)
		}
	}
}

// MARK: Async task objects

public extension DFSKIndexAsyncController
{
	/// Class to help with undo/redo
	class TextTask: NSObject
	{
		public let url: URL
		public let text: String
		public init(url: URL, text: String)
		{
			self.url = url
			self.text = text
			super.init()
		}
	}

	class FileTask: NSObject
	{
		public let urls: [URL]
		public init(_ urls: [URL])
		{
			self.urls = urls
			super.init()
		}
	}

	class SearchTask: NSObject
	{
		public struct Results
		{
			public let moreResultsAvailable: Bool
			public let results: [DFSKIndex.SearchResult]
		}

		public let query: String
		let search: DFSKIndex.ProgressiveSearch
		public init(_ index: DFSKIndex, query: String)
		{
			self.query = query
			self.search = index.progressiveSearch(index, query: query)
			super.init()
		}

		deinit
		{
			self.search.cancel()
		}

		public func next(_ maxResults: Int,
						 complete: @escaping (SearchTask, Results) -> Void)
		{
			DispatchQueue.global(qos: .userInitiated).async
			{
				let results = self.search.next(maxResults, timeout: 0.3)
				let searchResults = SearchTask.Results(moreResultsAvailable: results.moreResultsAvailable, results: results.results)
				DispatchQueue.main.async
				{
					complete(self, searchResults)
				}
			}
		}
	}
}

// MARK: Add

extension DFSKIndexAsyncController
{
	/// Add text async
	public func addText(async url: URL, text: String, complete: @escaping (TextTask) -> Void)
	{
		let b = BlockOperation
		{ [weak self] in
			_ = self?.index.add(url, text: text)
		}

		self.modifyQueue.addOperation(b)

		let textOp = TextTask(url: url, text: text)
		let completeBlock = BlockOperation
		{
			complete(textOp)
		}

		self.modifyQueue.addOperation(completeBlock)
	}

	/// Add documents async
	public func addURLs(async operation: FileTask, complete: @escaping (FileTask) -> Void)
	{
		DispatchQueue.global(qos: .userInitiated).async
		{ [weak self] in
			var newUrls: [URL] = []
			var blocks: [BlockOperation] = []
			operation.urls.forEach
			{
				let url = $0
				if FileManager.default.folderExists(url: url)
				{
					let urls = self?.folderUrls(url)
					for url in urls!
					{
						let b = BlockOperation
						{ [weak self] in
							_ = self?.index.add(url: url)
						}
						blocks.append(b)
						newUrls.append(url)
					}
				}
				else if FileManager.default.fileExists(url: url)
				{
					let b = BlockOperation
					{ [weak self] in
						_ = self?.index.add(url: url)
					}
					blocks.append(b)
					newUrls.append(url)
				}
			}

			let b = BlockOperation
			{
				complete(FileTask(newUrls))
			}

			self?.modifyQueue.addOperations(blocks, waitUntilFinished: false)
			self?.modifyQueue.addOperation(b)
		}
	}

	private func folderUrls(_ folderURL: URL) -> [URL]
	{
		let fileManager = FileManager.default

		guard fileManager.folderExists(url: folderURL) else
		{
			return []
		}

		var addedUrls: [URL] = []
		let enumerator = FileManager.default.enumerator(at: folderURL, includingPropertiesForKeys: nil)
		while let fileURL = enumerator?.nextObject() as? URL
		{
			if fileManager.fileExists(url: fileURL)
			{
				addedUrls.append(fileURL)
			}
		}
		return addedUrls
	}
}

// MARK: Remove

extension DFSKIndexAsyncController
{
	/// Remove text async
	public func removeText(async operation: TextTask, complete: @escaping (TextTask) -> Void)
	{
		let url = operation.url
		let removeBlock = BlockOperation
		{ [weak self] in
			_ = self?.index.remove(url: url)
		}

		let completeBlock = BlockOperation
		{
			complete(operation)
		}

		self.modifyQueue.addOperation(removeBlock)
		self.modifyQueue.addOperation(completeBlock)
	}

	/// Remove documents async
	public func removeURLs(async operation: FileTask, complete: @escaping (FileTask) -> Void)
	{
		var removeUrls: [BlockOperation] = []

		operation.urls.forEach
		{ url in
			let b = BlockOperation
			{ [weak self] in
				_ = self?.index.remove(url: url)
			}
			removeUrls.append(b)
		}

		let completeBlock = BlockOperation
		{
			complete(FileTask(operation.urls))
		}

		self.modifyQueue.addOperations(removeUrls, waitUntilFinished: false)
		self.modifyQueue.addOperation(completeBlock)
	}
}

// MARK: Search

public extension DFSKIndexAsyncController
{
	/// Create a search task
	public func search(async query: String) -> SearchTask
	{
		return SearchTask(self.index, query: query)
	}

	/// Get the next results on a search task, returning the results on the main thread
	public func next(_ search: SearchTask,
					 maxResults: Int,
					 complete: @escaping (SearchTask, DFSKIndex.ProgressiveSearch.Results) -> Void)
	{
		DispatchQueue.global(qos: .userInitiated).async
		{
			let results = search.search.next(maxResults, timeout: 0.3)
			let searchResults = DFSKIndex.ProgressiveSearch.Results(moreResultsAvailable: results.moreResultsAvailable, results: results.results)
			DispatchQueue.main.async
			{
				complete(search, searchResults)
			}
		}
	}

	public func cancel(_ search: SearchTask)
	{
		search.search.cancel()
	}
}

// MARK: Utilities

fileprivate extension FileManager
{
	func fileExists(url: URL) -> Bool
	{
		return self.urlExists(url: url, isDirectory: false)
	}

	func folderExists(url: URL) -> Bool
	{
		return self.urlExists(url: url, isDirectory: true)
	}

	private func urlExists(url: URL, isDirectory: Bool) -> Bool
	{
		var isDir: ObjCBool = true
		if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
		{
			return isDirectory == isDir.boolValue
		}
		return false
	}
}
