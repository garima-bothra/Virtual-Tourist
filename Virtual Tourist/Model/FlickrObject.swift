//
//  FlickrObject.swift
//  Virtual Tourist
//
//  Created by Garima Bothra on 14/05/20.
//  Copyright © 2020 Garima Bothra. All rights reserved.
//

import Foundation

class FlickrObject: NSObject {
    
    // MARK: Fetch photos for the selected pin location
    func getPhotosForLocation (latitude: Double, longitude: Double, completionHandler: @escaping (_ success: Bool, _ errorString: String?, _ dataArray: [Data], _ urlArray: [URL]) -> Void ) {
        let urlString = "\(AllConstants.Methods.photoSearchUrl)&lat=\(latitude)&lon=\(longitude)&per_page=30"
        print("urlString = \(urlString)")
        let request = URLRequest(url: URL(string: urlString)!)
       
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            
            guard let data = data else {
                completionHandler(false, "Unable to locate data in request", [], [])
                return
            }
            
            guard error == nil else {
                completionHandler(false, "An error occurred with the URL request: \(error!)", [], [])
                return
            }
            
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            guard statusCode! <= 299 && statusCode! >= 200 else {
                completionHandler(false, "Request failed with Status code \(statusCode!).", [], [])
                return
            }
            
            var parsedResults: AllConstants.PhotoResults
            do {
                parsedResults = try JSONDecoder().decode(AllConstants.PhotoResults.self, from: data)
            } catch {
                print("Could not parse the data")
                return
            }
            
            guard let stat = parsedResults.stat, stat == AllConstants.FlickrResponseValues.OKStatus else {
                print("Flickr API returned an error. See error code and message in \(parsedResults)")
                return
            }
            
            guard let photosDict = parsedResults.photos else {
                print("Cannot find key '\(AllConstants.FlickrResponseKeys.Photos) in \(parsedResults)")
                return
            }
            
            guard let totalPages = photosDict.pages else {
                debugPrint("Cannot find key '\(AllConstants.FlickrResponseKeys.Pages) in \(photosDict)")
                return
            }
            
            let pageLimit = min(totalPages, 4000/30)
            let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
            
            self.getPhotosForLocation(latitude: latitude, longitude: longitude, withPageNumber: randomPage, completionHandler: { (success, error, dataArray, urlArray) in
                if success {
                    parsedResults.photos?.page = randomPage
                }
                if error != nil {
                    debugPrint("Error passing data to getPhotosForLocation")
                }
                completionHandler(success, error, dataArray, urlArray)
                
            })
        }
        task.resume()
    }

    // MARK: For a random page, fetch data
    func getPhotosForLocation (latitude: Double, longitude: Double, withPageNumber: Int, completionHandler: @escaping (_ success: Bool, _ errorString: String?, _ dataArray: [Data], _ urlArray: [URL]) -> Void ) {
        let urlString = "\(AllConstants.Methods.photoSearchUrl)&lat=\(latitude)&lon=\(longitude)&per_page=30&page=\(withPageNumber)"
        print("urlString2 = ", urlString)
        let request = URLRequest(url: URL(string: urlString)!)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            
            guard let data = data else {
                completionHandler(false, "Unable to locate data in request", [], [])
                return
            }
            
            guard error == nil else {
                completionHandler(false, "An error occured with the URL request: \(error!)", [], [])
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode
            guard statusCode! <= 299 && statusCode! >= 200 else {
                completionHandler(false, "Request failed. Status code \(statusCode!).", [], [])
                return
            }

            do {
                let parsedResults = try JSONDecoder().decode(AllConstants.PhotoResults.self, from: data)
                var photoData: [Data] = []
                var photoId: [String] = []
                var photoURL: [URL] = []
                for photo in (parsedResults.photos?.photo!)! {
                    let imageData = try? Data(contentsOf: self.pinPhotoToURL(photo: photo))
                    photoData.append(imageData!)
                    photoId.append(photo.id!)
                    photoURL.append(self.pinPhotoToURL(photo: photo))
                }
                completionHandler(true, nil, photoData, photoURL)
                print("This many properties are being passed: \(photoData.count)")
                return
            } catch {
                completionHandler(false, "Data parse failed:\(error)", [], [])
                return
            }
        }
        task.resume()
    }
    
    //returns a url to be used as image data based on the pinPhoto object
    func pinPhotoToURL (photo: AllConstants.pinPhoto) -> URL {
        return URL(string: "https://farm\(photo.farm!).staticflickr.com/\(photo.server!)/\(photo.id!)_\(photo.secret!).jpg")!
    }
    
    // MARK: Singleton
    class func sharedInstance() -> FlickrObject {
        struct Singleton {
            static var sharedInstance = FlickrObject()
        }
        return Singleton.sharedInstance
    }
}
