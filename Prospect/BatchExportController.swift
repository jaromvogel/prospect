//
//  BatchExportController.swift
//  Prospect
//
//  Created by Jarom Vogel on 5/30/24.


import Foundation
import Cocoa
import SwiftUI
import UniformTypeIdentifiers

public class batchExportController {
    
    
    init() {
        
    }
    
    let panel:NSOpenPanel = NSOpenPanel()
    
    @objc func presentDialog(_ sender: Any?) {
        
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canDownloadUbiquitousContents = true
        panel.resolvesAliases = true
        panel.title = "Select files to export"
        panel.allowedContentTypes = [.procreateFiles]
        panel.prompt = "Select"
         
        if panel.runModal() == NSApplication.ModalResponse.OK {
            appState.batchExportQueue = panel.urls
            appState.objectWillChange.send()
        
            let batchWindow = NSWindow(
                contentRect: NSMakeRect(0, 0, 400, 200),
                styleMask: [.titled, .resizable, .miniaturizable, .closable],
                backing: .buffered,
                defer: false)
            batchWindow.makeKeyAndOrderFront(batchWindow)
            batchWindow.contentView = NSHostingView(rootView: batchExportView(app_state: appState))
            batchWindow.center()
            
            let _ = BatchExportWindowController(window: batchWindow)
            
        }
    }
}

public class BatchExportWindowController:NSWindowController {
    
    public override func loadWindow() {}

}

struct batchExportView:View {
    @ObservedObject var app_state: AppState
    
    var body: some View {
        ZStack {
            if (app_state.batchExportState == .active) {
                ProgressView(value: app_state.batchExportProgress)
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.blue))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            else {
                VStack(alignment: .trailing, spacing: 0, content: {
                    if (app_state.batchExportState == .started) {
                        Text("The following \(app_state.batchExportQueue?.count.description ?? "0") files will be exported:")
                            .frame(maxWidth: .infinity, maxHeight: 40, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        List {
                            ForEach(app_state.batchExportQueue ?? [URL](), id: \.self) { batchItem in
                                Text(batchItem.lastPathComponent)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        HStack(alignment: .center, spacing: 10, content: {
                            Button(action: {
                                app_state.batchExportQueue = nil
                                app_state.objectWillChange.send()
                                NSApplication.shared.keyWindow?.close()
                            }, label: {
                                Text("Cancel")
                            })
                            Button(action: {
                                // Display an NSSavePanel here
                                batchExportPanelController().presentDialog(nil)
                            }, label: {
                                Text("Pick Folder...")
                            })
                        })
                        .padding(.vertical, 15)
                    }
                    if (app_state.batchExportState == .completed) {
                        Text("\(app_state.batchExportQueue?.count.description ?? "0") files were exported successfully.")
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .multilineTextAlignment(.leading)
                        HStack(alignment: .center, spacing: 10, content: {
                            Button(action: {
                                NSApplication.shared.keyWindow?.close()
                            }, label: {
                                Text("Done")
                            })
                        })
                        .padding(.vertical, 15)
                    }
                    
                })
                .padding(.horizontal, 15)
                .frame(minWidth: 400, idealWidth: 900, maxWidth: .infinity, minHeight: 300, idealHeight: 700, maxHeight: .infinity)
            }
        }
        .onDisappear(perform: {
            appState.batchExportQueue = nil
            appState.batchExportState = .started
            appState.batchExportProgress = 0.0
        })
    }
}


public class batchExportPanelController {
    
    var formats:Array<String>?
    var selectedFormat:NSBitmapImageRep.FileType?
    let panel:NSOpenPanel = NSOpenPanel()
    
    @objc func presentDialog(_ sender: Any?) {
        formats = ["png", "jpg", "bmp", "tiff"]
        selectedFormat = .png
        panel.nameFieldLabel = "Save image as:"
        // Check for '/' character in filename and handle it
        panel.isExtensionHidden = false
        panel.canCreateDirectories = true
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        
        
        panel.message = "Choose your directory"
        panel.prompt = "Export Files"
//            panel.allowedFileTypes = ["png"]
        panel.allowedContentTypes = [.png]
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
            appState.batchExportState = .active
            batchExportURLs(urls: appState.batchExportQueue, saveDir: fileUrl, fileType: selectedFormat ?? .png)
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


func batchExportURLs(urls: Array<URL>?, saveDir: URL, fileType: NSBitmapImageRep.FileType) {
    guard let urls = urls else { return }
    
    var counter:CGFloat = 0
    
    urls.forEach({ url in
        if let wrapper = try? FileWrapper(url: url) {
            var procreate_doc:SilicaDocument? = readProcreateDocument(file: wrapper, noVideo: true)
            let _ = procreate_doc?.getLayer(procreate_doc?.composite, wrapper, {
                
                var exportname = (url.lastPathComponent as NSString).deletingPathExtension

                // Check that this filename isn't already in use. If it is, append " copy" to it and keep trying until that filename isn't used.
                while fileAlreadyExistsHere(exportname: exportname, url: url, fileType: fileType, saveDir: saveDir) {
                    exportname.append(" copy")
                }
                
                // Save the image to the specified url
                if let _ = procreate_doc?.composite_image?.save(as: exportname, fileType: fileType, at: saveDir) {
                    // Do something when saving is done
                    procreate_doc?.cleanUp()
                    procreate_doc = nil
                    counter += 1
                    appState.batchExportProgress = counter / CGFloat(urls.count)
                    if (appState.batchExportProgress == 1.0) {
                        appState.batchExportState = .completed
                        appState.batchExportProgress = 0.0
                    }
                    appState.objectWillChange.send()
                }
                
            })
            
        }
    })
}

func fileAlreadyExistsHere(exportname: String, url: URL, fileType: NSBitmapImageRep.FileType, saveDir: URL) -> Bool {
    let dest_file = exportname.appending(".").appending(fileType.pathExtension)
    let dest_filepath = saveDir.appendingPathComponent(dest_file)
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: dest_filepath.path) {
        return true
    }
    return false
}

