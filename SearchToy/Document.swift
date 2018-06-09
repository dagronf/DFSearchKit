//
//  Document.swift
//  SearchToy
//
//  Created by Darren Ford on 9/6/18.
//  Copyright © 2018 Darren Ford. All rights reserved.
//

import Cocoa

import DFSKSearchKit

class Document: NSDocument {

	@IBOutlet weak var urlField: NSTextField!
	@IBOutlet var docContentView: NSTextView!

	@IBOutlet weak var queryField: NSTextField!
	@IBOutlet var queryResultView: NSTextView!

	private var index: DFSKDataIndex?

	override init() {
	    super.init()
		// Add your subclass-specific initialization here.

		self.index = DFSKDataIndex.create()
	}

	override var windowNibName: NSNib.Name? {
		// Returns the nib file name of the document
		// If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this property and override -makeWindowControllers instead.
		return NSNib.Name("Document")
	}

	override func data(ofType typeName: String) throws -> Data
	{
		if let index = self.index
		{
			index.compact()
			return index.save()!
		}
		throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
	}

	override func read(from data: Data, ofType typeName: String) throws
	{
		self.index = DFSKDataIndex.load(from: data)
		if self.index == nil
		{
			throw NSError(domain: NSOSStatusErrorDomain, code: readErr, userInfo: nil)
		}
	}

}

extension Document
{
	@IBAction func addText(_ sender: NSButton)
	{
		if let url = URL(string: self.urlField.stringValue)
		{
			let text = self.docContentView.string
			_ = self.index!.add(url, text: text)

			self.updateChangeCount(NSDocument.ChangeType.changeDone)
		}
	}

	@IBAction func searchText(_ sender: NSButton)
	{
		self.index?.flush()

		let searchText = self.queryField.stringValue
		if searchText.count > 0
		{
			let result = self.index?.search(searchText)

			var str: String = ""
			result?.forEach {
				str += "\($0.url) - (\($0.score))\n"
			}

			self.queryResultView.string = str
		}
	}

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
				self.addURLs(panel.urls)
			}
		}
	}

	private func addURLs(_ urls: [URL])
	{
		guard let index = self.index else
		{
			return
		}

		var addedURLs: [URL] = []
		urls.forEach {
			let url = $0
			var isDir: ObjCBool = false
			if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
			{
				if isDir.boolValue
				{
					addedURLs.append(contentsOf: index.addFolderContent(folderURL: url))
				}
				else if index.add(url: url)
				{
					addedURLs.append(url)
				}
			}
		}

		if addedURLs.count > 0
		{
			self.updateChangeCount(NSDocument.ChangeType.changeDone)
		}
	}
}

