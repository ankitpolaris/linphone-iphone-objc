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

#import <UIKit/UIKit.h>
#import "TPMultiLayoutViewController.h"
#import "UIBouncingView.h"

@interface TabBarView : TPMultiLayoutViewController {
}

@property(nonatomic, strong) IBOutlet UIButton *historyButton;
@property(nonatomic, strong) IBOutlet UIButton *contactsButton;
@property(nonatomic, strong) IBOutlet UIButton *dialerButton;
@property(nonatomic, strong) IBOutlet UIButton *chatButton;
@property (weak, nonatomic) IBOutlet UILabel *historyBtnLabel;
@property (weak, nonatomic) IBOutlet UILabel *contactBtnLabel;
@property (weak, nonatomic) IBOutlet UILabel *dialerBtnLabel;
@property (weak, nonatomic) IBOutlet UILabel *chatBtnLabel;

@property(nonatomic, strong) IBOutlet UIBouncingView *historyNotificationView;
@property(nonatomic, strong) IBOutlet UIBouncingView *chatNotificationView;
@property(nonatomic, strong) IBOutlet UILabel *chatNotificationLabel;
@property(nonatomic, strong) IBOutlet UILabel *historyNotificationLabel;
@property(weak, nonatomic) IBOutlet UIImageView *selectedButtonImage;

- (void)update:(BOOL)appear;

- (IBAction)onHistoryClick:(id)event;
- (IBAction)onContactsClick:(id)event;
- (IBAction)onDialerClick:(id)event;
- (IBAction)onChatClick:(id)event;

@end
