//
//  ViewController.swift
//  slicingtest
//
//  Created by Jonathan Leo on 12/20/20.
//

import UIKit
import SceneKit
import ARKit
import ModelIO
import SceneKit.ModelIO

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var addButton: UIButton!
    
    var decodeTube: SCNNode!
    var planeNode: SCNNode!
    var heartNode: SCNNode!
    var planeEquation: simd_float4!
    var _voxels: SCNNode?
    
    // gestures
    var currentAngleY: Float = 0.0
    var currentAngleX: Float = 0.0
    var initNormal: simd_float3 = simd_float3(x: 0, y: 0, z: -1)
    let SCALE_FACTOR: CGFloat = 0.001
    var _explodeUsingCubes: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        self.sceneView.autoenablesDefaultLighting = true
        
        // Show statistics such as fps and timing information
//        sceneView.showsStatistics = true
        
        // Create a new scene
//        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // add button actions
        addButton.addTarget(self, action: #selector(add(_sender:)), for: .touchDown)
        
        // add panning gesture to rotate heartnode
        let panRotateRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGesture(sender:)))
        sceneView.addGestureRecognizer(panRotateRecognizer)
//
//        //add pinch gesture for enlarging object
//        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(pinchGesture(sender:)))
//        sceneView.addGestureRecognizer(pinchRecognizer)
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
    
    func plotSphere(planePos: simd_float2) {
        let z = (planeEquation.w - planeEquation.x * planePos.x - planeEquation.y * planePos.y) / planeEquation.z
        let worldPos = simd_float3(x: planePos.x, y: planePos.y, z: z)
        print(worldPos)
        
        plotRedSphere(radius: 0.05, worldPos: SCNVector3Make(worldPos.x, worldPos.y, worldPos.z))
    }
    
    func plotRedSphere(radius: Float, worldPos: SCNVector3) {
        let sphereGeo = SCNSphere(radius: CGFloat(radius))
        sphereGeo.firstMaterial?.diffuse.contents = UIColor.red
        let sphereNode = SCNNode(geometry: sphereGeo)
        
        sphereNode.name = "sphere"

        sphereNode.worldPosition = worldPos

        sceneView.scene.rootNode.addChildNode(sphereNode)
    }
    
    @objc func panGesture(sender: UIPanGestureRecognizer) {
        if planeNode != nil {
            self.planeNode.opacity = 1
            
            
            let translation = sender.translation(in: sender.view!)

            var newAngleX = (Float)(translation.y)*(Float)(Double.pi)/180.0
            newAngleX += currentAngleX
            var newAngleY = (Float)(translation.x)*(Float)(Double.pi)/180.0
            newAngleY += currentAngleY

            planeNode!.eulerAngles.x = newAngleX
            planeNode!.eulerAngles.y = newAngleY

            if(sender.state == UIGestureRecognizer.State.ended) {
                currentAngleX = newAngleX
                currentAngleY = newAngleY
            }

//             update plane equation
//            let normal = (planeNode.simdOrientation * simd_quatf(real: 0, imag: initNormal)) * planeNode.simdOrientation.inverse
//            planeEquation = simd_float4(normal.imag, simd_dot(normal.imag, planeNode.simdPosition))
//            print(planeEquation)
        }
    }
    
    @objc func pinchGesture(sender: UIPinchGestureRecognizer) {
        if decodeTube != nil && sender.state == .changed {
//            print("scale", sender.scale)
//            print("velocity", sender.velocity)
            let pinchScaleX = Float(sender.scale) * decodeTube!.scale.x
            let pinchScaleY =  Float(sender.scale) * decodeTube!.scale.y
            let pinchScaleZ =  Float(sender.scale) * decodeTube!.scale.z
            decodeTube!.scale = SCNVector3(pinchScaleX, pinchScaleY, pinchScaleZ)
            sender.scale = 1
            
            sceneView.scene.rootNode.childNodes.filter({ $0.name == "sphere" }).forEach({ $0.removeFromParentNode() })
        }
    }
    
    func placeTube() -> SCNNode? {
        if let currentFrame = sceneView.session.currentFrame {
            let tubeGeom = SCNTube(innerRadius: 0.1, outerRadius: 0.2, height: 0.3)
            let node = SCNNode(geometry: tubeGeom)

//            self.decodeTube.geometry?.firstMaterial?.diffuse.contents = UIColor.green
            node.name = "tubeNode"

            //Add node set distance in front of camera
            var translation = matrix_identity_float4x4
            translation.columns.3.x = 0
            translation.columns.3.y = 0
            translation.columns.3.z = -0.5
            let transform = simd_mul(currentFrame.camera.transform, translation)
            node.worldPosition = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            sceneView.scene.rootNode.addChildNode(node)
            return node
        }
        return nil
    }
    
    func placePlane() {
        if let currentFrame = sceneView.session.currentFrame {
            let planeGeo = SCNPlane(width: 0.4, height: 0.4)
            self.planeNode = SCNNode(geometry: planeGeo)
            
            self.planeNode.geometry?.firstMaterial?.diffuse.contents = UIColor(named: "blue")
            
            //Add node set distance in front of camera
            var translation = matrix_identity_float4x4
            translation.columns.3.x = 0
            translation.columns.3.y = 0
            translation.columns.3.z = -0.5
            let transform = simd_mul(currentFrame.camera.transform, translation)
            self.planeNode.worldPosition = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
//            self.planeNode.worldPosition = SCNVector3Make(translation.columns.3.x, translation.columns.3.y, translation.columns.3.z)
            
            // define plane equation initially
            let normal = (planeNode.simdOrientation * simd_quatf(real: 0, imag: initNormal)) * planeNode.simdOrientation.inverse
            planeEquation = simd_float4(normal.imag, simd_dot(normal.imag, planeNode.simdPosition))
            
            self.planeNode.opacity = 0
            
            sceneView.scene.rootNode.addChildNode(self.planeNode)
        }
    }
    
    func placeHeart() {
        self.heartNode = obj2SCNNode(name: "dTGA_reduced_5%")!

        if let currentFrame = sceneView.session.currentFrame {
            //Add node set distance in front of camera
            var translation = matrix_identity_float4x4
            translation.columns.3.x = 0
            translation.columns.3.y = 0
            translation.columns.3.z = -0.5
            let transform = simd_mul(currentFrame.camera.transform, translation)
            heartNode?.worldPosition = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)

            sceneView.scene.rootNode.addChildNode(self.heartNode)
        }
    }
    
    // MARK: - Voxelizing functions
    
    private func rnd() -> CGFloat {
        return 0.01 * CGFloat(SCALE_FACTOR) * ((CGFloat(arc4random()) / CGFloat(RAND_MAX)) - 0.5)
    }
    
    @IBAction func voxelize(node: SCNNode) {
        // Create MDLAsset from scene
        let tempScene = SCNScene()
        tempScene.rootNode.addChildNode(node)
        let asset = MDLAsset(scnScene: tempScene)
        
        // Create voxel grid from MDLAsset
//        let grid = MDLVoxelArray(asset: asset, divisions: 25, interiorShells: 0, exteriorShells: 0, patchRadius: 0.0)
        let grid = MDLVoxelArray(asset: asset, divisions: 100, patchRadius: 0.0)
//        grid.shellFieldInteriorThickness = 5
//        let grid = MDLVoxelArray
        if let voxelData = grid.voxelIndices() {   // retrieve voxel data
            // Create voxel parent node and add to scene
            _voxels?.removeFromParentNode()
            _voxels = SCNNode()
            self.sceneView.scene.rootNode.addChildNode(_voxels!)
            
            // Create the voxel node geometry
            let particle = SCNBox(width: 2.0 * SCALE_FACTOR, height: 2.0 * SCALE_FACTOR, length: 2.0 * SCALE_FACTOR, chamferRadius: 0.0)
            
//            // Get the character's texture map and convert to a bitmap
//            let contents = node.childNodes[0].geometry!.firstMaterial!.diffuse.contents
//            let url: URL // this sample assumes that the `diffuse` material property is an URL to an image
//            if let theUrl = contents as? URL {
//                url = theUrl
//            } else {
//                //### Or a relative path string to an image
//                let thePath = contents as! String
//                url = Bundle.main.url(forResource: thePath, withExtension: nil)!
//            }
//            let image: CGImage
//            #if os(iOS)
//                image = [[UIImage, imageWithContentsOfFile,:[url path]] CGImage]
//            #else
//                image = NSImage(byReferencing: url).cgImage(forProposedRect: nil, context: nil, hints: nil)!
//            #endif
//            let pixelData = image.dataProvider?.data!
//            let buf = CFDataGetBytePtr(pixelData)
//            let w = image.width
//            let h = image.height
//            let bpr = image.bytesPerRow // this sample assumes 8 bits per component
//            let bpp = image.bitsPerPixel / 8
            
            // Traverse the NSData voxel array and for each ijk index, create a voxel node positioned at its spatial location
            voxelData.withUnsafeBytes {voxelBytes in
                let voxels = voxelBytes.bindMemory(to: MDLVoxelIndex.self).baseAddress!
                let count = voxelData.count / MemoryLayout<MDLVoxelIndex>.size
                for i in 0..<count {
                    let position = grid.spatialLocation(ofIndex: voxels[i])
                    
//                    let OFFSET_FACTOR: CGFloat = 0.9
//                    // Determine color of the voxel by performing a hit test and then getting the texture coordinate at the point of intersection
//                    let tempFrom = SCNVector3Make(Float(position.x), Float(position.y), Float(position.z) + 1.0)
//                    let tempTo = SCNVector3Make(Float(position.x) * Float(OFFSET_FACTOR) , Float(position.y) * Float(OFFSET_FACTOR), Float(position.z) - 5.0)
//                    let tempOptions = [SCNHitTestOption.rootNode.rawValue : node, SCNHitTestOption.backFaceCulling.rawValue : false] as [String : Any]
//
//                    let results = self.sceneView.scene.rootNode.hitTestWithSegment(from: tempFrom, to: tempTo, options: tempOptions)
                    #if os(iOS)
                        var color = UIColor.darkGray // default voxel color
                    #else
                        var color = NSColor.darkGray
                    #endif
//                    if !results.isEmpty {
//                        let result = results[0]
//                        let tx = result.textureCoordinates(withMappingChannel: 0)
//                        // Get the bitmap pixel color at the texture coordinate
//                        let x = tx.x * CGFloat(w)
//                        let y = tx.y * CGFloat(h)
//                        let pixel = bpr * Int(round(y)) + bpp * Int(round(x))
//                        let r = CGFloat((buf?[pixel])!) / 255.0 // this sample code assumes that the first 3 components are R, G and B
//                        let g = CGFloat((buf?[pixel+1])!) / 255.0
//                        let b = CGFloat((buf?[pixel+2])!) / 255.0
//                        #if os(iOS)
//                            color = UIColor(red:r, green: g, blue: b, alpha: 1)
//                        #else
//                            color = NSColor(calibratedRed: r, green: g, blue:b, alpha: 1)
//                        #endif
//                    }
                    
                    // Create the voxel node and set its properties
                    let voxelNode = SCNNode(geometry: (particle.copy() as! SCNGeometry))
                    voxelNode.position = SCNVector3Make(Float(CGFloat(position.x) + rnd()), Float(CGFloat(position.y)), Float(CGFloat(position.z) + rnd()))
                    let material = SCNMaterial()
                    material.diffuse.contents = color
//                    material.selfIllumination.contents = "character.scnassets/textures/max_ambiant.png"
                    voxelNode.geometry!.firstMaterial = material
                    
                    // Add voxel node to the scene
                    _voxels!.addChildNode(voxelNode)
                }
            }
            _explodeUsingCubes = true
        }
    }

    func obj2SCNNode(name: String) -> SCNNode? {
        if let url = Bundle.main.url(forResource: name, withExtension: "obj", subdirectory: "art.scnassets") {
//            let asset = MDLAsset(url: url)
//            let scene = SCNScene(mdlAsset: asset)
            
            print(name)
            
            guard let scene = try? SCNScene(url: url, options: nil) else { return nil }
            
                        
            //assumes node we want is first child node
            //TO-DO: See how to change this for segmented objs
            let temp_node = scene.rootNode.childNodes[0]

            //change SCNNode transform so that center of SCNNode is center of it's SCNGeometry

            let (center, radius) = temp_node.boundingSphere

            temp_node.pivot = SCNMatrix4MakeTranslation(center.x, center.y, center.z)

            //scale SCNNode so that it is a reasonable size to the viewer
            //0.25 was choosen as object is set 0.5 units away from user
            let scale_change = 0.25 / radius

            temp_node.scale = SCNVector3(temp_node.scale.x * scale_change,
                                         temp_node.scale.y * scale_change,
                                         temp_node.scale.z * scale_change)

            return temp_node
            
        }
        return nil
    }
    
    // MARK: - Button Actions
    
    @objc func add(_sender: Any) {
//        placeHeart()
//        placePlane()
        self.decodeTube = placeTube()!
        voxelize(node: self.decodeTube)
        
//        placeTube()
        
        
        //create a light node
//        sceneView.scene.rootNode.addChildNode(self.createLightNode()!)
    }
    
    // Creating an adjustable light SCNNode
    func createLightNode()->SCNNode?{

        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.scale = SCNVector3(1,1,1)
        lightNode.light?.intensity = 600
        lightNode.castsShadow = true
        lightNode.position = SCNVector3Zero
        lightNode.light?.type = SCNLight.LightType.directional
        lightNode.light?.color = UIColor.white
        return lightNode
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
