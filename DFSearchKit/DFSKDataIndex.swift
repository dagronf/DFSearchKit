//
//  DFSKDataIndex.swift
//  DFSearchKit
//
//  Created by Darren Ford on 26/5/18.
//  Copyright © 2018 Darren Ford. All rights reserved.
//

import Foundation

class DFSKDataIndex: DFSKIndex
{
	// The data index store
	private var data = NSMutableData()

	private init(data: NSMutableData, index: SKIndex)
	{
		super.init(index: index)
		self.data = data
	}

	static func create(properties: Properties = Properties()) -> DFSKDataIndex?
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

	static func load(from data: Data) -> DFSKDataIndex?
	{
		if let rawData = (data as NSData).mutableCopy() as? NSMutableData,
			let skIndex = SKIndexOpenWithMutableData(rawData, nil)
		{
			return DFSKDataIndex.init(data: rawData, index: skIndex.takeUnretainedValue())
		}

		return nil
	}

	func save() -> Data?
	{
		flush()
		return self.data.copy() as? Data
	}
}
