//
//  DFSKSearchKitTests_objc.m
//  DFSKSearchKitTests-objc
//
//  Created by Darren Ford on 17/6/18.
//  Copyright © 2018 Darren Ford. All rights reserved.
//

#import <XCTest/XCTest.h>

@import DFSKSearchKit;

@interface DFSKSearchKitTests_objc : XCTestCase

@end

@implementation DFSKSearchKitTests_objc

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (DFSKDataIndex*)createWithDefaults
{
	DFSKIndexCreateProperties* properties = [[DFSKIndexCreateProperties alloc] initWithIndexType:kSKIndexInverted
																			   proximityIndexing:NO
																					   stopWords:[NSSet set]
																				   minTermLength:0];

	return [DFSKDataIndex createWithProperties:properties];
}

- (void)testBasicDataIndex
{
	DFSKDataIndex* index = [self createWithDefaults];
	XCTAssertNotNil(index);

	NSURL* d1 = [NSURL URLWithString:@"doc://temp.txt"];
	XCTAssertTrue([index add:d1 text:@"This is a test!" canReplace:NO]);
	[index flush];

	NSArray<DFSKIndexSearchResult*>* results = [index search:@"test" limit:10 timeout:1.0 options:kSKSearchOptionDefault];
	XCTAssertEqual(1, [results count]);
	if ([results count] != 1)
	{
		return;
	}
	DFSKIndexSearchResult* result = results[0];
	XCTAssertEqualObjects(d1, [result url]);
}

- (void)testBasicDocumentProperties
{
	DFSKDataIndex* index = [self createWithDefaults];
	XCTAssertNotNil(index);

	NSURL* d1 = [NSURL URLWithString:@"doc://temp.txt"];
	XCTAssertTrue([index add:d1 text:@"This is a test!" canReplace:NO]);
	[index flush];

	// Simple document properties

	NSDictionary* d1Props = @{ @"fish": @1, @"dog": @"hello there" };
	XCTAssertTrue([index setDocumentProperties:d1 properties:d1Props]);

	NSDictionary* docProps = [index documentProperties:d1];
	XCTAssertEqualObjects(d1Props, docProps);
}

- (void)testLoad
{
	DFSKDataIndex* index = [self createWithDefaults];
	XCTAssertNotNil(index);

	NSURL* d1 = [NSURL URLWithString:@"doc://temp.txt"];
	XCTAssertTrue([index add:d1 text:@"This is a test!" canReplace:NO]);
	[index flush];

	NSArray<DFSKIndexSearchResult*>* results = [index search:@"test" limit:10 timeout:1.0 options:kSKSearchOptionDefault];
	XCTAssertEqual(1, [results count]);
	if ([results count] != 1)
	{
		return;
	}
	DFSKIndexSearchResult* result = results[0];
	XCTAssertEqualObjects(d1, [result url]);

	NSData* saved = [index save];
	XCTAssertNotNil(saved);
	index = nil;

	DFSKDataIndex* loaded = [DFSKDataIndex loadFrom:saved];
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
	DFSKDataIndex* index = [self createWithDefaults];
	XCTAssertNotNil(index);

	// File on disk resource
	NSBundle* bun = [NSBundle bundleForClass:[self class]];
	NSURL* apacheURL = [bun URLForResource:@"APACHE_LICENSE" withExtension:@"pdf"];
	XCTAssertNotNil(apacheURL);
	XCTAssertTrue([index addWithUrl:apacheURL mimeType:nil canReplace:YES]);

	NSURL* shortStoryURL = [bun URLForResource:@"the_school_short_story" withExtension:@"txt"];
	XCTAssertNotNil(shortStoryURL);
	XCTAssertTrue([index addWithUrl:shortStoryURL mimeType:nil canReplace:YES]);

	NSSet* origURLs = [NSSet setWithObjects:apacheURL, shortStoryURL, nil];

	[index flush];

	// Simple search
	NSArray<DFSKIndexSearchResult*>* results = [index search:@"apache" limit:10 timeout:1.0 options:kSKSearchOptionDefault];
	XCTAssertEqual(1, [results count]);
	if ([results count] != 1)
	{
		return;
	}
	DFSKIndexSearchResult* result = results[0];
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
	DFSKDataIndex* index = [self createWithDefaults];
	XCTAssertNotNil(index);

	// File on disk resource
	NSBundle* bun = [NSBundle bundleForClass:[self class]];
	NSURL* apacheURL = [bun URLForResource:@"APACHE_LICENSE" withExtension:@"pdf"];
	XCTAssertNotNil(apacheURL);
	XCTAssertTrue([index addWithUrl:apacheURL mimeType:nil canReplace:YES]);

	NSURL* shortStoryURL = [bun URLForResource:@"the_school_short_story" withExtension:@"txt"];
	XCTAssertNotNil(shortStoryURL);
	XCTAssertTrue([index addWithUrl:shortStoryURL mimeType:nil canReplace:YES]);

	[index flush];

	// Progressively search for 'the' -- it should have two results

	DFSKIndexProgressiveSearch* search = [index progressiveSearchWithQuery:@"the" options:kSKSearchOptionDefault];
	DFSKIndexProgressiveSearchResults* progRes = [search next:1 timeout:1.0];
	XCTAssertTrue([progRes moreResultsAvailable]);
	XCTAssertEqual(1, [[progRes results] count]);

	progRes = [search next:1 timeout:1.0];
	XCTAssertFalse([progRes moreResultsAvailable]);
	XCTAssertEqual(1, [[progRes results] count]);

	[index compact];
	NSData* newSaved = [index save];

	[index close];
	index = nil;

	DFSKDataIndex* i3 = [DFSKDataIndex loadFrom:newSaved];
	XCTAssertNotNil(i3);

	NSArray<DFSKIndexSearchResult*>* results = [i3 search:@"the" limit:10 timeout:1.0 options:kSKSearchOptionDefault];
	XCTAssertEqual(2, [results count]);
	if ([results count] != 2)
	{
		return;
	}
}

- (void)testTermsAndCounts
{
	DFSKDataIndex* index = [self createWithDefaults];
	XCTAssertNotNil(index);

	// File on disk resource
	NSBundle* bun = [NSBundle bundleForClass:[self class]];
	NSURL* apacheURL = [bun URLForResource:@"APACHE_LICENSE" withExtension:@"pdf"];
	XCTAssertNotNil(apacheURL);
	XCTAssertTrue([index addWithUrl:apacheURL mimeType:nil canReplace:YES]);

	NSURL* shortStoryURL = [bun URLForResource:@"the_school_short_story" withExtension:@"txt"];
	XCTAssertNotNil(shortStoryURL);
	XCTAssertTrue([index addWithUrl:shortStoryURL mimeType:nil canReplace:YES]);

	[index flush];

	// Should be two documents in the index
	XCTAssertEqual(2, [[index documents] count]);

	// Apache document has 453 terms
	NSArray<DFSKIndexTermCount*>* terms = [index termsFor: apacheURL];
	XCTAssertEqual(453, [terms count]);
}

@end
