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

import Foundation
import CoreTelephony

enum NetworkType: Int {
	case network_none = 0
	case network_2g = 1
	case network_3g = 2
	case network_4g = 3
	case network_lte = 4
	case network_wifi = 5
}

struct APIService {
    
    func postData(to urlString: String, parameters: [String: Any], completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }

        let boundary = "Boundary-\(UUID().uuidString)" // Unique boundary identifier
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = createFormDataBody(parameters: parameters, boundary: boundary)
        request.httpBody = body

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "No data received", code: 0, userInfo: nil)))
                return
            }

            completion(.success(data))
        }
        task.resume()
    }

    func createFormDataBody(parameters: [String: Any], boundary: String) -> Data {
        var body = Data()

        for (key, value) in parameters {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // End of the form-data
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    
}




/*
* AppManager is a class that includes some useful functions.
*/
@objc class AppManager: NSObject {
	static func network() -> NetworkType {
		let info = CTTelephonyNetworkInfo()
		let currentRadio = info.currentRadioAccessTechnology
		if (currentRadio == CTRadioAccessTechnologyEdge) {
			return NetworkType.network_2g
		} else if (currentRadio == CTRadioAccessTechnologyLTE) {
			return NetworkType.network_4g
		}
		return NetworkType.network_3g
	}

	@objc static func recordingFilePathFromCall(address: String) -> String {
		var filePath = "recording_"
		filePath = filePath.appending(address.isEmpty ? "unknow" : address)
		let now = Date()
		let dateFormat = DateFormatter()
		dateFormat.dateFormat = "E-d-MMM-yyyy-HH-mm-ss"
		let date = dateFormat.string(from: now)
		
		filePath = filePath.appending("_\(date).mkv")
		
		let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
		var writablePath = paths[0]
		writablePath = writablePath.appending("/\(filePath)")
		let message:String = "file path is \(writablePath)"
		Log.directLog(BCTBX_LOG_MESSAGE, text: message)
		return writablePath
		//file name is recording_contact-name_dayName-day-monthName-year-hour-minutes-seconds
		//The recording prefix is used to identify recordings in the cache directory.
		//We will use name_dayName-day-monthName-year to separate recordings by days, then hour-minutes-seconds to order them in each day.
	}
		
	@objc static func removeFile(file: String)  {
		let fileManager = FileManager.default
		do {
			try fileManager.removeItem(atPath: file)
			Log.directLog(BCTBX_LOG_MESSAGE, text: "File :\(file) removed")

		} catch {
			Log.e("Could not remove file : \(file) \(error)")
		}
	}
	
    @objc static func updateAPNsRecords(token: String, userSipId: String) {
        // Usage Example
        let apiService = APIService()
        let url = Configs.baseURL + "pbx/updatetoken.php"
      
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // Customize format as needed
        let timeOfAddingToken = formatter.string(from: now)
              
        let userExtension = userSipId.components(separatedBy: "@").first
        print("UserExtension:\(userExtension ?? "")") // Output: 201-1234
        

        let parameters: [String: Any] = [
            "token": token,
            "platform": "ios",
            "userId": userSipId,
            "userSipId": userSipId,
            "userExtension": userExtension ?? "",
            "timeOfAddingToken": timeOfAddingToken,
            "userPhoneNumber": ""
        ]
        let userDefaults = UserDefaults.standard
        var savedToken: String?
        if let token = userDefaults.string(forKey: "devicetoken") {
            savedToken = token
        }
        if savedToken != token {
            apiService.postData(to: url, parameters: parameters) { result in
                switch result {
                case .success(let data):
                    print("Response Data: \(String(data: data, encoding: .utf8) ?? "Invalid Data")")
                    userDefaults.setValue(token, forKey: "devicetoken")
                    userDefaults.synchronize()
                case .failure(let error):
                    print("Error: \(error.localizedDescription)")
                }
            }
        }
        else {
            print("Device token previous uploaded to the server.")
        }
        
    }
    
    
}
