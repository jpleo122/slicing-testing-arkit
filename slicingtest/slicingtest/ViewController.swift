//
//  ViewController.swift
//  slicingtest
//
//  Created by Jonathan Leo on 12/20/20.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var addButton: UIButton!
    
    var decodeTube: SCNNode!
    var planeNode: SCNNode!
    var heartNode: SCNNode!
    var planeEquation: simd_float4!
    
    // gestures
    var currentAngleY: Float = 0.0
    var currentAngleX: Float = 0.0
    var initNormal: simd_float3 = simd_float3(x: 0, y: 0, z: -1)
    
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
    
    func updateSlicingPlane(refNode: SCNNode) {
        // update plane equation
        let normal = (planeNode.simdOrientation * simd_quatf(real: 0, imag: initNormal)) * planeNode.simdOrientation.inverse
        self.planeEquation = simd_float4(normal.imag, simd_dot(normal.imag, planeNode.simdPosition))
        
        // delete sliced models currently in scene
        sceneView.scene.rootNode.childNodes.filter({ $0.name == "slicedNode" }).forEach({ $0.removeFromParentNode() })
        
        // update sliced model and re add to scene
        let node = decodeGeom(node: refNode)!
        sceneView.scene.rootNode.addChildNode(node)
        node.transform = refNode.transform
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

            // update spheres
//            sceneView.scene.rootNode.childNodes.filter({ $0.name == "sphere" }).forEach({ $0.removeFromParentNode() })
            if sender.state == .ended {
                updateSlicingPlane(refNode: self.heartNode)
                self.heartNode.opacity = 0
            }
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
            decodeGeom(node: decodeTube)
        }
    }
    
    func placeTube() {
        if let currentFrame = sceneView.session.currentFrame {
            let tubeGeom = SCNTube(innerRadius: 0.1, outerRadius: 0.2, height: 0.3)
            self.decodeTube = SCNNode(geometry: tubeGeom)

//            self.decodeTube.geometry?.firstMaterial?.diffuse.contents = UIColor.green
            self.decodeTube.name = "tubeNode"

            //Add node set distance in front of camera
            var translation = matrix_identity_float4x4
            translation.columns.3.x = 0
            translation.columns.3.y = 0
            translation.columns.3.z = -0.5
            let transform = simd_mul(currentFrame.camera.transform, translation)
            self.decodeTube.worldPosition = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            sceneView.scene.rootNode.addChildNode(self.decodeTube)
        }
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
    
    // MARK: - Slicing functions
    
    // from https://stackoverflow.com/questions/17250501/extracting-vertices-from-scenekit
    func decodeGeom(node: SCNNode, scale: Float = 1) -> SCNNode? {
        let start = CFAbsoluteTimeGetCurrent()
        
        // 1% took around 5 seconds
        // 5% took 156 seconds
        // 10% took 11 minutes (660 seconds)
        
        let vertices = decodeVertices(node: node)
        let indices = decodeIndices(node: node)
        var normals = decodeNormal(node: node)
        
        if vertices == nil || indices == nil {
            print("Couldn't decode geometry")
            return nil
        }
    
        
        let transVert = vertices!.map{SCNVector3Make($0.x * scale, $0.y * scale, $0.z * scale)}
        
        let returnSlice = slice(vertices: transVert, transform: node.simdTransform, plane: self.planeEquation, indices: indices!, normals: normals!)
        
        let slicedVertices = returnSlice.0
        let slicedIndices = returnSlice.1
        let slicedNormals = returnSlice.2
        
        
        // Code below is to make an SCNNode of the sliced object
        
        let slicedSource = SCNGeometrySource(vertices: slicedVertices)
        let slicedElements = SCNGeometryElement(indices: slicedIndices, primitiveType: (node.geometry?.elements.first?.primitiveType)!)
        let slicedNormalsSource = SCNGeometrySource(normals: slicedNormals)
        
        // Right now this doesn't use the normalSource. Add slicedNormalSource to the sources array to use it
//        let slicedGeometry = SCNGeometry(sources: [slicedSource], elements:[slicedElements])
        let slicedGeometry = SCNGeometry(sources: [slicedSource, slicedNormalsSource], elements: [slicedElements])

        
        // Code below is to make an SCNNode of the original object
        
        // make scn node from decomposed source and elements
//        let source = SCNGeometrySource(vertices: transVert)
//        let normalSource = SCNGeometrySource(normals: normals!)
//        let element = SCNGeometryElement(indices: indices!, primitiveType: (node.geometry?.elements.first?.primitiveType)!)
//
//        let geometry = SCNGeometry(sources: [source, normalSource], elements: [element])
        
                
        // To show the original object: return SCNNode(geometry: geometry)
        // To show the sliced object: return SCNNode(geometry: geometry)
        
        // add name to node for easier deletion later
        let slicedNode = SCNNode(geometry: slicedGeometry)
        slicedNode.name = "slicedNode"
        
        let diff = CFAbsoluteTimeGetCurrent() - start
        print("Took \(diff) seconds")
        
        return slicedNode
        
        // sceneView.scene.rootNode.addChildNode(self.decodeTube)

    }
    
    func decodeVertices(node: SCNNode) -> [SCNVector3]? {
        let nodeSources = node.geometry?.sources(for: SCNGeometrySource.Semantic.vertex)
        if let nodeSource = nodeSources?.first {
            let stride = nodeSource.dataStride
            let offset = nodeSource.dataOffset
            let componentsPerVector = nodeSource.componentsPerVector
            let bytesPerVector = componentsPerVector * nodeSource.bytesPerComponent

            let vectors = [SCNVector3](repeating: SCNVector3Zero, count: nodeSource.vectorCount)
            let vertices = vectors.enumerated().map({
                (index: Int, element: SCNVector3) -> SCNVector3 in
                let vectorData = UnsafeMutablePointer<Float>.allocate(capacity: componentsPerVector)
                let byteRange = Range(NSMakeRange(index * stride + offset, bytesPerVector))
                let buffer = UnsafeMutableBufferPointer(start: vectorData, count: componentsPerVector)
                nodeSource.data.copyBytes(to: buffer, from: byteRange)
                return SCNVector3Make(buffer[0], buffer[1], buffer[2])
            })
            
            return vertices
        }
        return nil
    }
    
    func decodeNormal(node: SCNNode) -> [SCNVector3]? {
        let nodeSources = node.geometry?.sources(for: SCNGeometrySource.Semantic.normal)
        if let nodeSource = nodeSources?.first {
            let stride = nodeSource.dataStride
            let offset = nodeSource.dataOffset
            let componentsPerVector = nodeSource.componentsPerVector
            let bytesPerVector = componentsPerVector * nodeSource.bytesPerComponent

            let vectors = [SCNVector3](repeating: SCNVector3Zero, count: nodeSource.vectorCount)
            let vertices = vectors.enumerated().map({
                (index: Int, element: SCNVector3) -> SCNVector3 in
                let vectorData = UnsafeMutablePointer<Float>.allocate(capacity: componentsPerVector)
                let byteRange = Range(NSMakeRange(index * stride + offset, bytesPerVector))
                let buffer = UnsafeMutableBufferPointer(start: vectorData, count: componentsPerVector)
                nodeSource.data.copyBytes(to: buffer, from: byteRange)
                return SCNVector3Make(buffer[0], buffer[1], buffer[2])
            })
            
            return vertices
        }
        return nil
    }
    
    func decodeIndices(node: SCNNode) -> [UInt32]? {
        let nodeElements = node.geometry?.elements
        print(nodeElements!.count)
        var appendTo: [UInt32] = []
        for nodeElement in nodeElements! {
            let bytesPerIndex = nodeElement.bytesPerIndex
            let primitiveType = nodeElement.primitiveType
            let primitiveCount = nodeElement.primitiveCount
            
            // only decodes indices for triangles
            if primitiveType == SCNGeometryPrimitiveType.triangles {
                // 3 is used because of triangles
                let indexVector = [UInt32](repeating: 0, count: primitiveCount * 3)
                let indices = indexVector.enumerated().map({
                    (index: Int, element: UInt32) -> UInt32 in
                    let indexData = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
                    let byteRange = Range(NSMakeRange(index * bytesPerIndex, bytesPerIndex))
                    let buffer = UnsafeMutableBufferPointer(start: indexData, count: 1)
                    nodeElement.data.copyBytes(to: buffer, from: byteRange)
                    return UInt32(buffer[0])
                })
                for ind in indices{
                    appendTo.append(ind)
                }
            }
        }
        return appendTo
    }
    
    func slice(vertices: [SCNVector3], transform: simd_float4x4, plane: simd_float4, indices: [UInt32], normals: [SCNVector3]) -> ([SCNVector3], [UInt32], [SCNVector3]) {
       
        // Part 1: Array of Triangles is an array of array of three vertices that form a triangle.
        // It converts triplets of indices to triplets of vertices
        
        var arrayOfTriangles = [[SCNVector3]]()
        for i in stride(from: 0, to: indices.count, by: 3){
            var triangle = [SCNVector3]()
            for j in stride(from: i, to: i + 3, by: 1){
                // TO-DO Fix index out of range error that sometimes occurs here
                triangle.append(vertices[Int(indices[j])])
            }
            arrayOfTriangles.append(triangle)
        }

        
        // Part 2: choosing which vertices are chosen for slicing and keeping track of the deleted ones
        // Big assumption: the order of indices of normals correspond to the order of indices of vertices
        // Adds the normals when the vertices are added
        
        var newVertices = [SCNVector3]()
        var newNormals = [SCNVector3]()
        var deletedVertices = [SCNVector3]()
        var counter = 0
        for vertex in vertices {
            let tempVec = simd_float4(x: vertex.x, y: vertex.y, z: vertex.z, w: 1)
            var worldVec = transform * tempVec
            worldVec.w = -1
            
            let distance = simd_dot(worldVec, plane)
            
            if distance < 0 {
                // plotRedSphere(radius: 0.025, worldPos: SCNVector3Make(worldVec.x, worldVec.y, worldVec.z))
                
                // The code below makes sure that vertices are only added if they are not already in the
                // array. Having no repeats is important for part 4 to work.
                
                var addVertex = true
                for vertexCheck in newVertices {
                    if vertexCheck.x == vertex.x && vertexCheck.y == vertex.y && vertexCheck.z == vertex.z {
                        addVertex = false
                        break
                    }
                }
                if addVertex {
                    newVertices.append(vertex)
                    newNormals.append(normals[counter])
                }

            }
            else {
                deletedVertices.append(vertex)
            }
            counter += 1
        }

        
        // Part 3: Removes any triangles which contain a deleted vertex from part 2 as any of its vertices
        
        for i in stride(from: arrayOfTriangles.count - 1, to: 0, by: -1) {
            let arrayAtIndex = arrayOfTriangles[i]
            
            // To do: Replace the bool part with a break statement to break out of the deletedVertex for loop
            
            var bool = true
            for deletedVertex in deletedVertices {
                if bool {
                    for elem in arrayAtIndex {
                        if elem.x == deletedVertex.x && elem.y == deletedVertex.y && elem.z == deletedVertex.z {
                            arrayOfTriangles.remove(at: i)
                            bool = false
                        }
                    }
                }
            }
        }

        
        // Part 4: Creates an array of indices based off of the array of triangles.
        // Converts from triplets of vertices to triplets of indices, but they're not array in arrays
        
        var newIndices = [UInt32]()
        for triangle in arrayOfTriangles {
            for elem in triangle {
                var count = 0
                for vertex in newVertices {
                    if vertex.x == elem.x && vertex.y == elem.y && vertex.z == elem.z {
                        newIndices.append(UInt32(count))
                    }
                    count += 1
                }
            }
        }
    
        
        return (newVertices, newIndices, newNormals)
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
        placeHeart()
        placePlane()
        
//        let node = decodeGeom(node: self.decodeTube, scale: 0.33)!
//        sceneView.scene.rootNode.addChildNode(node)
//        node.transform = self.decodeTube.transform
//
//        self.decodeTube.opacity = 0
        
//        let node = decodeGeom(node: self.heartNode)!
//        sceneView.scene.rootNode.addChildNode(node)
//        node.transform = self.heartNode.transform
//
//        self.heartNode.opacity = 0
        
        //create a light node
        sceneView.scene.rootNode.addChildNode(self.createLightNode()!)
                
//        let initTubeNode = sceneView.scene.rootNode.childNode(withName: "tubeNode", recursively: false)!
//
//        self.decodeTube = decodeGeom(node: initTubeNode, scale: 0.33)
//        sceneView.scene.rootNode.addChildNode(self.decodeTube)
//        self.decodeTube.transform = initTubeNode.transform
//
//        sceneView.scene.rootNode.childNodes.filter({ $0.name == "tubeNode" }).forEach({ $0.removeFromParentNode() })
//        sceneView.scene.rootNode.addChildNode(self.decodeTube)
        
//        heartNode = obj2SCNNode(name: "dTGA_reduced")
//
//        if let currentFrame = sceneView.session.currentFrame {
//            //Add node set distance in front of camera
//            var translation = matrix_identity_float4x4
//            translation.columns.3.x = 0
//            translation.columns.3.y = 0
//            translation.columns.3.z = -0.5
//            let transform = simd_mul(currentFrame.camera.transform, translation)
//            heartNode?.worldPosition = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
//
//            sceneView.scene.rootNode.addChildNode(heartNode!)
//        }
        
//        decodeGeom(node: self.heartNode)
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
