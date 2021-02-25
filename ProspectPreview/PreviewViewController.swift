//
//  PreviewViewController.swift
//  ProspectPreview
//
//  Created by Vogel Family on 11/8/20.
//

import Cocoa
import Quartz
import ProcreateDocument

public var si_doc:SilicaDocument?
public var pro_url:URL?

class PreviewViewController: NSViewController, QLPreviewingController {
    
    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }

    override func loadView() {
        super.loadView()
//        super.preferredContentSize = (si_doc?.size)!
//        super.preferredContentSize = view.intrinsicContentSize
        
        if let panel = QLPreviewPanel.shared() {
            panel.acceptsMouseMovedEvents = true
            panel.setContentBorderThickness(0.0, for: .maxX)
            panel.setContentBorderThickness(0.0, for: .maxY)
            panel.setContentBorderThickness(0.0, for: .minX)
            panel.setContentBorderThickness(0.0, for: .minY)
        }
        
        // Do any additional setup after loading the view.
    }

    /*
     * Implement this method and set QLSupportsSearchableItems to YES in the Info.plist of the extension if you support CoreSpotlight.
     *
    func preparePreviewOfSearchableItem(identifier: String, queryString: String?, completionHandler handler: @escaping (Error?) -> Void) {
        // Perform any setup necessary in order to prepare the view.
        
        // Call the completion handler so Quick Look knows that the preview is fully loaded.
        // Quick Look will display a loading spinner while the completion handler is not called.
        handler(nil)
    }
     */
    
    @IBOutlet weak var previewScrollView: NSScrollView!
    
    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        
        // Perform any setup necessary in order to prepare the view.
        let ext = url.pathExtension
        
        let documentView = NSView()
        documentView.wantsLayer = true
        self.previewScrollView.documentView = documentView
        
        self.previewScrollView.allowsMagnification = true
        self.previewScrollView.autohidesScrollers = true
        self.previewScrollView.scrollerStyle = .overlay
        self.previewScrollView.horizontalScrollElasticity = .none
        self.previewScrollView.verticalScrollElasticity = .none
        self.previewScrollView.minMagnification = 1.0
        self.previewScrollView.maxMagnification = 100.0
        self.previewScrollView.usesPredominantAxisScrolling = false
        self.previewScrollView.backgroundColor = .clear
        self.view.layer?.backgroundColor = .clear
        
        pro_url = url
        var pro_file:FileWrapper?
        do {
            try pro_file = FileWrapper(url: pro_url!, options: .immediate)
        } catch {
            // couldn't create FileWrapper
        }
        
        if (ext == "brush") {
            let brush_thumb = getThumbImage(file: pro_file!)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                // your code here

                let brush_prev_size = CGSize(width: 800, height: 400)
                super.preferredContentSize = brush_prev_size
                self.previewScrollView.documentView?.frame.size = brush_prev_size
                self.previewScrollView.documentView?.layer?.backgroundColor = .black
                self.previewScrollView.documentView?.layer?.contentsGravity = .resizeAspect
                self.previewScrollView.documentView?.layer?.contents = brush_thumb
            
                handler(nil)
            }
        } else if (ext == "procreate") {
            let metadata: SilicaDocument? = getArchive(pro_file!)
            si_doc = metadata

            si_doc?.getComposite(pro_file!, {
                // Calculate size here, then set super.preferredContentSize, and maybe view.size? panel.contentView.size?
                let preview_size = getImageSize(si_doc: si_doc!, height: 700, minWidth: 300, maxWidth: 1000)
                let preview_size_w_title = CGSize(width: preview_size.width, height: preview_size.height)
                super.preferredContentSize = preview_size_w_title
                self.previewScrollView.documentView?.layer?.backgroundColor = .clear
                self.previewScrollView.documentView?.frame.size = preview_size
                self.previewScrollView.documentView?.layer?.contentsGravity = .resizeAspect
                self.previewScrollView.documentView?.layer?.contents = si_doc?.composite_image
                
                // Call the completion handler so Quick Look knows that the preview is fully loaded.
                // Quick Look will display a loading spinner while the completion handler is not called.
                handler(nil)
            })
        }
        
    }
    
    var zoom:CGFloat = 200.0

    override func magnify(with event: NSEvent) {
        if(event.phase == .changed){
            zoom += event.deltaZ
            self.previewScrollView.setMagnification(zoom / 200, centeredAt: self.view.convert(event.locationInWindow, to: self.previewScrollView.documentView))
        }
    }

    var commandPressed:Bool = false

    override func keyDown(with event: NSEvent) {
        zoom = 200.0
        self.previewScrollView.setMagnification(zoom / 200, centeredAt: NSPoint(x: 0, y: 0))

        if (event.keyCode == 55) {
            commandPressed = true
        }

        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if (event.keyCode == 55) {
            commandPressed = false
        }
    }
}
