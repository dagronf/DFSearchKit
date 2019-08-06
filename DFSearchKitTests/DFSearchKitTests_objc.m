//
//  DFSearchKitTests_objc.m
//  DFSearchKitTests-objc
//
//  Created by Darren Ford on 17/6/18.
//  Copyright © 2019 Darren Ford. All rights reserved.
//

#import <XCTest/XCTest.h>

@import DFSearchKit;

@interface DFSearchKitTests_objc : XCTestCase

@end

@implementation DFSearchKitTests_objc

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (DFSearchIndexMemory*)createWithDefaults
{
	DFSearchIndexCreateProperties* properties = [[DFSearchIndexCreateProperties alloc] initWithIndexType:DFSearchIndexTypeInverted
																					   proximityIndexing:NO
																							   stopWords:[NSSet set]
																						   minTermLength:0];
	return [DFSearchIndexMemory CreateWithProperties:properties];
}

- (void)testBasicDataIndex
{
	DFSearchIndexMemory* index = [self createWithDefaults];
	XCTAssertNotNil(index);

	NSURL* d1 = [NSURL URLWithString:@"doc://temp.txt"];
	XCTAssertTrue([index add:d1 text:@"This is a test!" canReplace:NO]);
	[index flush];

	NSArray<DFSearchIndexSearchResult*>* results = [index search:@"test" limit:10 timeout:1.0 options:kSKSearchOptionDefault];
	XCTAssertEqual(1, [results count]);
	if ([results count] != 1)
	{
		return;
	}
	DFSearchIndexSearchResult* result = results[0];
	XCTAssertEqualObjects(d1, [result url]);
}

- (void)testBasicDocumentProperties
{
	DFSearchIndexMemory* index = [self createWithDefaults];
	XCTAssertNotNil(index);

	NSURL* d1 = [NSURL URLWithString:@"doc://temp.txt"];
	XCTAssertTrue([index add:d1 text:@"This is a test!" canReplace:NO]);
	[index flush];

	// Simple document properties

	NSDictionary* d1Props = @{ @"fish": @1, @"dog": @"hello there" };
	XCTAssertTrue([index setDocumentProperties:d1 properties:d1Props]);

	NSDictionary* docProps = [index documentProperties:d1];
	XCTAssertEqualObjects(d1Props, docProps);

	NSData* saved = [index data];
	[index close];
	index = nil;

	DFSearchIndexMemory* loaded = [DFSearchIndexMemory LoadFrom:saved];
	XCTAssertNotNil(loaded);

	NSDictionary* savedProps = [loaded documentProperties:d1];
	XCTAssertEqualObjects(d1Props, savedProps);
}

- (void)testLoad
{
	DFSearchIndexMemory* index = [self createWithDefaults];
	XCTAssertNotNil(index);

	NSURL* d1 = [NSURL URLWithString:@"doc://temp.txt"];
	XCTAssertTrue([index add:d1 text:@"This is a test!" canReplace:NO]);
	[index flush];

	NSArray<DFSearchIndexSearchResult*>* results = [index search:@"test" limit:10 timeout:1.0 options:kSKSearchOptionDefault];
	XCTAssertEqual(1, [results count]);
	if ([results count] != 1)
	{
		return;
	}
	DFSearchIndexSearchResult* result = results[0];
	XCTAssertEqualObjects(d1, [result url]);

	NSData* saved = [index data];
	XCTAssertNotNil(saved);
	index = nil;

	DFSearchIndexMemory* loaded = [DFSearchIndexMemory LoadFrom:saved];
	results = [loaded search:@"test" limit:10 timeout:1.0 options:kSKSearchOptionDefault];
	XCTAssertEqual(1, [results count]);
	if ([results count] != 1)
	{
		return;
	}
	result = results[0];
	XCTAssertEqualObjects(d1, [result url]);
}

- (void)testLoadFileURLIntoIndex
{
	DFSearchIndexMemory* index = [self createWithDefaults];
	XCTAssertNotNil(index);

	// File on disk resource
	NSBundle* bun = [NSBundle bundleForClass:[self class]];
	NSURL* apacheURL = [bun URLForResource:@"APACHE_LICENSE" withExtension:@"pdf"];
	XCTAssertNotNil(apacheURL);
	XCTAssertTrue([index addWithFileURL:apacheURL mimeType:nil canReplace:YES]);

	NSURL* shortStoryURL = [bun URLForResource:@"the_school_short_story" withExtension:@"txt"];
	XCTAssertNotNil(shortStoryURL);
	XCTAssertTrue([index addWithFileURL:shortStoryURL mimeType:nil canReplace:YES]);

	NSSet* origURLs = [NSSet setWithObjects:apacheURL, shortStoryURL, nil];

	[index flush];

	// Simple search
	NSArray<DFSearchIndexSearchResult*>* results = [index search:@"apache" limit:10 timeout:1.0 options:kSKSearchOptionDefault];
	XCTAssertEqual(1, [results count]);
	if ([results count] != 1)
	{
		return;
	}
	DFSearchIndexSearchResult* result = results[0];
	XCTAssertEqualObjects(apacheURL, [result url]);

	results = [index search:@"the" limit:10 timeout:1.0 options:kSKSearchOptionDefault];
	XCTAssertEqual(2, [results count]);
	if ([results count] != 2)
	{
		return;
	}

	NSSet* searchURLs = [NSSet setWithObjects:results[0].url, results[1].url, nil];
	XCTAssertEqualObjects(origURLs, searchURLs);
}

- (void)testProgressiveSearch
{
	DFSearchIndexMemory* index = [self createWithDefaults];
	XCTAssertNotNil(index);

	// File on disk resource
	NSBundle* bun = [NSBundle bundleForClass:[self class]];
	NSURL* apacheURL = [bun URLForResource:@"APACHE_LICENSE" withExtension:@"pdf"];
	XCTAssertNotNil(apacheURL);
	XCTAssertTrue([index addWithFileURL:apacheURL mimeType:nil canReplace:YES]);

	NSURL* shortStoryURL = [bun URLForResource:@"the_school_short_story" withExtension:@"txt"];
	XCTAssertNotNil(shortStoryURL);
	XCTAssertTrue([index addWithFileURL:shortStoryURL mimeType:nil canReplace:YES]);

	[index flush];

	// Progressively search for 'the' -- it should have two results

	DFSearchIndexProgressiveSearch* search = [index progressiveSearchWithQuery:@"the" options:kSKSearchOptionDefault];
	DFSearchIndexProgressiveSearchResults* progRes = [search next:1 timeout:1.0];
	XCTAssertTrue([progRes moreResultsAvailable]);
	XCTAssertEqual(1, [[progRes results] count]);

	progRes = [search next:1 timeout:1.0];
	XCTAssertFalse([progRes moreResultsAvailable]);
	XCTAssertEqual(1, [[progRes results] count]);

	[index compact];
	NSData* newSaved = [index data];

	[index close];
	index = nil;

	DFSearchIndexMemory* i3 = [DFSearchIndexMemory LoadFrom:newSaved];
	XCTAssertNotNil(i3);

	NSArray<DFSearchIndexSearchResult*>* results = [i3 search:@"the" limit:10 timeout:1.0 options:kSKSearchOptionDefault];
	XCTAssertEqual(2, [results count]);
	if ([results count] != 2)
	{
		return;
	}
}

- (void)testInitializers
{
	DFSearchIndexCreateProperties* properties = [[DFSearchIndexCreateProperties alloc] initWithIndexType:DFSearchIndexTypeInverted
																												  proximityIndexing:NO
																															 stopWords:[NSSet set]
																														minTermLength:0];
	DFSearchIndexMemory* memIndex = [[DFSearchIndexMemory alloc] initWithProperties:properties];
	XCTAssertNotNil(memIndex);

	NSURL* d1 = [NSURL URLWithString:@"doc://temp.txt"];
	XCTAssertTrue([memIndex add:d1 text:@"This is a test!" canReplace:NO]);
	[memIndex flush];

	NSArray<DFSearchIndexSearchResult*>* results = [memIndex search:@"test" limit:10 timeout:1.0 options:kSKSearchOptionDefault];
	XCTAssertEqual(1, [results count]);
	if ([results count] != 1) {
		return;
	}
	DFSearchIndexSearchResult* result = results[0];
	XCTAssertEqualObjects(d1, [result url]);

	NSData* d = [memIndex data];
	XCTAssertNotNil(d);
	XCTAssert([d length] > 0);
	[memIndex close];
}

- (void)testTermsAndCounts
{
	DFSearchIndexMemory* index = [self createWithDefaults];
	XCTAssertNotNil(index);

	// File on disk resource
	NSBundle* bun = [NSBundle bundleForClass:[self class]];
	NSURL* apacheURL = [bun URLForResource:@"APACHE_LICENSE" withExtension:@"pdf"];
	XCTAssertNotNil(apacheURL);
	XCTAssertTrue([index addWithFileURL:apacheURL mimeType:nil canReplace:YES]);

	NSURL* shortStoryURL = [bun URLForResource:@"the_school_short_story" withExtension:@"txt"];
	XCTAssertNotNil(shortStoryURL);
	XCTAssertTrue([index addWithFileURL:shortStoryURL mimeType:nil canReplace:YES]);

	[index flush];

	// Should be two documents in the index
	XCTAssertEqual(2, [[index documentsWithTermState:DFSearchIndexTermStateAll] count]);

	// Apache document has 453 terms
	NSArray<DFSearchIndexTermCount*>* terms = [index termsFor:apacheURL];
	XCTAssertEqual(453, [terms count]);
}

- (void)testSummary
{
	NSBundle* bun = [NSBundle bundleForClass:[self class]];
	NSURL* shortStoryURL = [bun URLForResource:@"the_school_short_story" withExtension:@"txt"];
	XCTAssertNotNil(shortStoryURL);
	NSString* content = [NSString stringWithContentsOfURL:shortStoryURL encoding:NSUTF8StringEncoding error:NULL];

	DFSearchIndexSummarizer* summary = [[DFSearchIndexSummarizer alloc] init:content];
	XCTAssertNotNil(summary);

	NSUInteger count = [summary sentenceCount];
	XCTAssertEqual(91, count);

	NSArray<DFSearchIndexSummarizerSentence*>* sentences = [summary sentenceSummaryWithMaxSentences:4];
	XCTAssertEqual(4, [sentences count]);

	NSUInteger paraCount = [summary paragraphCount];
	XCTAssertEqual(25, paraCount);

	NSArray<DFSearchIndexSummarizerParagraph*>* paragraphs = [summary paragraphSummaryWithMaxParagraphs:2];
	XCTAssertEqual(2, [paragraphs count]);
}

@end
