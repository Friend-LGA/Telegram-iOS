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

fileprivate let animationDuration: Double = 0.5
fileprivate let animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

fileprivate struct Config {
    let inputTextContainerNode: (convertedFrame: CGRect, contentOffset: CGPoint, insets: UIEdgeInsets)
    let chatMessageMainContainerNode: (originalFrame: CGRect, convertedFrame: CGRect, originalSubnodeIndex: Int, originalClipsToBounds: Bool)
    let chatMessageMainContextNodeOriginalFrame: CGRect
    let chatMessageMainContextContentNodeOriginalFrame: CGRect
    let chatMessageBackgroundNode: (originalFrame: CGRect, offset: CGPoint)
    let chatMessageTextContentNodeOriginalFrame: CGRect
    let chatMessageTextNode: (originalFrame: CGRect, insets: UIEdgeInsets)
    let chatMessageStatusNode: (originalFrame: CGRect, offset: CGPoint, originalAlpha: CGFloat)
    let chatMessageWebpageContentNodeOriginalFrame: CGRect?
    let chatMessageReplyInfoNodeOriginalFrame: CGRect?
    let chatMessageForwardInfoNodeOriginalFrame: CGRect?
    let textInputStyle: (fillColor: UIColor, strokeColor: UIColor, minimalInputHeight: CGFloat)
    let bubbleStyle: (fillColor: UIColor, strokeColor: UIColor, minCornerRadius: CGFloat, maxCornerRadius: CGFloat, neighborsDirection: MessageBubbleImageNeighbors)
    
    init(viewNode: ChatControllerNode,
         inputPanelNode: ChatTextInputPanelNode,
         inputTextContainerNode: ASDisplayNode,
         chatMessageNode: ASDisplayNode,
         chatMessageMainContainerNode: ASDisplayNode,
         chatMessageMainContextNode: ASDisplayNode,
         chatMessageMainContextContentNode: ASDisplayNode,
         chatMessageBackgroundNode: ChatMessageBackground,
         chatMessageTextContentNode: ChatMessageTextBubbleContentNode,
         chatMessageTextNode: ASDisplayNode,
         chatMessageStatusNode: ASDisplayNode,
         chatMessageWebpageContentNode: ASDisplayNode? = nil,
         chatMessageReplyInfoNode: ASDisplayNode? = nil,
         chatMessageForwardInfoNode: ASDisplayNode? = nil) {
        // ASDisplayNode.convert() is giving wrong values, using UIView.convert() instead
        self.inputTextContainerNode = (convertedFrame: viewNode.textInputLastFrame ?? inputTextContainerNode.view.convert(inputTextContainerNode.view.bounds, to: viewNode.view),
                                       contentOffset: viewNode.textInputLastContentOffset ?? CGPoint.zero,
                                       insets: inputPanelNode.textInputNode?.textContainerInset ?? UIEdgeInsets.zero)
        
        self.chatMessageMainContainerNode = (originalFrame: chatMessageMainContainerNode.frame,
                                             convertedFrame: chatMessageMainContainerNode.view.convert(chatMessageMainContainerNode.view.bounds, to: viewNode.view),
                                             originalSubnodeIndex: chatMessageNode.subnodes!.firstIndex(of: chatMessageMainContainerNode)!,
                                             originalClipsToBounds: chatMessageMainContainerNode.clipsToBounds)
        
        self.chatMessageMainContextNodeOriginalFrame = chatMessageMainContextNode.frame
        self.chatMessageMainContextContentNodeOriginalFrame = chatMessageMainContextContentNode.frame
        
        let chatMessageBackgroundNodeConvertedFrame = chatMessageBackgroundNode.view.convert(chatMessageBackgroundNode.view.bounds, to: chatMessageMainContextContentNode.view)
        let chatMessageBackgroundNodeOffsetX = chatMessageMainContextContentNode.frame.width - chatMessageBackgroundNodeConvertedFrame.maxX
        let chatMessageBackgroundNodeOffsetY = chatMessageMainContextContentNode.frame.height - chatMessageBackgroundNodeConvertedFrame.maxY
        self.chatMessageBackgroundNode = (originalFrame: chatMessageBackgroundNode.frame,
                                          offset: CGPoint(x: chatMessageBackgroundNodeOffsetX, y: chatMessageBackgroundNodeOffsetY))
        
        self.chatMessageTextContentNodeOriginalFrame = chatMessageTextContentNode.frame
        
        self.chatMessageTextNode = (originalFrame: chatMessageTextNode.frame,
                                    insets: chatMessageTextContentNode.textNodeInsets)
        
        let chatMessageStatusNodeConvertedFrame = chatMessageStatusNode.view.convert(chatMessageStatusNode.view.bounds, to: chatMessageMainContextContentNode.view)
        let chatMessageStatusNodeOffsetX = chatMessageMainContextContentNode.frame.width - chatMessageStatusNodeConvertedFrame.maxX
        let chatMessageStatusNodeOffsetY = chatMessageMainContextContentNode.frame.height - chatMessageStatusNodeConvertedFrame.maxY
        self.chatMessageStatusNode = (originalFrame: chatMessageStatusNode.frame,
                                      offset: CGPoint(x: chatMessageStatusNodeOffsetX, y: chatMessageStatusNodeOffsetY),
                                      originalAlpha: chatMessageStatusNode.alpha)
        
        self.chatMessageWebpageContentNodeOriginalFrame = chatMessageWebpageContentNode?.frame
        self.chatMessageReplyInfoNodeOriginalFrame = chatMessageReplyInfoNode?.frame
        self.chatMessageForwardInfoNodeOriginalFrame = chatMessageForwardInfoNode?.frame
        
        self.textInputStyle = (fillColor: inputPanelNode.inputBackgroundColor(),
                               strokeColor: inputPanelNode.inputStrokeColor(),
                               minimalInputHeight: inputPanelNode.minimalInputHeight())
        
        self.bubbleStyle = (fillColor: chatMessageBackgroundNode.chatMessageBackgroundFillColor,
                            strokeColor: chatMessageBackgroundNode.chatMessageBackgroundStrokeColor,
                            minCornerRadius: chatMessageBackgroundNode.chatMessageBackgroundMinCornerRadius,
                            maxCornerRadius: chatMessageBackgroundNode.chatMessageBackgroundMaxCornerRadius,
                            neighborsDirection: chatMessageBackgroundNode.neighborsDirection)
    }
}

fileprivate func toRadians(_ degrees: CGFloat) -> CGFloat {
    degrees * .pi / 180.0
}

fileprivate func generateTailImage(_ config: Config, _ size: CGSize) -> UIImage {
    let tailColor = config.bubbleStyle.fillColor
    let maxCornerRadius = config.bubbleStyle.maxCornerRadius
    let tailWidth: CGFloat = 6.0
    let inset: CGFloat = 1.0 // some random inset, probably to stroke
    let rightInset: CGFloat = tailWidth + inset
    // Should be extracted to some global constant or config
    let minRadiusForFullTailCorner: CGFloat = 14.0
    
    // Please, be ready for all these random numbers... It is working though
    // I took it from ChatMessageBubbleImages.swift
    let bottomEllipse = CGRect(origin: CGPoint(x: size.width - 15.0 - inset, y: size.height - 17.0 - inset),
                               size: CGSize(width: 27.0, height: 17.0))
    let topEllipse = CGRect(origin: CGPoint(x: size.width - rightInset, y: size.height - 19.0 - inset),
                            size: CGSize(width: 23.0, height: 21.0))
    
    let formContext = DrawingContext(size: size)
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
        context.fill(CGRect(origin: CGPoint(x: size.width / 2.0, y: floor(size.height / 2.0)),
                            size: CGSize(width: size.width / 2.0 - rightInset, height: ceil(bottomEllipse.midY) - floor(size.height / 2.0))))
        context.setFillColor(UIColor.clear.cgColor)
        context.setBlendMode(.copy)
        context.fillEllipse(in: topEllipse)
    }
    return formContext.generateImage()!
}

fileprivate func generateTextInputBackgroundPath(_ config: Config, _ size: CGSize) -> UIBezierPath {
    let path = UIBezierPath()
    let radius: CGFloat = min(config.textInputStyle.minimalInputHeight / 2.0, size.height / 2.0)
    
    // Points in corners to draw arcs around
    let topLeftX: CGFloat = radius
    let topLeftY: CGFloat = radius
    let topRightX: CGFloat = size.width - radius
    let topRightY: CGFloat = radius
    let bottomRightX: CGFloat = size.width - radius
    let bottomRightY: CGFloat = size.height - radius
    let bottomLeftX: CGFloat = radius
    let bottomLeftY: CGFloat = size.height - radius
    
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
    path.addLine(to: CGPoint(x: size.width, y: bottomRightY))
    path.addArc(withCenter: CGPoint(x: bottomRightX, y: bottomRightY),
                radius: radius,
                startAngle: toRadians(0.0),
                endAngle: toRadians(90.0),
                clockwise: true)
    path.addLine(to: CGPoint(x: bottomLeftX, y: size.height))
    path.addArc(withCenter: CGPoint(x: bottomLeftX, y: bottomLeftY),
                radius: radius,
                startAngle: toRadians(90.0),
                endAngle: toRadians(180.0),
                clockwise: true)
    path.addLine(to: CGPoint(x: 0.0, y: topLeftY))
    path.close()
    return path
}

fileprivate func generateBubbleBackgroundPath(_ config: Config, _ size: CGSize) -> UIBezierPath {
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
    
    // Points in corners to draw arcs around
    let topLeftX: CGFloat = inset + topLeftRadius
    let topLeftY: CGFloat = inset + topLeftRadius
    let topRightX: CGFloat = size.width - rightInset - topRightRadius
    let topRightY: CGFloat = inset + topRightRadius
    let bottomRightX: CGFloat = size.width - rightInset - bottomRightRadius
    let bottomRightY: CGFloat = size.height - inset - bottomRightRadius
    let bottomLeftX: CGFloat = inset + bottomLeftRadius
    let bottomLeftY: CGFloat = size.height - inset - bottomLeftRadius
    
    // Boarders
    let leftX: CGFloat = inset
    let topY: CGFloat = inset
    let rightX: CGFloat = size.width - rightInset
    let bottomY: CGFloat = size.height - inset
    
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
    animation.timingFunction = animationTimingFunction
    return animation
}

fileprivate func setupRepositionAnimation(_ layer: CALayer, _ position: CGPoint, _ duration: Double) -> CABasicAnimation {
    let animation = CABasicAnimation(keyPath: "position")
    animation.fromValue = layer.position
    animation.toValue = [position.x, position.y]
    animation.duration = duration
    animation.timingFunction = animationTimingFunction
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
    
    static public func getAnimationCallback(chatControllerNode viewNode: ChatControllerNode) -> ChatHistoryListViewTransition.AnimationCallback {
        return { [weak wViewNode = viewNode] (chatMessageNode: ListViewItemNode, completion: (() -> Void)?) in
            let completion = completion ?? {}
            
            guard let viewNode = wViewNode,
                  let inputPanelNode = viewNode.inputPanelNode as? ChatTextInputPanelNode,
                  let chatMessageNode = chatMessageNode as? ChatMessageBubbleItemNode,
                  let chatMessageTextContentNode = chatMessageNode.chatMessageTextBubbleContentNode else {
                completion()
                return
            }
            
            let inputTextContainerNode = inputPanelNode.textInputContainer
            
            let chatMessageMainContainerNode = chatMessageNode.mainContainerNode
            let chatMessageMainContextNode = chatMessageNode.mainContextSourceNode
            let chatMessageMainContextContentNode = chatMessageMainContextNode.contentNode
            let chatMessageBackgroundNode = chatMessageNode.backgroundNode
            let chatMessageTextNode = chatMessageTextContentNode.textNode
                        
            let chatMessageWebpageContentNode: ChatMessageWebpageBubbleContentNode? = chatMessageNode.chatMessageWebpageBubbleContentNode
            let chatMessageStatusNode = chatMessageWebpageContentNode?.contentNode.statusNode ?? chatMessageTextContentNode.statusNode
            
            let chatMessageReplyInfoNode: ChatMessageReplyInfoNode? = chatMessageNode.replyInfoNode
            let chatMessageForwardInfoNode: ChatMessageForwardInfoNode? = chatMessageNode.forwardInfoNode
            
            // Node Hierarhy
            //
            // |- viewNode
            //   |- inputPanelNode
            //     |- inputTextContainerNode
            //   |- chatMessageNode
            //    |- chatMessageMainContainerNode
            //      |- chatMessageMainContextNode
            //        |- chatMessageMainContextContentNode
            //          |- chatMessageBackgroundNode
            //          |- chatMessageTextContentNode
            //            |- chatMessageTextNode
            //            |- chatMessageStatusNode
            //          |- chatMessageWebpageContentNode
            //            |- contentNode
            //              |- chatMessageStatusNode
            //          |- chatMessageMediaContentNode
            //          |- chatMessageReplyInfoNode
            //          |- chatMessageForwardInfoNode
            
            let config = Config(viewNode: viewNode,
                                inputPanelNode: inputPanelNode,
                                inputTextContainerNode: inputTextContainerNode,
                                chatMessageNode: chatMessageNode,
                                chatMessageMainContainerNode: chatMessageMainContainerNode,
                                chatMessageMainContextNode: chatMessageMainContextNode,
                                chatMessageMainContextContentNode: chatMessageMainContextContentNode,
                                chatMessageBackgroundNode: chatMessageBackgroundNode,
                                chatMessageTextContentNode: chatMessageTextContentNode,
                                chatMessageTextNode: chatMessageTextNode,
                                chatMessageStatusNode: chatMessageStatusNode,
                                chatMessageWebpageContentNode: chatMessageWebpageContentNode,
                                chatMessageReplyInfoNode: chatMessageReplyInfoNode,
                                chatMessageForwardInfoNode: chatMessageForwardInfoNode)
            
            let backgroundShapeLayer = CAShapeLayer()
            let tailLayer = CALayer()
            let maskShapeLayer = CAShapeLayer()
            // Prepare all nodes to be places and look exactly like input text view
            do {
                do { // chatMessageMainContainerNode
                    // Remove node content view from list view.
                    // Move it above input panel, but below navigation bar
                    chatMessageMainContainerNode.removeFromSupernode()
                    viewNode.insertSubnode(chatMessageMainContainerNode, aboveSubnode: viewNode.inputContextPanelContainer)
                    
                    chatMessageMainContainerNode.frame = config.inputTextContainerNode.convertedFrame
                    chatMessageMainContainerNode.clipsToBounds = true
                }
                
                let backgroundPath = generateTextInputBackgroundPath(config, config.inputTextContainerNode.convertedFrame.size)
                
                do { // chatMessageMainContextNode, draws bubble background
                    chatMessageMainContextNode.frame = config.inputTextContainerNode.convertedFrame.toBounds()
        
                    // Create sublayer which mimics input text view background and will be transformed to bubble
                    backgroundShapeLayer.path = backgroundPath.cgPath
                    backgroundShapeLayer.strokeColor = config.textInputStyle.strokeColor.cgColor
                    backgroundShapeLayer.fillColor = config.textInputStyle.fillColor.cgColor
                    chatMessageMainContextNode.layer.insertSublayer(backgroundShapeLayer, at: 0)
                    
                    // Create sublayer with tail image.
                    // Actually here are 3 ways it can be improved:
                    // 1. Draw tail as a part of the background bubble path, so it's transformation could be animated
                    // 2. Instead of UIImage draw a path
                    // 3. Have stored prepared image somewhere in "theme.chat"
                    tailLayer.contents = generateTailImage(config, config.chatMessageBackgroundNode.originalFrame.size).cgImage
                    tailLayer.frame = CGRect(origin: CGPoint(x: chatMessageMainContextNode.bounds.width - config.chatMessageBackgroundNode.offset.x - config.chatMessageBackgroundNode.originalFrame.width,
                                                             y: chatMessageMainContextNode.bounds.height - config.chatMessageBackgroundNode.offset.y - config.chatMessageBackgroundNode.originalFrame.height),
                                             size: config.chatMessageBackgroundNode.originalFrame.size)
                    tailLayer.opacity = 0.0
                    chatMessageMainContextNode.layer.insertSublayer(tailLayer, at: 0)
                }
                
                do { // chatMessageMainContextContentNode, masks everything outside of bubble background
                    chatMessageMainContextContentNode.frame = config.inputTextContainerNode.convertedFrame.toBounds()
                    
                    maskShapeLayer.path = backgroundPath.cgPath
                    maskShapeLayer.fillColor = UIColor.black.cgColor
                    chatMessageMainContextContentNode.layer.mask = maskShapeLayer
                }
                
                do { // chatMessageBackgroundNode
                    // We don't want to show original background yet,
                    // because we need to clip everything outside of it's bounds,
                    // which we are doing using "maskShapeLayer"
                    chatMessageBackgroundNode.isHidden = true
                }
                
                do { // chatMessageTextContentNode
                    chatMessageTextContentNode.frame = config.inputTextContainerNode.convertedFrame.toBounds()
                }
                
                do { // chatMessageWebpageContentNode
                    if let chatMessageWebpageContentNode = chatMessageWebpageContentNode,
                       let originalFrame = config.chatMessageWebpageContentNodeOriginalFrame {
                        chatMessageWebpageContentNode.frame = CGRect(origin: CGPoint(x: 0.0, y: originalFrame.minY),
                                                                     size: config.inputTextContainerNode.convertedFrame.size)
                    }
                }
                
                do { // chatMessageTextNode
                    // Actually we should calculate difference in insets here to match content,
                    // but apparently it is working fine without it. Needs to be investigated.
                    // let insetsOffsetY = config.chatMessageTextNode.insets.top - config.inputTextNode.insets.top
                    let insetsOffsetY: CGFloat = 0.0
                    chatMessageTextNode.frame = chatMessageTextNode.frame.offsetBy(dx: CGFloat.zero, dy: -config.inputTextContainerNode.contentOffset.y + insetsOffsetY)
                }
                
                do { // chatMessageStatusNode
                    let origin = CGPoint(x: chatMessageTextContentNode.bounds.width - config.chatMessageStatusNode.offset.x - config.chatMessageStatusNode.originalFrame.size.width,
                                                              y: chatMessageTextContentNode.bounds.height - config.chatMessageStatusNode.offset.y - config.chatMessageStatusNode.originalFrame.size.height)
                    let convertedOrigin = chatMessageTextContentNode.view.convert(origin, to: chatMessageStatusNode.supernode!.view)
                    chatMessageStatusNode.frame = CGRect(origin: convertedOrigin, size: chatMessageStatusNode.bounds.size)
                    chatMessageStatusNode.alpha = CGFloat.zero
                }
                
                do { // chatMessageReplyInfoNode
                    if let chatMessageReplyInfoNode = chatMessageReplyInfoNode,
                       let originalFrame = config.chatMessageReplyInfoNodeOriginalFrame {
                        let chatMessageReplyInfoNodeFrameOffsetY = config.chatMessageTextContentNodeOriginalFrame.minY - originalFrame.minY
                        chatMessageReplyInfoNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -chatMessageReplyInfoNodeFrameOffsetY),
                                                                size: chatMessageReplyInfoNode.bounds.size)
                    }
                }
                
                do { // chatMessageForwardInfoNode
                    if let chatMessageForwardInfoNode = chatMessageForwardInfoNode,
                       let originalFrame = config.chatMessageForwardInfoNodeOriginalFrame {
                        let chatMessageForwardInfoNodeFrameOffsetY = config.chatMessageTextContentNodeOriginalFrame.minY - originalFrame.minY
                        chatMessageForwardInfoNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -chatMessageForwardInfoNodeFrameOffsetY),
                                                                  size: chatMessageForwardInfoNode.bounds.size)
                    }
                }
            }
            
            // Preparation is done, it's time to go bananaz!!! (... and draw animations)
            CATransaction.begin()
            CATransaction.setCompletionBlock { [weak wChatMessageNode = chatMessageNode,
                                                weak wChatMessageMainContainerNode = chatMessageMainContainerNode,
                                                weak wChatMessageMainContextNode = chatMessageMainContextNode,
                                                weak wChatMessageMainContextContentNode = chatMessageMainContextContentNode,
                                                weak wChatMessageBackgroundNode = chatMessageBackgroundNode,
                                                weak wChatMessageTextContentNode = chatMessageTextContentNode,
                                                weak wChatMessageWebpageContentNode = chatMessageWebpageContentNode,
                                                weak wReplyInfoNode = chatMessageReplyInfoNode,
                                                weak wForwardInfoNode = chatMessageForwardInfoNode] in
                guard let sChatMessageNode = wChatMessageNode else {
                    completion()
                    return
                }
                if let sChatMessageMainContainerNode = wChatMessageMainContainerNode {
                    sChatMessageMainContainerNode.removeFromSupernode()
                    sChatMessageNode.insertSubnode(sChatMessageMainContainerNode, at: config.chatMessageMainContainerNode.originalSubnodeIndex)
                    sChatMessageMainContainerNode.frame = config.chatMessageMainContainerNode.originalFrame
                    sChatMessageMainContainerNode.clipsToBounds = config.chatMessageMainContainerNode.originalClipsToBounds
                }
                if let sChatMessageMainContextNode = wChatMessageMainContextNode {
                    sChatMessageMainContextNode.frame = config.chatMessageMainContextNodeOriginalFrame
                }
                if let sChatMessageMainContextContentNode = wChatMessageMainContextContentNode {
                    sChatMessageMainContextContentNode.frame = config.chatMessageMainContextContentNodeOriginalFrame
                    sChatMessageMainContextContentNode.layer.mask = nil
                    sChatMessageMainContextContentNode.backgroundColor = UIColor.clear
                }
                if let sChatMessageBackgroundNode = wChatMessageBackgroundNode {
                    sChatMessageBackgroundNode.frame = config.chatMessageBackgroundNode.originalFrame
                    sChatMessageBackgroundNode.isHidden = false
                }
                if let sChatMessageTextContentNode = wChatMessageTextContentNode {
                    sChatMessageTextContentNode.frame = config.chatMessageTextContentNodeOriginalFrame
                }
                if let sChatMessageWebpageContentNode = wChatMessageWebpageContentNode, let originalFrame = config.chatMessageWebpageContentNodeOriginalFrame {
                    sChatMessageWebpageContentNode.frame = originalFrame
                }
                if let sReplyInfoNode = wReplyInfoNode, let originalFrame = config.chatMessageReplyInfoNodeOriginalFrame {
                    sReplyInfoNode.frame = originalFrame
                }
                if let sForwardInfoNode = wForwardInfoNode, let originalFrame = config.chatMessageForwardInfoNodeOriginalFrame {
                    sForwardInfoNode.frame = originalFrame
                }
                backgroundShapeLayer.removeFromSuperlayer()
                tailLayer.removeFromSuperlayer()
                completion()
            }
            
            do { // chatMessageMainContainerNode
                let animations = [
                    setupResizeAnimation(chatMessageMainContainerNode.layer, config.chatMessageMainContainerNode.convertedFrame.size, animationDuration),
                    setupRepositionAnimation(chatMessageMainContainerNode.layer, config.chatMessageMainContainerNode.convertedFrame.position, animationDuration)
                ]
                chatMessageMainContainerNode.frame = config.chatMessageMainContainerNode.convertedFrame
                addAnimations(chatMessageMainContainerNode.layer, animations, animationDuration)
            }
            
            do { // chatMessageMainContextNode
                let animations = [
                    setupResizeAnimation(chatMessageMainContextNode.layer, config.chatMessageMainContextNodeOriginalFrame.size, animationDuration),
                    setupRepositionAnimation(chatMessageMainContextNode.layer, config.chatMessageMainContextNodeOriginalFrame.position, animationDuration)
                ]
                chatMessageMainContextNode.frame = config.chatMessageMainContextNodeOriginalFrame
                addAnimations(chatMessageMainContextNode.layer, animations, animationDuration)
            }
            
            do { // chatMessageMainContextContentNode
                let animations = [
                    setupResizeAnimation(chatMessageMainContextContentNode.layer, config.chatMessageMainContextContentNodeOriginalFrame.size, animationDuration),
                    setupRepositionAnimation(chatMessageMainContextContentNode.layer, config.chatMessageMainContextContentNodeOriginalFrame.position, animationDuration)
                ]
                chatMessageMainContextContentNode.frame = config.chatMessageMainContextContentNodeOriginalFrame
                addAnimations(chatMessageMainContextContentNode.layer, animations, animationDuration)
            }
            
            do { // chatMessageBackgroundNode
                let animations = [
                    setupResizeAnimation(chatMessageBackgroundNode.layer, config.chatMessageBackgroundNode.originalFrame.size, animationDuration),
                    setupRepositionAnimation(chatMessageBackgroundNode.layer, config.chatMessageBackgroundNode.originalFrame.position, animationDuration)
                ]
                chatMessageBackgroundNode.frame = config.chatMessageBackgroundNode.originalFrame
                addAnimations(chatMessageBackgroundNode.layer, animations, animationDuration)
            }
            
            let newBackgroundPath = generateBubbleBackgroundPath(config, config.chatMessageBackgroundNode.originalFrame.size)
            
            do { // maskShapeLayer
                let redrawPathAnimation = CABasicAnimation(keyPath: "path")
                redrawPathAnimation.fromValue = maskShapeLayer.path
                redrawPathAnimation.toValue = newBackgroundPath.cgPath
                redrawPathAnimation.duration = animationDuration
                redrawPathAnimation.timingFunction = animationTimingFunction
                maskShapeLayer.path = newBackgroundPath.cgPath
                
                let animations = [
                    setupResizeAnimation(maskShapeLayer, config.chatMessageBackgroundNode.originalFrame.size, animationDuration),
                    setupRepositionAnimation(maskShapeLayer, config.chatMessageBackgroundNode.originalFrame.position, animationDuration),
                    redrawPathAnimation
                ]
                maskShapeLayer.frame = config.chatMessageBackgroundNode.originalFrame
                addAnimations(maskShapeLayer, animations, animationDuration)
            }
            
            do { // backgroundShapeLayer
                let redrawPathAnimation = CABasicAnimation(keyPath: "path")
                redrawPathAnimation.fromValue = backgroundShapeLayer.path
                redrawPathAnimation.toValue = newBackgroundPath.cgPath
                redrawPathAnimation.duration = animationDuration
                redrawPathAnimation.timingFunction = animationTimingFunction
                backgroundShapeLayer.path = newBackgroundPath.cgPath

                let newStrokeColor = UIColor.clear.cgColor // chatMessageBackgroundNode.chatMessageBackgroundStrokeColor.cgColor
                let redrawStrokeAnimation = CABasicAnimation(keyPath: "strokeColor")
                redrawStrokeAnimation.fromValue = backgroundShapeLayer.strokeColor
                redrawStrokeAnimation.toValue = newStrokeColor
                redrawStrokeAnimation.duration = animationDuration
                redrawStrokeAnimation.timingFunction = animationTimingFunction
                backgroundShapeLayer.strokeColor = newStrokeColor

                let newFillColor = chatMessageBackgroundNode.chatMessageBackgroundFillColor.cgColor
                let redrawFillAnimation = CABasicAnimation(keyPath: "fillColor")
                redrawFillAnimation.fromValue = backgroundShapeLayer.fillColor
                redrawFillAnimation.toValue = newFillColor
                redrawFillAnimation.duration = animationDuration
                redrawFillAnimation.timingFunction = animationTimingFunction
                backgroundShapeLayer.fillColor = newFillColor

                let animations = [
                    setupResizeAnimation(backgroundShapeLayer, config.chatMessageBackgroundNode.originalFrame.size, animationDuration),
                    setupRepositionAnimation(backgroundShapeLayer, config.chatMessageBackgroundNode.originalFrame.position, animationDuration),
                    redrawPathAnimation,
                    redrawStrokeAnimation,
                    redrawFillAnimation
                ]
                backgroundShapeLayer.frame = config.chatMessageBackgroundNode.originalFrame
                addAnimations(backgroundShapeLayer, animations, animationDuration)
            }

            do { // tailShapeLayer
                let newFrame = CGRect(origin: CGPoint(x: config.chatMessageMainContextNodeOriginalFrame.width - config.chatMessageBackgroundNode.offset.x - config.chatMessageBackgroundNode.originalFrame.width,
                                                   y: config.chatMessageMainContextNodeOriginalFrame.height - config.chatMessageBackgroundNode.offset.y - config.chatMessageBackgroundNode.originalFrame.height),
                                         size: config.chatMessageBackgroundNode.originalFrame.size)
                
                let repositionAnimation = setupRepositionAnimation(tailLayer, newFrame.position, animationDuration)
                tailLayer.frame = newFrame

                let newOpacity: Float = 1.0
                let showAnimation = CABasicAnimation(keyPath: "opacity")
                showAnimation.fromValue = tailLayer.opacity
                showAnimation.toValue = newOpacity
                showAnimation.duration = animationDuration
                showAnimation.timingFunction = animationTimingFunction
                tailLayer.opacity = newOpacity

                let animations = [repositionAnimation, showAnimation]
                addAnimations(tailLayer, animations, animationDuration)
            }
            
            do { // chatMessageTextContentNode
                let animations = [
                    setupResizeAnimation(chatMessageTextContentNode.layer, config.chatMessageTextContentNodeOriginalFrame.size, animationDuration),
                    setupRepositionAnimation(chatMessageTextContentNode.layer, config.chatMessageTextContentNodeOriginalFrame.position, animationDuration)
                ]
                chatMessageTextContentNode.frame = config.chatMessageTextContentNodeOriginalFrame
                addAnimations(chatMessageTextContentNode.layer, animations, animationDuration)
            }
            
            do { // chatMessageTextNode
                let repositionAnimation = setupRepositionAnimation(chatMessageTextNode.layer, config.chatMessageTextNode.originalFrame.position, animationDuration)
                chatMessageTextNode.frame = config.chatMessageTextNode.originalFrame
                chatMessageTextNode.layer.add(repositionAnimation, forKey: "animation")
            }
            
            do { // chatMessageStatusNode
                let repositionAnimation = setupRepositionAnimation(chatMessageStatusNode.layer, config.chatMessageStatusNode.originalFrame.position, animationDuration)
                chatMessageStatusNode.frame = config.chatMessageStatusNode.originalFrame
                
                let showAnimation = CABasicAnimation(keyPath: "opacity")
                showAnimation.fromValue = chatMessageStatusNode.layer.opacity
                showAnimation.toValue = config.chatMessageStatusNode.originalAlpha
                showAnimation.duration = animationDuration
                showAnimation.timingFunction = animationTimingFunction
                chatMessageStatusNode.alpha = config.chatMessageStatusNode.originalAlpha
                
                let animations = [repositionAnimation, showAnimation]
                addAnimations(chatMessageStatusNode.layer, animations, animationDuration)
            }
            
            // chatMessageWebpageContentNode
            if let chatMessageWebpageContentNode = chatMessageWebpageContentNode,
               let originalFrame = config.chatMessageWebpageContentNodeOriginalFrame {
                let animations = [
                    setupResizeAnimation(chatMessageWebpageContentNode.layer, originalFrame.size, animationDuration),
                    setupRepositionAnimation(chatMessageWebpageContentNode.layer, originalFrame.position, animationDuration)
                ]
                chatMessageWebpageContentNode.frame = originalFrame
                addAnimations(chatMessageWebpageContentNode.layer, animations, animationDuration)
            }
            
            // chatMessageReplyInfoNode
            if let chatMessageReplyInfoNode = chatMessageReplyInfoNode,
               let originalFrame = config.chatMessageReplyInfoNodeOriginalFrame {
                let animations = [
                    setupResizeAnimation(chatMessageReplyInfoNode.layer, originalFrame.size, animationDuration),
                    setupRepositionAnimation(chatMessageReplyInfoNode.layer, originalFrame.position, animationDuration)
                ]
                chatMessageReplyInfoNode.frame = originalFrame
                addAnimations(chatMessageReplyInfoNode.layer, animations, animationDuration)
            }
            
            // chatMessageForwardInfoNode
            if let chatMessageForwardInfoNode = chatMessageForwardInfoNode,
               let originalFrame = config.chatMessageForwardInfoNodeOriginalFrame {
                let animations = [
                    setupResizeAnimation(chatMessageForwardInfoNode.layer, originalFrame.size, animationDuration),
                    setupRepositionAnimation(chatMessageForwardInfoNode.layer, originalFrame.position, animationDuration)
                ]
                chatMessageForwardInfoNode.frame = originalFrame
                addAnimations(chatMessageForwardInfoNode.layer, animations, animationDuration)
            }
            
            CATransaction.commit()
        }
    }
}
