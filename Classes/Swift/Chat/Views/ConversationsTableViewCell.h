//
//  ConversationsTableViewCell.h
//  linphone
//
//  Created by Ankit Khanna on 06/03/25.
//

#import <UIKit/UIKit.h>



@interface ConversationsTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIView *mainView;
@property (weak, nonatomic) IBOutlet UIImageView *chatTickIcon;
@property (weak, nonatomic) IBOutlet UILabel *chatLatestTimeLabel;
@property (weak, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *chatContentLabel;


- (id)initWithIdentifier:(NSString *)identifier;


@end


