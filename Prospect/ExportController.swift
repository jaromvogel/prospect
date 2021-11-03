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
    var fileurl: String?
    var isTimelapse: Bool?
    var TLPlayer: AVPlayer?
    
    init(exportImage: NSImage?, isTimelapse: Bool = false, TLPlayer: AVPlayer? = nil, filename: String, fileurl: String? = nil) {
        self.exportImage = exportImage
        self.filename = filename
        self.fileurl = fileurl
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
            // Check for '/' character in filename and handle it
            filename = filename?.replacingOccurrences(of: "/", with: ":")
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
                
                let exportname = (panel.nameFieldStringValue as NSString).deletingPathExtension
                
                // Save the image to the specified url
                if export_image.save(as: exportname, fileType: self.selectedFormat!, at: fileUrl) {
//                     Do something here when saving is done
                }
            }
        }
        else if (isTimelapse == true) {
            
            formats = ["H.264", "HEVC"]
            selectedVideoFormat = AVFileType.mp4
            panel.nameFieldLabel = "Save video as:"
            // Check for '/' character in filename and handle it
            filename = filename?.replacingOccurrences(of: "/", with: ":")
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

                appState.exportingTL[fileurl!] = true
                
                let progressUpdate = { progress in
                    appState.exportProgress[self.fileurl!] = progress
                }
                
                let exportname = (panel.nameFieldStringValue as NSString).deletingPathExtension
                TLPlayer!.pause()
                
                // Do something to export the video here
                exportTimelapse(player: TLPlayer, filename: exportname, saveToUrl: fileUrl, encoding: formats![popupButton.indexOfSelectedItem], filetype: selectedVideoFormat, progressUpdater: progressUpdate) {
                    appState.exportingTL[self.fileurl!] = false
                    appState.exportProgress[self.fileurl!] = 0.0
                    self.TLPlayer!.play()
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


//// Code to deal with scaling the export image and retina resolution
//func unscaledBitmapImageRep(forImage image: NSImage) -> NSBitmapImageRep {
//    guard let rep = NSBitmapImageRep(
//        bitmapDataPlanes: nil,
//        pixelsWide: Int(image.size.width),
//        pixelsHigh: Int(image.size.height),
//        bitsPerSample: 8,
//        samplesPerPixel: 4,
//        hasAlpha: true,
//        isPlanar: false,
//        colorSpaceName: .deviceRGB,
//        bytesPerRow: 0,
//        bitsPerPixel: 0
//    ) else {
//        preconditionFailure()
//    }
//
//    NSGraphicsContext.saveGraphicsState()
//    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
//    image.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1.0)
//    NSGraphicsContext.restoreGraphicsState()
//
//    return rep
//}
//
//func writeImage(
//    image: NSImage,
//    usingType type: NSBitmapImageRep.FileType,
//    withSizeInPixels size: NSSize?,
//    to url: URL) throws {
//    if let size = size {
//        image.size = size
//    }
//    let rep = unscaledBitmapImageRep(forImage: image)
//    let rep2 = rep.retagging(with: NSColorSpace.displayP3) // This seems to give me the correct color on export, but I need to do this earlier so it's what you see in-app as well
//
//    guard let data = rep2!.representation(using: type, properties:[.compressionFactor: 1.0]) else {
//        preconditionFailure()
//    }
//
//    try data.write(to: url.appendingPathExtension(type.pathExtension))
//}
