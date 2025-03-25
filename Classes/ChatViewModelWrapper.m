//
//  ChatViewModelWrapper.m
//  linphone
//
//  Created by Ankit Khanna on 04/03/25.
//
#import "linphoneapp-Swift.h" // Import Swift-generated header
#import "ChatViewModelWrapper.h"


@interface ChatViewModelWrapper ()
@property (nonatomic, strong) ChatViewModel *chatViewModel;
@end

@implementation ChatViewModelWrapper {
    ChatViewModel *_chatViewModel;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _chatViewModel = [[ChatViewModel alloc] init];
    }
    return self;
}

- (NSString *)generateChatIdForUser1:(NSString *)user1 user2:(NSString *)user2 {
    return [self.chatViewModel generateChatIdForUser1:user1 user2:user2];
}

- (void)sendMessageWithTextt:(NSString *)text
                   senderId:(NSString *)senderId
                 senderName:(NSString *)senderName
                     chatId:(NSString *)chatId
                       user1:(NSString *)user1
                       user2:(NSString *)user2 {
    [self.chatViewModel sendMessageWithText:text senderId:senderId senderName:senderName chatId:chatId user1:user1 user2:user2];
}

- (void)fetchLastMessageForChatId:(NSString *)chatId completion:(void (^)(NSDictionary * _Nullable))completion {
    [_chatViewModel fetchLastMessageFor:chatId completion:completion];
}

- (NSString *)formatTimestamp:(double)timestamp {
    return [self.chatViewModel formatTimestamp:timestamp];
}

@end
