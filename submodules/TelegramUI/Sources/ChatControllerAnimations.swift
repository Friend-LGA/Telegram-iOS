import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData

fileprivate extension CGRect {
    func toBounds() -> CGRect {
        return CGRect(origin: CGPoint.zero, size: self.size)
    }
    
    var position: CGPoint {
        return CGPoint(x: self.midX, y: self.midY)
    }
}

fileprivate struct Config {
    let animationDuration: Double = 5.0
    let textInputNode: (convertedFrame: CGRect, contentOffset: CGPoint, insets: UIEdgeInsets)
    let animatingNode: (originalFrame: CGRect, convertedFrame: CGRect, originalSubnodeIndex: Int)
    let animatingBackgroundNodeOriginalFrame: CGRect
    let animatingContentNodeOriginalFrame: CGRect
    let animatingTextNode: (originalFrame: CGRect, insets: UIEdgeInsets)
    let animatingStatusNode: (originalFrame: CGRect, originalAlpha: CGFloat)
    let textInputStyle: (fillColor: UIColor, strokeColor: UIColor, minimalInputHeight: CGFloat)
    let bubbleStyle: (fillColor: UIColor, strokeColor: UIColor, minCornerRadius: CGFloat, maxCornerRadius: CGFloat, neighborsDirection: MessageBubbleImageNeighbors)
    
    init(chatControllerNode: ChatControllerNode,
         inputPanelNode: ChatTextInputPanelNode,
         textInputNode: ASDisplayNode,
         animatingNode: ASDisplayNode,
         animatingNodeSupernode: ASDisplayNode,
         animatingBackgroundNode: ChatMessageBackground,
         animatingContentNode: ChatMessageTextBubbleContentNode,
         animatingTextNode: ASDisplayNode,
         animatingStatusNode: ASDisplayNode) {
        // ASDisplayNode.convert() is giving wrong values, using UIView.convert() instead
        self.textInputNode = (convertedFrame: chatControllerNode.textInputLastFrame ?? textInputNode.view.convert(textInputNode.view.bounds, to: chatControllerNode.view),
                              contentOffset: chatControllerNode.textInputLastContentOffset ?? CGPoint.zero,
                              insets: inputPanelNode.textInputNode?.textContainerInset ?? UIEdgeInsets.zero)
        
        self.animatingNode = (originalFrame: animatingNode.frame,
                              convertedFrame: animatingNode.view.convert(animatingNode.view.bounds, to: chatControllerNode.view),
                              originalSubnodeIndex: animatingNodeSupernode.subnodes!.firstIndex(of: animatingNode)!)
        
        self.animatingBackgroundNodeOriginalFrame = animatingBackgroundNode.frame
        self.animatingContentNodeOriginalFrame = animatingContentNode.frame
        
        self.animatingTextNode = (originalFrame: animatingTextNode.frame,
                                  insets: animatingContentNode.textNodeInsets)
            
        self.animatingStatusNode = (originalFrame: animatingStatusNode.frame,
                                    originalAlpha: animatingStatusNode.alpha)
        
        self.textInputStyle = (fillColor: inputPanelNode.inputBackgroundColor(),
                               strokeColor: inputPanelNode.inputStrokeColor(),
                               minimalInputHeight: inputPanelNode.minimalInputHeight())
        
        self.bubbleStyle = (fillColor: animatingBackgroundNode.chatMessageBackgroundFillColor,
                            strokeColor: animatingBackgroundNode.chatMessageBackgroundStrokeColor,
                            minCornerRadius: animatingBackgroundNode.chatMessageBackgroundMinCornerRadius,
                            maxCornerRadius: animatingBackgroundNode.chatMessageBackgroundMaxCornerRadius,
                            neighborsDirection: animatingBackgroundNode.neighborsDirection)
    }
}

fileprivate func toRadians(_ degrees: CGFloat) -> CGFloat {
    degrees * .pi / 180.0
}

fileprivate func generateTailImage(_ config: Config) -> UIImage {
    let tailColor = config.bubbleStyle.fillColor
    let imageSize = config.animatingBackgroundNodeOriginalFrame.size
    let imageWidth = imageSize.width
    let imageHeight = imageSize.height
    let maxCornerRadius = config.bubbleStyle.maxCornerRadius
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
    return formContext.generateImage()!
}

fileprivate func generateTextInputBackgroundPath(_ config: Config) -> UIBezierPath {
    let path = UIBezierPath()
    let layerWidth = config.textInputNode.convertedFrame.width
    let layerHeight = config.textInputNode.convertedFrame.height
    let radius: CGFloat = min(config.textInputStyle.minimalInputHeight / 2.0, layerHeight / 2.0)
    
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
    return path
}

fileprivate func generateBubbleBackgroundPath(_ config: Config) -> UIBezierPath {
    let path = UIBezierPath()
    let topLeftRadius: CGFloat
    let topRightRadius: CGFloat
    let bottomLeftRadius: CGFloat
    let bottomRightRadius: CGFloat
    
    switch config.bubbleStyle.neighborsDirection {
    case .bottom:
        topLeftRadius = config.bubbleStyle.maxCornerRadius
        topRightRadius = config.bubbleStyle.minCornerRadius
        bottomLeftRadius = config.bubbleStyle.maxCornerRadius
        bottomRightRadius = config.bubbleStyle.maxCornerRadius
    default:
        topLeftRadius = config.bubbleStyle.maxCornerRadius
        topRightRadius = config.bubbleStyle.maxCornerRadius
        bottomLeftRadius = config.bubbleStyle.maxCornerRadius
        bottomRightRadius = config.bubbleStyle.maxCornerRadius
    }
    
    let inset: CGFloat = 1.0 // ???
    let tailWidth: CGFloat = 6.0 // We need more magic numbers!
    let rightInset: CGFloat = inset + tailWidth
    let layerWidth = config.animatingBackgroundNodeOriginalFrame.width
    let layerHeight = config.animatingBackgroundNodeOriginalFrame.height
    
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
    return path
}

fileprivate func setupResizeAnimation(_ layer: CALayer, _ size: CGSize, _ duration: Double) -> CABasicAnimation {
    let animation = CABasicAnimation(keyPath: "bounds")
    animation.fromValue = layer.bounds
    animation.toValue = [CGFloat.zero, CGFloat.zero, size.width, size.height]
    animation.duration = duration
    return animation
}

fileprivate func setupRepositionAnimation(_ layer: CALayer, _ position: CGPoint, _ duration: Double) -> CABasicAnimation {
    let animation = CABasicAnimation(keyPath: "position")
    animation.fromValue = layer.position
    animation.toValue = [position.x, position.y]
    animation.duration = duration
    return animation
}

fileprivate func addAnimations(_ layer: CALayer, _ animations: [CAAnimation], _ duration: Double) {
    let animationGroup = CAAnimationGroup()
    animationGroup.animations = animations
    animationGroup.duration = duration
    layer.add(animationGroup, forKey: "animationGroup")
}

struct ChatControllerAnimations {
    private init() {}
    
    static public func getAnimationCallback(chatControllerNode: ChatControllerNode) -> ChatHistoryListViewTransition.AnimationCallback {
        return { [weak wChatControllerNode = chatControllerNode] (node: ListViewItemNode, completion: (() -> Void)?) in
            guard let chatControllerNode = wChatControllerNode else { return }
            guard let node = node as? ChatMessageBubbleItemNode else { return }
            guard let inputPanelNode = chatControllerNode.inputPanelNode as? ChatTextInputPanelNode else { return }
            
            let textInputNode = inputPanelNode.textInputContainer
            let animatingNode = node.mainContainerNode
            let animatingNodeSupernode = animatingNode.supernode!
            let animatingBackgroundNode = node.backgroundNode
            let animatingContentNode = node.chatMessageTextBubbleContentNode!
            let animatingTextNode = animatingContentNode.textNode
            let animatingStatusNode = animatingContentNode.statusNode
            
            let config = Config(chatControllerNode: chatControllerNode,
                                inputPanelNode: inputPanelNode,
                                textInputNode: textInputNode,
                                animatingNode: animatingNode,
                                animatingNodeSupernode: animatingNodeSupernode,
                                animatingBackgroundNode: animatingBackgroundNode,
                                animatingContentNode: animatingContentNode,
                                animatingTextNode: animatingTextNode,
                                animatingStatusNode: animatingStatusNode)
            
            // Remove node content view from list view.
            // Move it above input panel, but below navigation bar
            // Mimic text view proportions
            animatingNode.removeFromSupernode()
            chatControllerNode.insertSubnode(animatingNode, aboveSubnode: chatControllerNode.inputContextPanelContainer)
            
            animatingNode.frame = config.textInputNode.convertedFrame
            animatingBackgroundNode.frame = config.textInputNode.convertedFrame.toBounds()
            
            animatingContentNode.frame = config.textInputNode.convertedFrame.toBounds()
            animatingContentNode.clipsToBounds = true
            
            // Actually we should calculate difference in insets here to match content,
            // but apparently it is working fine without it. Needs to be investigated.
            // let insetsOffsetY = config.animatingTextNode.insets.top - config.inputTextNode.insets.top
            let insetsOffsetY: CGFloat = 0
            animatingTextNode.frame = animatingTextNode.frame.offsetBy(dx: CGFloat.zero, dy: -config.textInputNode.contentOffset.y + insetsOffsetY)
            
            let animatingStatusNodeFrameOffsetX = config.animatingContentNodeOriginalFrame.width - config.animatingStatusNode.originalFrame.maxX
            let animatingStatusNodeFrameOffsetY = config.animatingContentNodeOriginalFrame.height - config.animatingStatusNode.originalFrame.maxY
            animatingStatusNode.frame = CGRect(origin: CGPoint(x: animatingContentNode.bounds.width - animatingStatusNodeFrameOffsetX - config.animatingStatusNode.originalFrame.size.width,
                                                               y: animatingContentNode.bounds.height - animatingStatusNodeFrameOffsetY - config.animatingStatusNode.originalFrame.size.height),
                                               size: config.animatingStatusNode.originalFrame.size)
            animatingStatusNode.alpha = CGFloat.zero
                        
            // Create sublayer with tail image.
            // Actualy here are 3 ways it can be improved:
            // 1. Draw tail as a part of the background bubble path, so it's transformation could be animated
            // 2. Instead of UIImage draw a path
            // 3. Have stored prepared image somewhere in "theme.chat"
            let tailLayer = CALayer()
            tailLayer.contents = generateTailImage(config).cgImage
            tailLayer.frame = CGRect(origin: CGPoint(x: animatingBackgroundNode.bounds.width - config.animatingBackgroundNodeOriginalFrame.width,
                                                     y: animatingBackgroundNode.bounds.height - config.animatingBackgroundNodeOriginalFrame.height),
                                     size: config.animatingBackgroundNodeOriginalFrame.size)
            tailLayer.opacity = 0.0
            animatingBackgroundNode.layer.addSublayer(tailLayer)
            
            // Create sublayer which mimics input text view background and will be transformed to bubble
            let backgroundShapeLayer = CAShapeLayer()
            backgroundShapeLayer.path = generateTextInputBackgroundPath(config).cgPath
            backgroundShapeLayer.strokeColor = config.textInputStyle.strokeColor.cgColor
            backgroundShapeLayer.fillColor = config.textInputStyle.fillColor.cgColor
            animatingBackgroundNode.layer.addSublayer(backgroundShapeLayer)
                        
            // Preparation is done, it's time to do animations!
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
                tailLayer.removeFromSuperlayer()
                sAnimatingNode.removeFromSupernode()
                sAnimatingNodeSupernode.insertSubnode(sAnimatingNode, at: config.animatingNode.originalSubnodeIndex)
                sAnimatingNode.frame = config.animatingNode.originalFrame
                sAnimatingBackgroundNode.frame = config.animatingBackgroundNodeOriginalFrame
                sAnimatingContentNode.frame = config.animatingContentNodeOriginalFrame
                sAnimatingBackgroundNode.showImages()
                if let completion = completion {
                    completion()
                }
            }
            
            do { // animatingNode
                let animations = [
                    setupResizeAnimation(animatingNode.layer, config.animatingNode.convertedFrame.size, config.animationDuration),
                    setupRepositionAnimation(animatingNode.layer, config.animatingNode.convertedFrame.position, config.animationDuration)
                ]
                animatingNode.frame = config.animatingNode.convertedFrame
                addAnimations(animatingNode.layer, animations, config.animationDuration)
            }
            
            do { // animatingBackgroundNode
                let animations = [
                    setupResizeAnimation(animatingBackgroundNode.layer, config.animatingBackgroundNodeOriginalFrame.size, config.animationDuration),
                    setupRepositionAnimation(animatingBackgroundNode.layer, config.animatingBackgroundNodeOriginalFrame.position, config.animationDuration)
                ]
                animatingBackgroundNode.frame = config.animatingBackgroundNodeOriginalFrame
                addAnimations(animatingBackgroundNode.layer, animations, config.animationDuration)
            }
            
            do { // backgroundShapeLayer
                let newPath = generateBubbleBackgroundPath(config)
                let redrawPathAnimation = CABasicAnimation(keyPath: "path")
                redrawPathAnimation.fromValue = backgroundShapeLayer.path
                redrawPathAnimation.toValue = newPath.cgPath
                redrawPathAnimation.duration = config.animationDuration
                backgroundShapeLayer.path = newPath.cgPath
                
                let newStrokeColor = UIColor.clear.cgColor // animatingBackgroundNode.chatMessageBackgroundStrokeColor.cgColor
                let redrawStrokeAnimation = CABasicAnimation(keyPath: "strokeColor")
                redrawStrokeAnimation.fromValue = backgroundShapeLayer.strokeColor
                redrawStrokeAnimation.toValue = newStrokeColor
                redrawStrokeAnimation.duration = config.animationDuration
                backgroundShapeLayer.strokeColor = newStrokeColor
                
                let newFillColor = animatingBackgroundNode.chatMessageBackgroundFillColor.cgColor
                let redrawFillAnimation = CABasicAnimation(keyPath: "fillColor")
                redrawFillAnimation.fromValue = backgroundShapeLayer.fillColor
                redrawFillAnimation.toValue = newFillColor
                redrawFillAnimation.duration = config.animationDuration
                backgroundShapeLayer.fillColor = newFillColor
                
                let animations = [redrawPathAnimation, redrawStrokeAnimation, redrawFillAnimation]
                addAnimations(backgroundShapeLayer, animations, config.animationDuration)
            }
            
            do { // tailShapeLayer
                let repositionAnimation = setupRepositionAnimation(tailLayer, config.animatingBackgroundNodeOriginalFrame.toBounds().position, config.animationDuration)
                tailLayer.frame = config.animatingBackgroundNodeOriginalFrame.toBounds()
                
                let newOpacity: Float = 1.0
                let showAnimation = CABasicAnimation(keyPath: "opacity")
                showAnimation.fromValue = tailLayer.opacity
                showAnimation.toValue = newOpacity
                showAnimation.duration = config.animationDuration
                tailLayer.opacity = newOpacity
                
                let animations = [repositionAnimation, showAnimation]
                addAnimations(tailLayer, animations, config.animationDuration)
            }
            
            do { // animatingContentNode
                let animations = [
                    setupResizeAnimation(animatingContentNode.layer, config.animatingContentNodeOriginalFrame.size, config.animationDuration),
                    setupRepositionAnimation(animatingContentNode.layer, config.animatingContentNodeOriginalFrame.position, config.animationDuration)
                ]
                animatingContentNode.frame = config.animatingContentNodeOriginalFrame
                addAnimations(animatingContentNode.layer, animations, config.animationDuration)
            }
            
            do { // animatingTextNode
                let repositionAnimation = setupRepositionAnimation(animatingTextNode.layer, config.animatingTextNode.originalFrame.position, config.animationDuration)
                animatingTextNode.frame = config.animatingTextNode.originalFrame
                animatingTextNode.layer.add(repositionAnimation, forKey: "animation")
            }
            
            do { // animatingStatusNode
                let repositionAnimation = setupRepositionAnimation(animatingStatusNode.layer, config.animatingStatusNode.originalFrame.position, config.animationDuration)
                animatingStatusNode.frame = config.animatingStatusNode.originalFrame
                
                let showAnimation = CABasicAnimation(keyPath: "opacity")
                showAnimation.fromValue = animatingStatusNode.layer.opacity
                showAnimation.toValue = config.animatingStatusNode.originalAlpha
                showAnimation.duration = config.animationDuration
                animatingStatusNode.alpha = config.animatingStatusNode.originalAlpha
                
                let animations = [repositionAnimation, showAnimation]
                addAnimations(animatingStatusNode.layer, animations, config.animationDuration)
            }
            
            CATransaction.commit()
        }
    }
}
