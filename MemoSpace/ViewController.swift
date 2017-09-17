//
//  ViewController.swift
//  MemoSpace
//
//  Created by Robert Durst on 9/16/17.
//  Copyright © 2017 MemoSpace. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Alamofire
import CoreLocation
import FirebaseStorage
import Foundation

struct MemoImage {
    let image: UIImage
    let x: Float
    let y: Float
    let z: Float
}

let storage = Storage.storage()
let storageRef = storage.reference()

class ViewController: UIViewController, ARSCNViewDelegate, CLLocationManagerDelegate {
    
    
    let locationManager = CLLocationManager()
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations[0]
        let myLocation:CLLocationCoordinate2D = CLLocationCoordinate2DMake(location.coordinate.latitude, location.coordinate.longitude)
    }
    
    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
                func downloadImage(url: URL, xC: Float, yC: Float, zC: Float) {
                    print("Download Started for", url)
                    getDataFromUrl(url: url) { (data, response, error)  in
                        guard let data = data, error == nil else { return }
                        print(response?.suggestedFilename ?? url.lastPathComponent)
                        print("Download Finished")
                        DispatchQueue.main.async() { () -> Void in
                            let newImage = UIImage(data: data)
                            let newMemoImage = MemoImage(image: newImage!, x: xC, y: yC, z: zC)
                            print("X:", xC, "Y:", yC, "Z:", zC)
                            self.addImage(memoImage: newMemoImage)
                        }
                    }
                }
        
                Alamofire.request("https://memospace-backend.herokuapp.com/api/get_images").responseJSON { response in
                    print("Request: \(String(describing: response.request))")   // original url request
                    print("Response: \(String(describing: response.response))") // http url response
                    print("Result: \(response.result)")                         // response serialization result
        
                    if let json = response.result.value {
                        print("JSON: \(json)") // serialized json response
                        for element in json as! [Dictionary<String, AnyObject>] { // or [[String:AnyObject]]
                            if let checkedUrl = URL(string: element["image_url"] as! String) {
//                                let lat1 = Double((self.locationManager.location?.coordinate.latitude)!)
//                                let lon1 = Double((self.locationManager.location?.coordinate.longitude)!)
//
//                                let lat2 = element["latitude"]
//                                print("image latitude", lat2)
//                                let lon2 = element["longitude"]
//                                print("image longitude", lon2)
//
//
//                                let haverD = haversineDinstance(la1: lat1, lo1: lon1, la2: (lat2 as! Double as! Double), lo2: (lon2 as! Double))
//                                let haverTheta = angleFromCoordinate(lat1: lat1, long1: lon1, lat2: (lat2 as! Double as! Double), long2: (lon2 as! Double))
//
//                                let image_x = 0
//                                let image_y = haverD * cos(haverTheta)
//                                let image_z = -haverD * sin(haverTheta)
                                downloadImage(url: checkedUrl, xC: Float((element["longitude"] as? Float)!), yC: Float(0), zC: Float((element["latitude"] as? Float)!))
                            }
                        }
                    }
        
                    if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                        print("Data: \(utf8Text)") // original server data as UTF8 string
                    }
        
        
                }
        
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        //Add tap gesture and connect it to a function
        let tapGesture = UITapGestureRecognizer(target: self, action:
            #selector(ViewController.handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)
    }
    
    //Tap handler
    @objc
    func handleTap(gestureRecognize: UITapGestureRecognizer){
        
        //        print("Device orientation is", getOrientationString(), locationManager.location?.coordinate)
        let fileName = Date().ticks
        
        //Captures the snapshot
        var imageSnapped = sceneView.snapshot()
        
        //Rotating the image before adding it, based on the current device orientation
        if (UIDevice.current.orientation.isPortrait){
            imageSnapped = imageSnapped.image(withRotation: CGFloat((Double.pi / 2)))
        } else if (UIDevice.current.orientation == UIDeviceOrientation.portraitUpsideDown){
            imageSnapped = imageSnapped.image(withRotation: CGFloat(-(Double.pi)))
        } else if (UIDevice.current.orientation == UIDeviceOrientation.landscapeRight){
            imageSnapped = imageSnapped.image(withRotation: CGFloat((Double.pi)))
        }
        
        //Create a new MemoImage
        let newMemoImage = MemoImage(image: imageSnapped, x: 0, y: 0, z: -0.2)
        
        let data = UIImageJPEGRepresentation(imageSnapped, 0.8)
        
        // Create a reference to the file you want to upload
        let testRef = storageRef.child("images/\(fileName).jpg")
        
        // Upload the file to the path "images/rivers.jpg"
        let uploadTask = testRef.putData(data!, metadata: nil) { (metadata, error) in
            guard let metadata = metadata else {
                print("Upload failed..")
                return
            }
            print("Uploaded successfully!")
            // Metadata contains file metadata such as size, content-type, and download URL.
            let downloadURL = metadata.downloadURL
            
            //            print("The download URL", downloadURL()?.absoluteString)
            Alamofire.upload(
                multipartFormData: { multipartFormData in
                    if let imageData = UIImageJPEGRepresentation(imageSnapped, 0.8) {
                        multipartFormData.append((downloadURL()?.absoluteString.data(using: .utf8))!, withName: "image_url")
                        multipartFormData.append(getOrientationString().data(using: .utf8)!, withName: "orientation")
                        multipartFormData.append(String(format: "%f", (self.locationManager.location?.coordinate.longitude)!).data(using: .utf8)!, withName: "Longitude")
                        multipartFormData.append(String(format: "%f", (self.locationManager.location?.coordinate.latitude)!).data(using: .utf8)!, withName: "Latitude")
                        multipartFormData.append(String(format: "%f", (self.locationManager.location?.altitude)!).data(using: .utf8)!, withName: "Altitude")
                        
                    }
            },
                to: "https://memospace-backend.herokuapp.com/api/upload_image",
                method: .post,
                headers: ["Content-Type": "image/jpeg"],
                encodingCompletion: { encodingResult in
                    switch encodingResult {
                    case .success(let upload, _, _):
                        upload.responseJSON { response in
                            debugPrint(response)
                        }
                    case .failure(let encodingError):
                        print(encodingError)
                    }
            })
        }
        addImage(memoImage: newMemoImage)
    }
    
    //Adds a memoSpace image to the scene
    func addImage(memoImage: MemoImage){
        print("Add memoImage called!")
        //        print("In", UIDevice.current.orientation, "mode, the height is", memoImage.image.size.height, "and the width is", memoImage.image.size.width)
        
        //Getting the current fram
        guard let currentFrame = sceneView.session.currentFrame else {
            return
        }
        //Setting up the image plane
        var imagePlane:SCNPlane
        //Scaling..
        if (UIDevice.current.orientation == UIDeviceOrientation.portrait){  //If up straight portrait
            imagePlane = SCNPlane(width: sceneView.bounds.width / 2000,
                                  height: sceneView.bounds.height / 6000)
        } else if (UIDevice.current.orientation.isLandscape){   //If landscape (either left or right)
            imagePlane = SCNPlane(width: sceneView.bounds.width / 6000,
                                  height: sceneView.bounds.height / 6000)
        }
        else {  //Otherwise, Users cannot take images with their devices upside down
            return
        }
        
        
        //Adding the image to the imagePlane
        imagePlane.firstMaterial?.diffuse.contents = memoImage.image
        imagePlane.firstMaterial?.lightingModel = .constant
        
        
        // Create plane node and add it it the scene
        let planeNode = SCNNode(geometry: imagePlane)
        sceneView.scene.rootNode.addChildNode(planeNode)
        
        //Transform the image
        var translation = matrix_identity_float4x4
        translation.columns.3.z = memoImage.z
        translation.columns.3.x = memoImage.x
        translation.columns.3.y = memoImage.y
        planeNode.simdTransform = matrix_multiply(currentFrame.camera.transform, translation)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    // MARK: - ARSCNViewDelegate
    
    /*
     // Override to create and configure nodes for anchors added to the view's session.
     func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
     let node = SCNNode()
     
     return node
     }
     */
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}

func getOrientationString() -> String{
    var currentOrientation = ""
    switch UIDevice.current.orientation{
    case .portrait:
        currentOrientation="Portrait"
    case .portraitUpsideDown:
        currentOrientation="PortraitUpsideDown"
    case .landscapeLeft:
        currentOrientation="LandscapeLeft"
    case .landscapeRight:
        currentOrientation="LandscapeRight"
    default:
        currentOrientation = "Other"
    }
    return currentOrientation
}

//An extension to rotate the snapshot in case of portrait orientation
extension UIImage {
    func image(withRotation radians: CGFloat) -> UIImage {
        let cgImage = self.cgImage!
        let LARGEST_SIZE = CGFloat(max(self.size.width, self.size.height))
        let context = CGContext.init(data: nil, width:Int(LARGEST_SIZE), height:Int(LARGEST_SIZE), bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0, space: cgImage.colorSpace!, bitmapInfo: cgImage.bitmapInfo.rawValue)!
        
        var drawRect = CGRect.zero
        drawRect.size = self.size
        let drawOrigin = CGPoint(x: (LARGEST_SIZE - self.size.width) * 0.5,y: (LARGEST_SIZE - self.size.height) * 0.5)
        drawRect.origin = drawOrigin
        var tf = CGAffineTransform.identity
        tf = tf.translatedBy(x: LARGEST_SIZE * 0.5, y: LARGEST_SIZE * 0.5)
        tf = tf.rotated(by: CGFloat(radians))
        tf = tf.translatedBy(x: LARGEST_SIZE * -0.5, y: LARGEST_SIZE * -0.5)
        context.concatenate(tf)
        context.draw(cgImage, in: drawRect)
        var rotatedImage = context.makeImage()!
        
        drawRect = drawRect.applying(tf)
        
        rotatedImage = rotatedImage.cropping(to: drawRect)!
        let resultImage = UIImage(cgImage: rotatedImage)
        return resultImage
    }
}

//Extension to get the current timestamp for naming the files
extension Date {
    var ticks: String {
        return String(format: "%d",UInt64((self.timeIntervalSince1970 + 62_135_596_800) * 10_000_000))
    }
}

func getDataFromUrl(url: URL, completion: @escaping (_ data: Data?, _  response: URLResponse?, _ error: Error?) -> Void) {
    URLSession.shared.dataTask(with: url) {
        (data, response, error) in
        completion(data, response, error)
        }.resume()
}
//
//
//extension UIImageView {
//    func downloadedFrom(url: URL, contentMode mode: UIViewContentMode = .scaleAspectFit) {
//        contentMode = mode
//        URLSession.shared.dataTask(with: url) { (data, response, error) in
//            guard
//                let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
//                let mimeType = response?.mimeType, mimeType.hasPrefix("image"),
//                let data = data, error == nil,
//                let image = UIImage(data: data)
//                else { return }
//            DispatchQueue.main.async() { () -> Void in
//                self.image = image
//            }
//            }.resume()
//    }
//    func downloadedFrom(link: String, contentMode mode: UIViewContentMode = .scaleAspectFit) {
//        guard let url = URL(string: link) else { return }
//        downloadedFrom(url: url, contentMode: mode)
//    }
//}

func haversineDinstance(la1: Double, lo1: Double, la2: Double, lo2: Double, radius: Double = 6367444.7) -> Double {
    
    let haversin = { (angle: Double) -> Double in
        return (1 - cos(angle))/2
    }
    
    let ahaversin = { (angle: Double) -> Double in
        return 2*asin(sqrt(angle))
    }
    
    // Converts from degrees to radians
    let dToR = { (angle: Double) -> Double in
        return (angle / 360) * 2 * M_PI
    }
    
    let lat1 = dToR(la1)
    let lon1 = dToR(lo1)
    let lat2 = dToR(la2)
    let lon2 = dToR(lo2)
    
    return radius * ahaversin(haversin(lat2 - lat1) + cos(lat1) * cos(lat2) * haversin(lon2 - lon1))
}

func angleFromCoordinate(lat1: Double, long1: Double, lat2: Double, long2: Double) -> (Double){
    let dLon = (long2 - long1);
    let y = sin(dLon) * cos(lat2);
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    var brng = atan2(y, x);
    brng = Double((brng + 360).truncatingRemainder(dividingBy: 360));
    brng = 360 - brng; // count degrees counter-clockwise - remove to make clockwise
    
    return brng;
}
