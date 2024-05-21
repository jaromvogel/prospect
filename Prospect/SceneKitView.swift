//
//  SceneKitView.swift
//  Prospect
//
//  Created by Vogel Family on 5/11/24.
//

import SwiftUI
import Foundation
import ProcreateDocument
import SceneKit
import ZIPFoundation



struct SceneKitView: NSViewRepresentable {
    
    typealias UIViewType = SCNView
//    var view: SCNView = SCNView(frame: NSRect(origin: CGPointZero, size: CGSize(width: 100, height: 100)), options: ["prefferedRenderingApi": SCNRenderingAPI.metal])
    var view: SCNView = SCNView()
    
    var file: ProcreateDocumentType
    @Binding var scene_load_progress: CGFloat
    @Binding var show_meta: Bool
    
    init(file: ProcreateDocumentType, scene_load_progress: Binding<CGFloat>, show_meta: Binding<Bool>) {
        self.file = file
        self._scene_load_progress = scene_load_progress
        self._show_meta = show_meta
    }
    
    func makeNSView(context: Context) -> SCNView {
        view.allowsCameraControl = true
        
        view.backgroundColor = .clear
        view.autoenablesDefaultLighting = true
        view.rendersContinuously = true
//        view.debugOptions = [.showBoundingBoxes]
//        view.showsStatistics = true
        
//        let procreate_scene = load3DScene(file: file, view: view)
        view.scene = SCNScene()
        DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
            load3DScene(file: file, view: view, scene_load_progress: $scene_load_progress)
            file.procreate_doc?.view = view
            file.procreate_doc?.view?.scene = view.scene
        })
        
//        let camera = SCNCamera()
//        let cameranode = SCNNode()
//        cameranode.camera = camera
//        cameranode.position.z = 2.0
//        cameranode.position.x = 0.0
//        cameranode.position.y = 0.0
//        view.pointOfView = cameranode
//        view.defaultCameraController.inertiaEnabled = false
//
//        view.defaultCameraController.target = .init(0, 0, 0)
        
//        let testchild = SCNNode(geometry: SCNBox(width: 0.5, height: 1.4, length: 0.5, chamferRadius: 0))
//        procreate_scene.rootNode.addChildNode(testchild)
        
        view.delegate = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: SCNView, context: Context) {
//        load3DScene(file: file, view: view)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(view, file, $show_meta)
    }
    
    class Coordinator: NSObject, SCNSceneRendererDelegate {
        private let view: SCNView
        
        var file: ProcreateDocumentType
        var show_meta: Binding<Bool>
        
        init(_ view: SCNView, _ file: ProcreateDocumentType, _ show_meta: Binding<Bool>) {
            self.view = view
            self.file = file
            self.show_meta = show_meta
            
            super.init()
            
            //Tap Gesture
            let tapGesture = NSClickGestureRecognizer(target: self, action: #selector(tapDetected(sender:)))
            view.addGestureRecognizer(tapGesture)
        }
        
        // Not sure what the performance implications are here, but code in this function runs on every frame
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            
        }
        
        @objc func tapDetected (sender: NSClickGestureRecognizer) {
            // Dismiss metadata when tapping on the scene
            show_meta.wrappedValue = false
        }
        
        
    }
}


func load3DScene(file: ProcreateDocumentType, view: SCNView, scene_load_progress: Binding<CGFloat>) {

    // This stuff is all an abandoned attempt to load cached meshes. It's possible that would actually be the faster way to do this, but I kind of doubt it.
/*
    let scene = SCNScene()
    let unwrappedLayers = file.procreate_doc!.unwrappedLayers3D!
    for (index, layer) in unwrappedLayers.enumerated() {
//        print("layer name: \(layer.name)")
//        print("UUID: \(layer.textureSetComposite?.UUID)")
        for (meshindex, mesh) in layer.meshes!.enumerated() {
//            print(mesh.cachedMeshObject)
//            print("mesh index: \(mesh.cachedMeshObject?.meshIndex)")
//            print("mesh children: \(mesh.cachedMeshObject?.children)")
//            print("mesh indexBuffer uuid: \(mesh.cachedMeshObject?.indexBuffer?.uuid)")
//            print("mesh index count: \(mesh.cachedMeshObject?.indexCount)")
//            print("mesh vertex count: \(mesh.cachedMeshObject?.vertexCount)")
//            print("mesh vertexBuffer uuid: \(mesh.cachedMeshObject?.vertexPositionBuffer?.uuid)")

            
            // Load dilatedTriangles from Data?
            let dilTriData = getCachedMeshData(file: file.wrapper!, uuid: mesh.cachedMeshObject?.dilatedTriangleBuffer?.uuid)
//            print("dilated Triangle Data: \(dilTriData)")
//            dilTriData.forEach({ datapoint in
//                print(datapoint)
//            })
            
            
            // Load Vertex Position Data
            let vertexData = getCachedMeshData(file: file.wrapper!, uuid: mesh.cachedMeshObject?.vertexPositionBuffer?.uuid)
            print("vertex data: \(vertexData)")
//            vertexData.forEach({ datapoint in
//                print(datapoint)
//            })
            
            var arr2 = Array<UInt8>(repeating: 0, count: vertexData.count/MemoryLayout<UInt8>.stride)
            _ = arr2.withUnsafeMutableBytes { vertexData.copyBytes(to: $0) }
            print(arr2)
            
            let vertPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: vertexData.count/MemoryLayout<UInt8>.stride)
            let vertBuffer = view.device!.makeBuffer(bytes: vertPointer, length: vertexData.count, options: [])
            print("vertex buffer: \(vertBuffer)")
            let meshVertSource = SCNGeometrySource(buffer: vertBuffer!, vertexFormat: .float3, semantic: .vertex, vertexCount: mesh.cachedMeshObject!.vertexCount!, dataOffset: 3, dataStride: 12)
            
            // This could also be init'ed using data instead of buffer maybe?
            let meshVertSourceFromData = SCNGeometrySource(data: vertexData, semantic: .vertex, vectorCount: mesh.cachedMeshObject!.vertexCount!, usesFloatComponents: false, componentsPerVector: 3, bytesPerComponent: 12, dataOffset: 3, dataStride: 12)
//            print("meshVertSourceFromData: \(meshVertSourceFromData)")
            
            
            // Load Index Data
            let indexData = getCachedMeshData(file: file.wrapper!, uuid: mesh.cachedMeshObject?.indexBuffer?.uuid)
//            indexData.forEach({ datapoint in
//                print(datapoint)
//            })
            
            print("index data: \(indexData)")

            let indexPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: indexData.count/MemoryLayout<UInt8>.stride)
            let indexBuffer = view.device!.makeBuffer(bytes: indexPointer, length: indexData.count, options: [])
            print("index buffer: \(indexBuffer)")
            let meshIndexElement = SCNGeometryElement(buffer: indexBuffer!, primitiveType: .triangles, primitiveCount: mesh.cachedMeshObject!.dilatedTriangleCount!, bytesPerIndex: 4)
            print("meshIndexElement: \(meshIndexElement)")
            
            // This could also be init'ed using data instead of buffer maybe?
            let meshIndexElementFromData = SCNGeometryElement(data: indexData, primitiveType: .triangles, primitiveCount: mesh.cachedMeshObject!.dilatedTriangleCount!, bytesPerIndex: 4)
            print("meshIndexElementFromData: \(meshIndexElementFromData.data)")
            
            
            let meshGeometry = SCNGeometry(sources: [meshVertSource], elements: [meshIndexElement])
            let material = SCNMaterial()
            material.diffuse.contents = NSColor.yellow
            material.isDoubleSided = true
            meshGeometry.materials = [material]
            let meshnode = SCNNode(geometry: meshGeometry)
            scene.rootNode.addChildNode(meshnode)
            
            
            // Sanity Check - Create some custom geometry manually
            let testGeoSource = SCNGeometrySource(vertices: [
                SCNVector3(x: -0.2, y: -0.2, z: 0),
                SCNVector3(x: 0, y: 0.2, z: 0),
                SCNVector3(x: 0.2, y: -0.2, z: 0)
            ])
            let testIndices: [UInt8] = [
                0, 1, 2
            ]
            let testGeoElement = SCNGeometryElement(indices: testIndices, primitiveType: .triangles)
            let testGeo = SCNGeometry(sources: [testGeoSource], elements: [testGeoElement])
            let testMat = SCNMaterial()
            testMat.diffuse.contents = NSColor.red
            testMat.isDoubleSided = true
            testGeo.materials = [testMat]
            let testNode = SCNNode(geometry: testGeo)
            scene.rootNode.addChildNode(testNode)
            
//            let testsphere = SCNNode(geometry: SCNSphere(radius: 0.1))
//            scene.rootNode.addChildNode(testsphere)
        }
    }
 */
    let scene = get3DScene(file: file.wrapper!, meshExtension: file.procreate_doc?.meshExtension)
    scene.isPaused = false
    view.scene = scene
    
    let allMaterials = file.procreate_doc!.unwrappedLayers3D!

    
    var counter:CGFloat = 0
    
    DispatchQueue.global(qos: .userInteractive).async {
        DispatchQueue.concurrentPerform(iterations: allMaterials.count, execute: { index in
            autoreleasepool {
                
                let material = allMaterials[index]

                // We're loading each texture (diffuse, metalness, and roughness), then updating the counter after each is loaded
                guard let diffuse_texture = file.procreate_doc?.getLayer(material.textureSetComposite?.albedoLayer, file.wrapper!) else { return }
                counter += 1
                // We need to jump back to the main thread each time in order to update UI
                DispatchQueue.main.sync {
                    scene_load_progress.wrappedValue = counter / CGFloat(allMaterials.count * 3)
                }
                guard let metalness_texture = file.procreate_doc?.getLayer(material.textureSetComposite?.metallicLayer, file.wrapper!) else { return }
                counter += 1
                DispatchQueue.main.sync {
                    scene_load_progress.wrappedValue = counter / CGFloat(allMaterials.count * 3)
                }
                guard let roughness_texture = file.procreate_doc?.getLayer(material.textureSetComposite?.roughnessLayer, file.wrapper!) else { return }
                counter += 1

                DispatchQueue.main.sync {
                    // update the progress bar
                    scene_load_progress.wrappedValue = counter / CGFloat(allMaterials.count * 3)
                    
                    material.meshes?.forEach({ mesh in

//                        let applicable_mesh = scene.rootNode.childNode(withName: mesh.name!, recursively: true)
                        let applicable_meshes = scene.rootNode.childNodes(passingTest: { (node, stop) -> Bool in
                            if (node.geometry !== nil) {
                                return node.name == mesh.name!
                            }
                            return false
                        })
//                        print("applicable_meshes: \(applicable_meshes)")
                        var mats:[SCNMaterial] = []
                        applicable_meshes.forEach({ mesh in
                            let submats = mesh.geometry?.materials.filter({ $0.name == material.originalName })
                            submats?.forEach({ submat in
                                mats.append(submat)
                            })
                        })
//                        let mats = applicable_mesh?.geometry?.materials.filter({ $0.name == material.originalName })
                        mats.forEach({ mat in
                            // make sure to loop through materials
                            if (mat.name == material.originalName) {
                                mat.diffuse.contents = diffuse_texture
                                mat.metalness.contents = metalness_texture
                                mat.roughness.contents = roughness_texture
                            }
                            if let normalUrl = mat.normal.contents as? URL {
                                if let normalImg = getUSDZEmbeddedTexture(file: file.wrapper, textureUrl: normalUrl, meshExtension: file.procreate_doc?.meshExtension ?? "usdz") {
                                    mat.normal.contents = normalImg
                                }

                            }
                            if let ambientOccUrl = mat.ambientOcclusion.contents as? URL {
                                if let ambOccImg = getUSDZEmbeddedTexture(file: file.wrapper, textureUrl: ambientOccUrl, meshExtension: file.procreate_doc?.meshExtension ?? "usdz") {
                                    mat.ambientOcclusion.contents = ambOccImg
                                }
                            }
                        })
                        
                    })
                    
                }
            }

        })
    }

}

struct VertexData {
    var x, y, z: CGFloat // Position
    var nx, ny, nz: CGFloat // Normal
    var s, t: CGFloat // Texture Coords
}


// This is a bit hacky
// Basically, usdz files don't give a url for embedded texture data.
// Instead, they include an offset and a data length for which part of the USDZ file
// represents that texture. This function parses that and tries to read
// the image data from the file.

func getUSDZEmbeddedTexture(file: FileWrapper?, textureUrl: URL, meshExtension: String?) -> NSImage? {
    // First, get the usdz file data from the archive
    guard let file = file else { return nil }
    let archive = Archive(data: file.regularFileContents!, accessMode: .read, preferredEncoding: nil)
       
    var usdz_data:Data = Data()
    
    let path:String = "Mesh/Mesh.".appending(meshExtension ?? "usdz")

    let entry = archive![path]
    
    do {
        // DEBUG MODE
        // try _ = archive!.extract(entry!, bufferSize: UInt32(100000000), skipCRC32: true, consumer: { (data) in
        try _ = archive!.extract(entry!, bufferSize: UInt32(100000000), skipCRC32: false, consumer: { (data) in
            usdz_data.append(data)
        })
    } catch {
        NSLog("\(error)")
    }
    
    
    // I think I need to pick apart the textureUrl to get the offset and size,
    // then add that on to the end of the mesh url that I *can* access
    let imgInfo = textureUrl.absoluteString.split(separator: "?").last
    let imgDataStart = imgInfo?.split(separator: "&")[0].split(separator: "=")[1]
    let imgDataLength = imgInfo?.split(separator: "&")[1].split(separator: "=")[1]
    let start = Int(imgDataStart ?? "0")
    let length = Int(imgDataLength ?? "0")
    let adjData = usdz_data.subdata(in: start!..<start!+length!)
    let texImage = NSImage(data: adjData)
    return texImage
}
