//
//  ContentView.swift
//  Prospect
//
//  Created by Vogel Family on 11/2/20.
//

import SwiftUI
import Combine
import Foundation
import ProcreateDocument

class exportController {
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

struct ContentView: View {
    var si_doc: SilicaDocument?
    var body: some View {
        HStack() {
            if (file_ext == "procreate") {
                ProcreateView(silica_doc: si_doc!)
            }
            if (file_ext == "brush") {
                BrushView()
            }
        }
    }
}

struct ProcreateView: View {
    @ObservedObject var silica_doc: SilicaDocument
    @State private var scale:CGFloat = 1.0
    @State private var rotation:Double = 0
    @State private var lastScale:CGFloat = 1.0
    
    var body: some View {
        
        let magnificationGesture = MagnificationGesture()
            .onChanged { value in
                self.scale = value.magnitude
            }
            .onEnded { value in
                self.scale = 1.0
            }
        
        let rotationGesture = RotationGesture()
            .onChanged { value in
                self.rotation = value.degrees
            }
            .onEnded { value in
                self.rotation = 0
            }
        
        let magnificationAndRotationGesture = magnificationGesture.simultaneously(with: rotationGesture)
        
        HStack(alignment: .bottom, spacing: 0) {
            if (silica_doc.composite_image != nil) {
                Image(nsImage: silica_doc.composite_image!)
                    .resizable()
                    .aspectRatio(contentMode: ContentMode.fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .gesture(magnificationAndRotationGesture)
                    .scaleEffect(self.scale)
                    .animation(.easeOut)
                    .rotationEffect(Angle(degrees: self.rotation))
//                    .rotationEffect(.degrees(silica_doc.getRotation())) // Rotate based on orientation
                    // Flip based on flippedHorizontally / flippedVertically
//                    .scaleEffect(
//                        x: (si_doc?.flippedHorizontally!)! ? -1.0 : 1.0,
//                        y: (si_doc?.flippedVertically!)! ? -1.0 : 1.0,
//                        anchor: .center
//                    )
            } else {
                ProgressBar(progress: $silica_doc.comp_load)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(.white)
//                Text("Loading... \(silica_doc.comp_load)")
            }
            ZStack() {
                VStack(alignment: .leading, spacing: 20) {
                    InfoCell(label: "Title", value: silica_doc.name ?? "Untitled Artwork")
                    InfoCell(label: "Layer Count", value: String((silica_doc.layers!.count)))
                    InfoCell(label: "Author Name", value: silica_doc.authorName ?? "Unknown")
                    InfoCell(label: "Size", value: String(Int((silica_doc.size?.width)!)).appending(" x ").appending(String(Int((silica_doc.size?.height)!))))
                    InfoCell(label: "DPI", value: String((silica_doc.SilicaDocumentArchiveDPIKey)!))
                    Button(action: {
                        
                        exportController(si_doc: silica_doc).presentDialog(nil)
                        
                    }, label: {
                        Text("Export Image")
                    })
                }
                .padding(20)
            }
                .frame(maxWidth: 300, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(NSColor.init(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0)))
        }
        .padding(0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct InfoCell: View {
    var label:String
    var value:String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 11))
            Text(value)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 16))
        }
        .frame(maxWidth: .infinity)
        .padding(0)
    }
}


struct ProgressBar: View {
    @Binding var progress:CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            HStack() {
                VStack() {
                    Text(Int(progress * 100).description)
                    ZStack(alignment: .leading) {
                        Rectangle().frame(width: geometry.size.width / 3, height: 5)
                            .opacity(0.2)
                            .foregroundColor(.white)
                            .cornerRadius(2.5)
                        Rectangle().frame(width: geometry.size.width / 3 * progress, height: 5)
                            .foregroundColor(.white)
                            .opacity(0.9)
                            .cornerRadius(2.5)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

struct BrushView: View {
    var body: some View {
        HStack() {
            Rectangle().frame(width: 300, height: 300)
                .foregroundColor(Color.red)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
