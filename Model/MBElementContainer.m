//
//  MBElementContainer.m
//  Core
//
//  Created by Wido Riezebos on 5/19/10.
//  Copyright 2010 Itude Mobile. All rights reserved.
//

#import "MBElementContainer.h"
#import "MBElement.h"
#import "MBDocument.h"
#import "MBDocumentDefinition.h"
#import "MBElementContainer.h"
#import "StringUtilities.h"
#import "MBDataManagerService.h"
#import "MBScriptService.h"

@interface MBElementContainer()
	- (void) addAllPathsTo:(NSMutableSet*) set currentPath:(NSString*) currentPath;
	-(NSString*) substituteExpressions:(NSString*) expression usingNilMarker:(NSString*) nilMarker currentPath:(NSString*) currentPath;
@end


@implementation MBElementContainer

@synthesize parent = _parent;

- (id) init
{
	self = [super init];
	if (self != nil) {
		_elements = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void) dealloc
{
	[_elements release];
	[super dealloc];
}

- (id) copy {
	@throw [NSException exceptionWithName:@"OverrideInSubclass" reason:@"Cannot copy MBElementContainer" userInfo:nil];
}

- (void) copyChildrenInto:(MBElementContainer*) other {
	for(NSString *elementName in [_elements allKeys]) {
		for(MBElement *src in [_elements valueForKey:elementName]) {
			MBElement *copy = [src copy];
     		[other addElement: copy];		
			[copy release];
		}
	}
}

- (NSString*) uniqueId {
	NSMutableString *uid = [NSMutableString stringWithCapacity:200];
	for(NSString *elementName in [_elements allKeys]) {
		int idx = 0;
		for(MBElement *element in [_elements valueForKey:elementName]) {
			[uid appendFormat:@"[%i_%@", idx, [element uniqueId]];
		}
	}
	return uid;
}

-(void) addAllPathsTo:(NSMutableSet*) set currentPath:(NSString*) currentPath {
	for(NSString *elementName in [_elements allKeys]) {
		int idx = 0;
		for(MBElement *element in [_elements valueForKey:elementName]) {
			NSString *path = [NSString stringWithFormat:@"%@/%@[%i]", currentPath, elementName, idx++];
			[element addAllPathsTo: set currentPath:path];
		}
	}
}

- (int) evaluateIndexExpression:(NSMutableString*) combinedExpression forElementName:(NSString*) elementName {
	NSMutableArray *matchAttributes = [[NSMutableArray new] autorelease];
	NSMutableArray *matchValues = [[NSMutableArray new] autorelease];

	NSArray *expressions = [combinedExpression componentsSeparatedByString:@" and "];
	
	for(NSString *expression in expressions) {

		int eqPos = [expression rangeOfString:@"="].location;
		NSString *attrName = [[expression substringToIndex:eqPos] stripCharacters:@" "];
		NSMutableString *valueExpression = [NSMutableString stringWithString:[expression substringFromIndex:eqPos+1]];
		
		attrName = [self substituteExpressions:attrName usingNilMarker:attrName currentPath:nil];
		[valueExpression replaceOccurrencesOfString:@"'" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [valueExpression length])];
		[valueExpression replaceOccurrencesOfString:@"\"" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [valueExpression length])];
		NSString *value = [self substituteExpressions:valueExpression usingNilMarker:valueExpression currentPath:nil];

		[matchAttributes addObject:attrName];
		[matchValues addObject:value];
	}
	

	NSMutableArray *elements = [self elementsWithName:elementName];
	for(int i = 0; i< elements.count; i++) {
		BOOL match = TRUE;
		for(int j=0; match && j<[matchAttributes count]; j++) {
			NSString *attrName = [matchAttributes objectAtIndex:j];
			NSString *value = [matchValues objectAtIndex:j];
			match &= [[[elements objectAtIndex:i] valueForAttribute: attrName] isEqualToString:value];
		}
		if(match) return i;
	}
	
	// Return an index that exceeds the size of the elements array; this will be handled by if([rootList count] <= idx) below
	// i.e. if nillIfMissing is TRUE then a not matching expression will also return nil because of this:
	return elements.count;
}

- (id) valueForPathComponents:(NSMutableArray*)pathComponents withPath: (NSString*) originalPath nillIfMissing:(BOOL) nillIfMissing translatedPathComponents:(NSMutableArray*) translatedPathComponents {
	if([pathComponents count] > 0) {
		NSArray *rootNameParts = [[pathComponents objectAtIndex:0]componentsSeparatedByString:@"["]; 
		NSString *childElementName = [rootNameParts objectAtIndex:0];
		
		int idx = -99;
		
		// If the pathComponent is indexed (hello[0]) if the rootNameParts contains more than one entry
		if([rootNameParts count] > 1) {
			NSMutableString *idxStr = [NSMutableString stringWithString: [rootNameParts objectAtIndex:1]];
		    [idxStr replaceOccurrencesOfString:@"]" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [idxStr length])];
			
			// Look for the index value if the index is an expression (contains the '=' sign)
			if([idxStr rangeOfString:@"="].length != 0) {
				idx = [self evaluateIndexExpression:idxStr forElementName: childElementName];
			}
			else {
				idx = [idxStr intValue];
			}
		}
		
		[pathComponents removeObjectAtIndex:0];
		NSArray *allElementsWithSameNameAsChild = [self elementsWithName:childElementName];
		//NSArray *rootList = [self elementsWithName:childElementName];
		
		// If the pathComponent is not indexed (just hello, not hello[1]), return all the found elements with the same name
		if(idx  == -99) { 
			if([pathComponents count] == 0) return allElementsWithSameNameAsChild;
			NSString *msg = [NSString stringWithFormat:@"No index specified for %@ in path %@", childElementName, originalPath];
			@throw [NSException exceptionWithName:@"NoIndexSpecified" reason: msg userInfo:nil];
		}
		// If the index is somehow smaller than 0, throw an exception
		else if(idx<0) { 
			NSString *msg = [NSString stringWithFormat:@"Illegal index %i for %@ in path %@", idx, childElementName, originalPath];
			@throw [NSException exceptionWithName:@"IndexOutOfBounds" reason: msg userInfo:nil];
		}
		// If the number of elements with the same name exceeds the idx, return nil or throw an exception
		if([allElementsWithSameNameAsChild count] <= idx) { 
			if(nillIfMissing) return nil;
			NSString *msg = [NSString stringWithFormat:@"Index %i exceeds %i for %@ in path %@", idx, [allElementsWithSameNameAsChild count]-1, childElementName, originalPath];
			@throw [NSException exceptionWithName:@"IndexOutOfBounds" reason: msg userInfo:nil];
		}
		
		MBElement *root = [allElementsWithSameNameAsChild objectAtIndex:idx];
		[translatedPathComponents addObject: [NSString stringWithFormat: @"%@[%i]", root.name, idx]];
		return [root valueForPathComponents: pathComponents withPath: originalPath nillIfMissing: nillIfMissing translatedPathComponents:translatedPathComponents];
	}
	return self;
}

- (id) valueForPath:(NSString*)path translatedPathComponents:(NSMutableArray*) translatedPathComponents {
    if(path == nil) return nil;
    
	NSMutableArray *pathComponents = [path splitPath];
		
	// If there is a ':' in the name of the first component; we might need a different document than 'self'
	if([pathComponents count]>0) {
		NSRange range = [[pathComponents objectAtIndex:0] rangeOfString:@":"];
		if(range.length>0) {
			NSString *documentName = [[pathComponents objectAtIndex:0] substringToIndex: range.location];
			NSString *rootElementName = [[pathComponents objectAtIndex:0] substringFromIndex: range.location+1];
            if(![documentName isEqualToString:[self documentName]]) {
				// Different document! Dispatch the valueForPath
				[translatedPathComponents addObject:[NSString stringWithFormat:@"%@:", documentName]];
				MBDocument *doc = [self getDocumentFromSharedContext: documentName];
				if([rootElementName length] > 0) [pathComponents replaceObjectAtIndex:0 withObject:rootElementName];
				else [pathComponents removeObjectAtIndex:0];
				
				return [doc valueForPathComponents: pathComponents withPath: path nillIfMissing: TRUE translatedPathComponents:translatedPathComponents];
			}
			else [pathComponents replaceObjectAtIndex:0 withObject:rootElementName];
		}
	}
	return [self valueForPathComponents: pathComponents withPath: path nillIfMissing: TRUE translatedPathComponents:translatedPathComponents];
}

- (id) valueForPath:(NSString*)path {
	return [self valueForPath:path translatedPathComponents:nil];
}


- (void) setValue:(NSString*)value forPath:(NSString *)path {
	NSMutableArray *pathComponents = [path splitPath];
	
	NSString *attributeName = [NSString stringWithString: [pathComponents lastObject]];
	if([attributeName hasPrefix:@"@"]) {
		[pathComponents removeLastObject];
		attributeName = [attributeName substringFromIndex:1];
        //the line below commented by Xiaochen
		//MBElement *element = [self valueForPathComponents: pathComponents withPath: path nillIfMissing: FALSE translatedPathComponents: nil];
		
		/***added by Xiaochen****/
		//the commented line does not work for a different document in page
		NSMutableString *elementPath = [NSMutableString stringWithString:[pathComponents objectAtIndex:0]];
		for (int i = 1; i < [pathComponents count]; i++) {
			[elementPath appendFormat:@"/%@", [pathComponents objectAtIndex:i]];
		}
		MBElement *element = [self valueForPath: elementPath];
		/***end****/
        
		[element setValue:value forAttribute: attributeName];
	}
	else {
		NSString *msg = [NSString stringWithFormat:@"Identitifer %@ in Path %@ does not specify an attribute; cannot set value", attributeName, path];
		@throw [NSException exceptionWithName:@"InvalidPath" reason: msg userInfo:nil];
	}
}

-(void) addElement: (MBElement*) element {

	NSString *name = [element definition].name;
	element.parent = self;
	
	NSMutableArray *elementContainer = [self elementsWithName: name];
	if(elementContainer == nil)
	{
		elementContainer = [[NSMutableArray alloc] init];
		[_elements setValue:elementContainer forKey:name];
		[elementContainer release];
	}
	[elementContainer addObject:element];
}

-(void) deleteAllChildElements{
	[_elements removeAllObjects]; 
	[[self document] clearPathCache];
}

-(void) deleteElementWithName: (NSString*) name atIndex:(int) index {
	NSMutableArray *elementContainer = [self elementsWithName: name];
	
	if(index<0 || index>=[elementContainer count]) {
		NSString *msg = [NSString stringWithFormat:@"Invalid index (%i) for element with name %@ (count=%i)", index, name, [elementContainer count]];
		@throw [NSException exceptionWithName:@"InvalidPath" reason: msg userInfo:nil];
	}
	[elementContainer removeObjectAtIndex:index];
}

-(MBElement*) createElementWithName: (NSString*) name {
	NSMutableArray *pathComponents = [name splitPath];

	if([pathComponents count] > 1) {
		NSString *elementName = [pathComponents lastObject];
		[pathComponents removeLastObject];
		
		MBElement *target = [self valueForPathComponents:pathComponents withPath: name nillIfMissing: FALSE translatedPathComponents:nil];
        return [target createElementWithName:elementName];
	}
	else {
		MBElementDefinition *childDef = [[self definition] childWithName:name];
		MBElement *element = [childDef createElement];
		[self addElement:element];
		return element;
	}
}

-(NSMutableArray*) elementsWithName: (NSString*) name {
    if([@"*" isEqualToString: name]) {
        NSMutableArray *result = [NSMutableArray array];
        for(NSArray *lst in [_elements allValues]) [result addObjectsFromArray: lst];
        return result;
    }
	else {
		if(![self.definition isValidChild:name]) {
			NSString *msg = [NSString stringWithFormat:@"Child element with name %@ not present", name];
			@throw [NSException exceptionWithName:@"InvalidPath" reason: msg userInfo:nil];
		}
		
		NSMutableArray *result = [_elements valueForKey:name];	
		if(result == nil) {
			result = [NSMutableArray array];
			[_elements setValue:result forKey:name];
		}
		return result;
	}
}

- (NSMutableDictionary*) elements {
	return _elements;	
}
- (id) definition {
	return nil;
}

-(NSString*) name {
	return [[self definition] name];
}

-(NSString*) documentName {
	return [[self parent] documentName];
}
			   
-(MBDocument*) document {
	return [[self parent] document];
}

- (NSMutableDictionary*) sharedContext {
	return [[self parent] sharedContext];	
}

- (void) setSharedContext:(NSMutableDictionary*) sharedContext {
	[[self parent] setSharedContext:sharedContext];
}

- (MBDocument*) getDocumentFromSharedContext:(NSString*) documentName {
	MBDocument *result = [[self sharedContext] valueForKey:documentName];
	if(result == nil) {
		result = [[MBDataManagerService sharedInstance] loadDocument: documentName];
		if(result == nil) {
			NSString *msg = [NSString stringWithFormat:@"Could not load document with name %@", documentName];	
			@throw [NSException exceptionWithName:@"DocumentNotFound" reason:msg userInfo:nil];
		}
		[self registerDocumentWithSharedContext: result];
	}
	return result;
}

- (void) registerDocumentWithSharedContext:(MBDocument*) document {
	[document setSharedContext: [self sharedContext]];
	[[self sharedContext] setObject:document forKey: document.name];
}

-(NSString*) substituteExpressions:(NSString*) expression usingNilMarker:(NSString*) nilMarker currentPath:(NSString*) currentPath {
	
	if(expression == nil) return nil;
	
	if([expression rangeOfString:@"{"].length == 0) return expression;
	
	NSScanner *scanner = [NSScanner scannerWithString:expression];
	NSString *subPart = @"";
	NSString *singleExpression;
	NSMutableString *result = [NSMutableString stringWithString:@""];
	
	while([scanner scanUpToString:@"${" intoString:&subPart] || ![scanner isAtEnd]) {
		[result appendString:subPart];
		[scanner scanString:@"${" intoString:&subPart];
		BOOL hasExpression = [scanner scanUpToString:@"}" intoString:&singleExpression];
		if(hasExpression) {
			[scanner scanString:@"}" intoString:&subPart];
			if([singleExpression hasPrefix:@"."] && currentPath != nil && [currentPath length]>0) {
				singleExpression = [NSString stringWithFormat:@"%@/%@", currentPath, singleExpression];
			}
			NSString *value = [self valueForPath: singleExpression];
			if(value != nil) [result appendString:value];
			else [result appendString:nilMarker];
		}
		subPart = @"";
	}
	[result appendString:subPart];
	return result;	
}

- (NSString*) evaluateExpression:(NSString*) expression currentPath:(NSString*) currentPath {
	
	NSString *translated = [self substituteExpressions:expression usingNilMarker:@"null" currentPath: currentPath];
	return [[MBScriptService sharedInstance] evaluate:translated];
}

- (NSString*) evaluateExpression:(NSString*) expression {

	return [self evaluateExpression: expression currentPath: nil];
}

// Sorts on the given attribute(s) Multiple attributes must be separated by ,
// Descending sort on an attribute can be done by prefixing the attribute with a -
- (void) sortElements:(NSString*) elementName onAttributes:(NSString*) attributeNames {
	NSMutableArray *elements = [self elementsWithName:elementName];
	if([elements count] == 0) return;

	MBElementDefinition *elementDef = [(MBElement*)[elements objectAtIndex:0] definition];
	
    NSMutableArray *sortDescriptors = [NSMutableArray array];	
	
	for(NSString *attrSpec in [attributeNames componentsSeparatedByString:@","]) {
	  	attrSpec = [attrSpec stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		BOOL ascending = [attrSpec hasPrefix:@"+"] || ![attrSpec hasPrefix:@"-"];
		if([attrSpec hasPrefix:@"+"] || [attrSpec hasPrefix:@"-"]) attrSpec = [attrSpec substringFromIndex:1];
	
		MBAttributeDefinition *attrDef = [elementDef attributeWithName:attrSpec];
		if([[attrDef dataType] isEqualToString:@"int"]) [sortDescriptors addObject: [[[NSSortDescriptor alloc] initWithKey:attrSpec ascending:ascending selector:@selector(compareInt:)]autorelease]];
		else if([[attrDef dataType] isEqualToString:@"double"]) [sortDescriptors addObject: [[[NSSortDescriptor alloc] initWithKey:attrSpec ascending:ascending selector:@selector(compareDouble:)]autorelease]];
		else if([[attrDef dataType] isEqualToString:@"float"]) [sortDescriptors addObject: [[[NSSortDescriptor alloc] initWithKey:attrSpec ascending:ascending selector:@selector(compareFloat:)]autorelease]];
		else if([[attrDef dataType] isEqualToString:@"boolean"]) [sortDescriptors addObject: [[[NSSortDescriptor alloc] initWithKey:attrSpec ascending:ascending selector:@selector(compareBoolean:)]autorelease]];
		else [sortDescriptors addObject: [[[NSSortDescriptor alloc] initWithKey:attrSpec ascending:ascending selector:@selector(compare:)]autorelease]];
	}
	[elements sortUsingDescriptors: sortDescriptors];	
	// All indices of cached paths might have become invalid if the ordering has changed (which is likely; duh)
	[[self document] clearPathCache];
}	
@end
