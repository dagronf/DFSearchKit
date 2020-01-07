//
//  Document.swift
//  SearchToy
//
//  Created by Darren Ford on 9/6/18.
//  Copyright © 2019 Darren Ford. All rights reserved.
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

import DFSearchKit

class Document: NSDocument {
	
	@IBOutlet weak var urlField: NSTextField!
	@IBOutlet var docContentView: NSTextView!
	
	@IBOutlet weak var filesTable: NSTableView!

	@IBOutlet weak var queryField: NSTextField!
	@IBOutlet var queryResultView: NSTextView!

	private var index: DFSearchIndex.Memory = DFSearchIndex.Memory.Create()!
	private var indexer: DFSearchIndex.AsyncController?

	@objc dynamic fileprivate var operationCount: Int = 0
	@objc dynamic fileprivate var files: [URL] = []

	override init() {
		super.init()

		// Create a blank index for empty documents
		self.indexer = DFSearchIndex.AsyncController.init(index: index, delegate: self)

	}

	override var windowNibName: NSNib.Name? {
		// Returns the nib file name of the document
		// If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this property and override -makeWindowControllers instead.
		return NSNib.Name("Document")
	}

	override func windowControllerDidLoadNib(_ windowController: NSWindowController) {
		self.updateFiles()
	}
}

// MARK: - Read/Write

enum OpenError: Error {
	case runtimeError(String)
}

extension Document
{
	override func data(ofType typeName: String) throws -> Data
	{
		return self.index.data()!
	}
	
	override func read(from data: Data, ofType typeName: String) throws
	{
		guard let index = DFSearchIndex.Memory.Load(from: data) else {
			throw OpenError.runtimeError("Unable to load index file")
		}
		self.index = DFSearchIndex.Memory.Load(from: data)!
		self.indexer = DFSearchIndex.AsyncController.init(index: index, delegate: self)
	}
}

// MARK: - Add text

extension Document
{
	@IBAction func addText(_ sender: NSButton)
	{
		if let url = URL(string: self.urlField.stringValue)
		{
			let text = self.docContentView.string
			self.addTextOperation([DFSearchIndex.AsyncController.TextTask(url: url, text: text)])
		}
	}
	
	@objc func addTextOperation(_ textTasks: [DFSearchIndex.AsyncController.TextTask])
	{
		self.indexer?.addText(async: textTasks, complete: { [weak self] textTasks in
			if let blockSelf = self {
				DispatchQueue.main.async {
					blockSelf.undoManager?.registerUndo(withTarget: blockSelf, selector:#selector(blockSelf.removeTextOperation), object:textTasks)
					blockSelf.undoManager?.setActionName("Add Text")
					blockSelf.updateFiles()
				}
			}
		})
	}
	
	@objc func removeTextOperation(_ textTasks: [DFSearchIndex.AsyncController.TextTask])
	{
		self.indexer?.removeText(async: textTasks, complete: { [weak self] textTasks in
			if let blockSelf = self {
				DispatchQueue.main.async {
					blockSelf.undoManager?.registerUndo(withTarget: blockSelf, selector:#selector(blockSelf.addTextOperation), object:textTasks)
					blockSelf.undoManager?.setActionName("Remove Text")
					blockSelf.updateFiles()
				}
			}
		})
	}
}

// MARK: - Add files

extension Document
{
	@IBAction func addFiles(_ sender: Any)
	{
		let panel = NSOpenPanel()
		panel.showsResizeIndicator    = true;
		panel.canChooseDirectories    = true;
		panel.canCreateDirectories    = true;
		panel.allowsMultipleSelection = true;
		let window = self.windowControllers[0].window
		panel.beginSheetModal(for: window!) { (result) in
			if result == NSApplication.ModalResponse.OK
			{
				self.addURLs(DFSearchIndex.AsyncController.FilesTask(panel.urls))
			}
		}
	}
	
	@objc func addURLs(_ fileTask: DFSearchIndex.AsyncController.FilesTask)
	{
		self.indexer?.addURLs(async: fileTask, flushWhenComplete: true, complete: { [weak self] fileTask in
			if let blockSelf = self {
				DispatchQueue.main.async {
					blockSelf.undoManager?.registerUndo(withTarget: blockSelf, selector:#selector(blockSelf.removeURLs), object:fileTask)
					blockSelf.undoManager?.setActionName("Add \(fileTask.urls.count) Documents")
					blockSelf.updateFiles()
				}
			}
		})
	}
	
	@objc func removeURLs(_ fileTask: DFSearchIndex.AsyncController.FilesTask) {
		self.indexer?.removeURLs(async: fileTask, flushWhenComplete: true, complete: { [weak self] fileTask in
			if let blockSelf = self {
				DispatchQueue.main.async {
					blockSelf.undoManager?.registerUndo(withTarget: blockSelf, selector:#selector(blockSelf.addURLs), object:fileTask)
					blockSelf.undoManager?.setActionName("Remove \(fileTask.urls.count) Documents")
					blockSelf.updateFiles()
				}
			}
		})
	}
}

// MARK: - Search

extension Document
{

	func searchNext(_ searchTask: DFSearchIndex.AsyncController.SearchTask)
	{
		searchTask.next(10) { [weak self] (searchTask, results) in

			if results.moreResultsAvailable
			{
				self?.searchNext(searchTask)
			}
		}
	}

	@IBAction func searchText(_ sender: NSButton)
	{
		let searchText = self.queryField.stringValue

		self.index.flush()

		if searchText.count > 0 {
			let result = index.search(searchText)

			var str: String = ""
			result.forEach {
				str += "\($0.url) - (\($0.score))\n"
			}

			self.queryResultView.string = str
		}
		else
		{
			let result = index.documents()
			var str: String = ""
			result.forEach {
				str += "\($0)\n"
			}
			self.queryResultView.string = str
		}
	}
}

extension Document: DFSearchIndexAsyncControllerProtocol
{
	func queueDidEmpty(_ indexer: DFSearchIndex.AsyncController)
	{
	}

	func queueDidChange(_ indexer: DFSearchIndex.AsyncController, count: Int)
	{
		DispatchQueue.main.async { [weak self] in
			self?.operationCount = count
		}
	}

	func updateFiles()
	{
		self.files = self.index.documents(termState: .NotEmpty)
	}
}

