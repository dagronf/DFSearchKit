//
//  Document.swift
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

class Document: NSDocument {
	
	@IBOutlet weak var urlField: NSTextField!
	@IBOutlet var docContentView: NSTextView!
	
	@IBOutlet weak var filesTable: NSTableView!

	@IBOutlet weak var queryField: NSTextField!
	@IBOutlet var queryResultView: NSTextView!
	
	private var indexer: SearchToyIndexer?

	@objc dynamic fileprivate var operationCount: Int = 0
	@objc dynamic fileprivate var files: [URL] = []
	
	override init() {
		super.init()
		self.indexer = SearchToyIndexer.create()
		self.indexer?.delegate = self
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

extension Document
{
	override func data(ofType typeName: String) throws -> Data
	{
		if let index = self.indexer
		{
			return index.save()
		}
		throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
	}
	
	override func read(from data: Data, ofType typeName: String) throws
	{
		self.indexer = SearchToyIndexer.load(data)
		if self.indexer == nil
		{
			throw NSError(domain: NSOSStatusErrorDomain, code: readErr, userInfo: nil)
		}
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
			self.addTextOperation(SearchToyIndexer.TextOperation(url: url, text: text))
		}
	}
	
	@objc func addTextOperation(_ textOperation: SearchToyIndexer.TextOperation)
	{
		self.indexer?.addText(textOperation.url, text: textOperation.text, complete: { [weak self] textOperation in
			if let blockSelf = self {
				DispatchQueue.main.async {
					blockSelf.undoManager?.registerUndo(withTarget: blockSelf, selector:#selector(blockSelf.removeTextOperation), object:textOperation)
					blockSelf.undoManager?.setActionName("Add Text")
				}
			}
		})
		//self.updateChangeCount(NSDocument.ChangeType.changeDone)
	}
	
	@objc func removeTextOperation(_ textOperation: SearchToyIndexer.TextOperation)
	{
		self.indexer?.removeText(textOperation, complete: { [weak self] textOperation in
			if let blockSelf = self {
				DispatchQueue.main.async {
					blockSelf.undoManager?.registerUndo(withTarget: blockSelf, selector:#selector(blockSelf.addTextOperation), object:textOperation)
					blockSelf.undoManager?.setActionName("Remove Text")
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
				self.addURLs(SearchToyIndexer.FileOperation(panel.urls))
			}
		}
	}
	
	@objc func addURLs(_ operation: SearchToyIndexer.FileOperation)
	{
		self.indexer?.addURLs(operation, complete: { [weak self] fileOperation in
			if let blockSelf = self {
				DispatchQueue.main.async {
					blockSelf.undoManager?.registerUndo(withTarget: blockSelf, selector:#selector(blockSelf.removeURLs), object:fileOperation)
					blockSelf.undoManager?.setActionName("Add \(fileOperation.urls.count) Documents")
				}
			}
		})
	}
	
	@objc func removeURLs(_ operation: SearchToyIndexer.FileOperation) {
		self.indexer?.removeURLs(operation, complete: { [weak self] fileOperation in
			if let blockSelf = self {
				DispatchQueue.main.async {
					blockSelf.undoManager?.registerUndo(withTarget: blockSelf, selector:#selector(blockSelf.addURLs), object:fileOperation)
					blockSelf.undoManager?.setActionName("Remove \(fileOperation.urls.count) Documents")
				}
			}
		})
	}
}

// MARK: - Search

extension Document
{
	@IBAction func searchText(_ sender: NSButton)
	{
		guard let index = self.indexer else {
			return
		}
		
		index.flush()
		
		let searchText = self.queryField.stringValue
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

		updateFiles()
	}
}

extension Document: SearchToyIndexerProtocol
{
	func queueDidEmpty(_ indexer: SearchToyIndexer)
	{
		DispatchQueue.main.async { [weak self] in
			self?.updateFiles()
		}
	}

	func queueDidChange(_ count: Int)
	{
		DispatchQueue.main.async { [weak self] in
			self?.operationCount = count
		}
	}

	func updateFiles()
	{
		self.indexer?.flush()
		self.files = (self.indexer?.documents())!
	}
}

