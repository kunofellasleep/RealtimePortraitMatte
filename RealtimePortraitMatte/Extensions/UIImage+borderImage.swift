//
//  BorderImage.swift
//  BordersApp
//
//  Created by kuno on 2019/09/27.
//  Copyright © 2019 kuno. All rights reserved.
//

import UIKit

extension UIImage {

    static func borderImage(size:CGSize)->UIImage{
        
        UIGraphicsBeginImageContext(size)
        let context:CGContext = UIGraphicsGetCurrentContext()!
        context.setLineWidth(50.0)
        
        let color = UIColor.white.cgColor
        context.setStrokeColor(color)

        context.move(to: CGPoint(x:0, y:size.height / 3 * 1))
        context.addLine(to: CGPoint(x:size.width, y:size.height / 3 * 1))
        context.closePath()
        
        context.move(to: CGPoint(x:0, y:size.height / 3 * 2))
        context.addLine(to: CGPoint(x:size.width, y:size.height / 3 * 2))
        context.closePath()
        
        context.strokePath()

        let img:CGImage = context.makeImage()!
        return UIImage(cgImage: img)
    }
}
