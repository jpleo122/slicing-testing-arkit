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
    
    var tubeNode: SCNNode!
    var planeNode: SCNNode!
    var heartNode: SCNNode!
    var planeEquation: simd_float4!
    
    // gestures
    var currentAngleY: Float = 0.0
    var currentAngleX: Float = 0.0
    var planeNormal: simd_float3 = simd_float3(x: 0, y: 0, z: -1)
    let initNormal: simd_float3 = simd_float3(x: 0, y: 0, z: -1)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        self.sceneView.autoenablesDefaultLighting = true
        
        // Show statistics such as fps and timing information
        // sceneView.showsStatistics = true
        
        // Create a new scene
        // let scene = SCNScene(named: "art.scnassets/ship.scn")!
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // add button actions
        addButton.addTarget(self, action: #selector(add(_sender:)), for: .touchDown)
        
        // add panning gesture to rotate heartnode
        let panRotateRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGesture(sender:)))
        sceneView.addGestureRecognizer(panRotateRecognizer)

        //add pinch gesture for moving plane along normal
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
    
    
    func updatePlaneEquation() {
        // update normal
        let normal = (self.planeNode.simdOrientation * simd_quatf(real: 0, imag: self.initNormal)) * self.planeNode.simdOrientation.inverse
        
        self.planeNormal = normal.imag
//        print(normal.imag)
        self.planeEquation = simd_float4(self.planeNormal, simd_dot(self.planeNormal, self.planeNode.simdWorldPosition - self.heartNode.simdWorldPosition))
//        self.planeEquation = simd_float4(normal.imag, 0)
        
        print(self.planeEquation)
        
        let planeEquationValue = NSValue(scnVector4: SCNVector4Make(self.planeEquation.x, self.planeEquation.y, self.planeEquation.z, self.planeEquation.w))
        self.heartNode.geometry?.setValue(planeEquationValue, forKey: "plane_equation")
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
//            // update plane equation
//            let normal = (planeNode.simdOrientation * simd_quatf(real: 0, imag: self.planeNormal)) * planeNode.simdOrientation.inverse
//            print(normal.imag)
//            planeEquation = simd_float4(normal.imag, simd_dot(normal.imag, planeNode.simdPosition))
//            planeEquation = simd_float4(normal.imag, 0)
//
//            let planeEquationValue = NSValue(scnVector4: SCNVector4Make(planeEquation.x, planeEquation.y, planeEquation.z, planeEquation.w))
//            self.heartNode.geometry?.setValue(planeEquationValue, forKey: "plane_equation")
            self.updatePlaneEquation()
        }
    }
    
    @objc func pinchGesture(sender: UIPinchGestureRecognizer) {
        if self.planeNode != nil && sender.state == .changed {
            print("scale", sender.scale)
            print("velocity", sender.velocity)
            let pinchScaleX = Float(sender.scale - 1) * self.planeNormal.x
            let pinchScaleY =  Float(sender.scale - 1) * self.planeNormal.y
            let pinchScaleZ =  Float(sender.scale - 1) * self.planeNormal.z
//            let tempVec = self.planeNode.simdPosition =
            
            self.planeNode.simdWorldPosition += simd_float3(pinchScaleX, pinchScaleY, pinchScaleZ)
//            self.planeNode!.scale = SCNVector3(pinchScaleX, pinchScaleY, pinchScaleZ)
            sender.scale = 1
            
            self.updatePlaneEquation()
        }
    }
    
    func placeTube() {
        if let currentFrame = sceneView.session.currentFrame {
            let tubeGeom = SCNTube(innerRadius: 0.1, outerRadius: 0.2, height: 0.3)
            self.tubeNode = SCNNode(geometry: tubeGeom)

//            self.decodeTube.geometry?.firstMaterial?.diffuse.contents = UIColor.green
//            self.tubeNode.name = "tubeNode"

            //Add node set distance in front of camera
            var translation = matrix_identity_float4x4
            translation.columns.3.x = 0
            translation.columns.3.y = 0
            translation.columns.3.z = -0.5
            let transform = simd_mul(currentFrame.camera.transform, translation)
            self.tubeNode.worldPosition = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            addShaders(node: self.tubeNode)
            
            sceneView.scene.rootNode.addChildNode(self.tubeNode)
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
            
//            // define plane equation initially
//            let normal = (planeNode.simdOrientation * simd_quatf(real: 0, imag: self.planeNormal)) * planeNode.simdOrientation.inverse
//            print(normal.imag)
//            // planeEquation = simd_float4(normal.imag, simd_dot(normal.imag, planeNode.simdPosition))
//            planeEquation = simd_float4(normal.imag, 0)
//            self.updatePlaneEquation()
            
//            self.planeNode.opacity = 0
            
            sceneView.scene.rootNode.addChildNode(self.planeNode)
        }
    }
    
    func placeHeart() {
        self.heartNode = obj2SCNNode(name: "dTGA_snapped")!

        if let currentFrame = sceneView.session.currentFrame {
            //Add node set distance in front of camera
            var translation = matrix_identity_float4x4
            translation.columns.3.x = 0
            translation.columns.3.y = 0
            translation.columns.3.z = -0.5
            let transform = simd_mul(currentFrame.camera.transform, translation)
            heartNode?.worldPosition = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            self.updatePlaneEquation()
            
            addShaders(node: self.heartNode)

            sceneView.scene.rootNode.addChildNode(self.heartNode)
        }
    }
    
    func addShaders(node: SCNNode) {
        let planeEquationValue = NSValue(scnVector4: SCNVector4Make(planeEquation.x, planeEquation.y, planeEquation.z, planeEquation.w))
        node.geometry?.setValue(planeEquationValue, forKey: "plane_equation")
        // add geometry shader code
//        let geometryModiferString = """
//        #pragma arguments \
//        varying float clipFragment; \
//        #pragma body \
//        uniform vec4 plane_equation; \
//        float distance = dot(_geometry.position.xyz, plane_equation.xyz) + plane_equation.w; \"
//        if (distance <= 0.0) { \
//            clipFragment = 1.0; \
//        } else { \
//            clipFragment = 0.0; \
//        }
//        """
        
        // add geometry shader code
//        let geometryModiferString = """
//        #pragma arguments \
//        varying float clipFragment; \
//        #pragma body \
//        uniform vec4 plane_equation; \
//        float distance = dot(_geometry.position.xyz, plane_equation.xyz) + plane_equation.w; \
//        if (distance <= 0.0) { \
//            clipFragment = 1.0; \
//        } else { \
//            clipFragment = 0.0; \
//        }
//        """
        
//        let sunShader = """
//        uniform vec4 plane_equation; \
//
//        float theta1 = atan2(_geometry.position.x, _geometry.position.y); \
//        float theta2 = atan2(_geometry.position.x, _geometry.position.z); \
//        float pi = 3.14159; \
//
//        float distance = dot(_geometry.position.xyz, plane_equation.xyz) + plane_equation.w; \
//
//        if (distance > 0.0) { \
//            _geometry.position.xyz += _geometry.position.xyz * 0.2 \
//                * sin(theta1 * pi - u_time * 2) * sin(6.0 * theta1) \
//                * cos(7.0 * theta2); \
//        }
//        """
//        print(self.planeEquation)
        
//        let sunShader = """
//        #include <metal_stdlib> \
//
//        #pragma varyings \
//        float clipFragment \
//
//        #pragma arguments \
//        vec4 plane_equation; \
//
//        #pragma body \
//
//        float distance = dot(_geometry.position.xyz, plane_equation.xyz) + plane_equation.w;
//
//        if (distance > 0.0) { \
//            out.clipFragment = 1.0 \
//        } else { \
//            out.clipFragment = 0.0 \
//        }
//        """
        
        let sunShader = """
        #include <metal_stdlib>

        #pragma arguments
        float4 plane_equation;

        #pragma varyings
        float clipFragment;

        #pragma body
        float distance = dot(_geometry.position.xyz, plane_equation.xyz) + plane_equation.w;

        if (distance > 0.0) {
            out.clipFragment = 1.0;
        } else {
            out.clipFragment = 0.0;
        }
        """
        
        let fragment = """
        #include <metal_stdlib>

        #pragma varyings
        float clipFragment;

        #pragma body
        if (in.clipFragment > 0.0) {
            discard_fragment();
        }
        """
        
//        let surface = """
//        #include <metal_stdlib>
//
//        #pragma varyings
//        float clipFragment;
//
//        #pragma body
//        _surface.diffuse = float4(_surface.diffuse.rgb * in.clipFragment, in.clipFragment);
//        """
        
//        let surface = """
//        uniform vec4 plane_equation;
//
//        float a = 0.5;
//
//        float distance = dot(_surface.position.xyz, plane_equation.xyz) + plane_equation.w;
//
//        if (distance > 0.0) {
//            _surface.diffuse = vec4(_surface.diffuse.rgb * a, a);
//        }
//        """
        
//        let fragment = """
//        #include <metal_stdlib> \
//
//        #pragma body \
//        if (in.clipFragment > 0.0) { \
//            discard_fragment(); \
//        }
//        """
        
//        let sunSurface = """
//        #pragma transparent \
//        #pragma body \
//
//        float dotProductEdge = 0.5; \
//
//        float dotProduct = dot(_surface.view, _surface.normal); \
//        dotProduct = dotProduct < 0.0 ? 0.0 : dotProduct; \
//
//        _surface.diffuse.rgb = vec3(1.0, 1.0, 0.0); \
//
//        if (dotProduct <= dotProductEdge) { \
//            float a = dotProduct / dotProductEdge; \
//            _surface.diffuse = vec4(_surface.diffuse.rgb * a, a); \
//        }
        
//        // add fragment shader code
//        let fragmentModifierString = """
//        varying float clipFragment; \
//        #pragma transparent \
//        #pragma body \
//        if (clipFragment > 0.0) { \
//            discard_fragment(); \
//        }
//        """
        
        // add shaders to node geometry
        node.geometry?.shaderModifiers = [
            SCNShaderModifierEntryPoint.geometry: sunShader,
            SCNShaderModifierEntryPoint.fragment: fragment,
//            SCNShaderModifierEntryPoint.surface: surface,
        ]
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
            print(center)

//            temp_node.pivot = SCNMatrix4MakeTranslation(center.x, center.y, center.z)

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
        placePlane()
//        placeTube()
        placeHeart()
        
        //create a light node
        sceneView.scene.rootNode.addChildNode(self.createLightNode()!)
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
