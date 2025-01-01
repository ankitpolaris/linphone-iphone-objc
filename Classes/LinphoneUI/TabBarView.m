/*
 * Copyright (c) 2010-2020 Belledonne Communications SARL.
 *
 * This file is part of linphone-iphone
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#import "TabBarView.h"
#import "PhoneMainView.h"
#import "linphoneapp-Swift.h"

@implementation TabBarView

#pragma mark - ViewController Functions

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
    [_dialerButton setAdjustsImageWhenHighlighted:NO];
    [_contactsButton setAdjustsImageWhenHighlighted:NO];
	[NSNotificationCenter.defaultCenter addObserver:self
										   selector:@selector(changeViewEvent:)
											   name:kLinphoneMainViewChange
											 object:nil];
	[NSNotificationCenter.defaultCenter addObserver:self
										   selector:@selector(callUpdate:)
											   name:kLinphoneCallUpdate
											 object:nil];
	[NSNotificationCenter.defaultCenter addObserver:self
										   selector:@selector(messageReceived:)
											   name:kLinphoneMessageReceived
											 object:nil];
    [self updateTabColorsForIndex:2];
	[self update:FALSE];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	[self update:FALSE];
}

#pragma mark - Event Functions

- (void)callUpdate:(NSNotification *)notif {
	// LinphoneCall *call = [[notif.userInfo objectForKey: @"call"] pointerValue];
	// LinphoneCallState state = [[notif.userInfo objectForKey: @"state"] intValue];
	[self updateMissedCall:linphone_core_get_missed_calls_count(LC) appear:TRUE];
}

- (void)changeViewEvent:(NSNotification *)notif {
	UICompositeViewDescription *view = [notif.userInfo objectForKey:@"view"];
	if (view != nil) {
		[self updateSelectedButton:view];
	}
}

- (void)messageReceived:(NSNotification *)notif {
	[self updateUnreadMessage:TRUE];
}

#pragma mark - UI Update

- (void)update:(BOOL)appear {
	[self updateSelectedButton:[PhoneMainView.instance currentView]];
	[self updateMissedCall:linphone_core_get_missed_calls_count(LC) appear:appear];
	if (![LinphoneManager.instance lpConfigBoolForKey:@"disable_chat_feature"]) {
		[self updateUnreadMessage:appear];
	}
}

- (void)updateUnreadMessage:(BOOL)appear {
	int unreadMessage = [LinphoneManager unreadMessageCount];
	if (![LinphoneManager.instance lpConfigBoolForKey:@"disable_chat_feature"]) {
		if (unreadMessage > 0) {
			_chatNotificationLabel.text = [NSString stringWithFormat:@"%i", unreadMessage];
			[_chatNotificationView startAnimating:appear];
		} else {
			[_chatNotificationView stopAnimating:appear];
		}
	}
}

- (void)updateMissedCall:(int)missedCall appear:(BOOL)appear {
	if (missedCall > 0) {
		_historyNotificationLabel.text = [NSString stringWithFormat:@"%i", missedCall];
		[_historyNotificationView startAnimating:appear];
	} else {
		[_historyNotificationView stopAnimating:appear];
	}
}

- (void)updateTabColorsForIndex:(NSInteger)selectedIndex {
    NSArray<UIButton *> *buttons = @[self.historyButton, self.contactsButton, self.dialerButton, self.chatButton];
    NSArray<UILabel *> *labels = @[self.historyBtnLabel, self.contactBtnLabel, self.dialerBtnLabel, self.chatBtnLabel];
    
    UIColor *selectedColor = [UIColor systemBlueColor]; // Highlighted color
    UIColor *defaultColor = [UIColor colorWithRed:162/255.0 green:162/255.0 blue:162/255.0 alpha:1.0];

    
    for (NSInteger i = 0; i < buttons.count; i++) {
        UIButton *button = buttons[i];
        UILabel *label = labels[i];
        
        if (i == selectedIndex) {
            // Highlight the selected button and label
            [button setTitleColor:selectedColor forState:UIControlStateNormal];
            
            // If the button has an image, update its rendering mode and tint
            UIImage *buttonImage = [button imageForState:UIControlStateNormal];
            if (buttonImage) {
                UIImage *coloredImage = [buttonImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                [button setImage:coloredImage forState:UIControlStateNormal];
                button.tintColor = selectedColor;
            }
            
            label.textColor = selectedColor;
        }
        else {
            // Set others to default gray
            [button setTitleColor:defaultColor forState:UIControlStateNormal];
            
            // Reset image rendering mode and tint
            UIImage *buttonImage = [button imageForState:UIControlStateNormal];
            if (buttonImage) {
                UIImage *coloredImage = [buttonImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                [button setImage:coloredImage forState:UIControlStateNormal];
                button.tintColor = defaultColor;
            }
            
            label.textColor = defaultColor;
        }
        
        
//        if (i == selectedIndex) {
//            // Highlight the selected button and label
//            button.tintColor = selectedColor;
//            label.textColor = selectedColor;
//        } else {
//            // Set others to default gray
//            button.tintColor = defaultColor;
//            label.textColor = defaultColor;
//        }
    }
}

- (void)updateSelectedButton:(UICompositeViewDescription *)view {
	_historyButton.selected = [view equal:HistoryListView.compositeViewDescription] ||
							  [view equal:HistoryDetailsView.compositeViewDescription] ||
							  [view equal:ConferenceHistoryDetailsView.compositeViewDescription];
//	_contactsButton.selected = [view equal:ContactsListView.compositeViewDescription] ||
//							   [view equal:ContactDetailsView.compositeViewDescription];
	_dialerButton.selected = [view equal:DialerView.compositeViewDescription];
	_chatButton.selected = [view equal:ChatsListView.compositeViewDescription] ||
						   [view equal:ChatConversationCreateView.compositeViewDescription] ||
						   [view equal:ChatConversationInfoView.compositeViewDescription] ||
						   [view equal:ChatConversationImdnView.compositeViewDescription] ||
	[view equal:ChatConversationViewSwift.compositeViewDescription];
	if ([LinphoneManager.instance lpConfigBoolForKey:@"disable_chat_feature"] && [self viewIsCurrentlyPortrait]) {
		CGFloat itemWidth = [UIScreen mainScreen].bounds.size.width/3;
		[_chatButton setEnabled:false];
		[_chatButton setHidden:true];
		[_chatNotificationView setHidden:true];
		_historyButton.frame = CGRectMake(0, 0, itemWidth, 66);
		_contactsButton.frame = CGRectMake(itemWidth, 0, itemWidth, 66);
		_dialerButton.frame = CGRectMake(itemWidth*2, 0, itemWidth, 66);
		_selectedButtonImage.frame = CGRectMake(_selectedButtonImage.frame.origin.x, _selectedButtonImage.frame.origin.y, itemWidth, 3);
	} else if ([LinphoneManager.instance lpConfigBoolForKey:@"disable_chat_feature"] && ![self viewIsCurrentlyPortrait]) {
		[_chatButton setEnabled:false];
		[_chatButton setHidden:true];
		[_chatNotificationView setHidden:true];
		_historyButton.frame = CGRectMake(0, 20, 90, 90);
		_contactsButton.frame = CGRectMake(0, 120, 90, 90);
		_dialerButton.frame = CGRectMake(0, 220, 90, 90);
		_selectedButtonImage.frame = CGRectMake(_selectedButtonImage.frame.origin.x, _selectedButtonImage.frame.origin.y, 3, 90);
	}
	CGRect selectedNewFrame = _selectedButtonImage.frame;
	if ([self viewIsCurrentlyPortrait]) {
		selectedNewFrame.origin.x =
			(_historyButton.selected
				 ? _historyButton.frame.origin.x
				 : (_contactsButton.selected
						? _contactsButton.frame.origin.x
						: (_dialerButton.selected
							   ? _dialerButton.frame.origin.x
							   : (_chatButton.selected
									  ? _chatButton.frame.origin.x
									  : -selectedNewFrame.size.width /*hide it if none is selected*/))));
	} else {
		selectedNewFrame.origin.y =
			(_historyButton.selected
				 ? _historyButton.frame.origin.y
				 : (_contactsButton.selected
						? _contactsButton.frame.origin.y
						: (_dialerButton.selected
							   ? _dialerButton.frame.origin.y
							   : (_chatButton.selected
									  ? _chatButton.frame.origin.y
									  : -selectedNewFrame.size.height /*hide it if none is selected*/))));
	}

	CGFloat delay = ANIMATED ? 0.3 : 0;
	[UIView animateWithDuration:delay
					 animations:^{
					   _selectedButtonImage.frame = selectedNewFrame;

					 }];
}

#pragma mark - Action Functions

- (IBAction)onHistoryClick:(id)event {
	linphone_core_reset_missed_calls_count(LC);
	[self update:FALSE];
    [self updateTabColorsForIndex:0];
	[PhoneMainView.instance updateApplicationBadgeNumber];
	[PhoneMainView.instance changeCurrentView:HistoryListView.compositeViewDescription];
}

- (IBAction)onContactsClick:(id)event {
	[ContactSelection setAddAddress:nil];
    [self updateTabColorsForIndex:1];
	[PhoneMainView.instance changeCurrentView:ContactsListView.compositeViewDescription];
}

- (IBAction)onDialerClick:(id)event {
    [self updateTabColorsForIndex:2];
	[PhoneMainView.instance changeCurrentView:DialerView.compositeViewDescription];
}

- (IBAction)onSettingsClick:(id)event {
	[PhoneMainView.instance changeCurrentView:SettingsView.compositeViewDescription];
}

- (IBAction)onChatClick:(id)event {
    [self updateTabColorsForIndex:3];
	[PhoneMainView.instance changeCurrentView:ChatsListView.compositeViewDescription];
}

@end
