//
//  Photo+CoreDataProperties.swift
//  
//
//  Created by Fiza Rasool on 16/05/20.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension Photo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Photo> {
        return NSFetchRequest<Photo>(entityName: "Photo")
    }

    @NSManaged public var id: String?
    @NSManaged public var imageData: Data?
    @NSManaged public var imageURL: URL?
    @NSManaged public var pin: Pin?

}
