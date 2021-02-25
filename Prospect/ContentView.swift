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
import UniformTypeIdentifiers

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



extension UTType {
    static var procreateFiles: UTType {
//        UTType(importedAs: "dyn.ah62d4rv4ge81a6xtqr3gn2pyqy")
        UTType(filenameExtension: "procreate")!
    }
}

struct ProcreateDocumentType: FileDocument {

    static var readableContentTypes: [UTType] { [.procreateFiles] }
    var procreate_doc: SilicaDocument?
    var file_ext: String?
    var image_size: CGSize?

    init(configuration: ReadConfiguration) throws {
        // Read the file's contents from file.regularFileContents
        print("trying to read this thing")
        let filename = configuration.file.filename!
        file_ext = URL(fileURLWithPath: filename).pathExtension
        if (file_ext == "procreate") {
            procreate_doc = readProcreateDocument(file: configuration.file)
            image_size = getImageSize(si_doc: procreate_doc!, minWidth: 300, maxWidth: 1000)
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Create a FileWrapper with the updated contents and set configuration.fileWrapper to it.
        // This is possible because fileWrapper is an inout parameter.
        return configuration.existingFile!
    }
}


@main
struct ContentApp: App {
    var body: some Scene {
        DocumentScene()
    }
}

struct DocumentScene: Scene {
    @State var viewMode: Int = 1
    
    var body: some Scene {
        DocumentGroup(viewing: ProcreateDocumentType.self) { file in
            ContentView(file: file.$document)
                .toolbar {
                    ToolbarItemGroup(content: {
                            Picker("View", selection: $viewMode) {
                                Text("Artwork").tag(1)
                                Text("Timelapse").tag(2)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                    })
                }
                .presentedWindowToolbarStyle(ExpandedWindowToolbarStyle())
        }
    }
}

struct ContentView: View {
    @Binding var file: ProcreateDocumentType
    var url: URL?
    
    var body: some View {
        if (file.file_ext == "procreate") {
            ProcreateView(silica_doc: file.procreate_doc!, image_view_size: file.image_size!)
                .frame(width: file.image_size!.width, height: file.image_size!.height, alignment: .center)
        }
        if (file.file_ext == "brush") {
            BrushView(url: url, preview_size: file.image_size!)
                .frame(width: file.image_size!.width, height: file.image_size!.height, alignment: .center)
        }
    }
    
    private func toolbarAction() {
        print("hello")
    }
    
}

struct ProcreateView: View {
    @ObservedObject var silica_doc: SilicaDocument
    @State var image_view_size: CGSize
    @State private var show_meta: Bool = false
    
    func debugReloadImage() {
        print("reloading")
        silica_doc.composite_image = silica_doc.composite_image
        silica_doc.objectWillChange.send()
        silica_doc.composite_image?.objectWillChange.send()
    }
    
    var body: some View {

        ZStack() {
            if (silica_doc.composite_image != nil) {
                ProspectImageView(proImage: silica_doc.composite_image!, image_view_size: image_view_size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture {
                        self.show_meta.toggle()
                    }
            } else {
                ProgressBar(progress: $silica_doc.comp_load)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(.white)
            }
            VStack() {
                Spacer()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                GeometryReader() { geo in
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 20) {
                            InfoCell(label: "Title", value: silica_doc.name ?? "Untitled Artwork")
                            InfoCell(label: "Layer Count", value: String((silica_doc.layers!.count)))
                            InfoCell(label: "Author Name", value: silica_doc.authorName ?? "Unknown")
                            InfoCell(label: "Size", value: "\(silica_doc.size!.width) x \(silica_doc.size!.height)")
                            InfoCell(label: "DPI", value: String((silica_doc.SilicaDocumentArchiveDPIKey)!))
                        }
                        VStack(alignment: .leading, spacing: 20) {
                            Button(action: {
                                
                                exportController(si_doc: silica_doc).presentDialog(nil)
                                
                            }, label: {
                                Text("Export Image")
                            })
                            Button(action: {
                                
                                debugReloadImage()
                                
                            }, label: {
                                Text("DEBUG refresh image")
                            })
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(VisualEffectBlur(material: .popover))
                    .cornerRadius(15)
                    .shadow(radius: 30)
                    .animation(.spring(response: 0.2, dampingFraction: 0.75, blendDuration: 0.2))
                    .offset(x: 0, y: show_meta ? 0 : geo.size.height + 100)
                }
            }
            .padding(15)
        }
        .padding(0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct InfoCell: View {
    @Environment(\.colorScheme) var colorScheme
    var label:String
    var value:String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .foregroundColor(Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 11))
            Text(value)
                .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
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
    var url: URL?
    var preview_size: CGSize?
    
    var body: some View {
        HStack() {
            ProspectImageView(proImage: getThumbImage(url: url!), image_view_size: preview_size!)
//            Rectangle().frame(width: 300, height: 300)
//                .foregroundColor(Color.red)
        }
    }
}

struct ProspectImageView: NSViewRepresentable {
    @State var proImage: NSImage
    @State var image_view_size: CGSize
    
    func makeNSView(context: Context) -> NSScrollView {
        let subviewFrame = CGRect(origin: .zero,
                                  size: CGSize(width: image_view_size.width, height: image_view_size.height))

        let documentView = NSView(frame: subviewFrame)
        documentView.wantsLayer = true

        let scrollView = NSScrollView()
        scrollView.documentView = documentView
        scrollView.contentView.scroll(to: CGPoint(x: 0, y: subviewFrame.size.height))
        
        scrollView.allowsMagnification = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.backgroundColor = .black
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        scrollView.scrollsDynamically = true
        scrollView.minMagnification = 1.0
        scrollView.maxMagnification = 100.0
        scrollView.usesPredominantAxisScrolling = false //allows view to scroll diagonally when false

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        nsView.documentView?.layer?.contents = proImage
        nsView.documentView?.layer?.contentsGravity = .resizeAspect
    }
}
