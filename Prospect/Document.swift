//
//  Document.swift
//  Prospect
//
//  Created by Vogel Family on 11/2/20.
//

import Cocoa
import SwiftUI
import ZIPFoundation
import ProcreateDocument

//public var composite_image:NSImage?
public var file_ext:String?
public var pro_url:URL?

class Document: NSDocument {
    
    weak var si_doc:SilicaDocument?
    
    override init() {
        super.init()
        // Add your subclass-specific initialization here.
    }
    
    @IBAction func presentExportDialog(_ sender: Any?) {
        exportController(si_doc: si_doc).presentDialog(nil)
    }

    override class var autosavesInPlace: Bool {
        return false
    }
    
    override func close() {
        assert(Thread.isMainThread)
        super.close()
        self.si_doc?.composite_image = nil
        self.si_doc?.composite = nil
        self.si_doc = nil
    }
    
//    override func makeWindowControllers() {
//        var contentView:ContentView?
//        var image_size = CGSize(width: 800, height: 800)
//        
//        if (file_ext == "procreate") {
//            // Calculate the window size based on image aspect ratio.
//            image_size = getImageSize(si_doc: si_doc!, minWidth: 300, maxWidth: 1000)
//            
//            // Create the SwiftUI view that provides the window contents.
//            contentView = ContentView(si_doc: si_doc, image_view_size: image_size) // remove metadata space
//
//        } else if (file_ext == "brush") {
//            image_size = CGSize(width: 600, height: 300)
//            contentView = ContentView(image_view_size: image_size, url: pro_url)
//        }
//        let window = NSWindow(
//            contentRect: NSRect(origin: .zero, size: image_size),
//            styleMask: [.titled, .closable, .miniaturizable, .resizable],
//            backing: .buffered, defer: false)
//        window.isReleasedWhenClosed = true
//        window.center()
////        window.toolbar = NSToolbar()
////        window.toolbarStyle = .unifiedCompact
////        let item1id = NSToolbarItem.Identifier.init("item1")
////        let toolbarItem1 = NSToolbarItem(itemIdentifier: item1id)
////        toolbarItem1.label = "hello"
////        toolbarItem1.image = NSImage(systemSymbolName: "book.circle", accessibilityDescription: "hey")
////        window.toolbar?.insertItem(withItemIdentifier: item1id, at: 0)
//        
//        window.contentView = NSHostingView(rootView: contentView)
//        let windowController = NSWindowController(window: window)
//        self.addWindowController(windowController)
//    }
    
    override func data(ofType typeName: String) throws -> Data {
        // Insert code here to write your document to data of the specified type, throwing an error in case of failure.
        // Alternatively, you could remove this method and override fileWrapper(ofType:), write(to:ofType:), or write(to:ofType:for:originalContentsURL:) instead.
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

    override var isEntireFileLoaded: Bool {
        return false
    }
    
    override func read(from url: URL, ofType typeName: String) throws {
        // Insert code here to read your document from the given data of the specified type, throwing an error in case of failure.
        // Alternatively, you could remove this method and override read(from:ofType:) instead.
        // If you do, you should also override isEntireFileLoaded to return false if the contents are lazily loaded.
        
//        file_ext = url.pathExtension
//        if (file_ext == "brush") {
//            si_doc = nil
//            pro_url = url
//        } else if (file_ext == "procreate") {
//            pro_url = url
//            si_doc = getArchive(pro_url!)
//            
////            si_doc?.getComposite(url)
//            si_doc?.getComposite(url, {
//                // Do something after composite loads
//                self.si_doc?.objectWillChange.send()
//                self.si_doc?.composite_image?.objectWillChange.send()
//            })
//        }

        // Throw this if you can't open the document for whatever reason
//        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }
}
