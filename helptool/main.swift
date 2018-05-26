#!/usr/bin/swift

//
//  main.swift
//  helptool
//
//  Created by Darren Ford on 8/5/18.
//  Copyright © 2018 Darren Ford. All rights reserved.
//

import Foundation
import Cocoa

let gStopWords: Set = [
	"a",
	"about",
	"above",
	"after",
	"again",
	"against",
	"all",
	"am",
	"an",
	"and",
	"any",
	"are",
	"aren't",
	"aren’t",
	"as",
	"at",
	"be",
	"because",
	"been",
	"before",
	"being",
	"below",
	"between",
	"both",
	"but",
	"by",
	"can't",
	"can’t",
	"can",
	"cannot",
	"could",
	"couldn't",
	"couldn’t",
	"did",
	"didn't",
	"didn’t",
	"do",
	"does",
	"doesn't",
	"doesn’t",
	"doing",
	"don't",
	"don’t",
	"down",
	"during",
	"each",
	"few",
	"for",
	"from",
	"further",
	"had",
	"hadn't",
	"hadn’t",
	"has",
	"hasn't",
	"hasn’t",
	"have",
	"haven't",
	"haven’t",
	"having",
	"he'd",
	"he'll",
	"he's",
	"he’d",
	"he’ll",
	"he’s",
	"he",
	"her",
	"here's",
	"here’s",
	"here",
	"hers",
	"herself",
	"him",
	"himself",
	"his",
	"how's",
	"how’s",
	"how",
	"i'd",
	"i'll",
	"i'm",
	"i've",
	"i’d",
	"i’ll",
	"i’m",
	"i’ve",
	"i",
	"if",
	"in",
	"into",
	"is",
	"isn't",
	"isn’t",
	"it's",
	"it’s",
	"it",
	"its",
	"itself",
	"let's",
	"let’s",
	"me",
	"more",
	"most",
	"mustn't",
	"mustn’t",
	"my",
	"myself",
	"no",
	"nor",
	"not",
	"of",
	"off",
	"on",
	"once",
	"only",
	"or",
	"other",
	"ought",
	"our",
	"ours",
	"ourselves",
	"out",
	"over",
	"own",
	"said",
	"same",
	"say",
	"says",
	"shall",
	"shan't",
	"shan’t",
	"she'd",
	"she'll",
	"she's",
	"she’d",
	"she’ll",
	"she’s",
	"she",
	"should",
	"shouldn't",
	"shouldn’t",
	"so",
	"some",
	"such",
	"than",
	"that's",
	"that’s",
	"that",
	"the",
	"their",
	"theirs",
	"them",
	"themselves",
	"then",
	"there's",
	"there’s",
	"there",
	"these",
	"they'd",
	"they'll",
	"they're",
	"they've",
	"they’d",
	"they’ll",
	"they’re",
	"they’ve",
	"they",
	"this",
	"those",
	"through",
	"to",
	"too",
	"under",
	"until",
	"up",
	"upon",
	"us",
	"very",
	"was",
	"wasn't",
	"wasn’t",
	"we'd",
	"we'll",
	"we're",
	"we've",
	"we’d",
	"we’ll",
	"we’re",
	"we’ve",
	"we",
	"were",
	"weren't",
	"weren’t",
	"what's",
	"what’s",
	"what",
	"when's",
	"when’s",
	"when",
	"where's",
	"where’s",
	"where",
	"which",
	"while",
	"who's",
	"who’s",
	"who",
	"whom",
	"whose",
	"why's",
	"why’s",
	"why",
	"will",
	"with",
	"won't",
	"won’t",
	"would",
	"wouldn't",
	"wouldn’t",
	"you'd",
	"you'll",
	"you're",
	"you've",
	"you’d",
	"you’ll",
	"you’re",
	"you’ve",
	"you",
	"your",
	"yours",
	"yourself",
	"yourselves" ]

let args = CommandLine.arguments

//print("args = \(args)")

if args.count < 2 {
	print("Must provide either 'create' or 'search'")
	exit(-1)
}

if args[1] == "create" {

	if args.count < 2 {
		print("Must provide a filename to create the index in")
		exit(-1)
	}
	let indexFile = args[2]

	let fileList = FileManager.default.subpaths(atPath: args[3])
	if fileList == nil
	{
		print("Must provide either 'create' or 'search'")
		exit(-1)
	}

	let files = fileList!
	if FileManager.default.fileExists(atPath: indexFile) {
		print("Index file already exists \(indexFile)")
		try? FileManager.default.removeItem(atPath: indexFile)
	}

	let props = DFSKIndex.Properties.init(proximityIndexing: true, stopWords: gStopWords)
	guard let index = DFSKFileIndex.create(with: URL(string: indexFile)!, properties: props) else
	{
		exit(-1)
	}

	let htmls = files.filter { $0.hasSuffix(".htm") }
	print("files = \(htmls)")

	for file in htmls
	{
		let uuu = "\(args[3])/\(file)"
		let fileURL = NSURL.fileURL(withPath: uuu)
		if let str = try? String.init(contentsOf: fileURL) {
			let lines = str.split(separator: "\n")
			if !(lines[1].contains("Primary.WindowsOnly"))
			{
				index.add(url: fileURL)
			}
		}
	}

	index.save()
	index.close()

	exit(1)
}
else if args[1] == "search" {
	let indexFile = args[2]
	let query = args[3].split(separator: " ").map({ "\($0)*" }).joined(separator:" ")

	guard let index = DFSKFileIndex.load(from: URL(string: indexFile)!, writable: false) else
	{
		exit(-1)
	}

	let result = index.search(query)
	let sortedResults = result.sorted(by: { $0.score > $1.score })
	for item in sortedResults {
		print("\(item.0): \(item.1)")
	}
	exit(1)
}
