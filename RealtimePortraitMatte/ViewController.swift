//
//  ViewController.swift
//  RealtimePortraitMatte
//
//  Created by kuno on 2019/10/28.
//  Copyright © 2019 BIRDMAN Inc. All rights reserved.
//

import UIKit
import Metal
import MetalKit
import ARKit

extension MTKView : RenderDestinationProvider {
}

class ViewController: UIViewController, MTKViewDelegate, ARSessionDelegate {
   
        var session: ARSession!
        var renderer: Renderer!
        var displayLink : CADisplayLink?
    
        var frontImage: UIImage!
        var backImage: UIImage!

        override func viewDidLoad() {
            super.viewDidLoad()
            
            session = ARSession()
            session.delegate = self
            
            if let view = self.view as? MTKView {
                view.device = MTLCreateSystemDefaultDevice()
                view.backgroundColor = UIColor.clear
                view.delegate = self
                view.autoResizeDrawable = false
                guard view.device != nil else {
                    print("Metal is not supported on this device")
                    return
                }
                renderer = Renderer(session: session, metalDevice: view.device!, renderDestination: view)
                renderer.drawRectResized(size: view.bounds.size)
            }
            displayLink = CADisplayLink(target: self, selector: #selector(updateSequanceImages(_:)))
            displayLink!.add(to: .current, forMode: .default)
        }
        
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            let configuration = ARWorldTrackingConfiguration()
            configuration.frameSemantics = .personSegmentationWithDepth
            session.run(configuration)
            //常に手前に表示する画像(今回はダミー)
            let frontImagePath = Bundle.main.path(forResource: "dummy", ofType: "png")
            frontImage = UIImage(contentsOfFile:frontImagePath!)!
            //ボーダー画像作成
            backImage = UIImage.borderImage(size: configuration.videoFormat.imageResolution)
            //Back Layerを挟み込む位置
            renderer.changeBackLayerDistance(0.5)
        }
        
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            session.pause()
        }
        
        @objc func updateSequanceImages(_ displayLink: CADisplayLink) {
            renderer.updateTexture(frontImage: frontImage, backImage: backImage)
        }
        
        // MARK: - MTKViewDelegate
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer.drawRectResized(size: size)
        }
        
        // Called whenever the view needs to render
        func draw(in view: MTKView) {
            renderer.update()
        }
        
        // MARK: - ARSessionDelegate
        
        func session(_ session: ARSession, didFailWithError error: Error) {
            // Present an error message to the user
        }
        
        func sessionWasInterrupted(_ session: ARSession) {
            // Inform the user that the session has been interrupted, for example, by presenting an overlay
        }
        
        func sessionInterruptionEnded(_ session: ARSession) {
            // Reset tracking and/or remove existing anchors if consistent tracking is required
        }
    }
