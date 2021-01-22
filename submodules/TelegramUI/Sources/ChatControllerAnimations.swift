import Foundation
import UIKit
import Display

extension ChatController {
    private func messageSentAnimationCallback(chatControllerNode: ChatControllerNode) -> ChatHistoryListViewTransition.AnimationCallback {
        return { [weak wChatControllerNode = chatControllerNode] (node: ListViewItemNode, completion: (() -> Void)?) in
            guard let chatControllerNode = wChatDisplayNode else { return }
            guard let node = node as? ChatMessageBubbleItemNode else { return }
            guard let inputPanelNode = chatControllerNode.inputPanelNode as? ChatTextInputPanelNode else { return }
            
            let textInputNode = inputPanelNode.textInputContainer
            let textInputNodeBounds = textInputNode.bounds
            let textInputNodeFrameConverted = textInputNode.view.convert(textInputNode.view.bounds, to: chatControllerNode.view)
            
            let animatingNode = node.mainContainerNode
            let animatingNodeFrame = animatingNode.frame
            // ASDisplayNode.convert() is giving wrong value, using UIView.convert() instead
            let animatingNodeFrameConverted = animatingNode.view.convert(animatingNode.view.bounds, to: chatControllerNode.view)
            
            let animatingNodeSupernode = animatingNode.supernode!
            let animatingNodeIndex = animatingNodeSupernode.subnodes!.firstIndex(of: animatingNode)!
            
            let animatingBackgroundNode = node.backgroundNode
            let animatingBackgroundNodeFrame = animatingBackgroundNode.frame
            let animatingBackgroundNodeBounds = animatingBackgroundNode.bounds
            
            let animatingContentNode = node.chatMessageTextBubbleContentNode!
            let animatingContentNodeFrame = animatingContentNode.frame
            
            let animatingStatusNode = animatingContentNode.statusNode
            let animatingStatusNodeAlpha = animatingStatusNode.alpha
            
            // Remove node content view from list view.
            // Move it on top of current top view.
            // Mimic text view proportions
            do {
                animatingNode.removeFromSupernode()
                chatControllerNode.addSubnode(animatingNode)
                
                animatingNode.frame = textInputNodeFrameConverted
                animatingBackgroundNode.frame = textInputNodeBounds
                animatingContentNode.frame = textInputNodeBounds
                animatingStatusNode.alpha = CGFloat.zero
            }
            
            func toRadians(_ degrees: CGFloat) -> CGFloat {
                degrees * .pi / 180.0
            }
            
            // Create sublayer with tail image.
            // Actualy here are 3 ways it can be improved:
            // 1. Draw tail as a part of the background bubble path, so it's transformation could be animated
            // 2. Instead of UIImage draw a path
            // 3. Have stored prepared image somewhere in "theme.chat"
            let tailLayer = CALayer()
            do {
                let image: UIImage
                // draw tail image
                do {
                    let tailColor = animatingBackgroundNode.chatMessageBackgroundFillColor
                    let imageSize = animatingBackgroundNodeFrame.size
                    let imageWidth = imageSize.width
                    let imageHeight = imageSize.height
                    let maxCornerRadius = animatingBackgroundNode.chatMessageBackgroundMaxCornerRadius
                    let tailWidth: CGFloat = 6.0
                    let inset: CGFloat = 1.0 // some random inset, probably to stroke
                    let rightInset: CGFloat = tailWidth + inset
                    // Should be extracted to some global constant or config
                    let minRadiusForFullTailCorner: CGFloat = 14.0
                    
                    // Please, be ready for all these random numbers... It is working though
                    // I took it from ChatMessageBubbleImages.swift
                    let bottomEllipse = CGRect(origin: CGPoint(x: imageWidth - 15.0 - inset, y: imageHeight - 17.0 - inset),
                                               size: CGSize(width: 27.0, height: 17.0))
                    let topEllipse = CGRect(origin: CGPoint(x: imageWidth - rightInset, y: imageHeight - 19.0 - inset),
                                            size: CGSize(width: 23.0, height: 21.0))
                    
                    let formContext = DrawingContext(size: imageSize)
                    formContext.withContext { context in
                        context.setFillColor(tailColor.cgColor)
                        // Choose tail size
                        if maxCornerRadius >= minRadiusForFullTailCorner {
                            context.move(to: CGPoint(x: bottomEllipse.minX, y: bottomEllipse.midY))
                            context.addQuadCurve(to: CGPoint(x: bottomEllipse.midX, y: bottomEllipse.maxY),
                                                 control: CGPoint(x: bottomEllipse.minX, y: bottomEllipse.maxY))
                            context.addQuadCurve(to: CGPoint(x: bottomEllipse.maxX, y: bottomEllipse.midY),
                                                 control: CGPoint(x: bottomEllipse.maxX, y: bottomEllipse.maxY))
                            context.fillPath()
                        } else {
                            context.fill(CGRect(origin: CGPoint(x: bottomEllipse.minX - 2.0, y: bottomEllipse.midY),
                                                size: CGSize(width: bottomEllipse.width + 2.0, height: bottomEllipse.height / 2.0)))
                        }
                        context.fill(CGRect(origin: CGPoint(x: imageWidth / 2.0, y: floor(imageHeight / 2.0)),
                                            size: CGSize(width: imageWidth / 2.0 - rightInset, height: ceil(bottomEllipse.midY) - floor(imageHeight / 2.0))))
                        context.setFillColor(UIColor.clear.cgColor)
                        context.setBlendMode(.copy)
                        context.fillEllipse(in: topEllipse)
                    }
                    image = formContext.generateImage()!
                }
                
                tailLayer.contents = image.cgImage
                tailLayer.frame = CGRect(origin: CGPoint(x: textInputNodeBounds.width - animatingBackgroundNodeBounds.width,
                                                         y: textInputNodeBounds.height - animatingBackgroundNodeBounds.height),
                                         size: animatingBackgroundNodeBounds.size)
                tailLayer.opacity = 0.0
                animatingBackgroundNode.layer.addSublayer(tailLayer)
            }
            
            // Create sublayer with bubble backround image.
            let backgroundShapeLayer = CAShapeLayer()
            do {
                let path = UIBezierPath()
                // draw bubble path
                do {
                    let layerWidth = textInputNodeFrameConverted.width
                    let layerHeight = textInputNodeFrameConverted.height
                    let radius: CGFloat = min(inputPanelNode.minimalInputHeight() / 2.0, layerHeight / 2.0)
                    
                    // Points in corners to draw arcs around
                    let topLeftX: CGFloat = radius
                    let topLeftY: CGFloat = radius
                    let topRightX: CGFloat = layerWidth - radius
                    let topRightY: CGFloat = radius
                    let bottomRightX: CGFloat = layerWidth - radius
                    let bottomRightY: CGFloat = layerHeight - radius
                    let bottomLeftX: CGFloat = radius
                    let bottomLeftY: CGFloat = layerHeight - radius
                    
                    path.move(to: CGPoint(x: 0.0, y: topLeftY))
                    path.addArc(withCenter: CGPoint(x: topLeftX, y: topLeftY),
                                radius: radius,
                                startAngle: toRadians(180.0),
                                endAngle: toRadians(270.0),
                                clockwise: true)
                    path.addLine(to: CGPoint(x: topRightX, y: 0.0))
                    path.addArc(withCenter: CGPoint(x: topRightX, y: topRightY),
                                radius: radius,
                                startAngle: toRadians(270.0),
                                endAngle: toRadians(0.0),
                                clockwise: true)
                    path.addLine(to: CGPoint(x: layerWidth, y: bottomRightY))
                    path.addArc(withCenter: CGPoint(x: bottomRightX, y: bottomRightY),
                                radius: radius,
                                startAngle: toRadians(0.0),
                                endAngle: toRadians(90.0),
                                clockwise: true)
                    path.addLine(to: CGPoint(x: bottomLeftX, y: layerHeight))
                    path.addArc(withCenter: CGPoint(x: bottomLeftX, y: bottomLeftY),
                                radius: radius,
                                startAngle: toRadians(90.0),
                                endAngle: toRadians(180.0),
                                clockwise: true)
                    path.addLine(to: CGPoint(x: 0.0, y: topLeftY))
                    path.close()
                }
                
                backgroundShapeLayer.path = path.cgPath
                backgroundShapeLayer.strokeColor = inputPanelNode.inputStrokeColor().cgColor
                backgroundShapeLayer.fillColor = inputPanelNode.inputBackgroundColor().cgColor
                animatingBackgroundNode.layer.addSublayer(backgroundShapeLayer)
            }
            
            let duration = 0.5
            
            // Preparations are done, it's time to do animations!
            do {
                CATransaction.begin()
                CATransaction.setCompletionBlock { [weak wAnimatingNode = animatingNode,
                                                    weak wAnimatingBackgroundNode = animatingBackgroundNode,
                                                    weak wAnimatingContentNode = animatingContentNode,
                                                    weak wAnimatingNodeSupernode = animatingNodeSupernode] in
                    guard let sAnimatingNode = wAnimatingNode,
                          let sAnimatingBackgroundNode = wAnimatingBackgroundNode,
                          let sAnimatingContentNode = wAnimatingContentNode,
                          let sAnimatingNodeSupernode = wAnimatingNodeSupernode else {
                        return
                    }
                    backgroundShapeLayer.removeFromSuperlayer()
                    sAnimatingNode.removeFromSupernode()
                    sAnimatingNodeSupernode.insertSubnode(sAnimatingNode, at: animatingNodeIndex)
                    sAnimatingNode.frame = animatingNodeFrame
                    sAnimatingBackgroundNode.frame = animatingBackgroundNodeFrame
                    sAnimatingContentNode.frame = animatingContentNodeFrame
                    sAnimatingBackgroundNode.showImages()
                    if let completion = completion {
                        completion()
                    }
                }
                
                func calculatePosition(_ frame: CGRect) -> CGPoint {
                    return CGPoint(x: frame.midX, y: frame.midY)
                }
                
                func resizeAnimation(_ layer: CALayer, _ size: CGSize, _ duration: Double) -> CABasicAnimation {
                    let resizeAnimation = CABasicAnimation(keyPath: "bounds")
                    resizeAnimation.fromValue = layer.bounds
                    resizeAnimation.toValue = [CGFloat.zero, CGFloat.zero, size.width, size.height]
                    resizeAnimation.duration = duration
                    return resizeAnimation
                }
                
                func repositionAnimation(_ layer: CALayer, _ position: CGPoint, _ duration: Double) -> CABasicAnimation {
                    let repositionAnimation = CABasicAnimation(keyPath: "position")
                    repositionAnimation.fromValue = layer.position
                    repositionAnimation.toValue = [position.x, position.y]
                    repositionAnimation.duration = duration
                    return repositionAnimation
                }
                
                func addAnimations(_ layer: CALayer, _ animations: [CAAnimation]) {
                    let animationGroup = CAAnimationGroup()
                    animationGroup.animations = animations
                    animationGroup.duration = duration
                    layer.add(animationGroup, forKey: "animationGroup")
                }
                
                do { // animatingNode
                    let animations = [
                        resizeAnimation(animatingNode.layer, animatingNodeFrameConverted.size, duration),
                        repositionAnimation(animatingNode.layer, calculatePosition(animatingNodeFrameConverted), duration)
                    ]
                    animatingNode.frame = animatingNodeFrameConverted
                    addAnimations(animatingNode.layer, animations)
                }
                
                do { // animatingBackgroundNode
                    let animations = [
                        resizeAnimation(animatingBackgroundNode.layer, animatingBackgroundNodeFrame.size, duration),
                        repositionAnimation(animatingBackgroundNode.layer, calculatePosition(animatingBackgroundNodeFrame), duration)
                    ]
                    animatingBackgroundNode.frame = animatingBackgroundNodeFrame
                    addAnimations(animatingBackgroundNode.layer, animations)
                }
                
                do { // backgroundShapeLayer
                    let neighbors = animatingBackgroundNode.neighborsDirection
                    let minCornerRadius = animatingBackgroundNode.chatMessageBackgroundMinCornerRadius
                    let maxCornerRadius = animatingBackgroundNode.chatMessageBackgroundMaxCornerRadius
                    
                    let path = UIBezierPath()
                    do { // draw path
                        let topLeftRadius: CGFloat
                        let topRightRadius: CGFloat
                        let bottomLeftRadius: CGFloat
                        let bottomRightRadius: CGFloat
                        
                        switch neighbors {
                        case .bottom:
                            topLeftRadius = maxCornerRadius
                            topRightRadius = minCornerRadius
                            bottomLeftRadius = maxCornerRadius
                            bottomRightRadius = maxCornerRadius
                        default:
                            topLeftRadius = maxCornerRadius
                            topRightRadius = maxCornerRadius
                            bottomLeftRadius = maxCornerRadius
                            bottomRightRadius = maxCornerRadius
                        }
                        
                        let inset: CGFloat = 1.0 // ???
                        let rightInset: CGFloat = inset + 6.0 // We need more magic numbers!
                        let layerWidth = animatingBackgroundNodeBounds.width
                        let layerHeight = animatingBackgroundNodeBounds.height
                        
                        // Points in corners to draw arcs around
                        let topLeftX: CGFloat = inset + topLeftRadius
                        let topLeftY: CGFloat = inset + topLeftRadius
                        let topRightX: CGFloat = layerWidth - rightInset - topRightRadius
                        let topRightY: CGFloat = inset + topRightRadius
                        let bottomRightX: CGFloat = layerWidth - rightInset - bottomRightRadius
                        let bottomRightY: CGFloat = layerHeight - inset - bottomRightRadius
                        let bottomLeftX: CGFloat = inset + bottomLeftRadius
                        let bottomLeftY: CGFloat = layerHeight - inset - bottomLeftRadius
                        
                        // Boarders
                        let leftX: CGFloat = inset
                        let topY: CGFloat = inset
                        let rightX: CGFloat = layerWidth - rightInset
                        let bottomY: CGFloat = layerHeight - inset
                        
                        path.move(to: CGPoint(x: leftX, y: topLeftY))
                        path.addArc(withCenter: CGPoint(x: topLeftX, y: topLeftY),
                                    radius: topLeftRadius,
                                    startAngle: toRadians(180.0),
                                    endAngle: toRadians(270.0),
                                    clockwise: true)
                        path.addLine(to: CGPoint(x: topRightX, y: topY))
                        path.addArc(withCenter: CGPoint(x: topRightX, y: topRightY),
                                    radius: topRightRadius,
                                    startAngle: toRadians(270.0),
                                    endAngle: toRadians(0.0),
                                    clockwise: true)
                        path.addLine(to: CGPoint(x: rightX, y: bottomRightY))
                        path.addArc(withCenter: CGPoint(x: bottomRightX, y: bottomRightY),
                                    radius: bottomRightRadius,
                                    startAngle: toRadians(0.0),
                                    endAngle: toRadians(90.0),
                                    clockwise: true)
                        path.addLine(to: CGPoint(x: bottomLeftX, y: bottomY))
                        path.addArc(withCenter: CGPoint(x: bottomLeftX, y: bottomLeftY),
                                    radius: bottomLeftRadius,
                                    startAngle: toRadians(90.0),
                                    endAngle: toRadians(180.0),
                                    clockwise: true)
                        path.addLine(to: CGPoint(x: leftX, y: topLeftY))
                        path.close()
                    }
                    
                    let redrawPathAnimation = CABasicAnimation(keyPath: "path")
                    redrawPathAnimation.fromValue = backgroundShapeLayer.path
                    redrawPathAnimation.toValue = path.cgPath
                    redrawPathAnimation.duration = duration
                    backgroundShapeLayer.path = path.cgPath
                    
                    let newStrokeColor = UIColor.clear.cgColor // animatingBackgroundNode.chatMessageBackgroundStrokeColor.cgColor
                    let redrawStrokeAnimation = CABasicAnimation(keyPath: "strokeColor")
                    redrawStrokeAnimation.fromValue = backgroundShapeLayer.strokeColor
                    redrawStrokeAnimation.toValue = newStrokeColor
                    redrawStrokeAnimation.duration = duration
                    backgroundShapeLayer.strokeColor = newStrokeColor
                    
                    let newFillColor = animatingBackgroundNode.chatMessageBackgroundFillColor.cgColor
                    let redrawFillAnimation = CABasicAnimation(keyPath: "fillColor")
                    redrawFillAnimation.fromValue = backgroundShapeLayer.fillColor
                    redrawFillAnimation.toValue = newFillColor
                    redrawFillAnimation.duration = duration
                    backgroundShapeLayer.fillColor = newFillColor
                    
                    let animations = [redrawPathAnimation, redrawStrokeAnimation, redrawFillAnimation]
                    addAnimations(backgroundShapeLayer, animations)
                }
                
                do { // tailShapeLayer
                    let animation = repositionAnimation(tailLayer, calculatePosition(animatingBackgroundNodeBounds), duration)
                    tailLayer.frame = animatingBackgroundNodeBounds
                    
                    let newOpacity: Float = 1.0
                    let showAnimation = CABasicAnimation(keyPath: "opacity")
                    showAnimation.fromValue = tailLayer.opacity
                    showAnimation.toValue = newOpacity
                    showAnimation.duration = duration
                    tailLayer.opacity = newOpacity
                    
                    let animations = [animation, showAnimation]
                    addAnimations(tailLayer, animations)
                }
                
                do { // animatingContentNode
                    let animations = [
                        resizeAnimation(animatingContentNode.layer, animatingContentNodeFrame.size, duration),
                        repositionAnimation(animatingContentNode.layer, calculatePosition(animatingContentNodeFrame), duration)
                    ]
                    animatingContentNode.frame = animatingContentNodeFrame
                    addAnimations(animatingContentNode.layer, animations)
                }
                
                do { // animatingStatusNode
                    let showAnimation = CABasicAnimation(keyPath: "opacity")
                    showAnimation.fromValue = animatingStatusNode.layer.opacity
                    showAnimation.toValue = animatingStatusNodeAlpha
                    showAnimation.duration = duration
                    animatingStatusNode.alpha = animatingStatusNodeAlpha
                    animatingStatusNode.layer.add(showAnimation, forKey: "animation")
                }
                
                CATransaction.commit()
            }
        }
    }
}
