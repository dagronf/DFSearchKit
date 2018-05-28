//
//  DFSKFileIndex.swift
//  DFSearchKit
//
//  Created by Darren Ford on 26/5/18.
//  Copyright © 2018 Darren Ford. All rights reserved.
//

import Foundation

/// A file-based index
class DFSKFileIndex: DFSKIndex
{
	/// The file url where the index is located
	private(set) var fileURL: URL?

	init(url: URL, index: SKIndex)
	{
		super.init(index: index)
		self.fileURL = url
	}

	/// Open an index from a file url.
	///
	/// - Parameters:
	///   - url: The file url to open
	///   - writable: should the index be modifiable?
	/// - Returns: A new index object if successful, nil otherwise
	static func open(from url: URL, writable: Bool) -> DFSKFileIndex?
	{
		if let temp = SKIndexOpenWithURL(url as CFURL, nil, writable)
		{
			return DFSKFileIndex.init(url: url, index: temp.takeUnretainedValue())
		}

		return nil
	}

	/// Create an indexer using a new data container for the store
	///
	/// - Parameter url: the file URL to store the index at.  url must be a non-existent file
	/// - Parameter properties: the properties for index creation
	/// - Returns: A new index object if successful, nil otherwise
	static func create(with url: URL, properties: CreateProperties = CreateProperties()) -> DFSKFileIndex?
	{
		if !FileManager.default.fileExists(atPath: url.absoluteString),
			let skIndex = SKIndexCreateWithURL(url as CFURL,
											   nil,
											   properties.indexType,
											   properties.CFDictionary())
		{
			return DFSKFileIndex.init(url: url, index: skIndex.takeUnretainedValue())
		}
		else
		{
			return nil
		}
	}

	/// Flush, compact and write the content of the index to the file
	func save()
	{
		flush()
		compact()
	}
}
