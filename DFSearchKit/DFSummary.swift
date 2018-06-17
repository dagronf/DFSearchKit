//
//  DFSummary.swift
//  DFSearchKitTests
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

import Foundation
import CoreServices

@objc public class DFSummary: NSObject
{
	@objc(DFSummarySentence)
	public class Sentence: NSObject
	{
		@objc public init(text: String, rank: Int, sentenceOrder: Int, paragraphOrder: Int)
		{
			self.text = text
			self.rank = rank
			self.sentenceOrder = sentenceOrder
			self.paragraphOrder = paragraphOrder
		}

		@objc public let text: String
		@objc public let rank: Int
		@objc public let sentenceOrder: Int
		@objc public let paragraphOrder: Int
	}

	@objc(DFSummaryParagraph)
	public class Paragraph: NSObject
	{
		@objc public init(text: String, rank: Int, paragraphOrder: Int)
		{
			self.text = text
			self.rank = rank
			self.paragraphOrder = paragraphOrder
		}

		@objc public let text: String
		@objc public let rank: Int
		@objc public let paragraphOrder: Int
	}

	private let summary: SKSummary

	@objc public init(_ term: String)
	{
		self.summary = SKSummaryCreateWithString(term as CFString).takeRetainedValue()
	}

	@objc public func sentenceCount() -> Int
	{
		return SKSummaryGetSentenceCount(summary)
	}

	@objc public func sentenceSummary(maxSentences: Int = -1) -> [Sentence]
	{
		var result: [Sentence] = []

		let limit = (maxSentences == -1) ? self.sentenceCount() : maxSentences

		var rankOrder: [CFIndex] = Array(repeating: 0, count: limit)
		var sentenceOrder: [CFIndex] = Array(repeating: 0, count: limit)
		var paragraphOrder: [CFIndex] = Array(repeating: 0, count: limit)

		let res = SKSummaryGetSentenceSummaryInfo(self.summary, maxSentences, &rankOrder, &sentenceOrder, &paragraphOrder)
		if (res > 0)
		{
			for count in 0 ..< res
			{
				let sentence = SKSummaryCopySentenceAtIndex(self.summary, sentenceOrder[count]).takeRetainedValue()
				let summary = Sentence(text: sentence as String,
										rank: rankOrder[count] as Int,
										sentenceOrder: sentenceOrder[count] as Int,
										paragraphOrder: paragraphOrder[count] as Int)
				result.append( summary )
			}
		}
		return result
	}

	@objc public func paragraphCount() -> Int
	{
		return SKSummaryGetParagraphCount(summary)
	}

	@objc public func paragraphSummary(maxParagraphs: Int = -1) -> [Paragraph]
	{
		var result: [Paragraph] = []

		let limit = (maxParagraphs == -1) ? self.paragraphCount(): maxParagraphs

		var rankOrder: [CFIndex] = Array(repeating: 0, count: limit)
		var paragraphOrder: [CFIndex] = Array(repeating: 0, count: limit)

		let res = SKSummaryGetParagraphSummaryInfo(self.summary, limit, &rankOrder, &paragraphOrder)
		if (res > 0)
		{
			for count in 0 ..< res
			{
				let paragraph = SKSummaryCopyParagraphAtIndex(self.summary, paragraphOrder[count]).takeRetainedValue()
				let summary = Paragraph(text: paragraph as String,
									  	rank: rankOrder[count] as Int,
										paragraphOrder: paragraphOrder[count] as Int)
				result.append( summary )
			}
		}
		return result
	}
}
