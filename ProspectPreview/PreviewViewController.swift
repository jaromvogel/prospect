//
//  PreviewViewController.swift
//  ProspectPreview
//
//  Created by Vogel Family on 11/8/20.
//

import Cocoa
import Quartz
import ProcreateDocument
//import Prospect

public var si_doc:SilicaDocument?
public var pro_url:URL?

class PreviewViewController: NSViewController, QLPreviewingController, QLPreviewPanelDelegate {
    
    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
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
    
    
    // Clean up memory when dismissing a preview
    override func viewDidDisappear() {
        si_doc?.cleanUp()
        si_doc = nil
        pro_url = nil
    }
    
    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        
        // Perform any setup necessary in order to prepare the view.
        let ext = url.pathExtension
        
        let documentView = NSView()
        documentView.wantsLayer = true
        self.previewScrollView.contentView = CenteredClip(frame: CGRect(origin: .zero, size: CGSize(width: 0, height: 0)))
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

            let _ = si_doc?.getLayer(si_doc!.composite, pro_file!, {
                let preview_size = getImageSize(si_doc: si_doc!, height: 700, minWidth: 300, maxWidth: 1000)
                let preview_size_w_title = CGSize(width: preview_size.width, height: preview_size.height)
                super.preferredContentSize = preview_size_w_title
                self.previewScrollView.documentView?.layer?.backgroundColor = .clear
                self.previewScrollView.documentView?.frame.size = preview_size
                self.previewScrollView.documentView?.layer?.contentsGravity = .resizeAspect
                self.previewScrollView.documentView?.layer?.contents = si_doc?.composite_image
                self.previewScrollView.contentView.constrainBoundsRect(NSRect(origin: .zero, size: preview_size_w_title))
                
                // Call the completion handler so Quick Look knows that the preview is fully loaded.
                // Quick Look will display a loading spinner while the completion handler is not called.
                handler(nil)
            })

        } else if (ext == "swatches") {
            let swatches_thumb = getSwatchesImage(pro_file!)
            let swatches_size = CGSize(width: 600, height: 180)
            self.preferredContentSize = swatches_size
            self.previewScrollView.documentView?.frame.size = swatches_size
            self.previewScrollView.documentView?.layer?.backgroundColor = .black
            self.previewScrollView.documentView?.layer?.contentsGravity = .resizeAspect
            self.previewScrollView.documentView?.layer?.contents = swatches_thumb
            
            handler(nil)
        } else if (ext == "brushset") {
            let metadata: ProcreateBrushset? = ProcreateBrushset()
            metadata?.getBrushsetImage(file: pro_file!)
//            var brushset_load:CGFloat = 0.0
            let brushset_image = metadata?.brushsetImage
            var brushset_size = CGSize(width: 400, height: 600)
//            self.preferredMaximumSize = CGSize(width: 200, height: 400)
            let aspectsize = CGSize(width: brushset_size.width, height: brushset_size.width / brushset_image!.size.width * brushset_image!.size.height)
//            self.title = self.view.frame.debugDescription
            if (brushset_size.height > aspectsize.height) {
                brushset_size.height = aspectsize.height
            }
            self.preferredContentSize = brushset_size
            self.previewScrollView.documentView?.frame.size = aspectsize
//            self.previewScrollView.documentView?.layer?.backgroundColor = CGColor
            self.previewScrollView.documentView?.layer?.contentsGravity = .resizeAspectFill
            self.previewScrollView.documentView?.layer?.contents = brushset_image
            if let documentView = self.previewScrollView.documentView {
                documentView.scroll(NSPoint(x: 0, y: documentView.bounds.size.height))
            }
            
            handler(nil)
        }
        
    }
    
    var zoom:CGFloat = 200.0

    override func magnify(with event: NSEvent) {
        if(event.phase == .changed){
            zoom += event.deltaZ
            self.previewScrollView.setMagnification(zoom / 200, centeredAt: self.view.convert(event.locationInWindow, to: self.previewScrollView.documentView))
        }
    }
}
