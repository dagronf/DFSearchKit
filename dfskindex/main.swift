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

let args = CommandLine.arguments

if args.count < 2 {
	exit(-1)
}

if args[1] == "create" {

	let indexFile = args[2]

	let props = DFSKIndex.CreateProperties.init(proximityIndexing: true, stopWords: gStopWords)
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

	guard let index = DFSKFileIndex.open(from: URL(string: indexFile)!, writable: true) else
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

	guard let index = DFSKFileIndex.open(from: URL(string: indexFile)!, writable: true) else
	{
		exit(-1)
	}

	if args.count == 4
	{
		guard index.add(url: URL(string: url)!) else
		{
			exit(-1)
		}
	}
	else
	{
		let mimetype = args[4]
		guard index.add(url: URL(string: url)!, mimeType: mimetype) else
		{
			exit(-1)
		}
	}

	index.flush()
	index.save()
	index.close()

	exit(1)
}
else if args[1] == "documents" {

	let indexFile = args[2]

	guard let index = DFSKFileIndex.open(from: URL(string: indexFile)!, writable: true) else
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

	guard let index = DFSKFileIndex.open(from: URL(string: indexFile)!, writable: true) else
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

	guard let index = DFSKFileIndex.open(from: URL(string: indexFile)!, writable: false) else
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
