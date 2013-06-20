//
//  MBDefinition.m
//  Core
//
//  Created by Wido on 13-5-10.
//  Copyright 2010 Itude. All rights reserved.
//

#import "MBDefinition.h"


@implementation MBDefinition

@synthesize name = _name;

- (void) dealloc
{
	[_name release];
	[super dealloc];
}

-(NSString*) attributeAsXml:(NSString*)name withValue:(id) attrValue {
	return attrValue == nil?@"": [NSString stringWithFormat:@" %@='%@'", name, attrValue];
}

- (NSString *) asXmlWithLevel:(int)level {
	return @"";
}

- (NSString *) description {
	return [self asXmlWithLevel: 0];
}

-(void) validateDefinition {
	
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
	id	stringSelector = NSStringFromSelector(sel);
	int	parameterCount = [[stringSelector componentsSeparatedByString:@":"] count]-1;
	
	// Zero argument, forward to valueForKey:
	if (parameterCount == 0)
		return [super methodSignatureForSelector:@selector(valueForKey:)];
	
	// One argument starting with set, forward to setValue:forKey:
	if (parameterCount == 1 && [stringSelector hasPrefix:@"add"])
		return [super methodSignatureForSelector:@selector(setValue:forKey:)];
	
	// Discard the call
	return nil;
}

// Call valueForKey: and setValue:forKey: 
- (void)forwardInvocation:(NSInvocation *)invocation
{
	id	stringSelector = NSStringFromSelector([invocation selector]);
	int	parameterCount = [[stringSelector componentsSeparatedByString:@":"] count]-1;
	
	// Forwarding to setValue:forKey:
	if (parameterCount == 1)
	{
		id argument;
		// The first parameter to an ObjC method is the third argument
		// ObjC methods are C functions taking instance and selector as their first two arguments
		[invocation getArgument:&argument atIndex:2];
		
		NSString* msg = [NSString stringWithFormat:@"Check configuration.xml:\n%@does not implement %@ with argument %@", [self asXmlWithLevel:10], stringSelector, argument];
		@throw [NSException exceptionWithName:@"UnrecognizedSelector" reason:msg userInfo:nil];
	} 
	else 
		@throw [NSException exceptionWithName:@"UnrecognizedSelector" reason:stringSelector userInfo:nil];
}

- (BOOL) isPreConditionValid:(MBDocument*) document  currentPath:(NSString*) currentPath {
	return TRUE;	
}

@end