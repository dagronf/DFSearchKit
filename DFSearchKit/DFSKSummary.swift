//
//  DFSKSummary.swift
//  DFSearchKitTests
//
//  Created by Darren Ford on 9/6/18.
//  Copyright © 2018 Darren Ford. All rights reserved.
//

import Cocoa
import CoreServices

class DFSKSummary
{
	struct Sentence
	{
		var text: String
		var rank: Int
		var sentenceOrder: Int
		var paragraphOrder: Int
	}

	struct Paragraph
	{
		var text: String
		var rank: Int
		var paragraphOrder: Int
	}

	private let summary: SKSummary

	init(_ term: String)
	{
		self.summary = SKSummaryCreateWithString(term as CFString).takeRetainedValue()
	}

	func sentenceCount() -> Int
	{
		return SKSummaryGetSentenceCount(summary)
	}

	func sentenceSummary(maxSentences: Int = -1) -> [Sentence]
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

	func paragraphCount() -> Int
	{
		return SKSummaryGetParagraphCount(summary)
	}

	func paragraphSummary(maxParagraphs: Int = -1) -> [Paragraph]
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
