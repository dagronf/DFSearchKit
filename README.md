# DFSearchKit
A framework implementing a search index using SKSearchKit for both Swift and Objective-C

## Why?
I was interesting in learning about SKSearchKit and wanted a nice simple object to abstract away some of the unpleasantries when dealing with a C-style interface in Swift using native Swift types

## Usage

Find API references here -- [https://github.com/dagronf/DFSearckKit/blob/master/docs/index.html](https://github.com/dagronf/DFSearckKit/blob/master/docs/index.html)

The base library is split into three classes and an async controller

## Classes

### DFSearchIndex.Memory

A class inheriting from DFSearchIndex that implements an in-memory index.

```swift
guard let indexer = DFSearchIndex.Memory.Create() else {
   assert(false)
}

let documentURL = URL(string: ("doc-url://d1.txt")!
indexer.add(documentURL, text: "This is my first document")
	
let fileURL = // <the url for some file on disk>
indexer.add(fileURL, mimeType: "application/pdf")

// ... add more documents

indexer.flush()
   
let searchresult = indexer.search("first")

// Do something with the search results

```

`DFSearchIndex.Memory` provides methods to get the raw index data for storing, and to load from data

##### Load from a raw Data object
```swift
let indexData = Data(...)
let indexer = DFSearchIndex.Memory.Load(from: indexData)
```

##### Extract the raw Data object from the search index
```swift
let newIndexData = indexer.data()
```

### DFSearchIndex.File

A class inheriting from DFSearchIndex that allows the creation and use of an index on disk

```swift
// Create a index on disk
let newFileURL = // <some file url>
guard let newIndex = DFSearchIndex.File.Create(newFileURL) else {
   assert(false)
}

// Open a file index
let existingFileURL = // <some file url>
guard let fileIndex = DFSearchIndex.File.Open(existingFileURL) else {
   assert(false)
}

let documentURL = URL(string: ("doc-url://d1.txt")!
fileIndex.add(documentURL, text: "This is my first document"))
	
let fileURL = // <the url for some file on disk>
fileIndex.add(fileURL, mimeType: "application/pdf")

// Flush the index so that it is updated for searching
fileIndex.flush()

// Perform a basic search for the work 'first'
var result = indexer.search("first")

fileIndex.save()
fileIndex.close()

```

### DFSearchIndex.AsyncController

`DFSearchIndex.AsyncController` is a simple controller that takes an index object, and provides a safe method for handling async requests.

For example, to add a number of files asynchronously

```swift
guard let searchIndex = DDFSearchIndex.Memory.create() else {
   assert(false)
}

let asyncController = DFSearchIndex.AsyncController(index: searchIndex, delegate: nil)

let addTask = DFSearchIndex.AsyncController.FileTask(<file urls to add>)
asyncController.addURLs(async: addTask, complete: { task in
    // <block that is executed when the files have been added to the index>
})
	
...
	
let removeTask = DFSearchIndex.AsyncController.FileTask(<file urls to remove>)
asyncController.removeURLs(async: removeTask, complete: { task in
	// <block that is executed when the files have been removed from the index>
})
		
```
Internally the async controller uses an operation queue for handling requests.


## Searching

There are two methods for search

### Search all
The search all is available on the indexer object, and returns all the results it can get.  As such, for large indexes this may take quite a while to return.  It is provided mostly as a convenience function for small indexes.

```swift
guard let searchIndex = DFSearchIndex.Memory.Create() else {
   assert(false)
}

// Add some documents...
let firstURL = URL(string: ("doc-url://d1.txt"))!
searchIndex.add(firstURL, text: "This is my first document"))

// Flush the index
searchIndex.flush()

// Search for the word 'first'
let result1 = indexer.search("first")

searchIndex.save()
searchIndex.close()
```

### Progressive Search
For large indexes, the results may take quite a while to return.  Thus, the progressive index is more useful by returning limited sets of results progressively, and can be used on a background thread (as SKSearchIndex is thread safe) to progressively retrieve results in another thread (for example)

```swift 
/// ... load documents ...
let search = indexer.progressiveSearch(query: "dog")
var hasMoreResults = true
repeat {
   var searchChunk = search.next(10)
   
   // ... do something with searchChunk...
   
   hasMoreResults = searchChunk.moreResults
}
while hasMoreResults
```

## Summarization

```swift
let text = // <some text
let summary = DFSummarizer(text)

// Get the number of sentences in the text
let count = summary.sentenceCount()
```

## Samples

* `SearchToy` is a (very!) basic UI to show integration
* `dfsearchindex` is a simple command line tool (that is very unforgiving to its parameters at this point!) that uses DFSearchIndexFile to create a command line tool interface to the index

## Tests

* `DFSearchKitTests.swift`

	Swift tests.  Comprehensive

* `DFSearchKitTests_objc.m` 

	Objective-C tests, mainly for validating objc integration

* `DFSearchIndexAsyncTests.swift`

	Basic test suite to validate the async controller aspect of the library

* `DFSearchIndexSummaryTests.swift`

	Basic summary tests

## Thanks

Mattt Thompson (NSHipster)

[http://nshipster.com/search-kit/](http://nshipster.com/search-kit/)

Marc Charbonneau

[https://blog.mbcharbonneau.com/2009/02/26/searchkit-example-project/](https://blog.mbcharbonneau.com/2009/02/26/searchkit-example-project/)

Apple

[https://developer.apple.com/library/content/documentation/UserExperience/Conceptual/SearchKitConcepts/searchKit_concepts/searchKit_concepts.html](https://developer.apple.com/library/content/documentation/UserExperience/Conceptual/SearchKitConcepts/searchKit_concepts/searchKit_concepts.html)

Philip Dow (SPSearchStore)

[https://github.com/phildow/SPSearchStore](https://github.com/phildow/SPSearchStore)
