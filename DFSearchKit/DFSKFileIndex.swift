//
//  DFSKFileIndex.swift
//  DFSearchKit
//
//  Created by Darren Ford on 26/5/18.
//  Copyright © 2018 Darren Ford. All rights reserved.
//

import Foundation

class DFSKFileIndex: DFSKIndex
{
	private(set) var fileURL: URL?

	init(url: URL, index: SKIndex)
	{
		super.init(index: index)
		self.fileURL = url
	}

	static func load(from url: URL, writable: Bool) -> DFSKFileIndex?
	{
		if let temp = SKIndexOpenWithURL(url as CFURL, nil, writable)
		{
			return DFSKFileIndex.init(url: url, index: temp.takeUnretainedValue())
		}

		return nil
	}

	static func create(with url: URL, properties: Properties = Properties()) -> DFSKFileIndex?
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

	func save()
	{
		flush()
		compact()
	}
}
