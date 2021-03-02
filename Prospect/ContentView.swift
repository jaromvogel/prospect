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

public class AppState: ObservableObject {
    @Published var magnification: CGFloat = 1.0
}

let appState = AppState()

struct ProcreateDocumentType: FileDocument {

    static var readableContentTypes: [UTType] { [.procreateFiles, .brushFiles] }
    weak var procreate_doc: SilicaDocument?
    var file_ext: String?
    var image_size: CGSize?
    var brush_thumb: NSImage?
    var isExporting: Bool = false

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
    private let exportCommand = PassthroughSubject<Void, Never>()
    private let copyCommand = PassthroughSubject<Void, Never>()
    private let zoomInCommand = PassthroughSubject<Void, Never>()
    private let zoomOutCommand = PassthroughSubject<Void, Never>()
    private let zoomFitCommand = PassthroughSubject<Void, Never>()
    @ObservedObject var state = appState
    
    var body: some Scene {
        DocumentGroup(viewing: ProcreateDocumentType.self) { file in
            ContentView(file: file.$document)
            .frame(width: file.document.image_size!.width, height: file.document.image_size!.height, alignment: .center)
            // This should make the window resizeable, but for some reason it makes it always show up as a weird landscape size...
//                .frame(minWidth: 320, idealWidth: file.image_size!.width, maxWidth: .infinity, minHeight: 320, idealHeight: file.image_size!.height, maxHeight: .infinity, alignment: .center)
            .onDisappear() {
                // Clean up memory
                if (file.document.file_ext == "procreate") {
                    file.document.procreate_doc!.cleanUp()
                } else if (file.document.file_ext == "brush") {
                    file.document.brush_thumb = nil
                }
            }
            .onReceive(exportCommand) { _ in
                exportController(si_doc: file.document.procreate_doc).presentDialog(nil)
            }
            .onReceive(copyCommand) { _ in
                func writeImageToPasteboard(img: NSImage?)
                {
                    if (img != nil) {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.writeObjects([img!])
                    }
                }
                writeImageToPasteboard(img: file.document.procreate_doc?.composite_image)
            }
            .onReceive(zoomInCommand) {
                if (state.magnification < 100.0) {
                    state.magnification += 0.5
                }
            }
            .onReceive(zoomOutCommand) {
                if (state.magnification > 1.0) {
                    state.magnification -= 0.5
                }
            }
            .onReceive(zoomFitCommand) {
                state.magnification = 1.0
            }
        }
        .windowToolbarStyle(ExpandedWindowToolbarStyle())
        .commands {
            CommandGroup(replacing: CommandGroupPlacement.saveItem) {
                Button("Export") {
                    exportCommand.send()
                }.keyboardShortcut("e")
                Divider()
                Button("Close") {
                    NSApplication.shared.keyWindow?.close()
                }.keyboardShortcut("w")
            }
            CommandGroup(replacing: CommandGroupPlacement.undoRedo) {}
            CommandGroup(replacing: CommandGroupPlacement.pasteboard) {
                Button("Copy") {
                    copyCommand.send()
                }.keyboardShortcut("c")
            }
            CommandGroup(before: CommandGroupPlacement.toolbar, addition: {
                Button("Zoom In") {
                    zoomInCommand.send()
                }.keyboardShortcut("+")
                Button("Zoom Out") {
                    zoomOutCommand.send()
                }.keyboardShortcut("-")
                Button("Zoom to Fit") {
                    zoomFitCommand.send()
                }.keyboardShortcut("0")
            })
        }
    }
}

struct ContentView: View {
    @Binding var file: ProcreateDocumentType
    var url: URL?
    @State var show_meta:Bool = false
    @State var viewMode: Int = 1
    @ObservedObject var state = appState
    
    var body: some View {
        if (file.file_ext == "procreate") {
            ProcreateView(silica_doc: file.procreate_doc!, image_view_size: file.image_size!, show_meta: $show_meta)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar {
                    ToolbarItem(content: {
                        Button(action: {
                            show_meta.toggle()
                        }) {
                            Label("Info", systemImage: "info.circle")
                        }
                        .keyboardShortcut("i", modifiers: .command)
                    })
                    ToolbarItemGroup(placement: ToolbarItemPlacement.principal, content: {
                        Spacer()
                        Picker("View", selection: $viewMode) {
                            Text("Artwork").tag(1)
                            Text("Timelapse").tag(2)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        Spacer()
                    })
                    ToolbarItemGroup(content: {
                        Spacer()
                        Button(action: {
                            // zoom out
                            if (state.magnification > 1.0) {
                                state.magnification -= 0.5
                            }
                        }) {
                            Label("Zoom out", systemImage: "minus.magnifyingglass")
                        }
                        .keyboardShortcut("-", modifiers: .command)
                        Button(action: {
                            // zoom in
                            if (state.magnification < 100.0) {
                                state.magnification += 0.5
                            }
                        }) {
                            Label("Zoom in", systemImage: "plus.magnifyingglass")
                        }
                        .keyboardShortcut("=", modifiers: .command)
                        Button(action: {
                            // Export
                            exportController(si_doc: file.procreate_doc!).presentDialog(nil)
                        }) {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .keyboardShortcut("e", modifiers: .command)
                    })
                }
        }
        if (file.file_ext == "brush") {
            BrushView(thumb_image: file.brush_thumb, preview_size: file.image_size!)
                .frame(width: .infinity, height: .infinity, alignment: .center)
        }
    }
}

struct ProcreateView: View {
    @ObservedObject var silica_doc: SilicaDocument
    @State var image_view_size: CGSize
    @Binding var show_meta: Bool
    
    func debugReloadImage() {
        print("reloading")
//        NSApplication.shared.keyWindow?.close()
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
                        self.show_meta = false
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
    @ObservedObject var state = appState
    @State var scrollView:ImageViewer = ImageViewer()
    
    class ImageViewer: NSScrollView {
//        override func touchesMoved(with event: NSEvent) {
//            sync_magnification = self.magnification
//        }
        override func magnify(with event: NSEvent) {
            super.magnify(with: event)
            if (event.phase == .ended) {
                appState.magnification = self.magnification
            }
        }
        
//        override var acceptsFirstResponder: Bool { true }
//        override func keyDown(with event: NSEvent) {
//            super.keyDown(with: event)
//            print(">> key \(event.keyCode)")
//        }
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let subviewFrame = CGRect(origin: .zero,
                                  size: CGSize(width: image_view_size.width, height: image_view_size.height))

        let documentView = NSView(frame: subviewFrame)
        documentView.wantsLayer = true

//        let scrollView = ImageViewer()
        scrollView.allowedTouchTypes = NSTouch.TouchTypeMask.indirect
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
        
//        DispatchQueue.main.async { // wait till next event cycle
//            scrollView.window?.makeFirstResponder(scrollView)
//        }
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        nsView.animator().magnification = state.magnification
        nsView.documentView?.layer?.contents = proImage
        nsView.documentView?.layer?.contentsGravity = .resizeAspect
    }
}
