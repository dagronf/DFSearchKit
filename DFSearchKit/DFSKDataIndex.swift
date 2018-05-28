//
//  DFSKDataIndex.swift
//  DFSearchKit
//
//  Created by Darren Ford on 26/5/18.
//  Copyright © 2018 Darren Ford. All rights reserved.
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
