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

#import "MBSQLDataHandler.h"
#import "MBMetadataService.h"
#import "MBElement.h"
#import "MBMacros.h"

#import "FMResultSet.h"

#define C_DATABASE_NAME @"database.db"
#define C_GENERIC_SQL_REQUEST @"MBGenericSQLRequest"

@implementation MBSQLDataHandler

@synthesize databaseName = _databaseName;

- (id) init {
	self = [super init];
	if (self != nil) {
		self.databaseName = C_DATABASE_NAME;
	}
	return self;
}

- (void)dealloc {
    [_database close];
    [_database release];
    [_databaseName release];
    [super dealloc];
}

- (FMDatabase *)database {
    if (!_database) {
        DLog(@"MBSQLDataHandler.m: Opening database: %@", self.databaseName);
        NSString *dbPath = [self duplicateDatabaseToDocuments];
        
        _database = [[FMDatabase databaseWithPath:dbPath] retain];
        [_database open];
    }
    return _database;
}

// If a method name starts with 'new' or 'copy' the returned object must be retained.
- (NSString *)duplicateDatabaseToDocuments {
    NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *databasePath = [[documentPaths objectAtIndex:0] stringByAppendingPathComponent:self.databaseName];
    DLog(@"MBSQLDataHandler.m: at location: %@", databasePath);
    
    BOOL success = [[NSFileManager defaultManager] fileExistsAtPath:databasePath];
    if(success){
        DLog(@"MBSQLDataHandler.m: Database found at location");
        return databasePath;
    }
    
    NSString *databasePathFromApp = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:self.databaseName];
    DLog(@"MBSQLDataHandler.m: Database not found at location. Copying from local database at location: %@", databasePathFromApp);
    [[NSFileManager defaultManager] copyItemAtPath:databasePathFromApp toPath:databasePath error:nil];
    
    return databasePath;
}

- (MBDocument *)loadDocument:(NSString *)documentName withArguments:(MBDocument *)args {
    DLog(@"MBSQLDataHandler.m: Load document: %@", documentName);
    DLog(@"MBSQLDataHandler.m: with arguments: %@", [args asXmlWithLevel:0]);
    MBDocument *document = [[[MBMetadataService sharedInstance] definitionForDocumentName:documentName] createDocument];
    NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@", documentName];
    BOOL firstParameter = YES;
    NSString *queryOperator = [args valueForPath:@"/Query[0]/@operator"];
    queryOperator = (queryOperator?queryOperator:@"AND");
    NSString *groupBy = [args valueForPath:@"/Query[0]/@groupBy"];
    groupBy = (groupBy?[NSString stringWithFormat:@" GROUP BY %@", groupBy]:@"");
    
    for (MBElement *parameter in [args valueForPath:@"/Query[0]/Parameter"]) {
        NSString *key  = [parameter valueForAttribute:@"key"];
        NSString *value = [parameter valueForAttribute:@"value"];
        
        query = [NSString stringWithFormat:@"%@ %@ %@ = '%@'", query, (firstParameter?@"WHERE":queryOperator), key, value];
        firstParameter = NO;
    }
    
    query = [query stringByAppendingString:groupBy];
    DLog(@"MBSQLDataHandler.m: Execute query: %@", query);
    FMResultSet *resultSet = [self.database executeQuery:query];
    while ([resultSet next]) {
        [self addResultSet:resultSet toDocument:document];
    }
    return document;
}


- (MBDocument *)loadDocument:(NSString *)documentName {
    DLog(@"MBSQLDataHandler.m: Load document: %@", documentName);
    MBDocument *document = [[[MBMetadataService sharedInstance] definitionForDocumentName:documentName] createDocument];
    
    NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@", documentName];
    DLog(@"MBSQLDataHandler.m: Execute query: %@", query);
    FMResultSet *resultSet = [self.database executeQuery:query];
    while ([resultSet next]) {
        [self addResultSet:resultSet toDocument:document];
    }
    return document;
}

- (void)addResultSet:(FMResultSet*)resultSet toDocument:(MBDocument*)document {
    MBDocumentDefinition *documentDefinition = [[MBMetadataService sharedInstance] definitionForDocumentName:document.name];
    MBElementDefinition *elementDefinition = [[documentDefinition children]objectAtIndex:0];
    MBElement *resultSetRow = [document createElementWithName:[elementDefinition name]];
    NSArray *resultSetColumnNames = [elementDefinition attributes];
    for (int i=0; i<[resultSetColumnNames count]; i++) {
        NSString *columnName = [[resultSetColumnNames objectAtIndex:i] valueForKey:@"name"];
        NSString *columnValue = [resultSet stringForColumn:columnName];
        [resultSetRow setValue:columnValue forAttribute:columnName];
    }
}

- (void)storeDocument:(MBDocument *)document {
    NSString *tableName = document.name;
    MBDocumentDefinition *documentDefinition = [[MBMetadataService sharedInstance] definitionForDocumentName:tableName];
    MBElementDefinition *elementDefinition = [[documentDefinition children]objectAtIndex:0];
    
    [self dropTable:tableName];
    [self createTable:tableName withColumns:elementDefinition];
    
    [self.database beginTransaction];
    int key = 0;
    for (MBElement *row in [[document valueForPath:@"/"] elementsWithName:elementDefinition.name]) {
        [self addRow:row toTable:tableName containingColumns:elementDefinition withKey:key];
        key = key+1;
    }
    [self.database commit];
}

- (void) createTable:(NSString *)tableName withColumns:(MBElementDefinition *)columns {
    NSArray *resultSetColumnNames = [columns attributes];
    NSString *constraints = @"key INTEGER PRIMARY KEY";
    for (int i=0; i<[resultSetColumnNames count]; i++) {
        NSString *columnName = [[resultSetColumnNames objectAtIndex:i] valueForKey:@"name"];
        NSString *columntype = @"TEXT";
        if (columnName && ![columnName isEqualToString:@"key"]) {
            constraints = [NSString stringWithFormat:@"%@, %@ %@", constraints, columnName, columntype];
        }
    }
    NSString *query = [NSString stringWithFormat:@"CREATE TABLE %@ (%@)", tableName, constraints];
    [self.database executeUpdate:query];
}

- (void)dropTable:(NSString *)tableName {
    NSString *query = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@" ,tableName];
    DLog(@"MBSQLDataHandler.m: Execute query: %@", query);
    [self.database beginTransaction];
    [self.database executeUpdate:query];
    [self.database commit];
}

- (void)addRow:(MBElement *)row toTable:(NSString *)tableName containingColumns:(MBElementDefinition *)columns withKey:(int)key {
    NSArray *resultSetColumnNames = [columns attributes];
    NSMutableArray *arguments = [[[NSMutableArray alloc] init] autorelease];
    [arguments addObject:[NSNumber numberWithInt:key]];
    NSString *columnsString = @"key";
    NSString *valuesString = @"?";
    NSString *argumentsString = [NSString stringWithFormat:@"%d", key];
    for (int i=0; i<[resultSetColumnNames count]; i++) {
        NSString *columnName = [[resultSetColumnNames objectAtIndex:i] valueForKey:@"name"];
        NSString *columnValue = [NSString stringWithFormat:@"%@", [row valueForAttribute:columnName]];
        if (columnName && ![columnName isEqualToString:@"key"]) {
            [arguments addObject:columnValue];
            argumentsString = [argumentsString stringByAppendingFormat:@", %@", columnValue];
            columnsString = [columnsString stringByAppendingFormat:@", %@", columnName];
            valuesString = [valuesString stringByAppendingFormat:@", ?"];
        }
    }
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ (%@) values (%@)" ,tableName, columnsString, valuesString];
    DLog(@"MBSQLDataHandler.m: Execute query: %@ with arguments (%@)", query, argumentsString);
    [self.database executeUpdate:query withArgumentsInArray:arguments];
}

// Methods not used, but handy
- (void)clearTable:(NSString *)tableName {
    NSString *query = [NSString stringWithFormat:@"DELETE FROM %@" ,tableName];
    DLog(@"MBSQLDataHandler.m: Execute query: %@", query);
    [self.database beginTransaction];
    [self.database executeUpdate:query];
    [self.database commit];
}

- (BOOL)tableExists:(NSString*)tableName {
    BOOL exists = NO;
    
    NSString *query = [NSString stringWithFormat:@"SELECT name FROM sqlite_master WHERE type='table'"];
    DLog(@"MBSQLDataHandler.m: Execute query: %@", query);
    FMResultSet *resultSet = [self.database executeQuery:query];
    
    while ([resultSet next]) {
        NSString *foundTableName = [resultSet stringForColumn:@"name"];
        if ([foundTableName isEqualToString:tableName]) {
            DLog(@"MBSQLDataHandler.m: Table %@ found!", tableName);
            exists = YES;
        }
    }
    return exists;
}

@end