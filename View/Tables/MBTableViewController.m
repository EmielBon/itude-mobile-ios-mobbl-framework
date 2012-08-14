//
//  MBTableViewController.m
//  Core
//
//  Created by Robin Puthli on 5/18/10.
//  Copyright 2010 Itude Mobile. All rights reserved.
//
//  Note: [self.view viewWithTag:100] = fontMenu

#import "MBRowViewBuilder.h"
#import "MBTableViewController.h"
#import "MBPanel.h"
#import "MBField.h"
#import "MBRow.h"
#import "MBViewBuilderFactory.h"
#import "MBFieldDefinition.h"
#import "MBPage.h"
#import "MBPickerController.h"
#import "MBPickerPopoverController.h"
#import "MBDevice.h"
#import "MBDatePickerController.h"
#import "UIWebView+FontResizing.h"
#import "UIView+TreeWalker.h"
#import "MBFontCustomizer.h"


#define MAX_FONT_SIZE 20

#define C_CELL_Y_MARGIN 4

// TODO: Get the font size and name from the styleHandler
@interface MBTableViewController()

@property (nonatomic, retain) NSMutableDictionary *rowsByIndexPath;

@end

@implementation MBTableViewController

@synthesize styleHandler = _styleHandler;
@synthesize webViews = _webViews;
@synthesize finishedLoadingWebviews = _finishedLoadingWebviews;
@synthesize sections=_sections;
@synthesize page=_page;
@synthesize fontSize = _fontSize;
@synthesize fontMenuActive = _fontMenuActive;
@synthesize rowsByIndexPath = _rowsByIndexPath;

-(void) dealloc{
    // The following is REQUIRED to make sure no signal 10 is generated when a webview is still loading
    // while this controller is dealloced
    for(UIWebView *webView in [_webViews allValues]) {
        webView.delegate = nil;
    }
    //BINCKAPPS-635
    //ios tries to update sublayers, which calls the related uitableview to refresh
    //Uitableview then calls its delegate which has already been deallocated (an instance of this class)
    //so we manually remove the uitableview from its delegate controller when the controller gets deallocated
    [self.view removeFromSuperview];
    [_webViews release];
    [_sections release];
    [_rowsByIndexPath release];

    [super dealloc];
}

-(void) viewDidLoad{
	[super viewDidLoad];
	self.styleHandler = [[MBViewBuilderFactory sharedInstance] styleHandler];
    self.rowsByIndexPath = [NSMutableDictionary dictionary];
	self.finishedLoadingWebviews = NO;
	self.webViews = [NSMutableDictionary dictionary];
	[self tableView].backgroundColor = [UIColor clearColor];
    
    // TODO: Get the font size from the styleHandler
    self.fontSize = C_WEBVIEW_DEFAULT_FONTSIZE;
    self.fontMenuActive = NO;
}



-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView{
	return [self.sections count];
}

-(NSInteger) tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)sectionNo {
	MBPanel *section = (MBPanel *)[self.sections objectAtIndex:(NSUInteger) sectionNo];
	NSMutableArray *rows = [section descendantsOfKind: [MBPanel class] filterUsingSelector: @selector(type) havingValue: C_ROW];
	return [rows count];
}

-(MBRow *)getRowForIndexPath:(NSIndexPath *) indexPath {
	MBPanel *section = (MBPanel *)[self.sections objectAtIndex:(NSUInteger) indexPath.section];
	NSMutableArray *rows = [section descendantsOfKind: [MBPanel class] filterUsingSelector: @selector(type) havingValue: C_ROW];
	MBRow *row = [rows objectAtIndex:(NSUInteger) indexPath.row];
	return row;
}

-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	// The height is set below
	return [[[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 0.0f, 0.0f)] autorelease];	
}

// Need to call to pad the footer height otherwise the footer collapses
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	return section == [self.sections count]-1?0.0f:10.0f;
}

-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    NSLog(@"heightForRow: %@", indexPath);
    CGFloat height = 44;
	
	UIWebView *webView = [self.webViews objectForKey:indexPath];
	if (webView) {
		NSString *heightString = [webView stringByEvaluatingJavaScriptFromString:@"document.body.scrollHeight;"];
		height = [heightString floatValue] + C_CELL_Y_MARGIN * 2;
	}
    
	// Loop through the fields in the row to determine the size of multiline text cells 
	MBRow *row = [self getRowForIndexPath:indexPath];
	
	for(MBComponent *child in [row children]){
		if ([child isKindOfClass:[MBField class]]) {
			MBField *field = (MBField *)child;
			
			if ([C_FIELD_TEXT isEqualToString:field.type]){
				NSString * text;
				if(field.path != nil) {
					text = [field formattedValue];
				}
				else {
					text= field.label;
				}
				if (![self hasHTML:text]) {
					MBStyleHandler *styleHandler = [[MBViewBuilderFactory sharedInstance] styleHandler];
					// calculate bounding box
					CGSize constraint = CGSizeMake(tableView.frame.size.width - 20, 50000); // TODO -- shouldn't hard code the -20 for the label size here
					CGSize size = [text sizeWithFont:[styleHandler fontForField:field] constrainedToSize:constraint lineBreakMode:UILineBreakModeWordWrap];
					height = size.height + 22; // inset
				}
			}
		}
	}

    NSLog(@"webView = %@", webView);
    NSLog(@"height = %f", height);

    return height;
}

- (void)addFontCustomizerForWebView:(UIWebView *)webview
{
// Adds Two buttons to the navigationBar that allows the user to change the fontSize. We only add this on the
    // iPad, because the iPhone has very little room to paste all the buttons (refresh, close, etc.)
    if ([MBDevice isPad]) {

        UIViewController *parentViewcontroller = self.page.viewController;
        UIBarButtonItem *item = parentViewcontroller.navigationItem.rightBarButtonItem;

        if (item == nil || ![item isKindOfClass:[MBFontCustomizer class]]) {
            MBFontCustomizer *fontCustomizer = [[MBFontCustomizer new] autorelease];
            [fontCustomizer setButtonsDelegate:self];
            [fontCustomizer setSender:webview];
            [fontCustomizer addToViewController:parentViewcontroller animated:YES];
        }
    }
}

-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{

	MBRow *row = [self getRowForIndexPath:indexPath];
    id<MBRowViewBuilder> builder = [[MBViewBuilderFactory sharedInstance] rowViewBuilder];
    UITableViewCell *cell = [builder buildRowView:row forIndexPath:indexPath viewState:self.page.currentViewState
                                                      forTableView:tableView];

    // Register any webViews in the cell
    [self.webViews removeObjectForKey:indexPath]; // Make sure no old webViews are retained
    for (UIView *subview in [cell subviewsOfClass:[UIWebView class]]) {
        UIWebView *webview = (UIWebView *)subview;
        webview.delegate = self;
        [self.webViews setObject:subview forKey:indexPath];
        [webview refreshWithFontSize:self.fontSize];
        [self addFontCustomizerForWebView:webview];
    }

    [self.rowsByIndexPath setObject:row forKey:indexPath];

    return cell;
}

-(BOOL) hasHTML:(NSString *) text{
	BOOL result = NO;
	NSString * lowercaseText = [text lowercaseString];
	NSRange found = [lowercaseText rangeOfString:@"<html>"];
	if (found.location != NSNotFound) result = YES;
	
	found = [lowercaseText rangeOfString:@"<body>"];
	if (found.location != NSNotFound) result = YES;
    
	found = [lowercaseText rangeOfString:@"<b>"];
	if (found.location != NSNotFound) result = YES;
    
	found = [lowercaseText rangeOfString:@"<br>"];
	if (found.location != NSNotFound) result = YES;
    
	return result;
}

// callback when pickerView value changes
-(void)observeValueForKeyPath:(NSString *)keyPath
					 ofObject:(id)object
					   change:(NSDictionary *)change
					  context:(void *)context
{
	
    if ([keyPath isEqual:@"value"]) {
		[self.tableView reloadData];
	}
}	


-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    MBRow *selectedRow = [self.rowsByIndexPath objectForKey:indexPath];

	// use the first field we come across to trigger keyboard dismissal
//	for(MBField *field in [self.cellReferences allValues]){
//		[[field page] resignFirstResponder];
//		break;
//	}

    [self.page resignFirstResponder];

    for (MBField *field in [selectedRow childrenOfKind:[MBField class]]) {


        if ([C_FIELD_DROPDOWNLIST isEqualToString:field.type]) { //ds
            [self fieldWasSelected:field];
            [field addObserver:self forKeyPath:@"value" options:NSKeyValueObservingOptionNew context:nil];

            // iPad supports popovers, which are a nicer and better way to let the user make a choice from a dropdown list
            if ([MBDevice isPad]) {
                MBPickerPopoverController *picker = [[[MBPickerPopoverController alloc]
                                                                                 initWithField:field]
                                                                                 autorelease];
                //picker.field = field;
                UIView *cell = [tableView cellForRowAtIndexPath:indexPath];
                UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:picker];
                // We permit all arrow directions, except up and down because in 99 percent of all cases the apple framework will place the popover on a weird and ugly location with arrowDirectionUp
                [popover presentPopoverFromRect:cell.frame inView:self.view
                       permittedArrowDirections:UIPopoverArrowDirectionLeft | UIPopoverArrowDirectionRight
                                       animated:YES];
                picker.popover = popover;
                [popover release];
            }
                    // On devices with a smaller screensize it's better to use a scrollWheel
            else {
                MBPickerController *pickerController = [[[MBPickerController alloc]
                                                                             initWithNibName:@"MBPicker" bundle:nil]
                                                                             autorelease];
                pickerController.field = field;
                [field setViewData:pickerController
                            forKey:@"pickerController"]; // let the page retain the picker controller
                UIView *superview = [tableView window];
                [pickerController presentWithSuperview:superview];
            }


        } else if ([C_FIELD_DATETIMESELECTOR isEqualToString:field.type] ||
                [C_FIELD_DATESELECTOR isEqualToString:field.type] ||
                [C_FIELD_TIMESELECTOR isEqualToString:field.type] ||
                [C_FIELD_BIRTHDATE isEqualToString:field.type]) {

            [self fieldWasSelected:field];
            [field addObserver:self forKeyPath:@"value" options:NSKeyValueObservingOptionNew context:nil];

            MBDatePickerController *dateTimePickerController = [[[MBDatePickerController alloc]
                                                                                         initWithNibName:@"MBDatePicker"
                                                                                                  bundle:nil]
                                                                                         autorelease];
            dateTimePickerController.field = field;
            [field setViewData:dateTimePickerController forKey:@"datePickerController"];

            // Determine the datePickerModeStyle
            UIDatePickerMode datePickerMode = UIDatePickerModeDateAndTime;
            if ([C_FIELD_DATESELECTOR isEqualToString:field.type] || [C_FIELD_BIRTHDATE isEqualToString:field.type]) {
                datePickerMode = UIDatePickerModeDate;
            } else if ([C_FIELD_TIMESELECTOR isEqualToString:field.type]) {
                datePickerMode = UIDatePickerModeTime;
            }
            dateTimePickerController.datePickerMode = datePickerMode;

            if ([C_FIELD_BIRTHDATE isEqualToString:field.type]) {
                dateTimePickerController.maximumDate = [NSDate date];
            }

            UIView *superView = [tableView window];
            [dateTimePickerController presentWithSuperview:superView];


        } else if (field && [field outcomeName]) {
            [self fieldWasSelected:field];
            // this covers the case when field path has an indexed expressions while the commented one does not
            [field handleOutcome:[field outcomeName]
                   withPathArgument:[field evaluatedDataPath]];

        }
    }
}

// allows subclasses to attach behaviour to a field.
-(void) fieldWasSelected:(MBField *)field{
    (void)field;    // Prevent compiler warning of unused parameter
}

-(NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)sectionNo{
    MBPanel *section = (MBPanel *)[self.sections objectAtIndex:(NSUInteger) sectionNo];
    return [section title];
}


// UIWebViewDelegate methods
-(void) webViewDidFinishLoad:(UIWebView *)webView{
	BOOL done = YES;

    // reset the frame to something small, somehow this triggers UIKit to recalculate the height
    webView.frame = CGRectMake(webView.frame.origin.x, webView.frame.origin.y, webView.frame.size.width, 1);
    [webView sizeToFit];

	for (UIWebView *w in [self.webViews allValues]){
		if (w.loading) {
			done=NO;
		}
	}
	
	if (done) {
		if (!self.finishedLoadingWebviews) {
			self.finishedLoadingWebviews = YES;
			[self.tableView reloadData];
		}
	}
}

-(void) rebuildView {
	
}

-(void)reloadAllWebViews{
    self.finishedLoadingWebviews = NO;
    for (UIWebView *webView in [self.webViews allValues]) {
        [webView refreshWithFontSize:self.fontSize];
    }
}

#pragma mark -
#pragma mark MBFontChangeListenerProtocol methods

-(void)fontsizeIncreased:(id)sender {
    if (self.fontSize < MAX_FONT_SIZE) {
        self.fontSize ++;
        [self reloadAllWebViews];
    }
}

-(void)fontsizeDecreased:(id)sender {
    if (self.fontSize > C_WEBVIEW_DEFAULT_FONTSIZE) {
        self.fontSize --;
        [self reloadAllWebViews];
    }
}


@end
