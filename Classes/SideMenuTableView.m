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

#import "linphone/core_utils.h"

#import "SideMenuTableView.h"
#import "Utils.h"

#import "PhoneMainView.h"
#import "StatusBarView.h"
#import "ShopView.h"
#import "LinphoneManager.h"
#import "RecordingsListView.h"
#import "linphoneapp-Swift.h"

@implementation SideMenuEntry

- (id)initWithTitle:(NSString *)atitle image:(UIImage *)image tapBlock:(SideMenuEntryBlock)tapBlock {
	if ((self = [super init])) {
        img = image;
		title = atitle;
		onTapBlock = tapBlock;
	}
	return self;
}

@end

@implementation SideMenuTableView

- (void)viewDidLoad {
	[super viewDidLoad];

	// remove separators between empty items, cf
	// http://stackoverflow.com/questions/1633966/can-i-force-a-uitableview-to-hide-the-separator-between-empty-cells
	self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}

- (void)viewWillAppear:(BOOL)animated {
	linphone_core_stop_dtmf_stream(LC);
	[super viewWillAppear:animated];

	_sideMenuEntries = [[NSMutableArray alloc] init];

	[_sideMenuEntries
		addObject:[[SideMenuEntry alloc] initWithTitle:NSLocalizedString(@"Assistant", nil)
                                                 image:[UIImage imageNamed:@"menu_assistant.png"]
											  tapBlock:^() {
												[PhoneMainView.instance
													changeCurrentView:AssistantView.compositeViewDescription];
											  }]];
	BOOL mustLink = ([LinphoneManager.instance lpConfigIntForKey:@"must_link_account_time"] > 0);
	
	MSList *accounts = [LinphoneManager.instance createAccountsNotHiddenList];
	BOOL hasAccount = accounts != NULL;
	bctbx_free(accounts);
	if (mustLink && hasAccount && ![LinphoneManager.instance lpConfigIntForKey:@"hide_link_phone_number"]) {
		[_sideMenuEntries
			addObject:[[SideMenuEntry alloc] initWithTitle:NSLocalizedString(@"Link my account", nil)
                                                     image:[UIImage imageNamed:@"menu_link_account.png"]
												  tapBlock:^() {
													[PhoneMainView.instance
														changeCurrentView:AssistantLinkView.compositeViewDescription];
												  }]];
	}

    
	[_sideMenuEntries
		addObject:[[SideMenuEntry alloc] initWithTitle:NSLocalizedString(@"Settings", nil)
                                                 image:[UIImage imageNamed:@"menu_options.png"]
											  tapBlock:^() {
												[PhoneMainView.instance
													changeCurrentView:SettingsView.compositeViewDescription];
											  }]];
    [_sideMenuEntries
     addObject:[[SideMenuEntry alloc] initWithTitle:NSLocalizedString(@"Recordings", nil)
                                              image:[UIImage imageNamed:@"menu_recordings.png"]
                                           tapBlock:^() {
                                               [PhoneMainView.instance
                                                changeCurrentView:RecordingsListView.compositeViewDescription];
                                           }]];
	InAppProductsManager *iapm = LinphoneManager.instance.iapManager;
	if (iapm.enabled){
		[_sideMenuEntries
			addObject:[[SideMenuEntry alloc] initWithTitle:NSLocalizedString(@"Shop", nil)
                                                     image:nil
												  tapBlock:^() {
													[PhoneMainView.instance
														changeCurrentView:ShopView.compositeViewDescription];
												  }]];
	}
	
	LinphoneAccount *defaultAccount = linphone_core_get_default_account(LC);
	if (defaultAccount && linphone_account_params_get_audio_video_conference_factory_address(linphone_account_get_params(defaultAccount))){
		
		[_sideMenuEntries addObject:[[SideMenuEntry alloc] initWithTitle:VoipTexts.conference_scheduled
																   image:[UIImage imageNamed:@"side_menu_voip_meeting_schedule"]
																tapBlock:^() {
																  [PhoneMainView.instance
																	  changeCurrentView:ScheduledConferencesView.compositeViewDescription];

																}]];
	}
	
	[_sideMenuEntries addObject:[[SideMenuEntry alloc] initWithTitle:NSLocalizedString(@"About", nil)
                                                               image:[UIImage imageNamed:@"menu_about.png"]
															tapBlock:^() {
															  [PhoneMainView.instance
																  changeCurrentView:AboutView.compositeViewDescription];

															}]];
}

- (void)navigateToLoginFlowViewController {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"LoginStoryboard" bundle:nil];
    LoginViewController *loginViewController = [storyboard instantiateViewControllerWithIdentifier:@"LoginViewController"];
//    [self.navigationController pushViewController:loginViewController animated:YES];
    [self presentViewController:loginViewController animated:YES completion:nil];
}

#pragma mark - Table View Controller
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0) {
		
		BOOL hasDefault = (linphone_core_get_default_account(LC) != NULL);
		// default account is shown in the header already
		MSList *accounts = [LinphoneManager.instance createAccountsNotHiddenList];
		size_t count = bctbx_list_size(accounts);
		bctbx_free(accounts);
		return MAX(0, (int)count - (hasDefault ? 1 : 0));
	} else {
		return [_sideMenuEntries count] + 1;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [[UITableViewCell alloc] init];

	// isLcInitialized called here because this is called when going in bg after LC destroy
	if (indexPath.section == 0 && [LinphoneManager isLcInitialized]) {
		// do not display default account here, it is already in header view
		MSList *accounts = [LinphoneManager.instance createAccountsNotHiddenList];
		int idx =
			linphone_core_get_default_account(LC)
				? bctbx_list_index(accounts, linphone_core_get_default_account(LC))
				: HUGE_VAL;
		LinphoneAccount *account = bctbx_list_nth_data(accounts,
														 (int)indexPath.row + (idx <= indexPath.row ? 1 : 0));
		bctbx_free(accounts);
		if (account) {
			cell.textLabel.text = [NSString stringWithUTF8String:linphone_account_params_get_identity(linphone_account_get_params(account))];
			cell.imageView.image = [StatusBarView imageForState:linphone_account_get_state(account)];
		} else {
			LOGE(@"Invalid index requested, no proxy for row %d", indexPath.row);
		}
		cell.transform = CGAffineTransformMakeScale(-1.0, 1.0);
		cell.textLabel.transform = CGAffineTransformMakeScale(-1.0, 1.0);
		cell.imageView.transform = CGAffineTransformMakeScale(-1.0, 1.0);
	}
    else if (indexPath.section == 1 && indexPath.row == 0) {
        SideMenuEntry *entry = [_sideMenuEntries objectAtIndex:0];
        cell.imageView.image = entry->img;
        cell.textLabel.text = @"New Login Flow";
    }
    else {
		SideMenuEntry *entry = [_sideMenuEntries objectAtIndex:indexPath.row-1];
		cell.imageView.image = entry->img;
		cell.textLabel.text = entry->title;
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:NO];

	if (indexPath.section == 0) {
		[PhoneMainView.instance changeCurrentView:SettingsView.compositeViewDescription];
	}
    else if (indexPath.section == 1 && indexPath.row == 0) {
        [self navigateToLoginFlowViewController];
    }
    else {
		SideMenuEntry *entry = [_sideMenuEntries objectAtIndex:indexPath.row-1];
		LOGI(@"Entry %@ has been tapped", entry->title);
		if (entry->onTapBlock == nil) {
			LOGF(@"Entry %@ has no onTapBlock!", entry->title);
		} else {
			entry->onTapBlock();
		}
	}
	[PhoneMainView.instance.mainViewController hideSideMenu:YES];
}

@end
