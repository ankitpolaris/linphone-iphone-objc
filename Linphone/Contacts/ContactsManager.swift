/*
 * Copyright (c) 2010-2023 Belledonne Communications SARL.
 *
 * This file is part of Linphone
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

import linphonesw
import Contacts
import SwiftUI

final class ContactsManager: ObservableObject {
    
    static let shared = ContactsManager()
    
    private var coreContext = CoreContext.shared
    
    @Published var contacts: [Contact] = []
    
    private let nativeAddressBookFriendList = "Native address-book"
    let linphoneAddressBookFirendList = "Linphone address-book"
    
    private init() {
        fetchContacts()
    }
    
    func fetchContacts() {
        contacts.removeAll()
        DispatchQueue.global().async {
            let store = CNContactStore()
            store.requestAccess(for: .contacts) { (granted, error) in
                if let error = error {
                    print("failed to request access", error)
                    return
                }
                if granted {
                    let keys = [CNContactEmailAddressesKey, CNContactPhoneNumbersKey,
                                CNContactFamilyNameKey, CNContactGivenNameKey, CNContactNicknameKey,
                                CNContactPostalAddressesKey, CNContactIdentifierKey,
                                CNInstantMessageAddressUsernameKey, CNContactInstantMessageAddressesKey,
                                CNContactImageDataKey, CNContactThumbnailImageDataKey, CNContactOrganizationNameKey]
                    let request = CNContactFetchRequest(keysToFetch: keys as [CNKeyDescriptor])
                    do {
                        try store.enumerateContacts(with: request, usingBlock: { (contact, _) in
                            
                            DispatchQueue.main.sync {
                                self.contacts.append(
                                    Contact(
                                        firstName: contact.givenName,
                                        lastName: contact.familyName,
                                        organizationName: contact.organizationName,
                                        displayName: contact.nickname,
                                        sipAddresses: contact.instantMessageAddresses.map { $0.value.service == "SIP" ? $0.value.username : "" },
                                        phoneNumbers: contact.phoneNumbers.map { PhoneNumber(numLabel: $0.label ?? "", num: $0.value.stringValue)},
                                        imageData: self.saveImage(
                                            image:
                                                UIImage(data: contact.thumbnailImageData ?? Data())
                                            ?? self.textToImage(firstName: contact.givenName.isEmpty
                                                                && contact.familyName.isEmpty
                                                                && contact.phoneNumbers.first?.value.stringValue != nil
                                                                ? contact.phoneNumbers.first!.value.stringValue
                                                                : contact.givenName, lastName: contact.familyName),
                                            name: contact.identifier)
                                    )
                                )
                            }
                            self.contacts.sort(by: {
                                $0.firstName.folding(
                                    options: .diacriticInsensitive, locale: .current
                                ) < $1.firstName.folding(
                                    options: .diacriticInsensitive, locale: .current
                                )
                            })
                        })
                        
                    } catch let error {
                        print("Failed to enumerate contact", error)
                    }
                    
                } else {
                    print("access denied")
                }
            }
            
            var friends: [Friend] = []
            
            self.contacts.forEach { contact in
                do {
                    let friend = try self.coreContext.mCore.createFriend()
                    friend.edit()
                    try friend.setName(newValue: contact.firstName + " " + contact.lastName)
                    friend.organization = contact.organizationName
                    
                    var friendAddresses: [Address] = []
                    contact.sipAddresses.forEach { sipAddress in
                        let address = self.coreContext.mCore.interpretUrl(url: sipAddress, applyInternationalPrefix: true)
                        
                        if address != nil && ((friendAddresses.firstIndex(where: {$0.asString() == address?.asString()})) == nil) {
                            friend.addAddress(address: address!)
                            friendAddresses.append(address!)
                        }
                    }
                    
                    var friendPhoneNumbers: [PhoneNumber] = []
                    contact.phoneNumbers.forEach { phone in
                        do {
                            if (friendPhoneNumbers.firstIndex(where: {$0.numLabel == phone.numLabel})) == nil {
                                let phoneNumber = try Factory.Instance.createFriendPhoneNumber(phoneNumber: phone.num, label: phone.numLabel)
                                friend.addPhoneNumberWithLabel(phoneNumber: phoneNumber)
                                friendPhoneNumbers.append(phone)
                            }
                        } catch let error {
                            print("Failed to enumerate contact", error)
                        }
                    }
                    
                    let contactImage = contact.imageData.dropFirst(8)
                    friend.photo = "file:/" + contactImage
                    
                    friend.done()
                    friends.append(friend)
                    
                } catch let error {
                    print("Failed to enumerate contact", error)
                }
            }
            
            if self.coreContext.mCore.globalState == GlobalState.Shutdown || self.coreContext.mCore.globalState == GlobalState.Off {
                print("$TAG Core is being stopped or already destroyed, abort")
            } else if friends.isEmpty {
                print("$TAG No friend created!")
            } else {
                print("$TAG ${friends.size} friends created")
                
                let fetchedFriends = friends
                
                let nativeFriendList = self.coreContext.mCore.getFriendListByName(name: self.nativeAddressBookFriendList)
                var friendList = nativeFriendList
                if friendList == nil {
                    do {
                        friendList = try self.coreContext.mCore.createFriendList()
                    } catch let error {
                        print("Failed to enumerate contact", error)
                    }
                }
                
                if friendList!.displayName == nil || friendList!.displayName!.isEmpty {
                    print(
                        "$TAG Friend list [$nativeAddressBookFriendList] didn't exist yet, let's create it"
                    )
                    
                    friendList?.databaseStorageEnabled = false // We don't want to store local address-book in DB
                    
                    friendList!.displayName = self.nativeAddressBookFriendList
                    self.coreContext.mCore.addFriendList(list: friendList!)
                } else {
                    print(
                        "$TAG Friend list [$LINPHONE_ADDRESS_BOOK_FRIEND_LIST] found, removing existing friends if any"
                    )
                    friendList!.friends.forEach { friend in
                        _ = friendList!.removeFriend(linphoneFriend: friend)
                    }
                }
                
                fetchedFriends.forEach { friend in
                    _ = friendList!.addLocalFriend(linphoneFriend: friend)
                }
                
                friends.removeAll()
                
                print("$TAG Friends added")
                
                friendList!.updateSubscriptions()
                print("$TAG Subscription(s) updated")
            }
        }
    }
    
    func saveImage(image: UIImage, name: String) -> String {
        guard let data = image.jpegData(compressionQuality: 1) ?? image.pngData() else {
            return ""
        }
        let directory = FileManager.default.temporaryDirectory
        print("FileManagerFileManager \(directory.absoluteString)")
        do {
            try data.write(to: directory.appendingPathComponent(name + ".png"))
            return directory.appendingPathComponent(name + ".png").absoluteString
        } catch {
            print(error.localizedDescription)
            return ""
        }
    }
    
    func textToImage(firstName: String, lastName: String) -> UIImage {
        
        let lblNameInitialize = UILabel()
        lblNameInitialize.frame.size = CGSize(width: 100.0, height: 100.0)
        lblNameInitialize.font = UIFont(name: "NotoSans-ExtraBold", size: 40)
        lblNameInitialize.textColor = UIColor(Color.grayMain2c600)
        
        var textToDisplay = ""
        if firstName.first != nil {
            textToDisplay += String(firstName.first!)
        }
        if lastName.first != nil {
            textToDisplay += String(lastName.first!)
        }
        
        lblNameInitialize.text = textToDisplay.uppercased()
        lblNameInitialize.textAlignment = .center
        lblNameInitialize.backgroundColor = UIColor(Color.grayMain2c200)
        lblNameInitialize.layer.cornerRadius = 10.0
        
        var IBImgViewUserProfile = UIImage()
        UIGraphicsBeginImageContext(lblNameInitialize.frame.size)
        lblNameInitialize.layer.render(in: UIGraphicsGetCurrentContext()!)
        IBImgViewUserProfile = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return IBImgViewUserProfile
    }
}

struct PhoneNumber {
    var numLabel: String
    var num: String
}

struct Contact: Identifiable {
    var id = UUID()
    var firstName: String
    var lastName: String
    var organizationName: String
    var displayName: String
    var sipAddresses: [String] = []
    var phoneNumbers: [PhoneNumber] = []
    var imageData: String
}
