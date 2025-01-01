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

#import "StatusBarView.h"
#import "LinphoneManager.h"
#import "PhoneMainView.h"
#import <UserNotifications/UserNotifications.h>
#import "linphoneapp-Swift.h"

@implementation StatusBarView {

	NSTimer *callQualityTimer;
	NSTimer *callSecurityTimer;
	int messagesUnreadCount;
}

#pragma mark - Lifecycle Functions

- (void)dealloc {
	[NSNotificationCenter.defaultCenter removeObserver:self];
	[callQualityTimer invalidate];
}

#pragma mark - ViewController Functions

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];

	// Set observer
	[NSNotificationCenter.defaultCenter addObserver:self
										   selector:@selector(registrationUpdate:)
											   name:kLinphoneRegistrationUpdate
											 object:nil];

	[NSNotificationCenter.defaultCenter addObserver:self
										   selector:@selector(globalStateUpdate:)
											   name:kLinphoneGlobalStateUpdate
											 object:nil];

	[NSNotificationCenter.defaultCenter addObserver:self
										   selector:@selector(notifyReceived:)
											   name:kLinphoneNotifyReceived
											 object:nil];
	[NSNotificationCenter.defaultCenter addObserver:self
										   selector:@selector(mainViewChanged:)
											   name:kLinphoneMainViewChange
											 object:nil];

	[NSNotificationCenter.defaultCenter addObserver:self
										   selector:@selector(callUpdate:)
											   name:kLinphoneCallUpdate
											 object:nil];
	[NSNotificationCenter.defaultCenter addObserver:self
										   selector:@selector(onCallEncryptionChanged:)
											   name:kLinphoneCallEncryptionChanged
											 object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleUpdateCardViewColorNotification:)
                                                 name:@"UpdateCardViewColorNotification"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleUpdateCardViewHideNotification:)
                                                 name:@"UpdateCardViewHideNotification"
                                               object:nil];
    

	// Update to default state
	LinphoneAccount *account = linphone_core_get_default_account(LC);
	messagesUnreadCount = linphone_config_get_int(linphone_core_get_config(LC), "app", "voice_mail_messages_count", 0);

	[self accountUpdate:account];
	[self updateUI:linphone_core_get_calls_nb(LC)];
	[self updateVoicemail];
    // Set corner radius for titleContainerView
    self.titleContainerView.layer.cornerRadius = 14.0;
    self.titleContainerView.layer.masksToBounds = YES;
    UIColor *myColor = [StatusBarView colorWithHex:@"#FF4444"];
    self.titleContainerView.layer.borderColor = myColor.CGColor;
    self.titleContainerView.layer.borderWidth = 1.5;
    
    /*if (@available(iOS 15.0, *)) {
		[LocalPushManager.shared addActiveCallBackObserverWithAction:^(BOOL active) {
			_localpushIndicator.hidden = !active;
		}];
	} else {
		_localpushIndicator.hidden = true;
	}*/
	
	
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];

	// Remove observer
	[NSNotificationCenter.defaultCenter removeObserver:self name:kLinphoneRegistrationUpdate object:nil];
	[NSNotificationCenter.defaultCenter removeObserver:self name:kLinphoneGlobalStateUpdate object:nil];
	[NSNotificationCenter.defaultCenter removeObserver:self name:kLinphoneNotifyReceived object:nil];
	[NSNotificationCenter.defaultCenter removeObserver:self name:kLinphoneCallUpdate object:nil];
	[NSNotificationCenter.defaultCenter removeObserver:self name:kLinphoneMainViewChange object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:@"UpdateCardViewColorNotification" object:nil];
    
	if (callQualityTimer != nil) {
		[callQualityTimer invalidate];
		callQualityTimer = nil;
	}
	if (callSecurityTimer != nil) {
		[callSecurityTimer invalidate];
		callSecurityTimer = nil;
	}

	if (securityDialog != nil) {
		[securityDialog dismiss];
		securityDialog = nil;
	}
}

-(void)updateCardViewColor:(BOOL)isGray {
    if (isGray) {
    
//        self.cardView.backgroundColor = [UIColor colorWithRed:242.0/255.0 green:242.0/255.0 blue:247.0/255.0 alpha:1.0];
        self.cardView.backgroundColor = [[UIColor secondarySystemBackgroundColor] colorWithAlphaComponent:1.0];
    } else {
        self.cardView.backgroundColor = [UIColor whiteColor];
    }
}

+ (UIColor *)colorWithHex:(NSString *)hexString {
    // Remove '#' if it exists
    NSString *colorString = [hexString stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"#"]];
    
    // Make sure the string is 6 or 8 characters long
    if ([colorString length] == 6 || [colorString length] == 8) {
        // Extract the RGB values
        unsigned int hexValue;
        [[NSScanner scannerWithString:colorString] scanHexInt:&hexValue];
        
        // Extract RGB values from hexValue
        CGFloat red   = ((hexValue >> 16) & 0xFF) / 255.0;
        CGFloat green = ((hexValue >> 8) & 0xFF) / 255.0;
        CGFloat blue  = (hexValue & 0xFF) / 255.0;
        
        // If the string contains an alpha value, handle it
        CGFloat alpha = 1.0;
        if ([colorString length] == 8) {
            alpha = ((hexValue >> 24) & 0xFF) / 255.0;
        }
        
        return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
    }
    
    return [UIColor blackColor]; // Return black color if invalid hex
}

#pragma mark - Event Functions

- (void)registrationUpdate:(NSNotification *)notif {
	LinphoneAccount *account = linphone_core_get_default_account(LC);
	[self accountUpdate:account];
}

- (void)globalStateUpdate:(NSNotification *)notif {
	[self registrationUpdate:nil];
}

- (void)mainViewChanged:(NSNotification *)notif {
	[self registrationUpdate:nil];
}

- (void)handleUpdateCardViewColorNotification:(NSNotification *)notif {
    BOOL isGray = [notif.userInfo[@"isGray"] boolValue];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateCardViewColor:isGray];
    });
}

- (void)handleUpdateCardViewHideNotification:(NSNotification *)notif {
    BOOL isHidden = [notif.userInfo[@"isHidden"] boolValue];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (isHidden) {
            [self.cardView setHidden:YES];
        } else {
            [self.cardView setHidden:NO];
        }
    });
}

- (void)onCallEncryptionChanged:(NSNotification *)notif {
	LinphoneCall *call = linphone_core_get_current_call(LC);

	if (call && (linphone_call_params_get_media_encryption(linphone_call_get_current_params(call)) ==
				 LinphoneMediaEncryptionZRTP) &&
		(!linphone_call_get_authentication_token_verified(call))) {
		[self onSecurityClick:nil];
	}
}

- (void)notifyReceived:(NSNotification *)notif {
	const LinphoneContent *content = [[notif.userInfo objectForKey:@"content"] pointerValue];

	if ((content == NULL) || (strcmp("application", linphone_content_get_type(content)) != 0) ||
		(strcmp("simple-message-summary", linphone_content_get_subtype(content)) != 0) ||
		(linphone_content_get_buffer(content) == NULL)) {
		return;
	}
	const uint8_t *bodyTmp = linphone_content_get_buffer(content);
	const char *body = (const char *)bodyTmp;
	if ((body = strstr(body, "voice-message: ")) == NULL) {
		LOGW(@"Received new NOTIFY from voice mail but could not find 'voice-message' in BODY. Ignoring it.");
		return;
	}

	sscanf((const char *)body, "voice-message: %d", &messagesUnreadCount);

	LOGI(@"Received new NOTIFY from voice mail: there is/are now %d message(s) unread", messagesUnreadCount);

	// save in lpconfig for future
	linphone_config_set_int(linphone_core_get_config(LC), "app", "voice_mail_messages_count", messagesUnreadCount);

	[self updateVoicemail];
}

- (void)updateVoicemail {
	_voicemailButton.hidden = (messagesUnreadCount <= 0);
	_voicemailButton.titleLabel.text = @(messagesUnreadCount).stringValue;
}

- (void)callUpdate:(NSNotification *)notif {
	// show voice mail only when there is no call
	[self updateUI:linphone_core_get_calls(LC) != NULL];
	[self updateVoicemail];
}

#pragma mark -

+ (UIImage *)imageForState:(LinphoneRegistrationState)state {
	switch (state) {
		case LinphoneRegistrationFailed:
			return [UIImage imageNamed:@"led_error.png"];
		case LinphoneRegistrationCleared:
		case LinphoneRegistrationNone:
			return [UIImage imageNamed:@"bulb_disconnected.pdf"];
		case LinphoneRegistrationProgress:
		case LinphoneRegistrationRefreshing:
			return [UIImage imageNamed:@"led_inprogress.png"];
		case LinphoneRegistrationOk:
			return [UIImage imageNamed:@"bulb_connected.pdf"];
	}
}
- (void)accountUpdate:(LinphoneAccount *)account {
	LinphoneRegistrationState state = LinphoneRegistrationNone;
	NSString *message = nil;
	LinphoneGlobalState gstate = linphone_core_get_global_state(LC);
    int currentState = 0;
	if ([PhoneMainView.instance.currentView equal:AssistantView.compositeViewDescription] || [PhoneMainView.instance.currentView equal:CountryListView.compositeViewDescription]) {
        currentState = 2;
		message = NSLocalizedString(@"Configuring account", nil);
	} else if (gstate == LinphoneGlobalOn && !linphone_core_is_network_reachable(LC)) {
        currentState = 1;
		message = NSLocalizedString(@"Network down", nil);
	} else if (gstate == LinphoneGlobalConfiguring) {
        currentState = 2;
		message = NSLocalizedString(@"Fetching remote configuration", nil);
	} else if (account == NULL) {
		state = LinphoneRegistrationNone;
		MSList *accounts = [LinphoneManager.instance createAccountsNotHiddenList];
		if (accounts != NULL) {
            currentState = 1;
			message = NSLocalizedString(@"No default account", nil);
		} else {
            currentState = 2;
			message = NSLocalizedString(@"No account configured", nil);
		}
		bctbx_free(accounts);

	} else {
		state = linphone_account_get_state(account);

		switch (state) {
			case LinphoneRegistrationOk:
                currentState = 0;
				message = NSLocalizedString(@"Connected", nil);
				break;
			case LinphoneRegistrationNone:
			case LinphoneRegistrationCleared:
                currentState = 1;
				message = NSLocalizedString(@"Not connected", nil);
				break;
			case LinphoneRegistrationFailed:
                currentState = 1;
				message = NSLocalizedString(@"Connection failed", nil);
				break;
			case LinphoneRegistrationProgress:
                currentState = 2;
				message = NSLocalizedString(@"Connection in progress", nil);
				break;
			default:
				break;
		}
	}
	[_registrationState setTitle:message forState:UIControlStateNormal];
	_registrationState.accessibilityValue = message;
//	[_registrationState setImage:[self.class imageForState:state] forState:UIControlStateNormal];
    UIImage *statusImage = [self.class imageForState:state];
    _titleImageView.image = statusImage;
    
    if (currentState == 0) {
        self.titleContainerView.layer.borderColor = [UIColor systemGreenColor].CGColor;
    }
    else if (currentState == 2) {
        self.titleContainerView.layer.borderColor = [UIColor systemOrangeColor].CGColor;
    }
    else {
        UIColor *myColor = [StatusBarView colorWithHex:@"#FF4444"];
        self.titleContainerView.layer.borderColor = myColor.CGColor;
    }
}

#pragma mark -

- (void)updateUI:(BOOL)inCall {
	BOOL hasChanged = (_outcallView.hidden != inCall);

	_outcallView.hidden = inCall;
	_incallView.hidden = !inCall;

	if (!hasChanged)
		return;

	if (callQualityTimer) {
		[callQualityTimer invalidate];
		callQualityTimer = nil;
	}
	if (callSecurityTimer) {
		[callSecurityTimer invalidate];
		callSecurityTimer = nil;
	}
	if (securityDialog) {
		[securityDialog dismiss];
	}

	// if we are in call, we have to update quality and security icons every sec
	if (inCall) {
		callQualityTimer = [NSTimer scheduledTimerWithTimeInterval:1
															target:self
														  selector:@selector(callQualityUpdate)
														  userInfo:nil
														   repeats:YES];
		callSecurityTimer = [NSTimer scheduledTimerWithTimeInterval:1
															 target:self
														   selector:@selector(callSecurityUpdate)
														   userInfo:nil
															repeats:YES];
	}
}

- (void)callSecurityUpdate {
	BOOL pending = false;
	BOOL security = true;

	const MSList *list = linphone_core_get_calls(LC);
	if (list == NULL) {
		if (securityDialog) {
			[securityDialog dismiss];
		}
	} else {
		_callSecurityButton.hidden = NO;
		while (list != NULL) {
			LinphoneCall *call = (LinphoneCall *)list->data;
			LinphoneMediaEncryption enc =
				linphone_call_params_get_media_encryption(linphone_call_get_current_params(call));
			if (enc == LinphoneMediaEncryptionNone)
				security = false;
			else if (enc == LinphoneMediaEncryptionZRTP) {
				if (!linphone_call_get_authentication_token_verified(call)) {
					pending = true;
				}
			}
			list = list->next;
		}
		NSString *imageName =
			(security ? (pending ? @"security_pending.png" : @"security_ok.png") : @"security_ko.png");
		[_callSecurityButton setImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
	}
}

- (void)callQualityUpdate {
	LinphoneCall *call = linphone_core_get_current_call(LC);
	if (call != NULL) {
		int quality = MIN(4, floor(linphone_call_get_current_quality(call)));
		NSString *accessibilityValue = [NSString stringWithFormat:NSLocalizedString(@"Call quality: %d", nil), quality];
		if (![accessibilityValue isEqualToString:_callQualityButton.accessibilityValue]) {
			_callQualityButton.accessibilityValue = accessibilityValue;
			_callQualityButton.hidden = NO; //(quality == -1.f);
			UIImage *image =
				(quality == -1.f)
					? [UIImage imageNamed:@"call_quality_indicator_0.png"] // nil
					: [UIImage imageNamed:[NSString stringWithFormat:@"call_quality_indicator_%d.png", quality]];
			[_callQualityButton setImage:image forState:UIControlStateNormal];
		}
	}
}

#pragma mark - Action Functions

- (IBAction)onSecurityClick:(id)sender {
	if (linphone_core_get_calls_nb(LC)) {
		LinphoneCall *call = linphone_core_get_current_call(LC);
		if (call != NULL) {
			LinphoneMediaEncryption enc =
				linphone_call_params_get_media_encryption(linphone_call_get_current_params(call));
			if (enc == LinphoneMediaEncryptionZRTP) {
				NSString *code = [NSString stringWithUTF8String:linphone_call_get_authentication_token(call)];
				NSString *myCode;
				NSString *correspondantCode;
				if (linphone_call_get_dir(call) == LinphoneCallIncoming) {
					myCode = [code substringToIndex:2];
					correspondantCode = [code substringFromIndex:2];
				} else {
					correspondantCode = [code substringToIndex:2];
					myCode = [code substringFromIndex:2];
				}
				NSString *message = [NSString stringWithFormat:NSLocalizedString(@"\nCommunication security:\n\nTo raise the security level, you can check the following codes with your correspondent.\n\nSay:  %1$@\n\nYour correspondent must say:  %2$@", nil),
				 myCode.uppercaseString, correspondantCode.uppercaseString];
				
				if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive &&
					floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_9_x_Max) {
					UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
					content.title = NSLocalizedString(@"ZRTP verification", nil);
					content.body = message;
					content.categoryIdentifier = @"zrtp_request";
					content.userInfo = @{
						@"CallId" : [NSString
							stringWithUTF8String:linphone_call_log_get_call_id(linphone_call_get_call_log(call))]
					};

					UNNotificationRequest *req =
						[UNNotificationRequest requestWithIdentifier:@"zrtp_request" content:content trigger:NULL];
					[[UNUserNotificationCenter currentNotificationCenter]
						addNotificationRequest:req
						 withCompletionHandler:^(NSError *_Nullable error) {
						   // Enable or disable features based on authorization.
						   if (error) {
							   LOGD(@"Error while adding notification request :");
							   LOGD(error.description);
						   }
						 }];
				} else {
					if (securityDialog == nil) {
						__block __strong StatusBarView *weakSelf = self;
                        // define font of message
                        NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:message];
                        NSUInteger length = [message length];
                        UIFont *baseFont = [UIFont systemFontOfSize:21.0];
                        [attrString addAttribute:NSFontAttributeName value:baseFont range:NSMakeRange(0, length)];
                        UIFont *boldFont = [UIFont boldSystemFontOfSize:23.0];
                        [attrString addAttribute:NSFontAttributeName value:boldFont range:[message rangeOfString:@"Communication security"]];
                        UIColor *color = [UIColor colorWithRed:(150 / 255.0) green:(193 / 255.0) blue:(31 / 255.0) alpha:1.0];
                        [attrString addAttribute:NSForegroundColorAttributeName value:color range:[message rangeOfString:myCode.uppercaseString]];
                        [attrString addAttribute:NSForegroundColorAttributeName value:color range:[message rangeOfString:correspondantCode.uppercaseString]];
                        
						securityDialog = [UIConfirmationDialog ShowWithAttributedMessage:attrString
							cancelMessage:NSLocalizedString(@"Later", nil)
							confirmMessage:NSLocalizedString(@"Correct", nil)
							onCancelClick:^() {
							  if (linphone_core_get_current_call(LC) == call) {
								  linphone_call_set_authentication_token_verified(call, NO);
							  }
							  weakSelf->securityDialog = nil;
                              [LinphoneManager.instance lpConfigSetString:[NSString stringWithUTF8String:linphone_call_get_remote_address_as_string(call)] forKey:@"sas_dialog_denied"];
							}
							onConfirmationClick:^() {
							  if (linphone_core_get_current_call(LC) == call) {
								  linphone_call_set_authentication_token_verified(call, YES);
							  }
							  weakSelf->securityDialog = nil;
                                [LinphoneManager.instance lpConfigSetString:nil forKey:@"sas_dialog_denied"];
							} ];
                        
                        securityDialog.securityImage.hidden = FALSE;
						[securityDialog setSpecialColor];
                        [securityDialog setWhiteCancel];
					}
				}
			}
		}
	}
}

- (IBAction)onQualityClick:(id)sender {
	[ControlsViewModelBridge toggleStatsVisibility];
}

- (IBAction)onSideMenuClick:(id)sender {
	UICompositeView *cvc = PhoneMainView.instance.mainViewController;
	[cvc hideSideMenu:(cvc.sideMenuView.frame.origin.x == 0)];
}


- (IBAction)onRegistrationStateClick:(id)sender {
	if (linphone_core_get_default_account(LC)) {
		linphone_core_refresh_registers(LC);
	} else {
		
		MSList *accounts = [LinphoneManager.instance createAccountsNotHiddenList];
		if (accounts) {
			[PhoneMainView.instance changeCurrentView:SettingsView.compositeViewDescription];
		} else {
			[PhoneMainView.instance changeCurrentView:AssistantView.compositeViewDescription];
		}
		bctbx_free(accounts);
	}
}

@end
