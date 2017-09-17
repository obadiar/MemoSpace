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
import Foundation
import SwiftyJSON



struct MemoImage {
    let image: UIImage
    let x: Float
    let y: Float
    let z: Float
    let orientation: String
    let heading: String
}

struct RawMemoImage {
    let image_url: String
    let lat: Float
    let lon: Float
    let orientation: String
    let altitude: Float
}

let screenSize: CGRect = UIScreen.main.bounds
let screenWidth = screenSize.width
let screenHeight = screenSize.height

var toRemove = SCNNode()
var zoomedIn = false

class ViewController: UIViewController, ARSCNViewDelegate, CLLocationManagerDelegate {
    var curAlt = 10.0;
    let locationManager = CLLocationManager()
    var curLoc = [[Double(),Double()]]
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations[0]
        let myLocation:CLLocationCoordinate2D = CLLocationCoordinate2DMake(location.coordinate.latitude, location.coordinate.longitude)
    }
    
    @IBOutlet var sceneView: ARSCNView!    
    
    override func viewDidLoad() {
        
        
        
        super.viewDidLoad()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.distanceFilter = 0.1
 
        // Set the view's delegate
        sceneView.delegate = self

        // Show statistics such as fps and timing information
        sceneView.showsStatistics = false
        
        let button = UIButton(type: .custom)
        button.frame = CGRect(x: (screenWidth/2)-40, y: screenHeight-120, width: 80, height: 80)
        button.layer.cornerRadius = 0.2 * button.bounds.size.width
        button.clipsToBounds = true
        button.setImage(UIImage(named: "circle.png"), for: .normal)
        button.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
        sceneView.addSubview(button)
        
        callImages()
        
        
    }


    
    @objc func buttonAction(sender: UIButton!) {
        var text=""
        switch UIDevice.current.orientation{
        case .portrait:
            text="Portrait"
        case .portraitUpsideDown:
            text="PortraitUpsideDown"
        case .landscapeLeft:
            text="LandscapeLeft"
        case .landscapeRight:
            text="LandscapeRight"
        default:
            text="Another"
        }
        //print("Device orientation is", text, locationManager.location?.coordinate)
        //callImages()
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
        let newMemoImage = MemoImage(image: imageSnapped, x: 0, y: 0, z: -0.2, orientation: "none", heading: "none")
        
        addImage(memoImage: newMemoImage)
        
      
    }
    
    
    //Tap handler
    @objc
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.location(in: sceneView)
            
            let hitlist = sceneView.hitTest(location, options: nil)
            
            if let hitObject = hitlist.first {
                let node = hitObject.node
                
                if (zoomedIn){
                    toRemove.removeFromParentNode()
                    zoomedIn = false
                }
                
                else{
                    zoomedIn = true
                    let planeNode = SCNNode(geometry: node.geometry)
                    toRemove = planeNode
                    sceneView.scene.rootNode.addChildNode(planeNode)
                    
                    guard let currentFrame = sceneView.session.currentFrame else {
                        return
                    }
                    
                    
                    //Transform the image
                    var translation = matrix_identity_float4x4
                    translation.columns.3.z = -0.15
                    translation.columns.3.x = 0
                    translation.columns.3.y = 0
                    planeNode.simdTransform = matrix_multiply(currentFrame.camera.transform, translation)
                }
                
                
            }
        }
        
    }
    
    
    //Adds a memoSpace image to the scene
    func addImage(memoImage: MemoImage){
        
        
        //Getting the current fram
        guard let currentFrame = sceneView.session.currentFrame else {
            return
        }
        
        //Setting up the image plane
        var imagePlane: SCNPlane
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
    
    //Function to call the images
    func callImages(){
        var lat1 = Double((locationManager.location?.coordinate.latitude)!)
        var lon1 = Double((locationManager.location?.coordinate.longitude)!)
        
        Alamofire.request("https://memospace-backend.herokuapp.com/api/get_images").responseJSON { response in
            print("Request: \(String(describing: response.request))")   // original url request
            print("Response: \(String(describing: response.response))") // http url response
            print("Result: \(response.result)")                         // response serialization result
            
            if let json = response.result.value {
                var rawMemDataArry = [RawMemoImage]()
  // serialized json response
                for memData in json as! [Dictionary<String, AnyObject>] { // or [[String:AnyObject]]```
                    var image_url = memData["image_url"] as! String!
                    var lat = memData["latitude"] as! Float!
                    var lon = memData["longitude"] as! Float!
                    var orientation = memData["orientation"] as! String!
                    var altitude = memData["altitude"] as! Float!
                    print(altitude)
                    var newRawMem = RawMemoImage(image_url: image_url!, lat: lat!, lon: lon!, orientation: orientation!, altitude: altitude!)
                    rawMemDataArry.append(newRawMem)
                }
                
                var y_count = -0.4;
                var x_count = 0.4 ;
                
                for image in rawMemDataArry {
                    if (y_count > 0.5) {
                        y_count = -0.4
                        x_count -= 0.2
                    }
                    
                    
                    self.placeImage(memData: image, lat1: lat1, lon1: lon1, x_count: Float(x_count), y_count: Float(y_count))
                    
                    y_count += 0.2
                }
                
                
  
            }
        }
    }
    
    func placeImage(memData: RawMemoImage, lat1: Double, lon1: Double, x_count: Float, y_count: Float){

        let coords = CLLocation(latitude: CLLocationDegrees(memData.lat), longitude: CLLocationDegrees(memData.lon))
        let coords_cur = CLLocation(latitude: CLLocationDegrees(lat1), longitude: CLLocationDegrees(lon1))
        
        
        print(CLLocation.distance(coords_cur))
        
        // The image to dowload
       
        var url:String? = memData.image_url
        let remoteImageURL = URL(string: url!)
        
       

         // Use Alamofire to download the image
        Alamofire.request(remoteImageURL!).responseData { (response) in
                 if response.error == nil {
                         print(response.result)
        
                         // Show the downloaded image:
                         if let data = response.data {
                                 var image = UIImage(data: data)
                            let imageDownloadedObj = MemoImage(image: image!, x: Float(x_count), y: Float(y_count), z: -0.5, orientation: memData.orientation, heading: "null")
                            self.addImage(memoImage: imageDownloadedObj)
                             }
                    
                     }
             }
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
