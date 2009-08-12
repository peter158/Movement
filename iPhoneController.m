/*
 
 iPhoneController.m
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

#import "iPhoneController.h"
#import "AFCFactory.h"
#import "PNG Fixer.h"

#define APP_DIR @"/Applications/"
#define USER_APP_DIR @"/User/Applications/"
#define SPRINGBOARD_PLIST @"/User/Library/Preferences/com.apple.springboard.plist"

@implementation iPhoneController

@synthesize possibleIconFileKeys, possibleAppDisplayNameKeys, officialAppDisplayNames, springboard;

- (void)awakeFromNib {
	[[AFCFactory factory] setDelegate:self];
	
	// Grab official app display name, possible icon/app display name keys from
	// their respective plists in the main bundle
	possibleIconFileKeys = (NSArray *)[self contentsOfPlist:@"PossibleIconFileKeys"];
	possibleAppDisplayNameKeys = (NSArray *)[self contentsOfPlist:@"PossibleAppDisplayNameKeys"];
	officialAppDisplayNames = (NSDictionary *)[self contentsOfPlist:@"OfficialAppDisplayNames"];
}


#pragma mark -
#pragma mark iPhone utilities

// Retreive ALL apps (and their paths) on the connected iPhone (user && apple)
- (NSDictionary *)allAppPathsOnDevice {
	if (iPhone) {
		
		NSMutableDictionary *allApps = [[NSMutableDictionary alloc] initWithCapacity:2];
		
		// "Official" apps are in /Applications/<app name>.app/
		[allApps setObject:[iPhone listOfFoldersAtPath:APP_DIR] forKey:APP_DIR];
		NSRange isDotApp;
		NSMutableArray *userApps = [[NSMutableArray alloc] init];
		
		// "Third Party" apps are in /User/Applications/<crazy hash>/<app name>.app/
		for (NSString *folder in [iPhone listOfFoldersAtPath:USER_APP_DIR]) {
			NSString *appPath = [NSString pathWithComponents:[NSArray arrayWithObjects:USER_APP_DIR, folder, nil]];
			for (NSString *subFolder in [iPhone listOfFoldersAtPath:appPath]) {
				isDotApp = [subFolder rangeOfString:@".app"];
				if (isDotApp.location != NSNotFound) {
					[userApps addObject:[NSString pathWithComponents:[NSArray arrayWithObjects:folder, subFolder, nil]]];
				}
			}
		}
		
		[allApps setObject:(NSArray *)userApps forKey:USER_APP_DIR];
		return [(NSDictionary *)allApps autorelease];
	}
	return nil;
}

- (void)processAppsFromSpringboard {
	NSArray *iconLists = [[[self springboard] objectForKey:@"iconState"] objectForKey:@"iconLists"];
	NSMutableDictionary *apps = [[NSMutableDictionary alloc] init];
	NSDictionary *allAppPaths = [self allAppPathsOnDevice];

	for (NSString *basePath in allAppPaths) {
		for (NSString *appPath in [allAppPaths objectForKey:basePath]) {
			NSString *fullAppPath = [basePath stringByAppendingString:appPath];
			//NSLog(@"%@", fullAppPath);
			NSDictionary *appPlist = [self plistContentsForApp:fullAppPath];
			//NSLog(@"%@", appPlist);
			NSData *appIcon = [self iconForApp:fullAppPath plistContents:appPlist];
			//NSLog(@"%@", appIcon);
			NSString *appIdentifer = [appPlist valueForKey:@"CFBundleIdentifier"];
			NSString *appDisplayName = [self displayNameForApp:fullAppPath plistContents:appPlist];
			iPhoneApp *app = [[iPhoneApp alloc] initWithIdentifier:appIdentifer displayName:appDisplayName icon:appIcon];
			[apps setObject:app forKey:appIdentifer];
		}
	}
	NSLog(@"%@", apps);
	/*for (int screenNum = 0; screenNum < [iconLists count]; screenNum++) {
		
		// Add a screen to the AppController
		[appController addScreen:nil];
		
		NSArray *screenRows = [[iconLists objectAtIndex:screenNum] objectForKey:@"iconMatrix"];
		NSNumber *screenNSNum = [NSNumber numberWithInt:screenNum];
		
		for (int rowNum = 0; rowNum < [screenRows count]; rowNum++) {
			NSArray *row = [screenRows objectAtIndex:rowNum];
			for (int appNum = 0; appNum < [row count]; appNum++) {
				id app = [row objectAtIndex:appNum];
				if ([app isKindOfClass:[NSDictionary class]]) {
					NSNumber *appPosition = [NSNumber numberWithInt:((rowNum * 4) + appNum)];
					NSDictionary *appDict = [NSDictionary dictionaryWithObjectsAndKeys:
											 screenNSNum, @"screen", appPosition, @"position", nil];
					[appPositions setObject:appDict forKey:[app valueForKey:@"displayIdentifier"]];
				}				
			}
		}
		NSLog(@"%@", appPositions);
		
	}*/
}

- (NSDictionary *)plistContentsForApp:(NSString *)appPath {
	NSString *plistPath;
	NSArray *possibleInfoFiles = [NSArray arrayWithObjects:@"/Info.plist", @"/info.plist", nil];
	for (NSString *possibleFile in possibleInfoFiles) {
		NSString *path = [appPath stringByAppendingPathComponent:possibleFile];
		if ([[iPhone deviceInterface] isFileAtPath:path]) {
			plistPath = path;
		}
	}
	NSData *plist = [iPhone contentsOfFileAtPath:plistPath];
	return [NSPropertyListSerialization propertyListFromData:plist 
											mutabilityOption:NSPropertyListImmutable
													  format:nil
											errorDescription:nil];
}

- (NSData *)iconForApp:(NSString *)appPath plistContents:(NSDictionary *)plistContents {
	NSArray *possibleIconFiles = [NSArray arrayWithObjects:@"Icon.png", @"Icon-Small.png", @"icon.png", nil];
	NSString *appIconPath = [plistContents valueForKey:@"CFBundleIconFile"];
	if (!appIconPath) {
		for (NSString *iconPath in possibleIconFiles) {
			NSString *possibleIconPath = [appPath stringByAppendingPathComponent:iconPath];
			if ([[iPhone deviceInterface] isFileAtPath:possibleIconPath]) {
				appIconPath = iconPath;
				break;
			}
		}
	}
	appIconPath = [appPath stringByAppendingPathComponent:appIconPath];
	return [PNGFixer fixPNG:[iPhone contentsOfFileAtPath:appIconPath]];
}
			
- (NSString *)displayNameForApp:(NSString *)appPath plistContents:(NSDictionary *)plistContents {
	for (NSString *key in possibleAppDisplayNameKeys) {
		NSString *displayName = [plistContents valueForKey:key];
		if (displayName) {
			if ([officialAppDisplayNames valueForKey:displayName]) {
				displayName = [officialAppDisplayNames valueForKey:displayName];
			}
			return displayName;
		}
	}
	return nil;
}


#pragma mark -
#pragma mark Plist content retrieval helpers

- (id)contentsOfPlist:(NSString *)plistName {
	return [[NSPropertyListSerialization
				propertyListFromData:
					[NSData dataWithContentsOfFile:
						[[NSBundle mainBundle]
							pathForResource:plistName
							ofType:@"plist"]]
				mutabilityOption:NSPropertyListImmutable
				format:nil
				errorDescription:nil] retain];
}

// Retreive the SpringBoard plist file
- (NSMutableDictionary *)springboardFromPhone {
	if (iPhone) {
		
		NSData *sbData = [iPhone contentsOfFileAtPath:SPRINGBOARD_PLIST];
		return (NSMutableDictionary *)[NSPropertyListSerialization
										propertyListFromData:sbData
										mutabilityOption:NSPropertyListMutableContainersAndLeaves
										format:nil errorDescription:nil];
	}
	return nil;
}


#pragma mark -
#pragma mark AFC Factory Delegates

-(void)AFCDeviceWasConnected:(AFCDeviceRef *)dev {
	
	// This is where the action happens - the factory has
	// detected a new iPhone/iPod touch.
	if (iPhone) {
		
		if ([[[iPhone device] serialNumber] isEqualToString:[dev serialNumber]]) {
			
			// When the same device is reconnected, it seems to have 
			// a different device_id. Therefore, inform our instance 
			// that it's been changed.
			[iPhone setDeviceRef:dev andService:kRootAFC];

			return;
		} 
		
	}
	
	// If it isn't the same device as the previous one, make a new device. 
	[iPhone release];
	iPhone = nil;
	iPhone = [[AFCDevice alloc] initWithRef:dev andService:kRootAFC];
	
	if (!iPhone) {
		[NSException raise:@"iPhoneController" format:@"Error occurred when trying to init AFC device."];
		
	} else {
		NSLog(@"Device connected, ID: %d, SN: %@", [[iPhone device] deviceID], [[iPhone device] serialNumber]);
		[iPhone setDelegate:self];
		self.springboard = [self springboardFromPhone];
	}
	
}

@end