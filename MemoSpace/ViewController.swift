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

struct MemoImage {
    let image: UIImage
    let x: Float
    let y: Float
    let z: Float
}

class ViewController: UIViewController, ARSCNViewDelegate {
    

    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        print("Device orientation is", text)
        
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
        
        addImage(memoImage: newMemoImage)
    }
    
    //Adds a memoSpace image to the scene
    func addImage(memoImage: MemoImage){
        
//        print("In", UIDevice.current.orientation, "mode, the height is", memoImage.image.size.height, "and the width is", memoImage.image.size.width)
        
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
