//
//  Created by Vadim Shpakovski on 4/22/11.
//  Copyright 2011 Shpakovski. All rights reserved.
//

#import "MASPreferencesViewController.h"
#import "MASPreferencesWindowController.h"

NSString *const kMASPreferencesWindowControllerDidChangeViewNotification = @"MASPreferencesWindowControllerDidChangeViewNotification";

@interface MASPreferencesWindowController () // Private

- (void)updateViewControllerWithAnimation:(BOOL)animate;
- (void)setContentViewWithController:(NSViewController <MASPreferencesViewController> *)vc;
- (void)resetFirstResponderInViewController:(NSViewController <MASPreferencesViewController> *)vc;
@end

#pragma mark -

@implementation MASPreferencesWindowController

@synthesize viewControllers = _viewControllers;
@synthesize title = _title;

#pragma mark -

- (id)initWithViewControllers:(NSArray *)viewControllers
{
    return [self initWithViewControllers:viewControllers title:nil];
}

- (id)initWithViewControllers:(NSArray *)viewControllers title:(NSString *)title
{
    if ((self = [super initWithWindowNibName:@"MASPreferencesWindow"]))
    {
        _viewControllers = [viewControllers retain];
        _title = [title copy];
    }
    return self;
}

- (void)dealloc
{
    [[self window] setDelegate:nil];
    
    [_viewControllers release];
    [_title release];
    
    [super dealloc];
}

#pragma mark -

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    // Watch for resigning and closing to commit editing
    [[self window] setDelegate:self];
    
    if ([self.title length] > 0)
        [[self window] setTitle:self.title];
    [self selectControllerAtIndex:0 withAnimation:NO];
}

#pragma mark -
#pragma mark NSWindowDelegate

- (void)commitPreferences
{
    [[self window] makeFirstResponder:[self window]];
}

- (void)windowWillClose:(NSNotification *)notification
{
    [self commitPreferences];
	
	// Post notification that we're going to be dismissed. Lets parent window
	// clear us up instead of auto releasing this, since parent window might
	// be holding us in an object to check if we're already opened
	[[NSNotificationCenter defaultCenter] postNotificationName:kNotifPreferenceWindowDidClose
														object:nil];
	
	// Don't auto release, see above
	// [self autorelease];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    [self commitPreferences];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
//    [self resetFirstResponderInView:[[self window] contentView]];
}

#pragma mark -
#pragma mark Accessors

- (NSArray *)toolbarItemIdentifiers
{
    NSArray *identifiers = [_viewControllers valueForKey:@"toolbarItemIdentifier"];
    return identifiers;
}

#pragma mark -

- (NSUInteger)indexOfSelectedController
{
    NSString *selectedIdentifier = self.window.toolbar.selectedItemIdentifier;
    NSArray *identifiers = self.toolbarItemIdentifiers;
    NSUInteger selectedIndex = [identifiers indexOfObject:selectedIdentifier];
    return selectedIndex;
}

- (NSViewController *)selectedViewController
{
    NSString *selectedIdentifier = self.window.toolbar.selectedItemIdentifier;
    NSArray *identifiers = self.toolbarItemIdentifiers;
    NSUInteger selectedIndex = [identifiers indexOfObject:selectedIdentifier];
    NSViewController *selectedController = nil;
    if (NSLocationInRange(selectedIndex, NSMakeRange(0, self.viewControllers.count)))
        selectedController = [self.viewControllers objectAtIndex:selectedIndex];
    return selectedController;
}

#pragma mark -
#pragma mark NSToolbarDelegate

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    NSArray *identifiers = self.toolbarItemIdentifiers;
    return identifiers;
}                   
                   
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    NSArray *identifiers = self.toolbarItemIdentifiers;
    return identifiers;
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
    NSArray *identifiers = self.toolbarItemIdentifiers;
    return identifiers;
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    NSArray *identifiers = self.toolbarItemIdentifiers;
    NSUInteger controllerIndex = [identifiers indexOfObject:itemIdentifier];
    if (controllerIndex != NSNotFound)
    {
        id <MASPreferencesViewController> controller = [_viewControllers objectAtIndex:controllerIndex];
        toolbarItem.image = controller.toolbarItemImage;
        toolbarItem.label = controller.toolbarItemLabel;
        toolbarItem.target = self;
        toolbarItem.action = @selector(toolbarItemDidClick:);
    }
    return [toolbarItem autorelease];
}

#pragma mark -
#pragma mark Private methods

- (void)clearResponderChain
{
    // Remove view controller from the responder chain
    NSResponder *chainedController = self.window.nextResponder;
    if ([self.viewControllers indexOfObject:chainedController] == NSNotFound)
        return;
    self.window.nextResponder = chainedController.nextResponder;
    chainedController.nextResponder = nil;
}

- (void)patchResponderChain
{
    [self clearResponderChain];
    
    NSViewController *selectedController = self.selectedViewController;
    if (!selectedController)
        return;
    
    // Add current controller to the responder chain
    NSResponder *nextResponder = self.window.nextResponder;
    self.window.nextResponder = selectedController;
    selectedController.nextResponder = nextResponder;
}

#pragma mark -

- (void)updateViewControllerAnimated {
	[self updateViewControllerWithAnimation:YES];
}

- (void)updateViewControllerWithAnimation:(BOOL)animate
{
    // Retrieve currently selected view controller
    NSArray *identifiers = self.toolbarItemIdentifiers;
    NSString *itemIdentifier = self.window.toolbar.selectedItemIdentifier;
    NSUInteger controllerIndex = [identifiers indexOfObject:itemIdentifier];
    if (controllerIndex == NSNotFound) return;
    NSViewController <MASPreferencesViewController> *controller = [_viewControllers objectAtIndex:controllerIndex];
    
    // Retrieve the new window tile from the controller view
    if ([self.title length] == 0)
    {
        NSString *label = controller.toolbarItemLabel;
        self.window.title = label;
    }
    
    // Retrieve the view to place into window
    NSView *controllerView = controller.view;
    
    // Calculate changes for window size and position
    NSSize controllerViewSize = controllerView.bounds.size;
    NSView *contentView = self.window.contentView;
    NSSize contentSize = contentView.bounds.size;
    CGFloat widthChange = contentSize.width - controllerViewSize.width;
    CGFloat heightChange = contentSize.height - controllerViewSize.height;
    
    // Calculate new window size and position
    NSRect windowFrame = self.window.frame;
    windowFrame.size.width -= widthChange;
    windowFrame.size.height -= heightChange;
    windowFrame.origin.y += heightChange;
    
    // Place the view into window and perform reposition
    NSArray *subviews = [contentView.subviews retain];
    for (NSView *subview in contentView.subviews)
        [subview removeFromSuperviewWithoutNeedingDisplay];
    [subviews release];
    [self.window setFrame:windowFrame display:YES animate:animate];
    
    if ([_lastSelectedController respondsToSelector:@selector(viewDidDisappear)])
        [_lastSelectedController viewDidDisappear];
    if ([controller respondsToSelector:@selector(viewWillAppear)])
        [controller viewWillAppear];
    _lastSelectedController = controller;
    
    // Add controller view only after animation is ended to avoid blinking
    if (animate)
        [self performSelector:@selector(setContentViewWithController:) withObject:controller afterDelay:0.0];
    else
        [self performSelector:@selector(setContentViewWithController:) withObject:controller];
    
    // Insert view controller into responder chain
    [self patchResponderChain];
}

- (void)resetFirstResponderInViewController:(NSViewController <MASPreferencesViewController> *)vc {
	id initialFR = [vc initialFirstResponder];
	
	if (initialFR) {
		if ([initialFR canBecomeKeyView]) {
			// We have our own initial FR, return now
			[self.window makeFirstResponder:initialFR];
			return;
		}
	}
	
	[self resetFirstResponderInView:vc.view];
}

- (void)resetFirstResponderInView:(NSView *)view
{
    BOOL isNotButton = ![view isKindOfClass:[NSButton class]];
    BOOL canBecomeKey = view.canBecomeKeyView;
    if (isNotButton && canBecomeKey)
    {
        [self.window makeFirstResponder:view];
    }
    else
    {
        for (NSView *subview in view.subviews)
            [self resetFirstResponderInView:subview];
    }
}

- (void)setContentViewWithController:(NSViewController <MASPreferencesViewController> *)vc
{
    [self.window.contentView addSubview:vc.view];
    [self resetFirstResponderInViewController:vc];
}

- (void)toolbarItemDidClick:(NSToolbarItem*)sender
{
	[self.window.toolbar setSelectedItemIdentifier:sender.itemIdentifier];
	
//    [self updateViewControllerWithAnimation:YES];
	[self performSelector:@selector(updateViewControllerAnimated)
			   withObject:nil
			   afterDelay:0.0];

    [[NSNotificationCenter defaultCenter] postNotificationName:kMASPreferencesWindowControllerDidChangeViewNotification object:self];
}

#pragma mark -
#pragma mark Public methods

- (void)selectControllerAtIndex:(NSUInteger)controllerIndex withAnimation:(BOOL)animate
{
    if (!NSLocationInRange(controllerIndex, NSMakeRange(0, _viewControllers.count)))
        return;

    NSViewController <MASPreferencesViewController> *controller = [_viewControllers objectAtIndex:controllerIndex];
    NSString *newItemIdentifier = controller.toolbarItemIdentifier;
    self.window.toolbar.selectedItemIdentifier = newItemIdentifier;
    [self updateViewControllerWithAnimation:animate];
}

#pragma mark -
#pragma mark Actions

- (IBAction)goNextTab:(id)sender
{
    NSUInteger selectedIndex = self.indexOfSelectedController;
    NSUInteger numberOfControllers = [_viewControllers count];
    selectedIndex = (selectedIndex + 1) % numberOfControllers;
    [self selectControllerAtIndex:selectedIndex withAnimation:YES];
}

- (IBAction)goPreviousTab:(id)sender
{
    NSUInteger selectedIndex = self.indexOfSelectedController;
    NSUInteger numberOfControllers = [_viewControllers count];
    selectedIndex = (selectedIndex + numberOfControllers - 1) % numberOfControllers;
    [self selectControllerAtIndex:selectedIndex withAnimation:YES];
}

@end
