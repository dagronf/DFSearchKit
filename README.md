# DFSearchKit
A basic wrapper around SKSearchKit in Swift

## Why?
I was interesting in learning about SKSearchKit, and there was a lack of (simple) working examples to play with.

## Usage

The base library is split into three classes

### DFSKIndex

Core indexing library, wrapper around SKIndex and related methods.  Generally, you won't need to use this class directly unless you want to interface to your own SKIndex object.

### DFSKDataIndex

A class, inheriting from DFSKIndex that uses an in-memory search index.

#### Basic example

```
if let indexer = DFSKDataIndex.create()
{
	indexer.add(URL(string: ("doc-url://d1.txt"))!, text: "This is my first document"))
	indexer.add(url: URL(string: "file://tmp/mypdf.pdf", mimeType: "application/pdf"))
	indexer.flush()
	let searchresult = indexer.search("first")
	...
}
```

### DFSKFileIndex

A class, inheriting from DFSKIndex that allows the creation and use of an index on disk

#### Basic example

```
if let indexer = DFSKFileIndex.create(with: file.fileURL) else
{
	indexer.add(URL(string: ("doc-url://d1.txt"))!, text: "This is my first document"))
	indexer.flush()
	var result = indexer.search("first")
	indexer.save()
	indexer.close()
}
```

## Tests

`DFSearchKitTests.swift` contains a small number of tests (so far) that can be used to see how it works

`dfskindex` is a simple command line tool (that is very unforgiving to its parameters at this point!) that uses DFSKFileIndex to create a command line tool interface to the index

## Todo

Asynchronous search, lots of other stuff! This is a learning project only. Maybe it will be useful to someone 

## Thanks

Mattt Thompson (NSHipster)

[http://nshipster.com/search-kit/](http://nshipster.com/search-kit/)

Marc Charbonneau

[https://blog.mbcharbonneau.com/2009/02/26/searchkit-example-project/](https://blog.mbcharbonneau.com/2009/02/26/searchkit-example-project/)

Apple

[https://developer.apple.com/library/content/documentation/UserExperience/Conceptual/SearchKitConcepts/searchKit_concepts/searchKit_concepts.html](https://developer.apple.com/library/content/documentation/UserExperience/Conceptual/SearchKitConcepts/searchKit_concepts/searchKit_concepts.html)

Philip Dow (SPSearchStore)

[https://github.com/phildow/SPSearchStore](https://github.com/phildow/SPSearchStore)
