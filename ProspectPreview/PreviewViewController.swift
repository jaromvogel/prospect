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
        
        if let panel = QLPreviewPanel.shared() {
            panel.acceptsMouseMovedEvents = true
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
    
    @IBOutlet weak var previewImageView: NSImageView!
    @IBOutlet weak var previewImage: NSImageCell!
    @IBOutlet weak var previewScrollView: NSScrollView!
    @IBOutlet weak var previewScrollChild: NSView!
    
    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        
        // Perform any setup necessary in order to prepare the view.
        let ext = url.pathExtension
        
        self.previewScrollView.allowsMagnification = true
        self.previewScrollView.autohidesScrollers = true
        self.previewScrollView.scrollerStyle = .overlay
        self.previewScrollView.automaticallyAdjustsContentInsets = true
        self.previewScrollView.horizontalScrollElasticity = .none
        self.previewScrollView.verticalScrollElasticity = .none
        self.previewScrollView.minMagnification = 1.0
        self.previewScrollChild.frame = self.previewScrollView.frame
        
        if (ext == "brush") {
            let brush_thumb = getThumbImage(url: url)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                // your code here
                self.previewScrollChild.layer?.backgroundColor = .black
                self.previewScrollChild.layer?.contentsGravity = .resizeAspect
                self.previewScrollChild.layer?.contents = brush_thumb
                handler(nil)
            }
        } else if (ext == "procreate") {
            pro_url = url
            let metadata: SilicaDocument? = getArchive(pro_url!)
            si_doc = metadata

            si_doc?.getComposite(url, {
    //            super.preferredContentSize = si_doc?.composite_image?.size ?? CGSize(width: 100, height: 100)
    //            self.view.layer = CALayer()
    //            self.view.layer?.contentsGravity = .resizeAspect
    //            self.view.layer?.contents = si_doc?.composite_image
    //            self.view.wantsLayer = true
                self.previewScrollChild.layer?.contentsGravity = .resizeAspect
                self.previewScrollChild.layer?.contents = si_doc?.composite_image
                
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
            self.previewScrollView.setMagnification(zoom / 200, centeredAt: self.view.convert(event.locationInWindow, to: self.previewScrollChild))
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
