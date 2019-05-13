//
//  DFSearchIndexFile.swift
//  DFSearchKit
//
//  Created by Darren Ford on 26/5/18.
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

import Foundation

extension DFSearchIndex {
	/// A file-based index
	@objc(DFSearchIndexFile) public class File: DFSearchIndex {
		/// The file url where the index is located
		@objc public let fileURL: URL

		private init(url: URL, index: SKIndex) {
			self.fileURL = url
			super.init(index: index)
		}

		/// Open an index from a file url.
		///
		/// - Parameters:
		///   - fileURL: The file url to open
		///   - writable: should the index be modifiable?
		/// - Returns: A new index object if successful, nil otherwise
		@objc public static func Open(fileURL: URL, writable: Bool) -> DFSearchIndex.File? {
			if let temp = SKIndexOpenWithURL(fileURL as CFURL, nil, writable) {
				return DFSearchIndex.File(url: fileURL, index: temp.takeUnretainedValue())
			}
			return nil
		}

		/// Create an indexer using a new data container for the store
		///
		/// - Parameter fileURL: the file URL to store the index at.  url must be a non-existent file
		/// - Parameter properties: the properties for index creation
		/// - Returns: A new index object if successful, nil otherwise. Returns nil if the file already exists at url
		@objc public static func Create(fileURL: URL, properties: CreateProperties = CreateProperties()) -> DFSearchIndex.File? {
			if !FileManager.default.fileExists(atPath: fileURL.absoluteString),
				let skIndex = SKIndexCreateWithURL(
					fileURL as CFURL,
					nil,
					properties.indexType,
					properties.properties()
				) {
				return DFSearchIndex.File(url: fileURL, index: skIndex.takeUnretainedValue())
			} else {
				return nil
			}
		}

		/// Flush, compact and write the content of the index to the file
		@objc public func save() {
			flush()
			compact()
		}
	}
}
