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
import AVFoundation
import AVKit
import Sparkle
import SceneKit


extension UTType {
    static var procreateFiles: UTType {
        UTType(filenameExtension: "procreate")!
    }
    static var brushFiles: UTType {
        UTType(filenameExtension: "brush")!
    }
    static var swatchesFiles: UTType {
        UTType(filenameExtension: "swatches")!
    }
    static var brushSetFiles: UTType {
        UTType(filenameExtension: "brushset")!
    }
}

public class AppState: ObservableObject {
    @Published var zoomManager:Dictionary<String, CGFloat> = [String: CGFloat]()
    @Published var activeurl: String?
    @Published var exportingTL:Dictionary<String, Bool> = [String: Bool]()
    @Published var exportProgress:Dictionary<String, CGFloat> = [String: CGFloat]()
    @Published var exportingLayers:Dictionary<String, Bool> = [String: Bool]()
    @Published var exportingLayersProgress:Dictionary<String, CGFloat> = [String: CGFloat]()
    @Published var documentType: String?
    @Published var batchExportQueue: Array<URL>?
    @Published var batchExportProgress: CGFloat? = 0.0
    @Published var batchExportState:batchExportStatus = .started
}

public enum batchExportStatus {
    case started
    case active
    case completed
}

public let appState = AppState()

public struct ProcreateDocumentType: FileDocument {

    public static var readableContentTypes: [UTType] { [.procreateFiles, .brushFiles, .swatchesFiles, .brushSetFiles] }
    weak var procreate_doc: SilicaDocument?
    var brushset_file: ProcreateBrushset?
    var wrapper: FileWrapper?
//    var windowObservationMod: WindowObservationModifier?
    var file_ext: String?
    var image_size: CGSize?
    var brush: SilicaBrush?
    var brush_thumb: NSImage?
    var swatches_image: NSImage?
//    var window_observer: WindowObserver?
    var brushset_image: NSImage? = nil

    public init(configuration: ReadConfiguration) throws {
        // Read the file's contents from file.regularFileContents
        wrapper = configuration.file
//        window_observer = WindowObserver()
//        guard let window_observer = window_observer else { return }
//        windowObservationMod = WindowObservationModifier(windowObserver: window_observer)
        let filename = configuration.file.filename!
        file_ext = URL(fileURLWithPath: filename).pathExtension
        if (file_ext == "procreate") {
            wrapper = configuration.file
            procreate_doc = readProcreateDocument(file: configuration.file)
            
            image_size = getImageSize(si_doc: procreate_doc!, height: 800, minWidth: 300, maxWidth: 1200)
        } else if (file_ext == "brush") {
            brush = readSilicaBrush(file: configuration.file)
            image_size = CGSize(width: 400, height: 132)
            brush_thumb = brush!.thumbnail
        } else if (file_ext == "swatches") {
            image_size = CGSize(width: 600, height: 180)
            swatches_image = getSwatchesImage(configuration.file)
        } else if (file_ext == "brushset") {
            brushset_file = ProcreateBrushset()
            image_size = CGSize(width: 400, height: 600)
        }
    }
    
    mutating func loadBrushSet() {
        brushset_file?.getBrushsetImage(file: wrapper!, brushLabels: false)
    }
    
    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Create a FileWrapper with the updated contents and set configuration.fileWrapper to it.
        // This is possible because fileWrapper is an inout parameter.
        return configuration.existingFile!
    }
}


@main
struct ContentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        DocumentScene()
    }
}

struct DocumentScene: Scene {
    private let exportCommand = PassthroughSubject<Void, Never>()
    private let exportLayersCommand = PassthroughSubject<Void, Never>()
    private let exportFlattenedLayersCommand = PassthroughSubject<Void, Never>()
    private let batchExportCommand = PassthroughSubject<Void, Never>()
    private let copyCommand = PassthroughSubject<Void, Never>()
    private let zoomInCommand = PassthroughSubject<Void, Never>()
    private let zoomOutCommand = PassthroughSubject<Void, Never>()
    private let zoomFitCommand = PassthroughSubject<Void, Never>()
    @ObservedObject var state = appState
    
    var body: some Scene {
//        Settings{
//            Text("Hello")
//                .frame(width: 100, height: 100)
//        }
        DocumentGroup(viewing: ProcreateDocumentType.self) { file in
            let fileurl = file.fileURL!.absoluteString
            ContentView(file: file.$document, fileurl: fileurl)
            .frame(minWidth: file.document.image_size!.width, maxWidth: .infinity, minHeight: file.document.image_size!.height, maxHeight: .infinity, alignment: .center)
            .onAppear() {
                state.zoomManager[fileurl] = 1.0
            }
            .onDisappear() {
                // Clean up memory
                if (file.document.file_ext == "procreate") {
                    file.document.procreate_doc!.cleanUp()
                } else if (file.document.file_ext == "brush") {
                    file.document.brush_thumb = nil
                } else if (file.document.file_ext == "swatches") {
                    file.document.swatches_image = nil
                }
//                file.document.windowObservationMod = nil
//                file.document.window_observer = nil
//                print("clean up window observer here somehow")
                appState.exportProgress[fileurl] = nil
                appState.zoomManager[fileurl] = nil
                appState.exportingTL[fileurl] = nil
                appState.exportingLayers[fileurl] = nil
                appState.exportingLayersProgress[fileurl] = nil
                // Some way to clean up environment thing here?
            }
            .onReceive(exportCommand) { _ in
                if (fileurl == state.activeurl) {
                    var exportImage: NSImage?
                    var exportFilename: String?
                    var view: SCNView?
                    if (file.document.file_ext == "procreate") {
                        if (file.document.procreate_doc?.featureSet == 2) {
                            // Handle 3D export here
                            view = file.document.procreate_doc?.view
                            exportFilename = file.document.procreate_doc?.name ?? "Untitled Artwork"
                        } else {
                            exportImage = file.document.procreate_doc!.composite_image
                            exportFilename = file.document.procreate_doc!.name!
                        }
                    } else if (file.document.file_ext == "brush") {
                        exportImage = file.document.brush_thumb
                        exportFilename = String((file.fileURL?.lastPathComponent.split(separator: ".").first)!)
                    } else if (file.document.file_ext == "swatches") {
                        exportImage = file.document.swatches_image
                        exportFilename = String((file.fileURL?.lastPathComponent.split(separator: ".").first)!)
                    }
                    exportController(exportImage: exportImage, filename: exportFilename ?? "Unknown", view: view).presentDialog(nil)
                }
            }
            .onReceive(exportLayersCommand) { _ in
                if (fileurl == state.activeurl) {
                    let exportFilename = String((file.fileURL?.lastPathComponent.split(separator: ".").first)!)
                    exportLayersController(procreateFile: file.document, exportFilename: exportFilename, exportFlattened: false, fileurl: fileurl).presentDialog(nil)
                }
            }
            .onReceive(exportFlattenedLayersCommand) { _ in
                if (fileurl == state.activeurl) {
                    let exportFilename = String((file.fileURL?.lastPathComponent.split(separator: ".").first)!)
                    exportLayersController(procreateFile: file.document, exportFilename: exportFilename, exportFlattened: true, fileurl: fileurl).presentDialog(nil)
                }
            }
            .onReceive(copyCommand) { _ in
                if (fileurl == state.activeurl) {
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
            }
            .onReceive(zoomInCommand) {
                // some kind of check to see if fileurl is associated with the current active window
                if (fileurl == state.activeurl) {
                    if (state.zoomManager[fileurl]! < 100.0) {
                        state.zoomManager[fileurl]! += 0.5
                    }
                }
            }
            .onReceive(zoomOutCommand) {
                if (fileurl == state.activeurl) {
                    if (state.zoomManager[fileurl]! > 1.0) {
                        state.zoomManager[fileurl]! -= 0.5
                    }
                }
            }
            .onReceive(zoomFitCommand) {
                if (fileurl == state.activeurl) {
                    state.zoomManager[fileurl]! = 1.0
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
                if let window = notification.object as? NSWindow {
                    guard let representedURL = window.representedURL else { return }
                    if (window.isKeyWindow == true && representedURL.absoluteString == fileurl) {
//                        print("\(window.title) is now the key window \(window.isKeyWindow) with url: \(fileurl)")
                        state.activeurl = fileurl
                        if (file.document.procreate_doc?.featureSet == 2) {
                            state.documentType = "3D"
                        } else {
                            state.documentType = "2D"
                        }
                        state.objectWillChange.send()
                    }
                }
            }
        }
        .windowToolbarStyle(ExpandedWindowToolbarStyle())
        .commands {
            CommandGroup(after: .appInfo, addition: {
                Button("Check For Updates") {
                    SUUpdater.shared()?.checkForUpdates(self)
                }
            })
            CommandGroup(replacing: CommandGroupPlacement.saveItem) {
                Button("Export...") {
                    exportCommand.send()
                }.keyboardShortcut("e")
                if (appState.documentType == "3D") {
                    Button("Export Flattened Textures...") {
                        exportFlattenedLayersCommand.send()
                    }.keyboardShortcut("e", modifiers: [.command, .option])
                }
                Button("Export Layers...") {
                    exportLayersCommand.send()
                }.keyboardShortcut("e", modifiers: .option)
                Button("Batch Export...") {
                    appState.batchExportState = .started
                    batchExportController().presentDialog(nil)
                }.keyboardShortcut("e", modifiers: [.command, .shift])
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
    var fileurl: String
    @State var show_meta:Bool = false
    @State var viewMode: Int = 1
    @ObservedObject var state = appState
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if (file.file_ext == "procreate") {
            ProcreateView(fileurl: fileurl, file: file, silica_doc: file.procreate_doc!, image_view_size: file.image_size!, show_meta: $show_meta, viewMode: $viewMode)
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
                        if (viewMode == 1) {
                            Button(action: {
                                // zoom out
                                if (state.zoomManager[fileurl]! > 1.0) {
                                    state.zoomManager[fileurl]! -= 0.5
                                }
                            }) {
                                Label("Zoom out", systemImage: "minus.magnifyingglass")
                            }
                            .keyboardShortcut("-", modifiers: .command)
                            Button(action: {
                                // zoom in
                                if (state.zoomManager[fileurl]! < 100.0) {
                                    state.zoomManager[fileurl]! += 0.5
                                }
                            }) {
                                Label("Zoom in", systemImage: "plus.magnifyingglass")
                            }
                            .keyboardShortcut("=", modifiers: .command)
                        }
                        Button(action: {
                            // Export
                            let exportFilename:String = file.procreate_doc!.name ?? "Untitled Artwork"
                            if (viewMode == 1) {
                                let exportImage:NSImage = file.procreate_doc!.composite_image!
                                exportController(exportImage: exportImage, filename: exportFilename, view: file.procreate_doc?.view).presentDialog(nil)
                            } else if (viewMode == 2) {
                                exportController(exportImage: nil, isTimelapse: true, TLPlayer: file.procreate_doc?.videoPlayer, filename: exportFilename, fileurl: fileurl).presentDialog(nil)
                            }
                        }) {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .keyboardShortcut("e", modifiers: .command)
                    })
                }
        }
        if (file.file_ext == "brush") {
            BrushView(brush: file.brush!)
                .background(VisualEffectBlur.init(material: .underWindowBackground))
        }
        if (file.file_ext == "swatches") {
            ProspectImageView(fileurl: fileurl, proImage: file.swatches_image!, image_view_size: file.image_size!)
                .background(VisualEffectBlur.init(material: .underWindowBackground))
//                .environment(\.colorScheme, .dark)
        }
        if (file.file_ext == "brushset") {
            BrushsetView(brushset: file.brushset_file!, file: file)
            .background(VisualEffectBlur.init(material: .underWindowBackground))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}


struct ProcreateView: View {
    var fileurl: String
    @State var file: ProcreateDocumentType
    @ObservedObject var silica_doc: SilicaDocument
    @State var image_view_size: CGSize
    @Binding var show_meta: Bool
    @Binding var viewMode: Int
    @ObservedObject var state = appState
    
    func debugButton() {
        //        debug something here
        print("DEBUG")

//        // Using a foreach loop with autoreleasepool instead of concurrentperform is easier on RAM, but quite a bit slower
//        DispatchQueue.concurrentPerform(iterations: silica_doc.layers!.count, execute: { index in
//            autoreleasepool {
//                let layer = silica_doc.layers![index]
//                var layer_img = silica_doc.getLayer(layer, file.wrapper!)
//                if (layer_img != nil) {
//                    // write each layer to disk, then clear it from memory
//                    let fileUrl = FileManager.default.temporaryDirectory.appendingPathComponent("com.jaromvogel.prospect")
//                    do {
////                        try? FileManager.default.removeItem(at: fileUrl)
//                        try FileManager.default.createDirectory(at: fileUrl, withIntermediateDirectories: true, attributes: nil)
//                    } catch {
//                        print("couldn't create the directory :(")
//                    }
//
//                    if layer_img!.save(as: layer.UUID!, fileType: .tiff, at: fileUrl) {
//                        // Do something here when saving to disk is done
//                        // Maybe export to PSD somehow??
//                        print("\(String(describing: layer.name!)) saved at \(String(describing: fileUrl))")
//                    }
//
//                } else {
//                    print("layer not loaded!")
//                }
//                layer_img = nil
//            }
//        })
    }
    
    var body: some View {

        ZStack() {
            if (viewMode == 1) {
                if (silica_doc.composite_image != nil) {
                    if (file.procreate_doc?.featureSet == nil || file.procreate_doc?.featureSet == 1 || file.procreate_doc?.featureSet == 0) {
                        ProspectImageView(fileurl: fileurl, proImage: silica_doc.composite_image!, image_view_size: image_view_size)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onTapGesture {
                                self.show_meta = false
                            }
                    } else if (file.procreate_doc?.featureSet == 2) {
                        // Show 3D View
                        Procreate3DView(file: file, fileurl: fileurl, proImage: silica_doc.composite_image!, image_view_size: image_view_size, show_meta: $show_meta)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ProgressView(value: silica_doc.comp_load)
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.blue))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if (state.exportingLayers[fileurl] == true) {
                    VStack() {
                        ProgressView(value: state.exportingLayersProgress[fileurl])
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.blue))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .background(VisualEffectBlur(material: .popover))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if (viewMode == 2) {
                ZStack() {
                    if (file.procreate_doc?.videoEnabled == false) {
                        Text("Time-lapse Disabled")
                            .foregroundColor(Color.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        if (file.procreate_doc?.videoPlayer == nil) {
                            Text("loading...")
                                .foregroundColor(Color.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            VideoPlayer(player: file.procreate_doc?.videoPlayer)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .onTapGesture {
                                    self.show_meta = false
                                }
                        }
                        if (state.exportingTL[fileurl] == true) {
                            VStack() {
                                ProgressView(value: state.exportProgress[fileurl])
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color.blue))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .background(VisualEffectBlur(material: .popover))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
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
                            InfoCell(label: "Size", value: "\(String(describing: Int(silica_doc.composite_image?.size.width ?? 0))) x \(String(describing: Int(silica_doc.composite_image?.size.height ?? 0))) px")
                            InfoCell(label: "DPI", value: String((silica_doc.SilicaDocumentArchiveDPIKey)!))
                        }
                        VStack(alignment: .leading, spacing: 20) {
                            InfoCell(label: "Color Profile", value: String((silica_doc.colorProfile?.SiColorProfileArchiveICCNameKey) ?? "sRGB"))
                            InfoCell(label: "Video Length", value: silica_doc.videoDuration!)
                            InfoCell(label: "Video Resolution", value: getVideoResolution(silica_doc.videoResolutionKey ?? "1080", silica_doc.videoEnabled!))
                            InfoCell(label: "Total Strokes Made", value: String(silica_doc.strokeCount ?? 0))
                            InfoCell(label: "Tracked Time", value: secondsToHoursAndMinutes(silica_doc.SilicaDocumentTrackedTimeKey!))
                        }
//                        VStack(alignment: .leading, spacing: 20) {
//                            Button(action: {
//
//                                debugButton()
//
//                            }, label: {
//                                Text("DEBUG")
//                            })
//                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(VisualEffectBlur(material: .popover))
                    .cornerRadius(15)
                    .shadow(radius: 30)
                    .animation(.spring(response: 0.2, dampingFraction: 0.75, blendDuration: 0.2), value: show_meta)
                    .offset(x: 0, y: show_meta ? 0 : geo.size.height + 100)
                }
            }
            .padding(15)
        }
        .padding(0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectBlur(material: .popover))
        .onChange(of: viewMode, perform: { value in
            if (value == 2) {
                silica_doc.videoPlayer?.playImmediately(atRate: 1.0)
            } else if (value == 1) {
                // make sure image is zoomed to fit
                appState.zoomManager[fileurl]! = 1.0
                silica_doc.videoPlayer?.pause()
            }
        })
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
//        .frame(maxWidth: .infinity)
        .padding(0)
    }
}


struct BrushView: View {
    @ObservedObject var brush: SilicaBrush
    var padding:CGFloat = 5.0
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: brush.thumbnail!)
                .resizable()
                .if(colorScheme == .light) {
                    $0.colorInvert()
                }
                .background(
                    RoundedRectangle.init(cornerRadius: 6.0)
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .opacity(0.5)
                )
            Text(brush.name ?? "Untitled Brush")
                .font(.system(size: 14.0).weight(.bold))
                .foregroundColor(Color(colorScheme == .dark ? CGColor.init(gray: 0.7, alpha: 1.0) : CGColor.init(gray: 0.2, alpha: 1.0)))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
        }
        .padding(padding)
    }
}


struct BrushsetView: View {
    @ObservedObject var brushset: ProcreateBrushset
    @State var file: ProcreateDocumentType
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            if (brushset.brushsetImage != nil) {
                ScrollView(.vertical, showsIndicators: true, content: {
                    VStack(spacing: 0) {
                        ForEach(brushset.brushes!, id: \.self) { brush in
                            BrushView(brush: brush, padding: 0.0)
                                .frame(maxWidth: .infinity, maxHeight: 118)
                                .padding(.horizontal, 5.0)
                                .padding(.top, 5.0)
                        }
                    }
                    .padding(.bottom, 5.0)
                })
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.blue))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear() {
            DispatchQueue.main.async {
                file.loadBrushSet()
            }
        }
//        HStack() {
//            if (brushset.brushsetImage != nil) {
//                ScrollView(/*@START_MENU_TOKEN@*/.vertical/*@END_MENU_TOKEN@*/, showsIndicators: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/, content: {
//                    Image(nsImage: brushset.brushsetImage!)
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                })
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//                .if (colorScheme == .light) {
//                    $0.colorInvert()
//                }
//                .background(VisualEffectBlur.init(material: .underWindowBackground))
//            } else {
//                ProgressView()
//                    .progressViewStyle(CircularProgressViewStyle(tint: Color.blue))
//                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//            }
//        }
//        .onAppear() {
//            DispatchQueue.main.async {
//                brushset.loadBrushset(file: file.wrapper!)
//            }
//        }
    }
}


struct ProspectImageView: NSViewRepresentable {
    var fileurl: String
    @State var proImage: NSImage
    @State var image_view_size: CGSize
    @ObservedObject var state = appState
//    @State var scrollView:ImageViewer?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = ImageViewer(fileurl: fileurl)
//        let subviewFrame = CGRect(origin: .zero,
//                                  size: CGSize(width: image_view_size.width, height: image_view_size.height))
        let subviewFrame = CGRect(origin: .zero,
                                  size: CGSize(width: image_view_size.width, height: image_view_size.height))

        let documentView = NSView(frame: subviewFrame)
        documentView.wantsLayer = true

//        let scrollView = ImageViewer()
        scrollView.allowedTouchTypes = NSTouch.TouchTypeMask.indirect
        scrollView.contentView = CenteredClip(frame: subviewFrame)
        scrollView.documentView = documentView
        scrollView.contentView.constrainBoundsRect(NSRect(origin: .zero, size: subviewFrame.size))
        scrollView.contentView.scroll(to: CGPoint(x: 0, y: subviewFrame.size.height))
        scrollView.automaticallyAdjustsContentInsets = true
        scrollView.allowsMagnification = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        
        scrollView.drawsBackground = false
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
        nsView.animator().magnification = state.zoomManager[fileurl] ?? 1.0
        nsView.documentView?.layer?.contents = proImage
        nsView.documentView?.layer?.contentsGravity = .resizeAspect
    }
}

class ImageViewer: NSScrollView {
    var fileurl: String
    
    init(fileurl: String) {
        self.fileurl = fileurl
        super.init(frame: NSRect(x: 0.0, y: 0.0, width: 10.0, height: 10.0))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
//        override func touchesMoved(with event: NSEvent) {
//            sync_magnification = self.magnification
//        }
    
    override func magnify(with event: NSEvent) {
        super.magnify(with: event)
        if (event.phase == .ended) {
            appState.zoomManager[fileurl]! = self.magnification
        }
    }
    
    override func rotate(with event: NSEvent) {
        super.rotate(with: event)
//            self.frameCenterRotation = CGFloat(-event.rotation)
//            self.rotate(byDegrees: CGFloat(-event.rotation))
    }
    
//        override var acceptsFirstResponder: Bool { true }
//        override func keyDown(with event: NSEvent) {
//            super.keyDown(with: event)
//            print(">> key \(event.keyCode)")
//        }
}

struct Procreate3DView: View {
    var file: ProcreateDocumentType
    var fileurl: String
    @State var proImage: NSImage
    @State var image_view_size: CGSize
    @State var scene_load_progress: CGFloat = 0
    @Binding var show_meta: Bool
    @ObservedObject var state = appState
    
    var body: some View {
        ZStack {
            SceneKitView(file: file, scene_load_progress: $scene_load_progress, show_meta: $show_meta)
                .onTapGesture {
                    print("tapped the thing")
                }
            if (scene_load_progress < 1.0) {
                VStack(spacing: 0, content: {
                    ProgressView(value: scene_load_progress)
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.blue))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VisualEffectBlur(material: .popover))
            }
        }

    }
}


extension View {
    @ViewBuilder func `if`<T>(_ condition: Bool, transform: (Self) -> T) -> some View where T : View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
