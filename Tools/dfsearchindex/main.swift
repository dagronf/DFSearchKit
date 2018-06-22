#!/usr/bin/swift

//
//  main.swift
//  helptool
//
//  Created by Darren Ford on 8/5/18.
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

let args = CommandLine.arguments

if args.count < 2 {
	exit(-1)
}

if args[1] == "create" {

	let indexFile = args[2]

	let props = DFSearchIndexFile.CreateProperties.init(proximityIndexing: true, stopWords: gStopWords)
	guard let index = DFSearchIndexFile.create(with: URL(string: indexFile)!, properties: props) else
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

	guard let index = DFSearchIndexFile.open(from: URL(string: indexFile)!, writable: true) else
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

	guard let index = DFSearchIndexFile.open(from: URL(string: indexFile)!, writable: true) else
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
else if args[1] == "add_folder"
{
	let indexFile = args[2]

	guard let folderURL = URL(string: args[3]),
		let index = DFSearchIndexFile.open(from: URL(string: indexFile)!, writable: true) else
	{
		exit(-1)
	}

	let added = index.addFolderContent(folderURL: folderURL)
	added.forEach { print("Added: \($0)") }

	index.flush()
	index.compact()
	index.close()
}
else if args[1] == "prune"
{
	let indexFile = args[2]
	guard let index = DFSearchIndexFile.open(from: URL(string: indexFile)!, writable: true) else
	{
		exit(-1)
	}
	let _ = index.prune(progress: { (total, progress) in
		print("Pruned \(progress) of \(total) documents")
	})
	index.compact()
	index.close()
	exit(1)
}
else if args[1] == "documents"
{
	let indexFile = args[2]
	guard let index = DFSearchIndexFile.open(from: URL(string: indexFile)!, writable: true) else
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

	guard let index = DFSearchIndexFile.open(from: URL(string: indexFile)!, writable: true) else
	{
		exit(-1)
	}

	let docs = index.terms(for: URL(string: url)!)
	let sortedDocs = docs.sorted(by: { $0.count > $1.count })

	for item in sortedDocs {
		print("\(item.term): \(item.count)")
	}

	index.close()

	exit(1)
}
else if args[1] == "search" {
	let indexFile = args[2]
	let query = args[3].split(separator: " ").map({ "\($0)*" }).joined(separator:" ")

	guard let index = DFSearchIndexFile.open(from: URL(string: indexFile)!, writable: false) else
	{
		exit(-1)
	}

	let result = index.search(query)
	let sortedResults = result.sorted(by: { $0.score > $1.score })
	for item in sortedResults {
		print("\(item.url): \(item.score)")
	}
	exit(1)
}
