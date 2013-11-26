/*
 * (C) Copyright Itude Mobile B.V., The Netherlands.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "StringUtilitiesHelper.h"
#import "LocaleUtilities.h"

static StringUtilitiesHelper *_instance = nil;

@implementation StringUtilitiesHelper

@synthesize dateFormatterToFormatDateFromXml = _dateFormatterToFormatDateFromXml;
@synthesize dateFormatterToFormatDateDependingOnCurrentDate = _dateFormatterToFormatDateDependingOnCurrentDate;
@synthesize volumeNumberFormatter = _volumeNumberFormatter;
@synthesize priceWithMinimalDecimalsNumberFormatter = _priceWithMinimalDecimalsNumberFormatter;
@synthesize priceWithTwoDecimalsNumberFormatter = _priceWithTwoDecimalsNumberFormatter;
@synthesize priceWithThreeDecimalsNumberFormatter = _priceWithThreeDecimalsNumberFormatter;
@synthesize numberWithOriginalNumberOfDecimalsNumberFormatter = _numberWithOriginalNumberOfDecimalsNumberFormatter;
@synthesize numberWithTwoDecimalsNumberFormatter = _numberWithTwoDecimalsNumberFormatter;
@synthesize numberWithThreeDecimalsNumberFormatter = _numberWithThreeDecimalsNumberFormatter;

+ (void) createInstance {
	@synchronized(self) {
		if(_instance == nil) {
			_instance = [[self alloc] init];
		}
	}	
}

- (id) init {
	if (self =[super init]) {
		
		// force Binck locale
		NSString *decimalSeparator = [[NSLocale currentLocale] getDecimalSeparator];
		NSString *groupingSeparator = [[NSLocale currentLocale] getGroupingSeparator];
		
		// XML date formatter
		self.dateFormatterToFormatDateFromXml = [[[NSDateFormatter alloc] init] autorelease];
		[self.dateFormatterToFormatDateFromXml setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];

		// Date or time date formatter
		self.dateFormatterToFormatDateDependingOnCurrentDate = [[[NSDateFormatter alloc] init] autorelease];

		// Volume
		self.volumeNumberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
		[self.volumeNumberFormatter setUsesGroupingSeparator:YES];
		[self.volumeNumberFormatter setDecimalSeparator:decimalSeparator]; // force Binck locale
		[self.volumeNumberFormatter setGroupingSeparator:groupingSeparator]; // force Binck locale
		[self.volumeNumberFormatter setGroupingSize:3];
		
		// Price with minimal decimals
		self.priceWithMinimalDecimalsNumberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
		[self.priceWithMinimalDecimalsNumberFormatter setMinimumIntegerDigits:1];
		[self.priceWithMinimalDecimalsNumberFormatter setMaximumFractionDigits:3];
		[self.priceWithMinimalDecimalsNumberFormatter setMinimumFractionDigits:0];
		[self.priceWithMinimalDecimalsNumberFormatter setUsesGroupingSeparator:YES];
		[self.priceWithMinimalDecimalsNumberFormatter setGroupingSize:3];
		[self.priceWithMinimalDecimalsNumberFormatter setDecimalSeparator:decimalSeparator]; // force Binck locale
		[self.priceWithMinimalDecimalsNumberFormatter setGroupingSeparator:groupingSeparator]; // force Binck locale
		
		// Price with two decimals
		self.priceWithTwoDecimalsNumberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
		[self.priceWithTwoDecimalsNumberFormatter setMinimumIntegerDigits:1];
		[self.priceWithTwoDecimalsNumberFormatter setMaximumFractionDigits:2];
		[self.priceWithTwoDecimalsNumberFormatter setMinimumFractionDigits:2];
		[self.priceWithTwoDecimalsNumberFormatter setUsesGroupingSeparator:YES];
		[self.priceWithTwoDecimalsNumberFormatter setGroupingSize:3];
		[self.priceWithTwoDecimalsNumberFormatter setDecimalSeparator:decimalSeparator]; // force Binck locale
		[self.priceWithTwoDecimalsNumberFormatter setGroupingSeparator:groupingSeparator]; // force Binck locale
		
		// Price with trhee decimals
		self.priceWithThreeDecimalsNumberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
		[self.priceWithThreeDecimalsNumberFormatter setMinimumIntegerDigits:1];
		[self.priceWithThreeDecimalsNumberFormatter setMaximumFractionDigits:3];
		[self.priceWithThreeDecimalsNumberFormatter setMinimumFractionDigits:3];
		[self.priceWithThreeDecimalsNumberFormatter setUsesGroupingSeparator:YES];
		[self.priceWithThreeDecimalsNumberFormatter setGroupingSize:3];
		[self.priceWithThreeDecimalsNumberFormatter setDecimalSeparator:decimalSeparator]; // force Binck locale
		[self.priceWithThreeDecimalsNumberFormatter setGroupingSeparator:groupingSeparator]; // force Binck locale
		
		// Number with original number of decimals
		self.numberWithOriginalNumberOfDecimalsNumberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
		[self.numberWithOriginalNumberOfDecimalsNumberFormatter setMinimumIntegerDigits:1];
		[self.numberWithOriginalNumberOfDecimalsNumberFormatter setNumberStyle:kCFNumberDoubleType];
		[self.numberWithOriginalNumberOfDecimalsNumberFormatter setGeneratesDecimalNumbers:YES];
		//[self.numberWithOriginalNumberOfDecimalsNumberFormatter setMinimumFractionDigits:3];
		//[self.numberWithOriginalNumberOfDecimalsNumberFormatter setMaximumFractionDigits:3];
		[self.numberWithOriginalNumberOfDecimalsNumberFormatter setUsesGroupingSeparator:NO];
		[self.numberWithOriginalNumberOfDecimalsNumberFormatter setDecimalSeparator:decimalSeparator]; // force Binck locale
		
		// Number with two decimals
		self.numberWithTwoDecimalsNumberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
		[self.numberWithTwoDecimalsNumberFormatter setMinimumIntegerDigits:1];
		[self.numberWithTwoDecimalsNumberFormatter setMaximumFractionDigits:2];
		[self.numberWithTwoDecimalsNumberFormatter setUsesGroupingSeparator:YES];
		[self.numberWithTwoDecimalsNumberFormatter setDecimalSeparator:decimalSeparator]; // force Binck locale
		[self.numberWithTwoDecimalsNumberFormatter setGroupingSeparator:groupingSeparator]; // force Binck locale
		[self.numberWithTwoDecimalsNumberFormatter setGroupingSize:3];
		
		// Number with three decimals
		self.numberWithThreeDecimalsNumberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
		[self.numberWithThreeDecimalsNumberFormatter setMinimumIntegerDigits:1];
		[self.numberWithThreeDecimalsNumberFormatter setMaximumFractionDigits:3];
		[self.numberWithThreeDecimalsNumberFormatter setUsesGroupingSeparator:YES];
		[self.numberWithThreeDecimalsNumberFormatter setDecimalSeparator:decimalSeparator]; // force Binck locale
		[self.numberWithThreeDecimalsNumberFormatter setGroupingSeparator:groupingSeparator]; // force Binck locale
		[self.numberWithThreeDecimalsNumberFormatter setGroupingSize:3];

	}
	return self;
}


- (void) dealloc
{
	[_dateFormatterToFormatDateFromXml release];
	[_dateFormatterToFormatDateDependingOnCurrentDate release];
	[_volumeNumberFormatter release];
	[_priceWithMinimalDecimalsNumberFormatter release];
	[_priceWithTwoDecimalsNumberFormatter release];
	[_priceWithThreeDecimalsNumberFormatter release];
	[_numberWithOriginalNumberOfDecimalsNumberFormatter release];
	[_numberWithTwoDecimalsNumberFormatter release];
	[_numberWithThreeDecimalsNumberFormatter release];
	[super dealloc];
}


#pragma mark -
#pragma mark Getters

+ (NSDateFormatter *)dateFormatterToFormatDateFromXml {
	
	// To make it threadSafe, create a formatter for each thread that is calling this method
	NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
    NSDateFormatter *dateFormatter = [threadDictionary objectForKey: @"DateFromXmlDateFormatter"];
    if (dateFormatter == nil)
    {
		@synchronized(self){
			dateFormatter = [[[_instance dateFormatterToFormatDateFromXml] copy] autorelease];
			[threadDictionary setObject: dateFormatter forKey: @"DateFromXmlDateFormatter"];
		}
    }
    return dateFormatter;
	
	// return [_instance dateFormatterToFormatDateFromXml]; // This is NOT threadsafe!!!
}

+ (NSDateFormatter *)dateFormatterToFormatDateDependingOnCurrentDate{
	
	// To make it threadSafe, create a formatter for each thread that is calling this method
	NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
    NSDateFormatter *dateFormatter = [threadDictionary objectForKey: @"DateDependingOnDateDateFormatter"];
    if (dateFormatter == nil)
    {
		@synchronized(self){
			dateFormatter = [[[_instance dateFormatterToFormatDateDependingOnCurrentDate] copy] autorelease];
			[threadDictionary setObject: dateFormatter forKey: @"DateDependingOnDateDateFormatter"];
		}
    }
    return dateFormatter;
	
	//return [_instance dateFormatterToFormatDateDependingOnCurrentDate]; // This is NOT threadsafe!!!
}

+ (NSNumberFormatter *)numberFormatterToFormatPriceWithMinimalDecimals {
	
	// To make it threadSafe, create a formatter for each thread that is calling this method
	NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
    NSNumberFormatter *numberFormatter = [threadDictionary objectForKey: @"priceWithMinimalDecimalsNumberFormatter"];
    if (numberFormatter == nil)
    {
		@synchronized(self){
			numberFormatter = [[[_instance priceWithMinimalDecimalsNumberFormatter] copy] autorelease];
			[threadDictionary setObject: numberFormatter forKey: @"priceWithMinimalDecimalsNumberFormatter"];
		}
    }
    return numberFormatter;
	
	//return [_instance priceWithMinimalDecimalsNumberFormatter]; // This is NOT threadsafe!!!
}

+ (NSNumberFormatter *)numberFormatterToFormatPriceWithTwoDecimals {
	
	// To make it threadSafe, create a formatter for each thread that is calling this method
	NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
    NSNumberFormatter *numberFormatter = [threadDictionary objectForKey: @"priceWithTwoDecimalsNumberFormatter"];
    if (numberFormatter == nil)
    {
		@synchronized(self){
			numberFormatter = [[[_instance priceWithTwoDecimalsNumberFormatter] copy] autorelease];
			[threadDictionary setObject: numberFormatter forKey: @"priceWithTwoDecimalsNumberFormatter"];
		}
    }
    return numberFormatter;
	
	//return [_instance priceWithTwoDecimalsNumberFormatter]; // This is NOT threadsafe!!!
}

+ (NSNumberFormatter *)numberFormatterToFormatPriceWithThreeDecimals {
	
	// To make it threadSafe, create a formatter for each thread that is calling this method
	NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
    NSNumberFormatter *numberFormatter = [threadDictionary objectForKey: @"priceWithThreeDecimalsNumberFormatter"];
    if (numberFormatter == nil)
    {
		@synchronized(self){
			numberFormatter = [[[_instance priceWithThreeDecimalsNumberFormatter] copy] autorelease];
			[threadDictionary setObject: numberFormatter forKey: @"priceWithThreeDecimalsNumberFormatter"];
		}
    }
    return numberFormatter;
	
	//return [_instance priceWithThreeDecimalsNumberFormatter]; // This is NOT threadsafe!!!
}

+ (NSNumberFormatter *)numberFormatterToFormatVolume {
	
	// To make it threadSafe, create a formatter for each thread that is calling this method
	NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
    NSNumberFormatter *numberFormatter = [threadDictionary objectForKey: @"volumeNumberFormatter"];
    if (numberFormatter == nil)
    {
		@synchronized(self){
			numberFormatter = [[[_instance volumeNumberFormatter] copy] autorelease];
			[threadDictionary setObject: numberFormatter forKey: @"volumeNumberFormatter"];
		}
    }
    return numberFormatter;
	
	//return [_instance volumeNumberFormatter]; // This is NOT threadsafe!!!
}

+ (NSNumberFormatter *)numberFormatterToFormatNumberWithOriginalNumberOfDecimals {
	
	// To make it threadSafe, create a formatter for each thread that is calling this method
	NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
    NSNumberFormatter *numberFormatter = [threadDictionary objectForKey: @"numberWithOriginalNumberOfDecimalsNumberFormatter"];
    if (numberFormatter == nil)
    {
		@synchronized(self){
			numberFormatter = [[[_instance numberWithOriginalNumberOfDecimalsNumberFormatter] copy] autorelease];
			[threadDictionary setObject: numberFormatter forKey: @"numberWithOriginalNumberOfDecimalsNumberFormatter"];
		}
    }
    return numberFormatter;
	
	//return [_instance numberWithOriginalNumberOfDecimalsNumberFormatter]; // This is NOT threadsafe!!!
}

+ (NSNumberFormatter *)numberFormatterToFormatNumberWithTwoDecimals {
	
	// To make it threadSafe, create a formatter for each thread that is calling this method
	NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
    NSNumberFormatter *numberFormatter = [threadDictionary objectForKey: @"numberWithTwoDecimalsNumberFormatter"];
    if (numberFormatter == nil)
    {
		@synchronized(self){
			numberFormatter = [[[_instance numberWithTwoDecimalsNumberFormatter] copy] autorelease];
			[threadDictionary setObject: numberFormatter forKey: @"numberWithTwoDecimalsNumberFormatter"];
		}
    }
    return numberFormatter;
	
	// return [_instance numberWithTwoDecimalsNumberFormatter]; // This is NOT threadsafe!!!
}

+ (NSNumberFormatter *)numberFormatterToFormatNumberWithThreeDecimals {
	
	// To make it threadSafe, create a formatter for each thread that is calling this method
	NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
    NSNumberFormatter *numberFormatter = [threadDictionary objectForKey: @"numberWithThreeDecimalsNumberFormatter"];
    if (numberFormatter == nil)
    {
		@synchronized(self){
			numberFormatter = [[[_instance numberWithThreeDecimalsNumberFormatter] copy] autorelease];
			[threadDictionary setObject: numberFormatter forKey: @"numberWithThreeDecimalsNumberFormatter"];
		}
    }
    return numberFormatter;
	
	// return [_instance numberWithThreeDecimalsNumberFormatter]; // This is NOT threadsafe!!!
}

@end