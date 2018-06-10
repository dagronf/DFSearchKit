//
//  SearchToyIndexer.swift
//  SearchToy
//
//  Created by Darren Ford on 9/6/18.
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

import Cocoa
import DFSKSearchKit

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

protocol SearchToyIndexerProtocol
{
	func queueDidEmpty(_ indexer: SearchToyIndexer)
	func queueDidChange(_ count: Int)
}

/// Background indexer using operation queues
class SearchToyIndexer: NSObject {
	
	/// Class to help with undo/redo
	class TextOperation: NSObject
	{
		let url: URL
		let text: String
		init(url: URL, text: String) {
			self.url = url
			self.text = text
			super.init()
		}
	}

	class FileOperation: NSObject
	{
		let urls: [URL]
		init(_ urls: [URL]) {
			self.urls = urls
			super.init()
		}
	}

	private var index: DFSKDataIndex

	var delegate: SearchToyIndexerProtocol? = nil

	/// Queue for handling async modifications to the index
	let modifyQueue = OperationQueue()
	
	static func create() -> SearchToyIndexer {
		let indexer = SearchToyIndexer(DFSKDataIndex.create()!)
		return indexer
	}
	
	init(_ index: DFSKDataIndex) {
		self.index = index
		super.init()

		self.modifyQueue.maxConcurrentOperationCount = 6
		self.modifyQueue.addObserver(self, forKeyPath: "operations", options: .new, context: nil)
	}

	deinit {
		self.modifyQueue.removeObserver(self, forKeyPath: "operations")
	}

	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		if keyPath == "operations" {
			if self.modifyQueue.operations.count == 0 {
				self.delegate?.queueDidEmpty(self)
			}
			self.delegate?.queueDidChange(self.modifyQueue.operationCount)
		}
	}

	static func load(_ data: Data) -> SearchToyIndexer? {
		if let index = DFSKDataIndex.load(from: data) {
			return SearchToyIndexer.init(index)
		}
		return nil
	}
	
	func save() -> Data	{
		self.index.compact()
		return self.index.save()!
	}
	
	/// Add text async
	func addText(_ url: URL, text: String, complete: @escaping (TextOperation) -> Void)
	{
		let b = BlockOperation { [weak self] in
			_ = self?.index.add(url, text: text)
		}

		self.modifyQueue.addOperation(b)

		let textOp = TextOperation(url: url, text: text)
		let completeBlock = BlockOperation {
			complete(textOp)
		}

		self.modifyQueue.addOperation(completeBlock)
	}
	
	/// Remove documents async
	func removeURLs(_ operation: FileOperation, complete: @escaping (FileOperation) -> Void) {
		var removeUrls: [BlockOperation] = []

		operation.urls.forEach { url in
			let b = BlockOperation { [weak self] in
				_ = self?.index.remove(url: url)
			}
			removeUrls.append(b)
		}

		let completeBlock = BlockOperation {
			complete(FileOperation(operation.urls))
		}

		self.modifyQueue.addOperations(removeUrls, waitUntilFinished: false)
		self.modifyQueue.addOperation(completeBlock)
	}
	
	/// Remove text async
	func removeText(_ operation: TextOperation, complete: @escaping (TextOperation) -> Void)
	{
		let url = operation.url
		let removeBlock = BlockOperation { [weak self] in
			_ = self?.index.remove(url: url)
		}

		let completeBlock = BlockOperation {
			complete(operation)
		}

		self.modifyQueue.addOperation(removeBlock)
		self.modifyQueue.addOperation(completeBlock)
	}
	
	/// Add documents async
	func addURLs(_ operation: FileOperation, complete: @escaping (FileOperation) -> Void)
	{
		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
			var newUrls: [URL] = []
			var blocks: [BlockOperation] = []
			operation.urls.forEach {
				let url = $0
				var isDir: ObjCBool = false
				if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
				{
					if isDir.boolValue
					{
						let urls = self?.folderUrls(url)
						for url in urls!
						{
							let b = BlockOperation { [weak self] in
								_ = self?.index.add(url: url)
							}
							blocks.append(b)
							newUrls.append(url)
						}
					}
					else
					{
						let b = BlockOperation { [weak self] in
							_ = self?.index.add(url: url)
						}
						blocks.append(b)
						newUrls.append(url)
					}
				}
			}

			let b = BlockOperation {
				complete(FileOperation(newUrls))
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
	
	func flush()
	{
		self.index.flush()
	}
	
	func search(_ query: String,
				limit: Int = 10,
				timeout: TimeInterval = 1.0,
				options: SKSearchOptions = SKSearchOptions(kSKSearchOptionDefault)) -> [ DFSKIndex.SearchResult ]
	{
		return self.index.search(query, limit: limit, timeout: timeout, options: options)
	}
	
	func documents() -> [URL]
	{
		return self.index.documents()
	}
	
}
