/*
 
 AppController.m
 iPhone App Organizer
 
 Copyright (c) 2009 Jeff Stieler
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must, in all cases, contain attribution of 
 Jeff Stieler as the original author of the source code 
 shall be included in all such resulting software products or distributions.
 3. The name of the author may not be used to endorse or promote products
 derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS"' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 
 */

#import "AppController.h"

#define SCREEN_WIDTH 320
#define SCREEN_HEIGHT 384 // iPhone screen (480) minus dock (96)
#define PAD 10
#define CONTAINER_HEIGHT (SCREEN_HEIGHT + (PAD * 2))
#define SCREEN_X_OFFSET(x) (x * SCREEN_WIDTH) + (PAD * (x + 1))
#define MAX_APP_SCREENS 11

@implementation AppController

@synthesize screenControllers, dockController, numberOfDockApps, numberOfAppsPerRow, numberOfAppsPerScreen;

- (void)setNumberOfAppsPerRow:(int)appsPerRow {
	numberOfAppsPerRow = appsPerRow;
	numberOfAppsPerScreen = (appsPerRow * APPS_PER_COLUMN);
}

- (void)awakeFromNib {
	[self initialSetup];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSBeginInformationalAlertSheet(@"Welcome to Movement!", 
							  @"Ok!", nil, nil, 
							  [self window], 
							  self, 
							  nil, 
							  nil, 
							  nil, 
							  @"Important Usage Instructions:\n\n1. Connect device\n2. Click \"Read Apps\"\n3. Rearrange your apps\n4. Click \"Write Apps\"\n5. Disconnect and restart the device\n6. Quit");
}

- (void)initialSetup {
	self.screenControllers = [[[NSMutableArray alloc] init] autorelease];
	self.dockController = [[[AppScreenController alloc] init] autorelease];
	dockController.apps = [NSMutableArray array];
	dockController.screen = dockView;
	dockController.appController = self;
	[dockController setScreenAttributesAndDelegate:dockController];
	[loadingSheetIndicator setUsesThreadedAnimation:YES];
	[NSApp setDelegate:self];
	[writeAppsButton setEnabled:NO];
}

- (void)dealloc {
	[screenControllers release];
	[dockController release];
	[super dealloc];
}

- (IBAction)addScreen:(id)sender {
	if ([screenControllers count] < MAX_APP_SCREENS) {
		AppScreenController *controller = [[AppScreenController alloc] initWithController:self];
		[screensArrayController addObject:controller];
		[controller release];
	}
}


- (IBAction)removeLastScreen:(id)sender {
	if ([[[screenControllers lastObject] apps] count] == 0) {
		[screensArrayController removeObject:[screenControllers lastObject]];
	}
}

- (void)removeScreenController:(AppScreenController *)aScreenController {
	[screensArrayController removeObject:aScreenController];
}


- (void)reloadScreenAtIndex:(int)screenNum {
	if (screenNum == DOCK) {
		[[dockController screen] reloadData];
	} else if (screenNum < [screenControllers count]) {
		[[[screenControllers objectAtIndex:screenNum] screen] reloadData];
	}
}

- (void)addApp:(iPhoneApp *)anApp toScreen:(int)aScreen {
	if (anApp) {
		// Handle the Dock apps
		if (aScreen == DOCK) {
			[[dockController apps] addObject:anApp];
		} else {
			AppScreenController *screenController = [screenControllers objectAtIndex:aScreen];
			if (!screenController) {
				[self addScreen:nil];
				screenController = [screenControllers objectAtIndex:aScreen];
			}
			[[screenController apps] addObject:anApp];
		}
	}
}


- (void)moveApps:(NSArray *)appsToMove 
   fromScreenNum:(int)fromScreenIdx 
	 toScreenNum:(int)toScreenIdx 
		 atIndex:(int)dragIndex
initialScreenNum:(int)initialScreenIdx
 initialDragApps:(NSArray *)initialDragApps {
	
	NSLog(@"move apps: %@ from screen #%d to #%d at index %d (init screen: %d)", appsToMove, fromScreenIdx, toScreenIdx, dragIndex, initialScreenIdx);
	// Get references to each screen's controller, being mindful of the dock
	AppScreenController *destinationController, *originController;
	
	destinationController = (toScreenIdx == DOCK) ? dockController : [screenControllers objectAtIndex:toScreenIdx];
	originController = (fromScreenIdx == DOCK) ? dockController : [screenControllers objectAtIndex:fromScreenIdx];
	
	// Insert the dragged apps into the destination screen
	NSLog(@"inserting apps: %@ to screen #%d at index %d", appsToMove, toScreenIdx, dragIndex);
	[destinationController insertApps:appsToMove atIndex:dragIndex];
	
	// Remove dragged apps from origin screen
	NSLog(@"removing apps: %@ from screen #%d", appsToMove, fromScreenIdx);
	[originController removeApps:appsToMove];
	
	// Determine how many apps the screen we just inserted into has now
	int destinationScreenAppCount = [[destinationController apps] count];

	// Handle this case: 
	//  we have overflowed all the way back to the initial screen, which happens to be the last
	//  screen. delete the apps that we originally dragged from it, and return - thats it
	if ((toScreenIdx == initialScreenIdx) && 
		((toScreenIdx + 1) == [screenControllers count]) &&
		(destinationScreenAppCount > numberOfAppsPerScreen)) {
		
		NSLog(@"we have overflowed all the way back to the initial screen, which happens to be the last");
		NSLog(@"removing initial apps: %@", initialDragApps);
		[destinationController removeApps:initialDragApps];
		NSLog(@"screen after removal: %@", [destinationController apps]);
		return;
	}
	
	NSLog(@"destination screen app count: %d", destinationScreenAppCount);
	NSLog(@"destination screen apps: %@", [destinationController apps]);
	
	// Handle overflow - doesn't happen for dock
	if ((toScreenIdx != DOCK) && (destinationScreenAppCount > numberOfAppsPerScreen)) {
		// Get all overflowing apps 
		NSMutableArray *overflowingApps = [NSMutableArray array];
		for (int i = numberOfAppsPerScreen; i < destinationScreenAppCount; i++) {
			[overflowingApps addObject:[[destinationController apps] objectAtIndex:i]];
		}
		// Determine new destination screen, create if necessary
		int newDestinationIdx = (toScreenIdx + 1);
		if ((newDestinationIdx + 1) > [screenControllers count]) {
			NSLog(@"adding a screen!");
			[self addScreen:nil];
		}
		
		// Move overflowing apps to the next screen
		[self moveApps:overflowingApps 
		 fromScreenNum:toScreenIdx 
		   toScreenNum:newDestinationIdx 
			   atIndex:0 
	  initialScreenNum:initialScreenIdx
	   initialDragApps:initialDragApps];
		
	}
	
}

- (IBAction)readAppsFromSpringBoard:(id)sender {
	[loadingSheetLabel setStringValue:@"Reading apps from device..."];
	[NSApp beginSheet:loadingSheet
	   modalForWindow:[self window]
		modalDelegate:self  
	   didEndSelector:nil 
		  contextInfo:nil];
	[loadingSheetIndicator startAnimation:self];
	[phoneController readAppsFromSpringboard];
	[loadingSheetIndicator stopAnimation:self];
	[NSApp endSheet:loadingSheet];
	[loadingSheet orderOut:nil];
	[writeAppsButton setEnabled:YES];
}

- (IBAction)promptWriteAppsToSpringboard:(id)sender {
	// First, prompt the user to backup their existing springboard plist
	NSBeginCriticalAlertSheet(@"Do you want to make a backup of your springboard?", 
							  @"Yes!", @"No, I'm reckless", nil, 
							  [self window], 
							  self, 
							  @selector(sheetDidEndShouldBackup:returnCode:contextInfo:), 
							  nil, 
							  nil, 
							  @"You really should backup your springboard. This is beta software!");
}


# pragma mark -
# pragma mark Sheet methods
- (void)sheetDidEndShouldBackup: (NSWindow *)sheet
					 returnCode: (NSInteger)returnCode
					contextInfo: (void *)contextInfo
{
    
	if (returnCode == NSAlertDefaultReturn) {
		NSSavePanel *savePanel = [NSSavePanel savePanel];
		
		int result = [savePanel runModalForDirectory:nil file:@"springboard.plist"];
		
		if (result == NSOKButton) {
			[phoneController backupSpringBoardToFilePath:[savePanel filename]];
		}
	}
	[phoneController writeAppsToSpringBoard];
	[sheet orderOut:nil];
	NSSound *completeSound = [NSSound soundNamed:@"Glass"];
	
	NSBeginCriticalAlertSheet(@"Movement Complete", 
							  @"Ok!", nil, nil, 
							  [self window], 
							  self, 
							  nil, 
							  nil, 
							  nil, 
							  @"\nThank you for using Movement!\n\nRestart your device for changes to take effect.");
	[completeSound play];
}

@end
