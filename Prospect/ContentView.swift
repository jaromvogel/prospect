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


extension UTType {
    static var procreateFiles: UTType {
//        UTType(importedAs: "dyn.ah62d4rv4ge81a6xtqr3gn2pyqy")
        UTType(filenameExtension: "procreate")!
    }
    static var brushFiles: UTType {
        UTType(filenameExtension: "brush")!
    }
}

struct ProcreateDocumentType: FileDocument {

    static var readableContentTypes: [UTType] { [.procreateFiles, .brushFiles] }
    weak var procreate_doc: SilicaDocument?
    var file_ext: String?
    var image_size: CGSize?
    var brush_thumb: NSImage?

    init(configuration: ReadConfiguration) throws {
        // Read the file's contents from file.regularFileContents
        let filename = configuration.file.filename!
        file_ext = URL(fileURLWithPath: filename).pathExtension
        if (file_ext == "procreate") {
            procreate_doc = readProcreateDocument(file: configuration.file)
            image_size = getImageSize(si_doc: procreate_doc!, minWidth: 300, maxWidth: 1200)
        } else if (file_ext == "brush") {
            image_size = CGSize(width: 600, height: 300)
            brush_thumb = getThumbImage(file: configuration.file)
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
    var body: some Scene {
        DocumentGroup(viewing: ProcreateDocumentType.self) { file in
            ContentView(file: file.$document)
            .onDisappear() {
                // Clean up memory
                if (file.document.file_ext == "procreate") {
                    file.document.procreate_doc!.cleanUp()
                } else if (file.document.file_ext == "brush") {
                    file.document.brush_thumb = nil
                }
            }
        }
        .windowToolbarStyle(ExpandedWindowToolbarStyle())
    }
}

struct ContentView: View {
    @Binding var file: ProcreateDocumentType
    var url: URL?
    @State var viewMode: Int = 1

//    print("init running")
//    NSApplication.shared.keyWindow?.isReleasedWhenClosed = true
//    print(NSApplication.shared.keyWindow)
    
    var body: some View {
//        Rectangle().foregroundColor(.red)
//            .frame(width: 300, height: 300, alignment: .center)
        if (file.file_ext == "procreate") {
            ProcreateView(silica_doc: file.procreate_doc!, image_view_size: file.image_size!)
                .frame(width: file.image_size!.width, height: file.image_size!.height, alignment: .center)
                .toolbar {
                    ToolbarItemGroup(placement: ToolbarItemPlacement.principal, content: {
                            Picker("View", selection: $viewMode) {
                                Text("Artwork").tag(1)
                                Text("Timelapse").tag(2)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                    })
                    ToolbarItem(content: {
                        Button(action: {
                            print("pressed")
                        }) {
                            Label("buttom name", systemImage: "book.circle")
                        }
                    })
                }
        }
        if (file.file_ext == "brush") {
            BrushView(thumb_image: file.brush_thumb, preview_size: file.image_size!)
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
        NSApplication.shared.keyWindow?.close()
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
    var thumb_image: NSImage?
    var preview_size: CGSize?
    
    var body: some View {
        HStack() {
            ProspectImageView(proImage: thumb_image!, image_view_size: preview_size!)
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
