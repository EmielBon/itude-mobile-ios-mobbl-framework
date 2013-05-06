//
//  MBViewManager.m
//  Core
//
//  Created by Wido on 28-5-10.
//  Copyright 2010 Itude Mobile BV. All rights reserved.
//

#import "MBMacros.h"
#import "MBViewManager.h"
#import "MBPageStackDefinition.h"
#import "MBDialogDefinition.h"
#import "MBPageStackController.h"
#import "MBDialogController.h"
#import "MBOutcomeDefinition.h"
#import "MBOutcome.h"
#import "MBMetadataService.h"
#import "MBPage.h"
#import "MBAlert.h"
#import "MBResourceService.h"
#import "MBActivityIndicator.h"
#import "MBConfigurationDefinition.h"
#import "MBSpinner.h"
#import "MBLocalizationService.h"
#import "MBBasicViewController.h"
#import "MBTransitionStyle.h"

// Used to get a stylehandler to style navigationBar
#import "MBStyleHandler.h"
#import "MBViewBuilderFactory.h"

#import <objc/runtime.h>
#import <objc/message.h>

@interface MBViewManager() {
	UIWindow *_window;
	UITabBarController *_tabController;
	NSMutableDictionary *_pageStackControllers;
	NSMutableDictionary *_dialogControllers;
	NSMutableDictionary *_activityIndicatorCounts;
	NSMutableArray *_pageStackControllersOrdered;
	NSMutableArray *_dialogControllersOrdered;
	NSMutableArray *_sortedNewPageStackNames;
	NSString *_activePageStackName;
	NSString *_activeDialogName;
	UIAlertView *_currentAlert;
	UINavigationController *_modalController;
	int _activityIndicatorCount;
	BOOL _singlePageMode;
}

-(MBPageStackController*) pageStackControllerWithName:(NSString*) name;
- (void) clearWindow;
- (void) updateDisplay;
- (void) resetView;
- (void) showAlertView:(MBPage*) page;
- (void) addPageToPageStack:(MBPage *) page displayMode:(NSString*) displayMode transitionStyle:(NSString *)transitionStyle selectPageStack:(BOOL) shouldSelectPageStack;
@end

@implementation MBViewManager

@synthesize window = _window;
@synthesize tabController = _tabController;
@synthesize activePageStackName = _activePageStackName;
@synthesize activeDialogName = _activeDialogName;
@synthesize currentAlert = _currentAlert;
@synthesize singlePageMode = _singlePageMode;

- (id) init {
	self = [super init];
	if (self != nil) {
		_activityIndicatorCounts = [NSMutableDictionary new];
        _window = [[UIWindow alloc] initWithFrame: [[UIScreen mainScreen]bounds]];
		_sortedNewPageStackNames = [NSMutableArray new];
		self.singlePageMode = FALSE;
        [self resetView];
	}
	return self;
}

- (void) dealloc {
	[_pageStackControllers release];
	[_dialogControllers release];
	[_window release];
	[_tabController release];
	[_sortedNewPageStackNames release];
	[_activityIndicatorCounts release];
	[_activePageStackName release];
	[_activeDialogName release];
	[_currentAlert release];
	[_modalController release];
	[super dealloc];
}

-(void) showPage:(MBPage*) page displayMode:(NSString*) displayMode {
    [self showPage:page displayMode:displayMode transitionStyle:nil selectPageStack:TRUE];
}

- (void) showPage:(MBPage*) page displayMode:(NSString*) displayMode transitionStyle:(NSString *) transitionStyle {
    [self showPage:page displayMode:displayMode transitionStyle:transitionStyle selectPageStack:TRUE];
}

-(void) showPage:(MBPage*) page displayMode:(NSString*) displayMode selectPageStack:(BOOL) shouldSelectPageStack {
    [self showPage:page displayMode:displayMode transitionStyle:nil selectPageStack:shouldSelectPageStack];
}


-(void) showPage:(MBPage*) page displayMode:(NSString*) displayMode transitionStyle:(NSString *) transitionStyle selectPageStack:(BOOL) shouldSelectPageStack {
    
    
    DLog(@"ViewManager: showPage name=%@ pageStack=%@ mode=%@ type=%i", page.pageName, page.pageStackName, displayMode, page.pageType);

	if(page.pageType == MBPageTypesErrorPage || [@"POPUP" isEqualToString:displayMode]) {
		[self showAlertView: page];
	}
	else if(_modalController == nil &&
			([@"MODAL" isEqualToString:displayMode] || 
			 [@"MODALWITHCLOSEBUTTON" isEqualToString:displayMode] || 
			 [@"MODALFORMSHEET" isEqualToString:displayMode] ||
			 [@"MODALFORMSHEETWITHCLOSEBUTTON" isEqualToString:displayMode] || 
			 [@"MODALPAGESHEET" isEqualToString:displayMode] ||
			 [@"MODALPAGESHEETWITHCLOSEBUTTON" isEqualToString:displayMode] ||
			 [@"MODALFULLSCREEN" isEqualToString:displayMode] ||
			 [@"MODALFULLSCREENWITHCLOSEBUTTON" isEqualToString:displayMode] || 
			 [@"MODALCURRENTCONTEXT" isEqualToString:displayMode] ||
			 [@"MODALCURRENTCONTEXTWITHCLOSEBUTTON" isEqualToString:displayMode])) {
                // TODO: support nested modal pageStacks
                _modalController = [[UINavigationController alloc] initWithRootViewController:[page viewController]];
                [[[MBViewBuilderFactory sharedInstance] styleHandler] styleNavigationBar:_modalController.navigationBar];
                
                BOOL addCloseButton = NO;
                if ([@"MODALFORMSHEET" isEqualToString:displayMode])			[_modalController setModalPresentationStyle:UIModalPresentationFormSheet];
                else if ([@"MODALPAGESHEET" isEqualToString:displayMode])		[_modalController setModalPresentationStyle:UIModalPresentationPageSheet];
                else if ([@"MODALFULLSCREEN" isEqualToString:displayMode])		[_modalController setModalPresentationStyle:UIModalPresentationFullScreen];
                else if ([@"MODALCURRENTCONTEXT" isEqualToString:displayMode])	[_modalController setModalPresentationStyle:UIModalPresentationCurrentContext];
                else if ([@"MODALWITHCLOSEBUTTON" isEqualToString:displayMode]) addCloseButton = YES;
                else if ([@"MODALFORMSHEETWITHCLOSEBUTTON" isEqualToString:displayMode]) {
                    addCloseButton = YES;
                    [_modalController setModalPresentationStyle:UIModalPresentationFormSheet];
                }
                else if ([@"MODALPAGESHEETWITHCLOSEBUTTON" isEqualToString:displayMode]) {
                    addCloseButton = YES;
                    [_modalController setModalPresentationStyle:UIModalPresentationFormSheet];
                }
                else if ([@"MODALFULLSCREENWITHCLOSEBUTTON" isEqualToString:displayMode]) {
                    addCloseButton = YES;
                    //[_modalController setModalPresentationStyle:UIModalPresentationFormSheet];
                    [_modalController setModalPresentationStyle:UIModalPresentationFullScreen];
                }
                else if ([@"MODALCURRENTCONTEXTWITHCLOSEBUTTON" isEqualToString:displayMode]) {
                    addCloseButton = YES;
                    [_modalController setModalPresentationStyle:UIModalPresentationFormSheet];
                }
                
                if (addCloseButton) {
                    NSString *closeButtonTitle = MBLocalizedString(@"closeButtonTitle");
                    UIBarButtonItem *closeButton = [[[UIBarButtonItem alloc] initWithTitle:closeButtonTitle style:UIBarButtonItemStyleBordered target:self action:@selector(endModalPageStack)] autorelease];
                    [_modalController.topViewController.navigationItem setRightBarButtonItem:closeButton animated:YES];
                }
                                                
                // If tabController is nil, there is only one viewController
                if (_tabController) {
                    [[[MBApplicationFactory sharedInstance] transitionStyleFactory] applyTransitionStyle:transitionStyle withMovement:MBTransitionMovementPush forViewController:_tabController];
                    page.transitionStyle = transitionStyle;
                    [self presentViewController:_modalController fromViewController:_tabController animated:YES];
                }
                else if (_singlePageMode){
                    MBPageStackController *pageStackController = [[_pageStackControllers allValues] objectAtIndex:0];
                    [[[MBApplicationFactory sharedInstance] transitionStyleFactory] applyTransitionStyle:transitionStyle withMovement:MBTransitionMovementPush forViewController:_modalController];
                    page.transitionStyle = transitionStyle;
                    [self presentViewController:_modalController fromViewController:pageStackController.navigationController animated:YES];
                }
                // tell other view controllers that they have been dimmed (and auto-refresh controllers may need to stop refreshing)
                NSDictionary * dict = [NSDictionary dictionaryWithObject:_modalController forKey:@"modalViewController"];
                [[NSNotificationCenter defaultCenter] postNotificationName:MODAL_VIEW_CONTROLLER_PRESENTED object:self userInfo:dict];
            }
	else if(_modalController != nil) {
		UIViewController *currentViewController = [page viewController];
        
        // Apply transition. Pushing on the navigation stack
        id<MBTransitionStyle> transition = [[[MBApplicationFactory sharedInstance] transitionStyleFactory] transitionForStyle:transitionStyle];
        [transition applyTransitionStyleToViewController:_modalController forMovement:MBTransitionMovementPush];
        page.transitionStyle = transitionStyle;
		[_modalController pushViewController:currentViewController animated:[transition animated]];
		
		// See if the first viewController has a barButtonItem that can close the controller. If so, add it to the new controller
		UIViewController *rootViewController = [_modalController.viewControllers objectAtIndex:0];		
		UIBarButtonItem *rightBarButtonItem = rootViewController.navigationItem.rightBarButtonItem;
		NSString *closeButtonTitle = MBLocalizedString(@"closeButtonTitle");
		if (rightBarButtonItem != nil && [rightBarButtonItem.title isEqualToString:closeButtonTitle] && 
			currentViewController.navigationItem.rightBarButtonItem == nil) {
            UIBarButtonItem *closeButton = [[[UIBarButtonItem alloc] initWithTitle:closeButtonTitle style:UIBarButtonItemStyleBordered target:self action:@selector(endModalPageStack)] autorelease];
            [currentViewController.navigationItem setRightBarButtonItem:closeButton animated:YES];
		}
		
		// Workaround for view delegate method calls in modal views Controller (BINCKAPPS-426 and MOBBL-150)
		[currentViewController performSelector:@selector(viewWillAppear:) withObject:nil afterDelay:0];
		[currentViewController performSelector:@selector(viewDidAppear:) withObject:nil afterDelay:0]; 
	}
    else {
		[self addPageToPageStack:page displayMode:displayMode transitionStyle:transitionStyle selectPageStack:shouldSelectPageStack];
	}
}	

-(void) addPageToPageStack:(MBPage *) page displayMode:(NSString*) displayMode transitionStyle:transitionStyle selectPageStack:(BOOL) shouldSelectPageStack {
    
    
    MBDialogDefinition *dialogDef = [[MBMetadataService sharedInstance] dialogDefinitionForPageStackName:page.pageStackName];
    MBDialogController *dialogController = [self dialogWithName:dialogDef.name];
    
    if (dialogController == nil) {
        dialogController = [self createDialogController:dialogDef];
        [self updateDisplay];
    }
    
    MBPageStackController *pageStackController = [dialogController pageStackControllerWithName:page.pageStackName];
    [pageStackController showPage:page displayMode:displayMode transitionStyle:transitionStyle];

	
	if(shouldSelectPageStack ) {
        [self activatePageStackWithName:page.pageStackName];
    }
}

- (MBDialogController *)createDialogController:(MBDialogDefinition *)definition {
    MBDialogController *dialogController = [self dialogWithName:definition.name];
    
    if (dialogController == nil) {
        dialogController = [[MBApplicationFactory sharedInstance] createDialogController:definition];
        
        [_dialogControllers setValue:dialogController forKey:dialogController.name];
        for (MBPageStackController *stack in dialogController.pageStackControllers) {
            [_pageStackControllers setObject:stack forKey:stack.name];
            [_pageStackControllersOrdered addObject:stack.name];
        }
    }
    return dialogController;
}

-(void) showAlertView:(MBPage*) page {
	
	
	if(self.currentAlert == nil) {
		//			[self.currentAlert dismissWithClickedButtonIndex:0 animated: FALSE];
		
		NSString *title;
		NSString *message;
        MBDocument *document = page.document;
		
        if([document.name isEqualToString:DOC_SYSTEM_EXCEPTION] &&
           [[document valueForPath:PATH_SYSTEM_EXCEPTION_TYPE] isEqualToString:DOC_SYSTEM_EXCEPTION_TYPE_SERVER]) {
			title = [document valueForPath:PATH_SYSTEM_EXCEPTION_NAME];
			message = [document valueForPath:PATH_SYSTEM_EXCEPTION_DESCRIPTION];
		}
		
        else if([document.name isEqualToString:DOC_SYSTEM_EXCEPTION]) {
			title = MBLocalizedString(@"Application error");
			message = MBLocalizedString(@"Unknown error");
		}
		else {
			title = page.title;
			message = MBLocalizedString([document valueForPath:@"/message[0]/@text"]);
			if(message == nil) message = MBLocalizedString([document valueForPath:@"/message[0]/@text()"]);
		}
		
		_currentAlert = [[UIAlertView alloc]
							 initWithTitle: title
							 message: message
							 delegate:self
							 cancelButtonTitle:@"OK"
							 otherButtonTitles:nil];
		
        // There seem to be timing issues with displaying the alert 
        // while the screen is being redrawn due to becoming active after sleep or background
        // The alert was shown, but the background was blank / white.
        // #BINCKAPPS-357 is solved by scheduling the alert to be displayed after all UI stuff has been finished
		[self.currentAlert performSelector:@selector(show) withObject:nil afterDelay:0.1];
	}
}

- (void)showAlert:(MBAlert *)alert {
    [alert.alertView show];
}

- (void) makeKeyAndVisible {
	[self.tabController.moreNavigationController popToRootViewControllerAnimated:NO];
	[self.window makeKeyAndVisible];
	
	// ensure first Dialog is selected.
	if (_dialogControllersOrdered.count >0) {
		_activeDialogName = (NSString*)[_dialogControllersOrdered objectAtIndex:0];
	}
}

- (void) presentViewController:(UIViewController *)controller fromViewController:(UIViewController *)fromViewController animated:(BOOL)animated {
    // iOS 6.0 and up
    if ([fromViewController respondsToSelector:@selector(presentViewController:animated:completion:)]) {
        [fromViewController presentViewController:controller animated:animated completion:nil];
    }
    // iOS 5.x and lower
    else {
        // Suppress the deprecation warning
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [fromViewController presentModalViewController:controller animated:animated];
        #pragma clang diagnostic pop
    }
    
}

- (void) dismisViewController:(UIViewController *)controller animated:(BOOL)animated {
    // iOS 6.0 and up
    if ([controller respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]) {
        [controller dismissViewControllerAnimated:animated completion:nil];
    }
    // iOS 5.x and lower
    else {
        
        // Suppress the deprecation warning
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [controller dismissModalViewControllerAnimated:animated];
        #pragma clang diagnostic pop
    }
}

- (void) endModalPageStack {
	if(_modalController != nil) {
		// Hide any activity indicator for the modal stuff:
		while(_activityIndicatorCount >0) [self hideActivityIndicator];
		
        // If tabController is nil, there is only one viewController
        if (self.tabController) {
            [self dismisViewController:self.tabController animated:TRUE];
        }
        else if (_singlePageMode){
            MBPageStackController *pageStackController = [[_pageStackControllers allValues] objectAtIndex:0];
            [self dismisViewController:pageStackController.navigationController animated:YES];
        }
        
		[[NSNotificationCenter defaultCenter] postNotificationName:MODAL_VIEW_CONTROLLER_DISMISSED object:self];
		[_modalController release];	
		_modalController = nil;
	}
}

- (void) popPage:(NSString*) pageStackName {
    MBPageStackController *result = [self pageStackControllerWithName:pageStackName];
    [result popPageWithTransitionStyle:nil animated:FALSE];
}

-(void) endPageStackWithName:(NSString*) pageStackName keepPosition:(BOOL) keepPosition {
    MBPageStackController *result = [self pageStackControllerWithName:pageStackName]; 
    if(result != nil) {
        [_pageStackControllersOrdered removeObject:result];
        [_pageStackControllers removeObjectForKey: pageStackName];
        [self updateDisplay];
    }
	if(!keepPosition) [_sortedNewPageStackNames removeObject:pageStackName];
}

-(void) activatePageStackWithName:(NSString*) pageStackName {
	
	self.activePageStackName = pageStackName;
    
    MBPageStackController *pageStackController = [self pageStackControllerWithName:pageStackName];
    MBDialogController *dialogController = [self dialogWithName:[pageStackController dialogName]];
    
	self.activeDialogName = [dialogController name];
	
	
	// Only set the selected tab if realy necessary; because it messes up the more navigation controller
	int idx = _tabController.selectedIndex;
	int shouldBe = [_tabController.viewControllers indexOfObject:dialogController.rootViewController];
	
	// Apparently we need to select the tab. Only now we cannot do this for tabs that are on the more tab
	// because it destroys the navigation controller for some reason
	// TODO: Make selecting a pageStack work; even if it is nested within the more tab
    if(idx != shouldBe/* && shouldBe < FIRST_MORE_TAB_INDEX*/) {
		UIViewController *ctrl = [_tabController selectedViewController];
		[ctrl viewWillDisappear:FALSE];
		[_tabController setSelectedViewController: dialogController.rootViewController];
		[ctrl viewDidDisappear:FALSE];
	}
}

- (void) resetView {
    
    [_tabController release];
    [_pageStackControllers release];
    [_pageStackControllersOrdered release];
	[_dialogControllers release];
	[_dialogControllersOrdered release];
	[_modalController release];
    
    _tabController = nil;
	_modalController = nil;
    _pageStackControllers = [NSMutableDictionary new];
    _pageStackControllersOrdered = [NSMutableArray new];
	_dialogControllers = [NSMutableDictionary new];
	_dialogControllersOrdered = [NSMutableArray new];
    [self clearWindow];
}


- (void) resetViewPreservingCurrentPageStack {
    // TODO: This will probably fail because Dialogs (ViewControllers) have nested PageStacks (NavigationControllers)
	for (UIViewController *controller in [_tabController viewControllers]){
		if ([controller isKindOfClass:[UINavigationController class]]) {
			[(UINavigationController *) controller popToRootViewControllerAnimated:YES];
		}
	}
	
}

-(MBPageStackController*) pageStackControllerWithName:(NSString*) name {
	return [_pageStackControllers objectForKey: name];
}

-(MBDialogController*) dialogWithName:(NSString*) name {
	
	MBDialogController *result = [_dialogControllers objectForKey: name];
	return result;
}

- (void) sortTabs {
	NSMutableArray *orderedTabNames = [NSMutableArray new];
	
	// First add the names of the dialogs that are NOT new; the order is already OK
    for (MBDialogController *dialogController in _dialogControllersOrdered) {
        for (MBPageStackController *pageStackController in dialogController.pageStackControllers) {
            if ([_sortedNewPageStackNames indexOfObject:pageStackController.name] == NSNotFound) {
                [orderedTabNames addObject:dialogController.name];
            }
        }
    }
    
	// Now add the names of new dialogs that are not yet in the resulting array:
	for(NSString *pageStackName in _sortedNewPageStackNames) {
        MBDialogDefinition *dialogDef = [[MBMetadataService sharedInstance] dialogDefinitionForPageStackName:pageStackName];
        MBDialogController *dialogController = [self dialogWithName:dialogDef.name];
		if([orderedTabNames indexOfObject:dialogController.name] == NSNotFound)  {
            [orderedTabNames addObject:dialogController.name];
        }
	}
    
	// Now rebuild the _dialogControllersOrdered array; using the order of the orderedTabNames
	[_dialogControllersOrdered removeAllObjects];
	for(NSString *name in orderedTabNames) {
		MBDialogController *dlgCtrl = [_dialogControllers valueForKey:name];
		// dlgCtrl might be nil! This is because the application controller may have started processing
		// and already has notified us; but the processing (in the background) has not yet completed.
		// Inthis case; the name of the pageStack is already known but it is not yet created
		if(dlgCtrl != nil) [_dialogControllersOrdered addObject: dlgCtrl];
	}
	[orderedTabNames release];
}	

// Remove every view that is not the activityIndicatorView
-(void) clearWindow {
    for(UIView *view in [self.window subviews]) {
		if(![view isKindOfClass:[MBActivityIndicator class]]) [view removeFromSuperview];
	}
}

- (void)setContentViewController:(UIViewController *)viewController {
    [self clearWindow];
    [self.window setRootViewController:viewController];
}

-(void) updateDisplay {
    if(_singlePageMode && [_dialogControllers count] == 1) {
        MBDialogController *dialogController = [[_dialogControllers allValues]objectAtIndex: 0];
        [dialogController loadView];
        [self setContentViewController:dialogController.rootViewController];
    } 
    else if([_dialogControllers count] > 1 || !_singlePageMode) 
	{
		if(_tabController == nil) {
			
			///////////////// CREATE THE TAB CONTROLLER
			///////////////////////////////////////////
			
			_tabController = [[UITabBarController alloc] init];
			_tabController.delegate = self;
			
			// Apply style to the tabbarController
			[[[MBViewBuilderFactory sharedInstance] styleHandler] styleTabBarController:_tabController];
            [self setContentViewController:_tabController];
		}		
		[self sortTabs];
		
        NSMutableArray *tabs = [NSMutableArray new];
        int idx = 0;
        for (MBDialogController *dialogController in _dialogControllersOrdered) {
            
            // Load the view
            [dialogController loadView];
            UIViewController *viewController = dialogController.rootViewController;
            
            viewController.hidesBottomBarWhenPushed = TRUE;
            [viewController setHidesBottomBarWhenPushed: FALSE];

            // Create a tabbarProperties
            UIImage *tabImage = [[MBResourceService sharedInstance] imageByID: dialogController.iconName];
            NSString *tabTitle = MBLocalizedString(dialogController.title);
            UITabBarItem *tabBarItem = [[[UITabBarItem alloc] initWithTitle:tabTitle image:tabImage tag:idx] autorelease];
            viewController.tabBarItem = tabBarItem;
            
            [tabs addObject:viewController];
            
            idx ++;
    
        }
        
        [_tabController setViewControllers: tabs animated: YES];
		[[_tabController moreNavigationController] setHidesBottomBarWhenPushed:FALSE];
        _tabController.moreNavigationController.delegate = self;
        _tabController.customizableViewControllers = nil;
        [tabs release];
    }
}

-(BOOL) tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController {
	return YES;
}

- (void)showActivityIndicator {
	if(_activityIndicatorCount == 0) {
		// determine the maximum bounds of the screen
		CGRect bounds = [UIScreen mainScreen].applicationFrame;	
		
		MBActivityIndicator *blocker = [[[MBActivityIndicator alloc] initWithFrame:bounds] autorelease];

		[self.window addSubview:blocker];
	}
	_activityIndicatorCount ++;
}

- (void)hideActivityIndicator {
	if(_activityIndicatorCount > 0) {
		_activityIndicatorCount--;
		
		if(_activityIndicatorCount == 0) {
			UIView *top = [self.window.subviews lastObject];
			if ([top isKindOfClass:[MBActivityIndicator class]])
				[top removeFromSuperview];
		}
	}
}

-(CGRect) bounds {
    return [self.window bounds];
}

- (void) notifyPageStackUsage:(NSString*) pageStackName {
	if(pageStackName != nil) {
		if(![_sortedNewPageStackNames containsObject:pageStackName]) {
			[_sortedNewPageStackNames addObject:pageStackName];
        }
        
        // TODO: This looks wrong. Figure out what is happening here
		// Create a temporary pageStack controller
//		MBPageStackController *pageStackController = [self pageStackControllerWithName: pageStackName];
//		if(pageStackController == nil) {
//			MBPageStackDefinition *pageStackDefinition = [[MBMetadataService sharedInstance] definitionForPageStackName: pageStackName];
//			pageStackController = [[MBPageStackController alloc] initWithDefinition: pageStackDefinition];
//			
//			[_pageStackControllers setValue: pageStackController forKey: pageStackName];
//			[pageStackController release];
//			[self updateDisplay];
//		}
	}
}

// Method is called when the tabBar will be edited by the user (when the user presses the edid-button on the more-page). 
// It is used to update the style of the "Edit" navigationBar behind the Edit-button
- (void)tabBarController:(UITabBarController *)tabBarController willBeginCustomizingViewControllers:(NSArray *)viewControllers {	
	// Get the navigationBar from the edit-view behind the more-tab and apply style to it. 
    UINavigationBar *navBar = [[[tabBarController.view.subviews objectAtIndex:1] subviews] objectAtIndex:0];
	[[[MBViewBuilderFactory sharedInstance] styleHandler] styleNavigationBar:navBar];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	self.currentAlert = nil;
}

- (MBViewState) currentViewState {
	// Currently fullscreen is not implemented
	if(_modalController != nil) return MBViewStateModal;
	if(_tabController != nil) return MBViewStateTabbed;
	return MBViewStatePlain;
}

-(void) tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController{
    // Set active dialog name
    for (MBDialogController *dialogController in [_dialogControllers allValues]) {
        if (viewController == dialogController.rootViewController) {
            self.activeDialogName = dialogController.name;
            break;
        }
    }
}

-(void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if ([viewController isKindOfClass:[MBBasicViewController class]])
    {
        MBBasicViewController* controller = (MBBasicViewController*) viewController;
        [controller.pageStackController didActivate];
    }
}

-(void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
 if ([viewController isKindOfClass:[MBBasicViewController class]])
    {
        MBBasicViewController* controller = (MBBasicViewController*) viewController;
        [controller.pageStackController willActivate];
        
    }
}

@end
