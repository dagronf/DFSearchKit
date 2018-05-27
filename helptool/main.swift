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
	print("Must provide either 'create', 'add_text' or 'search'")
	exit(-1)
}

if args[1] == "create" {

	let indexFile = args[2]

	let props = DFSKIndex.Properties.init(proximityIndexing: true, stopWords: gStopWords)
	guard let index = DFSKFileIndex.create(with: URL(string: indexFile)!, properties: props) else
	{
		exit(-1)
	}

	index.save()
	index.close()

	exit(1)
}
else if args[1] == "add_text" {

	let indexFile = args[2]
	let url = args[3]
	let message = args[4]

	guard let index = DFSKFileIndex.load(from: URL(string: indexFile)!, writable: true) else
	{
		exit(-1)
	}

	guard index.add(URL(string: url)!, text: message) else
	{
		exit(-1)
	}

	index.save()
	index.close()

	exit(1)
}
else if args[1] == "add_file" {

	let indexFile = args[2]
	let url = args[3]
	let mimetype = args[4]

	guard let index = DFSKFileIndex.load(from: URL(string: indexFile)!, writable: true) else
	{
		exit(-1)
	}

	guard index.add(url: URL(string: url)!, mimeType: mimetype) else
	{
		exit(-1)
	}

	index.flush()
	index.save()
	index.close()

	exit(1)
}
else if args[1] == "documents" {

	let indexFile = args[2]

	guard let index = DFSKFileIndex.load(from: URL(string: indexFile)!, writable: true) else
	{
		exit(-1)
	}

	let docs = index.documents()
	for item in docs {
		print("\(item)")
	}

	index.close()

	exit(1)
}
else if args[1] == "terms" {

	let indexFile = args[2]
	let url = args[3]

	guard let index = DFSKFileIndex.load(from: URL(string: indexFile)!, writable: true) else
	{
		exit(-1)
	}

	let docs = index.termsAndCounts(for: URL(string: url)!)
	let sortedDocs = docs.sorted(by: { $0.count > $1.count })

	for item in sortedDocs {
		print("\(item.0): \(item.1)")
	}

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
