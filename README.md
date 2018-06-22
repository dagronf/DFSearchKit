# DFSearchKit
A framework implementing a search index using SKSearchKit for both Swift and Objective-C

## Why?
I was interesting in learning about SKSearchKit and wanted a nice simple object to abstract away some of the unpleasantries when dealing with a C-style interface in Swift

## Usage

Find API references here -- [https://github.com/dagronf/DFSearckKit/blob/master/docs/index.html](https://github.com/dagronf/DFSearckKit/blob/master/docs/index.html)

The base library is split into three classes and an async controller

### Core

#### DFSearchIndex

Core indexing library, wrapper around SKIndex and related methods.  Generally, you won't need to use this class directly unless you want to interface to your own SKIndex object.

#### DFSearchIndexData

A class inheriting from DFIndex that implements an in-memory index.

```
if let indexer = DFSearchIndexData.create()
{
	let documentURL = URL(string: ("doc-url://d1.txt")!
	indexer.add(documentURL, text: "This is my first document")
	
	let fileURL = <the url for some file on disk>
	indexer.add(fileURL, mimeType: "application/pdf")

	indexer.flush()
	let searchresult = indexer.search("first")
	...
}
```

`DFSearchIndexData` provides methods to get the raw index data for storing, and to load from data

`let indexer = DFSearchIndexData.load(from: myData)`

`let newIndexData = indexer.save()`


#### DFIndexFile

A class inheriting from DFIndex that allows the creation and use of an index on disk

* Create a new index file on disk and add some items to id

```
if let indexer = DFSearchIndexFile.create(with: file.fileURL)
{
   let documentURL = URL(string: ("doc-url://d1.txt")!
	indexer.add(documentURL, text: "This is my first document"))
	
	let fileURL = <the url for some file on disk>
	indexer.add(fileURL, mimeType: "application/pdf")
	
	indexer.flush()
	var result = indexer.search("first")
	indexer.save()
	indexer.close()
}
```

### Async controller

`DFSearchIndexAsyncController` is a simple controller that takes an index object, and provides a safe method for handling async requests.

For example, to add a number of files asynchronously

```
	let indexer = DFSearchIndexData.create()
	let asyncController = DFSearchIndexAsyncController(index: indexer, delegate: nil)

	let addTask = DFSearchIndexAsyncController.FileTask(<file urls to add>)
	asyncController.addURLs(async: addTask, complete: { task in
		<block that is executed when the files have been added to the index>
	})
	
	...
	
	let removeTask = DFSearchIndexAsyncController.FileTask(<file urls to remove>)
	asyncController.removeURLs(async: removeTask, complete: { task in
		<block that is executed when the files have been removed from the index>
	})
		
```
Internally the async controller uses an operation queue for handling requests.


## Searching

There are two methods for search

### Search all
The search all is available on the indexer object, and returns all the results it can get.  As such, for large indexes this may take quite a while to return.  It is provided mostly as a convenience function for small indexes.

```
if let indexer = DFSearchIndexData.create()
{
	indexer.add(URL(string: ("doc-url://d1.txt"))!, text: "This is my first document"))
	indexer.flush()
	var result = indexer.search("first")
	indexer.save()
	indexer.close()
}
```

### Search progressive
For large indexes, the results may take quite a while to return.  Thus, the progressive index is more useful by returning limited sets of results progressively, and can be used on a background thread (as SKSearchIndex is thread safe) to progressively retrieve results in another thread (for example)

```
	let search = indexer.progressiveSearch(query: "dog")
	... load documents ...
	var hasMoreResults = true
	repeat
	{
		var searchChunk = search.next(10)
		... do something with searchChunk...
		hasMoreResults = searchChunk.moreResults
	}
	while hasMoreResults
```

## Samples

* `SearchToy` is a (very!) basic UI to show integration
* `dfindex` is a simple command line tool (that is very unforgiving to its parameters at this point!) that uses DFFileIndex to create a command line tool interface to the index

## Tests

`DFIndexTests.swift`, `DFSummaryTests.swift` and `DFSearchKitTests_objc.m` contain a small number of tests (so far) that can be used to see how it works in both Swift and Objective-C

## Thanks

Mattt Thompson (NSHipster)

[http://nshipster.com/search-kit/](http://nshipster.com/search-kit/)

Marc Charbonneau

[https://blog.mbcharbonneau.com/2009/02/26/searchkit-example-project/](https://blog.mbcharbonneau.com/2009/02/26/searchkit-example-project/)

Apple

[https://developer.apple.com/library/content/documentation/UserExperience/Conceptual/SearchKitConcepts/searchKit_concepts/searchKit_concepts.html](https://developer.apple.com/library/content/documentation/UserExperience/Conceptual/SearchKitConcepts/searchKit_concepts/searchKit_concepts.html)

Philip Dow (SPSearchStore)

[https://github.com/phildow/SPSearchStore](https://github.com/phildow/SPSearchStore)
