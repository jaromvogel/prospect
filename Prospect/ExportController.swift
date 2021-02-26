//
//  ExportController.swift
//  Prospect
//
//  Created by Vogel Family on 2/25/21.
//

import Foundation
import Cocoa

public class exportController {
    var si_doc: SilicaDocument?
    
    init(si_doc: SilicaDocument?) {
        self.si_doc = si_doc
    }

    
    let formats = ["png", "jpg", "bmp", "tiff"]
    var selectedFormat:NSBitmapImageRep.FileType?
    let panel:NSSavePanel = NSSavePanel()

    @objc func presentDialog(_ sender: Any?) {
        selectedFormat = .png
        panel.nameFieldLabel = "Save image as:"
        panel.nameFieldStringValue = "\(si_doc!.name ?? "untitled_artwork")"
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
        popupButton.addItems(withTitles: formats)
        popupButton.selectItem(at: 0)
        popupButton.action = #selector(changeFileFormat(_:))
        popupButton.target = self

        // (You'll also want to add a label like "File Format:",
        //  and center everything horizontally.)
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
//        label.widthAnchor.constraint(equalToConstant: 200).isActive = true
        
        if panel.runModal() == NSApplication.ModalResponse.OK, let fileUrl = panel.directoryURL {
            // Get the image to export
            let export_image  = si_doc!.composite_image!

            // Save the image to the specified url
            if export_image.save(as: si_doc!.name ?? "untitled_artwork", fileType: self.selectedFormat!, at: fileUrl) {
                // Do something here when saving is done
            }
        }
    }

    @objc func changeFileFormat(_ format: NSPopUpButton) {
        let imageExt = formats[format.indexOfSelectedItem]
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
