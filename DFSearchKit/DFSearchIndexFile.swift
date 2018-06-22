//
//  DFSearchIndexFile.swift
//  DFSearchKit
//
//  Created by Darren Ford on 26/5/18.
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

/// A file-based index
@objc public class DFSearchIndexFile: DFSearchIndex
{
	/// The file url where the index is located
	@objc public private(set) var fileURL: URL?

	private init(url: URL, index: SKIndex)
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
	@objc public static func open(from url: URL, writable: Bool) -> DFSearchIndexFile?
	{
		if let temp = SKIndexOpenWithURL(url as CFURL, nil, writable)
		{
			return DFSearchIndexFile(url: url, index: temp.takeUnretainedValue())
		}

		return nil
	}

	/// Create an indexer using a new data container for the store
	///
	/// - Parameter url: the file URL to store the index at.  url must be a non-existent file
	/// - Parameter properties: the properties for index creation
	/// - Returns: A new index object if successful, nil otherwise. Returns nil if the file already exists at url
	@objc public static func create(with url: URL, properties: CreateProperties = CreateProperties()) -> DFSearchIndexFile?
	{
		if !FileManager.default.fileExists(atPath: url.absoluteString),
			let skIndex = SKIndexCreateWithURL(
				url as CFURL,
				nil,
				properties.indexType,
				properties.properties()
			)
		{
			return DFSearchIndexFile(url: url, index: skIndex.takeUnretainedValue())
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
