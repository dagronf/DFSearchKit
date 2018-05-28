//
//  DFSKDataIndex.swift
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

/// A memory-based index using NSMutableData as the backing.
class DFSKDataIndex: DFSKIndex
{
	// The data index store
	private var data = NSMutableData()

	private init(data: NSMutableData, index: SKIndex)
	{
		super.init(index: index)
		self.data = data
	}

	/// Create an indexer using a new data container for the store
	///
	/// - Parameter properties: the properties for index creation
	/// - Returns: A new index object if successful, nil otherwise
	static func create(properties: CreateProperties = CreateProperties()) -> DFSKDataIndex?
	{
		let data = NSMutableData()
		if let skIndex = SKIndexCreateWithMutableData(data, nil,
													  properties.indexType,
													  properties.CFDictionary())
		{
			return DFSKDataIndex.init(data: data, index: skIndex.takeUnretainedValue())
		}
		return nil
	}

	/// Create an indexer using the data stored in 'data'.
	///
	/// **NOTE** Makes a copy of the data first - does not work on a live Data object
	///
	/// - Parameter data: The data to load as an index
	/// - Returns: A new index object if successful, nil otherwise
	static func load(from data: Data) -> DFSKDataIndex?
	{
		if let rawData = (data as NSData).mutableCopy() as? NSMutableData,
			let skIndex = SKIndexOpenWithMutableData(rawData, nil)
		{
			return DFSKDataIndex.init(data: rawData, index: skIndex.takeUnretainedValue())
		}

		return nil
	}

	/// Returns the index content as a (copied) Swift Data object
	func save() -> Data?
	{
		flush()
		return self.data.copy() as? Data
	}
}
