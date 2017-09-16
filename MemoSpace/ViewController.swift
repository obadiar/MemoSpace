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

struct MemoImage {
    let image: UIImage
    let x: Float
    let y: Float
    let z: Float
}

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

class ViewController: UIViewController, ARSCNViewDelegate, CLLocationManagerDelegate {
    
    let locationManager = CLLocationManager()
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations[0]
        let myLocation:CLLocationCoordinate2D = CLLocationCoordinate2DMake(location.coordinate.latitude, location.coordinate.longitude)
    }
    
    
    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        
        
        
        super.viewDidLoad()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        
        //print(locationManager.location?.coordinate.latitude)
        
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        
        //Add tap gesture and connect it to a function
        let tapGesture = UITapGestureRecognizer(target: self, action:
            #selector(ViewController.handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)
    }
    
    //The function for the tap
    @objc
    func handleTap(gestureRecognize: UITapGestureRecognizer){
        //Captures the snapshot
        var imageSnapped = sceneView.snapshot()
        
        //Create a new MemoImage
        var newMemoImage = MemoImage(image: imageSnapped, x: 0, y: 0, z: -0.2)
        
        addImage(memoImage: newMemoImage)
    }
    
    //The function to add the image
    func addImage(memoImage: MemoImage){
        
        //Getting the current fram
        guard let currentFrame = sceneView.session.currentFrame else {
            return
        }
        
        //Setting up the image plane
        var imagePlane = SCNPlane(width: sceneView.bounds.width / 6000,
                                  height: sceneView.bounds.height / 6000)
        
        
        
        
        //var imageSnapped = UIImage(named:imageName)!
        
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
