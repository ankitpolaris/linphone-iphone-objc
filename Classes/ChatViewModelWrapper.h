//
//  ChatViewModelWrapper.h
//  linphone
//
//  Created by Ankit Khanna on 04/03/25.
//

#import <Foundation/Foundation.h>


@interface ChatViewModelWrapper : NSObject

- (instancetype)init;
- (NSString *)generateChatIdForUser1:(NSString *)user1 user2:(NSString *)user2;
- (void)sendMessageWithTextt:(NSString *)text
                   senderId:(NSString *)senderId
                 senderName:(NSString *)senderName
                     chatId:(NSString *)chatId
                       user1:(NSString *)user1
                       user2:(NSString *)user2;
- (void)fetchLastMessageForChatId:(NSString *)chatId completion:(void (^)(NSDictionary * _Nullable))completion;

@end

