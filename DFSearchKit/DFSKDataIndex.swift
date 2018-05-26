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

	init(data: NSMutableData, index: SKIndex)
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

	static func load(from data: NSData) -> DFSKDataIndex?
	{
		let data = data.mutableCopy() as! NSMutableData
		if let skIndex = SKIndexOpenWithMutableData(data, nil)
		{
			return DFSKDataIndex.init(data: data, index: skIndex.takeUnretainedValue())
		}

		return nil
	}

	func save() -> NSData?
	{
		flush()
		compact()
		return self.data.copy() as? NSData;
	}
}
