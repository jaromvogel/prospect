//
//  ExportController.swift
//  Prospect
//
//  Created by Vogel Family on 2/25/21.
//

import Foundation
import Cocoa
import AVFoundation

public class exportController {
    var exportImage: NSImage?
    var filename: String?
    var isTimelapse: Bool?
    var TLPlayer: AVPlayer?
    
    init(exportImage: NSImage?, isTimelapse: Bool = false, TLPlayer: AVPlayer? = nil, filename: String) {
        self.exportImage = exportImage
        self.filename = filename
        self.isTimelapse = isTimelapse
        self.TLPlayer = TLPlayer
    }

    var formats:Array<String>?
    var selectedFormat:NSBitmapImageRep.FileType?
    var selectedVideoFormat:AVFileType?
    let panel:NSSavePanel = NSSavePanel()

    @objc func presentDialog(_ sender: Any?) {
        if (exportImage != nil) {
            formats = ["png", "jpg", "bmp", "tiff"]
            selectedFormat = .png
            panel.nameFieldLabel = "Save image as:"
            panel.nameFieldStringValue = "\(filename ?? "untitled_artwork")"
            panel.isExtensionHidden = false
            panel.canCreateDirectories = true
            
            panel.message = "Choose your directory"
            panel.prompt = "Choose"
            panel.allowedFileTypes = ["png"]
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
                // Get the image to export
                let export_image = exportImage!

                // Check for '/' character in filename and handle it
                filename = filename?.replacingOccurrences(of: "/", with: ":")
                
                // Save the image to the specified url
                if export_image.save(as: filename ?? "untitled_artwork", fileType: self.selectedFormat!, at: fileUrl) {
                    // Do something here when saving is done
                }
            }
        }
        else if (isTimelapse == true) {
            
            formats = ["H.264", "HEVC"]
            selectedVideoFormat = AVFileType.mp4
            panel.nameFieldLabel = "Save video as:"
            panel.nameFieldStringValue = "\(filename ?? "untitled_artwork")"
            panel.isExtensionHidden = false
            panel.canCreateDirectories = true
            
            panel.message = "Choose your directory"
            panel.prompt = "Choose"
            panel.allowedFileTypes = ["mp4"]
            panel.setFrame(NSRect(x: 0, y: 0, width: 800, height: 500), display: true)
            
            // Add file format selector:
            let popupButton = NSPopUpButton(
                frame: NSRect(x: 0, y: 0, width: 300, height: 40),
                pullsDown: false)
            popupButton.removeAllItems()
            popupButton.addItems(withTitles: formats!)
            popupButton.selectItem(at: 0)
//            popupButton.action = #selector(changeFileFormat(_:))
            popupButton.target = self

            let label = NSTextField()
            label.stringValue = "Encoding:"
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
                // Check for '/' character in filename and handle it
                filename = filename?.replacingOccurrences(of: "/", with: ":")
                
                appState.exportingTL = true
                
                let progressUpdate = { progress in
                    appState.exportProgress = progress
                }
                
                // Do something to export the video here
                exportTimelapse(player: TLPlayer, filename: filename!, saveToUrl: fileUrl, encoding: formats![popupButton.indexOfSelectedItem], filetype: selectedVideoFormat, progressUpdater: progressUpdate) {
                    appState.exportingTL = false
                    appState.exportProgress = 0.0
                }
            }
            
        }
    }

    @objc func changeFileFormat(_ format: NSPopUpButton) {
        let imageExt = formats![format.indexOfSelectedItem]
        if (imageExt == "png") {
            selectedFormat = .png
        } else if (imageExt == "jpg") {
            selectedFormat = .jpeg
        } else if (imageExt == "bmp") {
            selectedFormat = .bmp
        } else if (imageExt == "tiff") {
            selectedFormat = .tiff
        }
        // update the file extension
        panel.allowedFileTypes = [imageExt]
    }
}
