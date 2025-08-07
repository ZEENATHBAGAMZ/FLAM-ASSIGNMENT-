// Model: FurnitureItem
struct FurnitureItem: Identifiable {
    let id = UUID()
    let name: String
    let usdzFileName: String
}
//ViewModel: FurniturePlacementViewModel
import Combine

class FurniturePlacementViewModel: ObservableObject {
    @Published var availableFurniture: [FurnitureItem] = [
        FurnitureItem(name: "Chair", usdzFileName: "chair.usdz"),
        FurnitureItem(name: "Sofa", usdzFileName: "sofa.usdz")
    ]
    
    @Published var selectedFurniture: FurnitureItem?
    @Published var scanningState: String = "Ready to scan"
}
// SceneController (ARKit Manager)
import ARKit
import RealityKit
import Combine

class SceneController: NSObject, ObservableObject {
    let arView: ARView = ARView(frame: .zero)
    private var cancellables = Set<AnyCancellable>()
    
    @Published var scanningState: String = "Initializing..."

    func startSession() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.sceneReconstruction = .meshWithClassification
        config.environmentTexturing = .automatic
        config.frameSemantics = .personSegmentationWithDepth
        
        arView.session.run(config)
        arView.debugOptions = [.showFeaturePoints, .showSceneUnderstanding]
        arView.automaticallyConfigureSession = true
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        arView.environment.sceneUnderstanding.options.insert(.receivesLighting)
        
        arView.session.delegate = self
    }

    func placeFurniture(modelName: String) {
        guard let modelEntity = try? ModelEntity.loadModel(named: modelName) else { return }

        let anchor = AnchorEntity(plane: .horizontal)
        modelEntity.generateCollisionShapes(recursive: true)
        modelEntity.scale = [0.5, 0.5, 0.5] // Adjust scaling if needed

        anchor.addChild(modelEntity)
        arView.scene.addAnchor(anchor)
    }

    // Gesture Support
    func installGestures(on entity: Entity) {
        entity.generateCollisionShapes(recursive: true)
        arView.installGestures([.rotation, .translation], for: entity)
    }
}
//AR Session Delegate – Room Detection Feedback
extension SceneController: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                DispatchQueue.main.async {
                    self.scanningState = "Detected surface: \(meshAnchor.geometry.faces.count) faces"
                }
            }
        }
    }
}
//SwiftUI View – Furniture AR View
struct ARFurnitureView: View {
    @StateObject var viewModel = FurniturePlacementViewModel()
    @StateObject var sceneController = SceneController()

    var body: some View {
        VStack {
            ARViewContainer(arView: sceneController.arView)
                .edgesIgnoringSafeArea(.all)

            ScrollView(.horizontal) {
                HStack {
                    ForEach(viewModel.availableFurniture) { item in
                        Button(action: {
                            viewModel.selectedFurniture = item
                            sceneController.placeFurniture(modelName: item.usdzFileName)
                        }) {
                            Text(item.name)
                                .padding()
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
            }.padding()

            Text("Status: \(viewModel.scanningState)")
                .onReceive(sceneController.$scanningState) { state in
                    viewModel.scanningState = state
                }
        }
        .onAppear {
            sceneController.startSession()
        }
    }
}
// ARViewContainer (UIViewRepresentable)
struct ARViewContainer: UIViewRepresentable {
    let arView: ARView

    func makeUIView(context: Context) -> ARView {
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
