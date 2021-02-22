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
    
    var si_doc:SilicaDocument?
    
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
    
    override func makeWindowControllers() {
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView(si_doc: si_doc)

        // Create the window and set the content view.
        var image_size = CGSize(width: 800, height: 800)
        if (file_ext == "procreate") {
            image_size = getImageSize()
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: image_size.width + 300, height: image_size.height),
            styleMask: [.titled, .borderless, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = true
        window.center()
        window.contentView = NSHostingView(rootView: contentView)
        let windowController = NSWindowController(window: window)
        self.addWindowController(windowController)
    }
    
    func getImageSize() -> CGSize {
        var width = 800
        let height = 800
        let maxWidth = 1000
        let minWidth = 300
        var img_height = si_doc?.size?.height
        var img_width = si_doc?.size?.width

        var orientation:String
        if (si_doc?.orientation! == 3 || si_doc?.orientation! == 4) {
            orientation = "landscape"
            img_height = si_doc?.size?.width
            img_width = si_doc?.size?.height
        } else {
            orientation = "portrait"
        }
        
        let ratio = img_width! / img_height!
        
        if (orientation == "landscape") {
            width = Int(CGFloat(height) * ratio)
        } else {
            width = Int(CGFloat(width) * ratio)
        }
        
        if (width > maxWidth) {
            width = maxWidth
        } else if (width < minWidth) {
            width = minWidth
        }
        
        return CGSize(width: width, height: height)
    }

    
    
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
        
        file_ext = url.pathExtension
        if (file_ext == "brush") {
            si_doc = nil
        } else if (file_ext == "procreate") {
            pro_url = url
            let metadata: SilicaDocument? = getArchive(pro_url!)
            si_doc = metadata
            
            si_doc?.getComposite(url)
        }

        // Throw this if you can't open the document for whatever reason
//        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }
}
