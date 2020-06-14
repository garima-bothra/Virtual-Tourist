//
//  ViewController.swift
//  Virtual Tourist
//
//  Created by Garima Bothra on 13/05/20.
//  Copyright © 2020 Garima Bothra. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController, UICollectionViewDelegate, MKMapViewDelegate, UICollectionViewDataSource, NSFetchedResultsControllerDelegate, UICollectionViewDelegateFlowLayout {
    
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var noImagesLabel: UILabel!
    @IBOutlet weak var newCollectionButton: UIBarButtonItem!
    @IBOutlet weak var imageCollectionView: UICollectionView!
    
    let reuseIdentifier = "Cell"
    var dataController: DataController!
    var fetchedResultsController: NSFetchedResultsController<Photo>!
    var placeHolderCount: Int!
    var currentPin: Pin!
    var photosExist: Bool!
    var insertedIndexPaths: [IndexPath]!
    var deletedIndexPaths: [IndexPath]!
    var updatedIndexPaths: [IndexPath]!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        imageCollectionView.delegate = self
        imageCollectionView.dataSource = self
        
        let width = (imageCollectionView.frame.width - 20) / 3
        let layout = imageCollectionView.collectionViewLayout as! UICollectionViewFlowLayout
        layout.itemSize = CGSize(width: width, height: width)
        
        dataController = AllConstants.dataController
        
        currentPin = AllConstants.currentPin
        let latDelta: Double = 1.0
        let longDelta: Double = 1.0
        let span = MKCoordinateSpanMake(latDelta, longDelta)
        let centerCoordinate = CLLocationCoordinate2D(latitude: currentPin.latitude, longitude: currentPin.longitude)
        let region = MKCoordinateRegionMake(centerCoordinate, span)
        mapView.setRegion(region, animated: true)
        
        //add currentPin to mapView
        let lat = CLLocationDegrees(currentPin.latitude)
        let long = CLLocationDegrees(currentPin.longitude)
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
        
        self.noImagesLabel.isHidden = true
        reloadImages()
        
        photosExist = AllConstants.photosExist
        
        if photosExist == false {
            fetchNewPhotos()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        fetchedResultsController = nil
    }
    
    func fetchNewPhotos() {
        FlickrObject.sharedInstance().getPhotosForLocation(latitude: (AllConstants.coordinate?.latitude)!, longitude: (AllConstants.coordinate?.longitude)!) {(success, error, data, url) in
            if success {
                DispatchQueue.main.async {
                    self.newCollectionButton.isEnabled = false
                }
                self.placeHolderCount = data.count
                print("Placeholder count = ", self.placeHolderCount!)
                OperationQueue.main.addOperation({
                    self.imageCollectionView.reloadData()
                })

                for property in url {
                    let photo = Photo(context: self.dataController.viewContext)
                    photo.imageURL = property
                    self.currentPin.addToPhotos(photo)
                    print("Image URL: ", photo.imageURL as Any)
                }
                
                self.placeHolderCount = nil
                DispatchQueue.main.async {
                    self.newCollectionButton.isEnabled = true
                }
                try? self.dataController.viewContext.save()
            }
            
            if error != nil {
                let alert = UIAlertController(title: "Error", message: "", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title:NSLocalizedString("OK", comment: "Default Action"), style: .default))
                alert.message = error!
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    func reloadImages() {
        let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
        let predicate = NSPredicate(format: "pin == %@", currentPin)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self as! NSFetchedResultsControllerDelegate
        do {
            try fetchedResultsController.performFetch()
            print("Success fetching results controller")
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
    }
    
    @IBAction func pullNewPhotoCollection(_ sender: Any) {
        for photo in fetchedResultsController.fetchedObjects! {
            dataController.viewContext.delete(photo)
        }
        fetchNewPhotos()
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }
    
    // MARK: CollectionView DataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let sections = fetchedResultsController.sections?[section]{
            print("Sections: ", sections.numberOfObjects)
            return sections.numberOfObjects
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        debugPrint("Setting cell with photo")
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! FlickrPhotoCell
        
        let photoForCell = fetchedResultsController.object(at: indexPath)
        if photoForCell.imageData == nil {
            cell.imageView.image = #imageLiteral(resourceName: "VirtualTourist_120")
            cell.activityIndicator.startAnimating()
            DispatchQueue.global(qos: .background).async {
                self.downloadImageData(imageURL: photoForCell.imageURL, completionHandlerForDownloadImageData: { (success, imageData, error) in
                    if success {
                        print("Success")
                        performUIUpdatesOnMain {
                            if let imageData = imageData {
                                photoForCell.imageData = imageData
                                
                                do {
                                    try self.dataController.viewContext.save()
                                } catch {
                                    print("Unable to save photo")
                                }
                                cell.imageView.image = UIImage(data: photoForCell.imageData!)
                                cell.activityIndicator.stopAnimating()
                                cell.activityIndicator.hidesWhenStopped = true
                            }
                        }
                    }
                })
            }
        }
        if photoForCell.imageData != nil {
            performUIUpdatesOnMain {
                if let imageData = photoForCell.imageData {
                    cell.imageView.image = UIImage(data: imageData)
                    cell.activityIndicator.stopAnimating()
                    cell.activityIndicator.hidesWhenStopped = true
                }
            }
        }
        return cell
    }
    
    func collectionView (_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let destroyAction = UIAlertAction(title: "Delete", style: .destructive) { (action) in
            let photoToDelete = self.fetchedResultsController.object(at: indexPath)
            self.dataController.viewContext.delete(photoToDelete)
            do{
                try self.dataController.viewContext.save()
            } catch {
                print("Error in saving the view.")
            }
        }
        alertController.addAction(destroyAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .default)
        alertController.addAction(cancelAction)
        present(alertController, animated: true)
        }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = true
            pinView!.pinTintColor = .red
            pinView!.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        }
        else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
    func downloadImageData(imageURL: URL?, completionHandlerForDownloadImageData: @escaping(_ success: Bool, _ imageData: Data?, _ error: String?) -> Void) {
        if let imageURL = imageURL, let imageData = try? Data(contentsOf: imageURL) {
            completionHandlerForDownloadImageData(true, imageData, nil)
        } else {
            completionHandlerForDownloadImageData(false, nil, "Cannot download image!")
        }
    }
    
    func downloadImage( imagePath:String, completionHandler: @escaping (_ imageData: Data?, _ errorString: String?) -> Void){
        
        let imgURL = NSURL(string: imagePath)
        let request: NSURLRequest = NSURLRequest(url: imgURL! as URL)
        
        let task = URLSession.shared.dataTask(with: request as URLRequest) {data, response, downloadError in
            
            if downloadError != nil {
                completionHandler(nil, "Could not download image \(imagePath)")
            } else {
                
                completionHandler(data, nil)
            }
        }
        
        task.resume()
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        insertedIndexPaths = [IndexPath]()
        deletedIndexPaths = [IndexPath]()
        updatedIndexPaths = [IndexPath]()
        self.imageCollectionView.numberOfItems(inSection: 0)
    }
    
    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange anObject: Any,
        at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?) {
        
        switch (type) {
        case .insert:
            insertedIndexPaths.append(newIndexPath!)
            break
        case .delete:
            deletedIndexPaths.append(indexPath!)
            break
        case .update:
            updatedIndexPaths.append(indexPath!)
            break
        case .move:
            print("Not possible. Try again later.")
            break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        imageCollectionView.performBatchUpdates({() -> Void in
            
            for indexPath in self.insertedIndexPaths {
                self.imageCollectionView.insertItems(at: [indexPath])
            }
            
            for indexPath in self.deletedIndexPaths {
                self.imageCollectionView.deleteItems(at: [indexPath])
            }
            
            for indexPath in self.updatedIndexPaths {
                self.imageCollectionView.reloadItems(at: [indexPath])
            }
            
        }, completion: nil)
    }
}



