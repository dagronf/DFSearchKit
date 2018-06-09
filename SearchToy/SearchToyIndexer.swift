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
	
	private var index: DFSKDataIndex
	
	/// Queue for handling async modifications to the index
	let modifyQueue = OperationQueue()
	
	static func create() -> SearchToyIndexer
	{
		let indexer = SearchToyIndexer(DFSKDataIndex.create()!)
		return indexer
	}
	
	init(_ index: DFSKDataIndex) {
		self.index = index
		self.modifyQueue.maxConcurrentOperationCount = 6
		
		super.init()
	}
	
	static func load(_ data: Data) -> SearchToyIndexer?
	{
		if let index = DFSKDataIndex.load(from: data)
		{
			return SearchToyIndexer.init(index)
		}
		return nil
	}
	
	func save() -> Data
	{
		self.index.compact()
		return self.index.save()!
	}
	
	/// Add text async
	func addText(_ url: URL, text: String) -> TextOperation
	{
		let b = BlockOperation { [weak self] in
			_ = self?.index.add(url, text: text)
		}
		self.modifyQueue.addOperation(b)
		return TextOperation(url: url, text: text)
	}
	
	/// Remove documents async
	func removeURLs(_ urls: [URL])
	{
		urls.forEach { url in
			let b = BlockOperation { [weak self] in
				_ = self?.index.remove(url: url)
			}
			self.modifyQueue.addOperation(b)
		}
	}
	
	/// Remove text async
	func removeText(_ operation: TextOperation) -> TextOperation
	{
		let url = operation.url
		let b = BlockOperation { [weak self] in
			_ = self?.index.remove(url: url)
		}
		self.modifyQueue.addOperation(b)
		return operation
	}
	
	/// Add documents async
	func addURLs(_ urls: [URL], urlLoaded: @escaping ([URL]) -> Void)
	{
		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
			var newUrls: [URL] = []
			var blocks: [BlockOperation] = []
			urls.forEach {
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
			
			urlLoaded(newUrls)
			self?.modifyQueue.addOperations(blocks, waitUntilFinished: false)
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
