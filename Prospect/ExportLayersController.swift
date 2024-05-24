//
//  ExportLayersController.swift
//  Prospect
//
//  Created by Vogel Family on 2/25/21.
//

import Foundation
import Cocoa
import ProcreateDocument
import UniformTypeIdentifiers


public class exportLayersController {
    var procreateFile: ProcreateDocumentType?
    var exportFilename: String?
    var exportFlattened: Bool
    var fileurl: String?
    
    init(procreateFile: ProcreateDocumentType, exportFilename: String?, exportFlattened: Bool, fileurl: String) {
        self.procreateFile = procreateFile
        self.exportFilename = exportFilename
        self.exportFlattened = exportFlattened
        self.fileurl = fileurl
    }
    
    var formats:Array<String>?
    var selectedFormat:NSBitmapImageRep.FileType?
    let panel:NSSavePanel = NSSavePanel()
    
    @objc func presentDialog(_ sender: Any?) {
        
        formats = ["png", "bmp", "tiff"]
        selectedFormat = .png
        panel.nameFieldLabel = "Save image as:"
        // Check for '/' character in filename and handle it
        let filename = exportFilename?.replacingOccurrences(of: "/", with: ":")
        panel.nameFieldStringValue = "\(filename ?? "untitled_artwork")"
        panel.isExtensionHidden = true
        panel.canCreateDirectories = true
        
        panel.setFrame(NSRect(x: 0, y: 0, width: 800, height: 500), display: true)
        
        
        // Add file format selector:
        let popupButton = NSPopUpButton(
            frame: NSRect(x: 0, y: 0, width: 300, height: 40),
            pullsDown: false)
        popupButton.removeAllItems()
        popupButton.addItems(withTitles: formats!)
        popupButton.selectItem(at: 0)
        popupButton.action = #selector(changeFileFormat(_:))
        popupButton.target = self
        
        let label = NSTextField()
        label.stringValue = "File Format:"
        label.isEditable = false
        label.isSelectable = false
        label.drawsBackground = false
        label.isBezeled = false
        
        let accessoryView = NSView()
        accessoryView.translatesAutoresizingMaskIntoConstraints = false
        accessoryView.heightAnchor.constraint(equalToConstant: 40.0).isActive = true
        accessoryView.widthAnchor.constraint(greaterThanOrEqualToConstant: panel.frame.width - 200).isActive = true
        panel.accessoryView = accessoryView
        
        accessoryView.addSubview(popupButton)
        popupButton.translatesAutoresizingMaskIntoConstraints = false
        popupButton.trailingAnchor.constraint(equalTo: accessoryView.trailingAnchor, constant: -10.0).isActive = true
        popupButton.centerYAnchor.constraint(equalTo: accessoryView.centerYAnchor).isActive = true
        popupButton.widthAnchor.constraint(equalToConstant: 200).isActive = true
        
        accessoryView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.trailingAnchor.constraint(equalTo: popupButton.leadingAnchor, constant: -10.0).isActive = true
        label.centerYAnchor.constraint(equalTo: accessoryView.centerYAnchor).isActive = true
         
        if panel.runModal() == NSApplication.ModalResponse.OK, let fileUrl = panel.directoryURL {
                        
            // This is the part that actually exports layers
            
            guard let count = procreateFile?.procreate_doc?.layers?.count else { return }
            guard let procreateFile = procreateFile else { return }
            guard let procreate_doc = procreateFile.procreate_doc else { return }
            
            let exportDirName = (panel.nameFieldStringValue as NSString).deletingPathExtension
            
            var exportUrl:URL?
            if #available(macOS 13, *) {
                exportUrl = fileUrl.appending(path: exportDirName)
            } else {
                exportUrl = fileUrl.appendingPathComponent(exportDirName)
            }
            guard let exportUrl = exportUrl else { return }
            
            do {
                try FileManager.default.createDirectory(at: exportUrl, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("error: \(error)")
            }
            
            appState.exportingLayers[fileurl!] = true
            var counter:CGFloat = 0
            
            if (exportFlattened == true) {
                
                // Need to get a count of what materials we should have here
                guard var count = procreate_doc.unwrappedLayers3D?.count else { return }
                count *= 3 // at least 3 images (diffuse, rough, metal) for each 3D layer
                
                func checkProgress() {
                    // update the progress bar
                    DispatchQueue.main.sync {
                        appState.exportingLayersProgress[fileurl!] = counter / CGFloat(count)
                        if (counter == CGFloat(count)) {
                            appState.exportingLayers[self.fileurl!] = false
                            appState.exportingLayersProgress[self.fileurl!] = 0.0
                        }
                    }
                }
                
                // Get already loaded composite textures from the model
                guard let scene = procreate_doc.view?.scene else { return }
                DispatchQueue.global(qos: .userInteractive).async {
                    scene.rootNode.enumerateChildNodes({ (child, stop) in
                        child.geometry?.materials.forEach({ mat in
                            let mat_name = mat.name ?? "Untitled_Material"
                            if let diffuse_tex:NSImage = mat.diffuse.contents as? NSImage {
                                let tex_name = mat_name.appending("-").appending("Color")
                                _ = diffuse_tex.save(as: tex_name, fileType: self.selectedFormat ?? .png, at: exportUrl)
                                counter += 1
                                checkProgress()
                            }
                            if let metalness_tex:NSImage = mat.metalness.contents as? NSImage {
                                let tex_name = mat_name.appending("-").appending("Metallic")
                                _ = metalness_tex.save(as: tex_name, fileType: self.selectedFormat ?? .png, at: exportUrl)
                                counter += 1
                                checkProgress()
                            }
                            if let roughness_tex:NSImage = mat.roughness.contents as? NSImage {
                                let tex_name = mat_name.appending("-").appending("Roughness")
                                _ = roughness_tex.save(as: tex_name, fileType: self.selectedFormat ?? .png, at: exportUrl)
                                counter += 1
                                checkProgress()
                            }
                            if let normal_tex:NSImage = mat.normal.contents as? NSImage {
                                let tex_name = mat_name.appending("-").appending("Normal")
                                _ = normal_tex.save(as: tex_name, fileType: self.selectedFormat ?? .png, at: exportUrl)
                            }
                            if let ambient_occ_tex:NSImage = mat.ambientOcclusion.contents as? NSImage {
                                let tex_name = mat_name.appending("-").appending("AmbientOcclusion")
                                _ = ambient_occ_tex.save(as: tex_name, fileType: self.selectedFormat ?? .png, at: exportUrl)
                            }
                        })
                    })
                }
                
            } else {
                DispatchQueue.global(qos: .userInteractive).async {
                    // Using a foreach loop with autoreleasepool instead of concurrentperform is easier on RAM, but quite a bit slower
                    DispatchQueue.concurrentPerform(iterations: count, execute: { index in
                        autoreleasepool {
                            guard let layer = procreate_doc.layers?[index] else { return }
                            guard let wrapper = procreateFile.wrapper else { return }
                            var layer_img = procreate_doc.getLayer(layer, wrapper)
                            if (layer_img != nil) {
                                // write each layer to disk, then clear it from memory
                                
                                guard let layers = procreate_doc.layers else { return }
                                guard let layernumber = layers.firstIndex(of: layer) else { return }
                                let layername = String(layernumber).appending("_").appending(layer.name ?? "Untitled Layer")
                                
                                if let _ = layer_img?.save(as: layername, fileType: self.selectedFormat ?? .png, at: exportUrl) {
                                    // Do something here when saving to disk is done
//                                    print("\(String(describing: layer.name ?? "untitled layer")) saved at \(String(describing: exportUrl))")
                                    counter += 1
                                    DispatchQueue.main.sync { [weak self] in
                                        // update the progress bar
                                        appState.exportingLayersProgress[self!.fileurl!] = counter / CGFloat(count)
                                        if (counter == CGFloat(count)) {
                                            appState.exportingLayers[self!.fileurl!] = false
                                            appState.exportingLayersProgress[self!.fileurl!] = 0.0
                                        }
                                    }
                                }

                                
                            } else {
                                print("layer not loaded!")
                            }
                            layer_img = nil
                        }
                    })
                }
            }
            // end layer export
            
        }
    }
    
    @objc func changeFileFormat(_ format: NSPopUpButton) {
        let imageExt = formats![format.indexOfSelectedItem]
        var selectedType:UTType = .png
        if (imageExt == "png") {
            selectedFormat = .png
            selectedType = .png
        } else if (imageExt == "jpg") {
            selectedFormat = .jpeg
            selectedType = .jpeg
        } else if (imageExt == "bmp") {
            selectedFormat = .bmp
            selectedType = .bmp
        } else if (imageExt == "tiff") {
            selectedFormat = .tiff
            selectedType = .tiff
        }
        // update the file extension
        panel.allowedContentTypes = [selectedType]
    }
}
