/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The sample app's main view controller.
*/

import UIKit
import RealityKit
import ARKit
import Combine

class ViewController: UIViewController, ARSessionDelegate {

    @IBOutlet var arView: ARView!
    @IBOutlet weak var messageLabel: MessageLabel!
    
    // The 3D character to display.
    var character: BodyTrackedEntity?
    let characterOffset: SIMD3<Float> = [-1.0, 0, 0] // Offset the character by one meter to the left
    let characterAnchor = AnchorEntity()
    
    let jointNames3D = ["root", "hips_joint", "left_upLeg_joint", "left_leg_joint", "left_foot_joint", "left_toes_joint", "left_toesEnd_joint", "right_upLeg_joint", "right_leg_joint", "right_foot_joint", "right_toes_joint", "right_toesEnd_joint", "spine_1_joint", "spine_2_joint", "spine_3_joint", "spine_4_joint", "spine_5_joint", "spine_6_joint", "spine_7_joint", "left_shoulder_1_joint", "left_arm_joint", "left_forearm_joint", "left_hand_joint", "left_handIndexStart_joint", "left_handIndex_1_joint", "left_handIndex_2_joint", "left_handIndex_3_joint", "left_handIndexEnd_joint", "left_handMidStart_joint", "left_handMid_1_joint", "left_handMid_2_joint", "left_handMid_3_joint", "left_handMidEnd_joint", "left_handPinkyStart_joint", "left_handPinky_1_joint", "left_handPinky_2_joint", "left_handPinky_3_joint", "left_handPinkyEnd_joint", "left_handRingStart_joint", "left_handRing_1_joint", "left_handRing_2_joint", "left_handRing_3_joint", "left_handRingEnd_joint", "left_handThumbStart_joint", "left_handThumb_1_joint", "left_handThumb_2_joint", "left_handThumbEnd_joint", "neck_1_joint", "neck_2_joint", "neck_3_joint", "neck_4_joint", "head_joint", "jaw_joint", "chin_joint", "left_eye_joint", "left_eyeLowerLid_joint", "left_eyeUpperLid_joint", "left_eyeball_joint", "nose_joint", "right_eye_joint", "right_eyeLowerLid_joint", "right_eyeUpperLid_joint", "right_eyeball_joint", "right_shoulder_1_joint", "right_arm_joint", "right_forearm_joint", "right_hand_joint", "right_handIndexStart_joint", "right_handIndex_1_joint", "right_handIndex_2_joint", "right_handIndex_3_joint", "right_handIndexEnd_joint", "right_handMidStart_joint", "right_handMid_1_joint", "right_handMid_2_joint", "right_handMid_3_joint", "right_handMidEnd_joint", "right_handPinkyStart_joint", "right_handPinky_1_joint", "right_handPinky_2_joint", "right_handPinky_3_joint", "right_handPinkyEnd_joint", "right_handRingStart_joint", "right_handRing_1_joint", "right_handRing_2_joint", "right_handRing_3_joint", "right_handRingEnd_joint", "right_handThumbStart_joint", "right_handThumb_1_joint", "right_handThumb_2_joint", "right_handThumbEnd_joint"]
    
    let jointNames2D = ["head_joint", "neck_1_joint", "right_shoulder_1_joint", "right_forearm_joint", "right_hand_joint", "left_shoulder_1_joint", "left_forearm_joint", "left_hand_joint", "right_upLeg_joint", "right_leg_joint", "right_foot_joint", "left_upLeg_joint", "left_leg_joint", "left_foot_joint", "right_eye_joint", "left_eye_joint", "root"]

    

    
    // A tracked raycast which is used to place the character accurately
    // in the scene wherever the user taps.
    var placementRaycast: ARTrackedRaycast?
    var tapPlacementAnchor: AnchorEntity?
    
    var jointNameToEntityMap3D = [String: AnchorEntity]()

    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        arView.session.delegate = self
        
        // If the iOS device doesn't support body tracking, raise a developer error for
        // this unhandled case.
        guard ARBodyTrackingConfiguration.isSupported else {
            fatalError("This feature is only supported on devices with an A12 chip")
        }

        // Run a body tracking configration.
        let configuration = ARBodyTrackingConfiguration()
//        configuration.frameSemantics.insert(.bodyDetection)
        arView.session.run(configuration)
        

        
        arView.scene.addAnchor(characterAnchor)

        
        
        let jointMesh = MeshResource.generateSphere(radius: 0.01)
        let jointMaterial = SimpleMaterial(color: SimpleMaterial.Color.red, roughness: 0.0, isMetallic: false )
        
        
        
        for jointName in jointNames3D {
            jointNameToEntityMap3D[jointName] = AnchorEntity()
            let jointModelComponent = ModelComponent(mesh: jointMesh, materials: [jointMaterial])
            jointNameToEntityMap3D[jointName]?.components[ModelComponent.self] = jointModelComponent
            arView.scene.addAnchor(jointNameToEntityMap3D[jointName]!)
            
            jointNameToEntityMap3D[jointName]!.scale = [1.0, 1.0, 1.0]
            jointNameToEntityMap3D[jointName]!.isEnabled = false
        }
        
        
        

        
//         Asynchronously load the 3D character.
        var cancellable: AnyCancellable? = nil
        cancellable = Entity.loadBodyTrackedAsync(named: "character/robot").sink(
            receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    print("Error: Unable to load model: \(error.localizedDescription)")
                }
                cancellable?.cancel()
        }, receiveValue: { (character: Entity) in
            if let character = character as? BodyTrackedEntity {
                // Scale the character to human size
                character.scale = [1.0, 1.0, 1.0]
                self.character = character
                cancellable?.cancel()

            } else {
                print("Error: Unable to load model as BodyTrackedEntity")
            }
        })
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        
        for anchor in anchors {
            guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }
            // Update the position of the character anchor's position.
            let bodyPosition = simd_make_float3(bodyAnchor.transform.columns.3)
            characterAnchor.isEnabled = false
            characterAnchor.position = bodyPosition //+ characterOffset
//            characterAnchor.
            // Also copy over the rotation of the body anchor, because the skeleton's pose
            // in the world is relative to the body anchor's rotation.
            characterAnchor.orientation = Transform(matrix: bodyAnchor.transform).rotation
            if let character = character, character.parent == nil {
                // Attach the character to its anchor as soon as
                // 1. the body anchor was detected and
                // 2. the character was loaded.
                characterAnchor.addChild(character)
                
            }
            
            //3D SKELETON VISUALIZATION
            
            // Access to the Position of Root Node
            let hipWorldPosition = bodyAnchor.transform
            // Accessing the Skeleton Geometry
            let skeleton = bodyAnchor.skeleton
            // Accessing List of Transforms of all Joints Relative to Root
            let jointTransforms = skeleton.jointModelTransforms
            // Iterating over All Joints
            for (i, jointTransform) in jointTransforms.enumerated() {
//                print(jointTransform)
//                guard i != 0 else { print(skeleton.definition.jointNames[i]); continue}
//                jointNameToEntityMap[skeleton.definition.jointNames[i]]!.position = (simd_make_float3(jointTransform.columns.3)
//                    + simd_make_float3(hipWorldPosition.columns.3)) // root postion
////
//                jointNameToEntityMap[skeleton.definition.jointNames[i]]!.orientation = Transform(matrix: jointTransform).rotation
//                    + Transform(matrix: bodyAnchor.transform).rotation
                

                jointNameToEntityMap3D[skeleton.definition.jointNames[i]]!.move(to: jointTransform, relativeTo: characterAnchor)
                jointNameToEntityMap3D[skeleton.definition.jointNames[i]]!.isEnabled = true
                
                

            }
            
            
            
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
         // Accessing ARBody2D Object from ARFrame
         guard let person = frame.detectedBody as? ARBody2D else { return }
        // Use Skeleton Property to Access the Skeleton
//        print("hello")
        let skeleton2D = person.skeleton
         // Access Definition Object Containing Structure
         let definition = skeleton2D.definition
        print(definition.jointNames)
        
         // List of Joint Landmarks
         let jointLandmarks = skeleton2D.jointLandmarks
         // Iterate over All the Landmarks
         for (i, joint) in jointLandmarks.enumerated() {
         // Find Index of Parent
         let parentIndex = definition.parentIndices[i]
         // Check If It’s Not the Root
         guard parentIndex != -1 else { continue }

        // Find Position of Parent Index
        let parentJoint = jointLandmarks [parentIndex]
        
         }
        
//        frame.
     }
}
