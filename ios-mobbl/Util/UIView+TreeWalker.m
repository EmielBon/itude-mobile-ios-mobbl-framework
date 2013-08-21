//
//  UIView(TreeWalker) 
//
//  Created by Pieter Kuijpers on 14-08-12.
//  Copyright (c) 2012 Itude Mobile. All rights reserved.
//

#import "UIView+TreeWalker.h"

@implementation UIView (TreeWalker)

- (NSArray *)subviewsOfClass:(Class)clazz
{
    NSMutableArray *result = [NSMutableArray array];
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:clazz]) {
            [result addObject:subview];
        }
        [result addObjectsFromArray:[subview subviewsOfClass:clazz]];
    }
    return result;
}

- (UIView *)firstSuperviewOfClass:(Class)clazz
{
    UIView *superView = [self superview];
    while (superView) {
        if ([superView isKindOfClass:clazz]) {
            return superView;
        }
        else {
            superView = [superView superview];
        }
    }

    return nil;
}

@end