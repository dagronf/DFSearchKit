//
//  DFSearchIndexAsyncController.swift
//  DFSearchKitTests
//
//  Created by Darren Ford on 11/6/18.
//  Copyright © 2019 Darren Ford. All rights reserved.
//

import Foundation

/// Protocol for notifying a delegate when the operation queue changes state
@objc public protocol DFSearchIndexAsyncControllerProtocol {
	/// The queue is now empty
	func queueDidEmpty(_ indexer: DFSearchIndex.AsyncController)
	/// The queue's operation count did change
	func queueDidChange(_ indexer: DFSearchIndex.AsyncController, count: Int)
}

extension DFSearchIndex {
	/// A controller for a DFSearchIndex object that supports asynchronous calls to the index
	@objc(DFSearchIndexAsyncController) public class AsyncController: NSObject {
		let index: DFSearchIndex
		let delegate: DFSearchIndexAsyncControllerProtocol?

		/// Queue for handling async modifications to the index
		fileprivate let modifyQueue = OperationQueue()

		/// Is the controller currently processing requests?
		@objc public dynamic var queueComplete: Bool = true
		/// The total number of outstanding requests
		@objc public dynamic var queueSize: Int = 0

		/// Initializer
		public init(index: DFSearchIndex, delegate: DFSearchIndexAsyncControllerProtocol?) {
			self.index = index
			self.delegate = delegate
			super.init()

			self.modifyQueue.maxConcurrentOperationCount = 6
			self.modifyQueue.addObserver(self, forKeyPath: "operations", options: .new, context: nil)
			self.addObserver(self, forKeyPath: "queueComplete", options: .new, context: nil)
		}

		deinit {
			self.modifyQueue.removeObserver(self, forKeyPath: "operations")
		}

		/// Queue observer
		public override func observeValue(
			forKeyPath keyPath: String?,
			of _: Any?,
			change _: [NSKeyValueChangeKey: Any]?,
			context _: UnsafeMutableRawPointer?
		) {
			if keyPath == "operations" {
				self.willChangeValue(for: \.queueSize)
				self.willChangeValue(for: \.queueComplete)
				self.queueSize = self.modifyQueue.operationCount
				self.queueComplete = (self.queueSize == 0)
				self.didChangeValue(for: \.queueSize)
				self.didChangeValue(for: \.queueComplete)

				if self.queueSize == 0 {
					if let delegate = self.delegate {
						delegate.queueDidEmpty(self)
					}
				}

				self.delegate?.queueDidChange(self, count: self.modifyQueue.operationCount)
			}
		}

		/// Cancel all the outstanding requests if they haven't already been started.
		///
		/// Note that all tasks waiting on completion that are cancelled will not be called back
		///
		/// - Parameter complete: called when the cancel operation is complete
		@objc public func cancelCurrent(_ complete: @escaping () -> Void) {
			self.modifyQueue.cancelAllOperations()
			self.waitUntilQueueIsComplete(complete)
		}

		/// Call back when the operation queue is complete (ie. empty)
		///
		/// - Parameter complete: called when all the operations are complete
		@objc public func waitUntilQueueIsComplete(_ complete: @escaping () -> Void) {
			if self.queueComplete {
				complete()
			} else {
				DispatchQueue.global(qos: .userInitiated).async { [weak self] in
					self?.modifyQueue.waitUntilAllOperationsAreFinished()
					complete()
				}
			}
		}
	}
}

// MARK: Async task objects

@objc(DFSearchIndexAsyncController) public extension DFSearchIndex.AsyncController {
	/// A task for asynchronously handling the addition of text to the index
	@objc(DFSearchIndexAsyncControllerTextTask)
	class TextTask: NSObject {
		public let url: URL
		public let text: String

		/// Create a text async task
		///
		/// - Parameters:
		///   - url: the identifying document URL
		///   - text: The text to add to the index
		public init(url: URL, text: String) {
			self.url = url
			self.text = text
			super.init()
		}
	}

	/// A task for handling file input
	@objc(DFSearchIndexAsyncControllerFilesTask)
	class FilesTask: NSObject {
		public let urls: [URL]

		/// Add file URLs to the search index
		///
		/// - Parameter urls: The urls to add
		public init(_ urls: [URL]) {
			self.urls = urls
			super.init()
		}
	}

	/// A task for handling searches
	@objc(DFSearchIndexAsyncControllerSearchTask)
	class SearchTask: NSObject {
		fileprivate let search: DFSearchIndex.ProgressiveSearch

		/// The search term used to create the task
		public let query: String

		/// Create a search task in the specified index
		fileprivate init(_ index: DFSearchIndex, query: String) {
			self.query = query
			self.search = index.progressiveSearch(query: query)
			super.init()
		}

		deinit {
			self.search.cancel()
		}

		/// Return the next chunk of search results
		///
		/// - Parameters:
		///   - maxResults: The maximum number of search results to return in the chunk
		///   - timeout: How long to 'wait' to receive the results
		///   - complete: Callback block for when the search is complete
		public func next(
			_ maxResults: Int,
			timeout: TimeInterval = 1.0,
			complete: @escaping (SearchTask, DFSearchIndex.ProgressiveSearch.Results) -> Void
		) {
			DispatchQueue.global(qos: .userInitiated).async {
				let results = self.search.next(maxResults, timeout: timeout)
				let searchResults = DFSearchIndex.ProgressiveSearch.Results(moreResultsAvailable: results.moreResultsAvailable, results: results.results)
				DispatchQueue.main.async {
					complete(self, searchResults)
				}
			}
		}
	}
}

// MARK: Add

@objc(DFSearchIndexAsyncController) public extension DFSearchIndex.AsyncController {
	/// Create a flush operation
	private func flushOperation() -> BlockOperation {
		let flushOperation = BlockOperation()
		flushOperation.addExecutionBlock { [weak self, weak flushOperation] in
			if flushOperation?.isCancelled == false {
				_ = self?.index.flush()
			}
		}
		return flushOperation
	}

	/// Add text elements to the index asynchronously
	///
	/// - Parameters:
	///   - textTasks: the texts to add
	///   - flushWhenComplete: If true, flushes the index once all of the URLs are added
	///   - complete: Callback block when the add has completed
	@objc func addText(
		async textTasks: [TextTask],
		flushWhenComplete: Bool = false,
		complete: @escaping ([TextTask]) -> Void
	) {
		var addOperations: [BlockOperation] = []
		for task in textTasks {
			let addBlock = BlockOperation()
			addBlock.addExecutionBlock { [weak self, weak addBlock] in
				if addBlock?.isCancelled == false {
					_ = self?.index.add(task.url, text: task.text)
				}
			}
			addOperations.append(addBlock)
		}

		// Create our 'we've finished' operation
		let completeOperation = BlockOperation()
		completeOperation.completionBlock = {
			complete(textTasks)
		}

		if flushWhenComplete {
			let flushOperation = self.flushOperation()

			// The flush operation has to occur when all the add operations are complete
			addOperations.forEach { flushOperation.addDependency($0) }
			completeOperation.addDependency(flushOperation)
			addOperations.append(flushOperation)
		} else {
			// Make our completion dependent on all the 'add' blocks
			addOperations.forEach { completeOperation.addDependency($0) }
		}
		addOperations.append(completeOperation)

		self.modifyQueue.addOperations(addOperations, waitUntilFinished: false)
	}

	/// Add file urls to the index asynchronously.
	///
	/// - Parameters:
	///   - fileTask: The file operation to complete
	///   - flushWhenComplete: If true, flushes the index once all of the URLs are added
	///   - complete: Callback block when the add has completed
	@objc func addURLs(
		async fileTask: FilesTask,
		flushWhenComplete: Bool = false,
		complete: @escaping (FilesTask) -> Void
	) {
		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
			var newUrls: [URL] = []
			var addOperations: [BlockOperation] = []

			fileTask.urls.forEach {
				let url = $0
				if FileManager.default.folderExists(url: url) {
					let urls = self?.folderUrls(url)
					for url in urls! {
						let addOperation = BlockOperation()
						addOperation.addExecutionBlock { [weak self, weak addOperation] in
							if addOperation?.isCancelled == false {
								_ = self?.index.add(fileURL: url)
							}
						}
						addOperations.append(addOperation)
						newUrls.append(url)
					}
				} else if FileManager.default.fileExists(url: url) {
					let addOperation = BlockOperation()
					addOperation.addExecutionBlock { [weak self, weak addOperation] in
						if addOperation?.isCancelled == false {
							_ = self?.index.add(fileURL: url)
						}
					}
					addOperations.append(addOperation)
					newUrls.append(url)
				}
			}

			// Create our 'we've finished' operation
			let completeOperation = BlockOperation()
			completeOperation.completionBlock = {
				complete(FilesTask(newUrls))
			}

			if flushWhenComplete,
				let flushOperation = self?.flushOperation() {
				// The flush operation has to occur when all the add operations are complete
				addOperations.forEach { flushOperation.addDependency($0) }
				completeOperation.addDependency(flushOperation)
				addOperations.append(flushOperation)
			} else {
				// Make our completion dependent on all the 'add' blocks
				addOperations.forEach { completeOperation.addDependency($0) }
			}
			addOperations.append(completeOperation)
			self?.modifyQueue.addOperations(addOperations, waitUntilFinished: false)
		}
	}

	/// Returns all of the files contained within the specified folder url recursively
	///
	/// - Parameter folderURL: The folder to be scanned
	/// - Returns: An array of all the file URLs contained within the folder
	private func folderUrls(_ folderURL: URL) -> [URL] {
		let fileManager = FileManager.default

		guard fileManager.folderExists(url: folderURL) else {
			return []
		}

		var addedUrls: [URL] = []
		let enumerator = FileManager.default.enumerator(at: folderURL, includingPropertiesForKeys: nil)
		while let fileURL = enumerator?.nextObject() as? URL {
			if fileManager.fileExists(url: fileURL) {
				addedUrls.append(fileURL)
			}
		}
		return addedUrls
	}
}

// MARK: Remove

@objc(DFSearchIndexAsyncController) public extension DFSearchIndex.AsyncController {
	/// Remove all documents with zero terms from the index
	///
	/// - Parameter complete: called when the task is complete
	@objc func prune(complete: @escaping (FilesTask) -> Void) {
		let emptyURLs = self.index.documents(termState: .Empty)
		let fileTask = FilesTask(emptyURLs)
		self.removeURLs(async: fileTask, complete: complete)
	}

	/// Remove text async
	@objc func removeText(
		async tasks: [TextTask],
		flushWhenComplete: Bool = false,
		complete: @escaping ([TextTask]) -> Void
	) {
		var removeOperations: [BlockOperation] = []
		for task in tasks {
			let url = task.url
			let removeOperation = BlockOperation()
			removeOperation.addExecutionBlock { [weak self, weak removeOperation] in
				if removeOperation?.isCancelled == false {
					_ = self?.index.remove(url: url)
				}
			}
			removeOperations.append(removeOperation)
		}

		// Create our 'we've finished' operation
		let completeOperation = BlockOperation()
		completeOperation.completionBlock = {
			complete(tasks)
		}

		if flushWhenComplete {
			let flushOperation = self.flushOperation()

			// The flush operation has to occur when all the add operations are complete
			removeOperations.forEach { flushOperation.addDependency($0) }
			completeOperation.addDependency(flushOperation)
			removeOperations.append(flushOperation)
		} else {
			// Make our completion dependent on all the 'add' blocks
			removeOperations.forEach { completeOperation.addDependency($0) }
		}
		removeOperations.append(completeOperation)

		self.modifyQueue.addOperations(removeOperations, waitUntilFinished: false)
	}

	/// Remove documents async
	@objc func removeURLs(
		async operation: FilesTask,
		flushWhenComplete: Bool = false,
		complete: @escaping (FilesTask) -> Void
	) {
		var removeOperations: [BlockOperation] = []

		operation.urls.forEach { url in
			let removeOperation = BlockOperation { [weak self] in
				_ = self?.index.remove(url: url)
			}
			removeOperations.append(removeOperation)
		}

		// Create our 'we've finished' operation
		let completeOperation = BlockOperation()
		completeOperation.completionBlock = {
			complete(FilesTask(operation.urls))
		}

		if flushWhenComplete {
			let flushOperation = self.flushOperation()

			// The flush operation has to occur when all the add operations are complete
			removeOperations.forEach { flushOperation.addDependency($0) }
			completeOperation.addDependency(flushOperation)
			removeOperations.append(flushOperation)
		} else {
			// Make our completion dependent on all the 'add' blocks
			removeOperations.forEach { completeOperation.addDependency($0) }
		}
		removeOperations.append(completeOperation)

		self.modifyQueue.addOperations(removeOperations, waitUntilFinished: false)
	}
}

// MARK: Search

@objc(DFSearchIndexAsyncController) public extension DFSearchIndex.AsyncController {
	/// Create a search task
	@objc func search(async query: String) -> SearchTask {
		return SearchTask(self.index, query: query)
	}
}

// MARK: Utilities

private extension FileManager {
	func fileExists(url: URL) -> Bool {
		return self.urlExists(url: url, isDirectory: false)
	}

	func folderExists(url: URL) -> Bool {
		return self.urlExists(url: url, isDirectory: true)
	}

	private func urlExists(url: URL, isDirectory: Bool) -> Bool {
		var isDir: ObjCBool = true
		if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
			return isDirectory == isDir.boolValue
		}
		return false
	}
}
