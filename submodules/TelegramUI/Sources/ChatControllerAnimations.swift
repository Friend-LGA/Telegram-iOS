import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences

fileprivate extension CGRect {
    func toBounds() -> CGRect {
        return CGRect(origin: CGPoint.zero, size: self.size)
    }
    
    var position: CGPoint {
        return CGPoint(x: self.midX, y: self.midY)
    }
}

fileprivate struct Config {
    let inputTextContainerNode: (convertedFrame: CGRect, contentOffset: CGPoint, contentSize: CGSize, insets: UIEdgeInsets)
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
                                       contentSize: viewNode.textInputLastContentSize ?? CGSize.zero,
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

fileprivate func updateAnimation(_ animation: CABasicAnimation, duration: Double, timingFunction: ChatAnimationTimingFunction) {
    animation.duration = Double(timingFunction.duration) * duration
    animation.timingFunction = CAMediaTimingFunction(controlPoints: Float(timingFunction.controlPoint1.x), Float(timingFunction.controlPoint1.y), Float(timingFunction.controlPoint2.x), Float(timingFunction.controlPoint2.y))
}

fileprivate func setupResizeAnimation(layer: CALayer, size: CGSize, duration: Double, timingFunction: ChatAnimationTimingFunction) -> CABasicAnimation {
    let animation = CABasicAnimation(keyPath: "bounds")
    animation.fromValue = layer.bounds
    animation.toValue = [CGFloat.zero, CGFloat.zero, size.width, size.height]
    updateAnimation(animation, duration: duration, timingFunction: timingFunction)
    return animation
}

fileprivate func setupRepositionXAnimation(layer: CALayer, positionX: CGFloat, duration: Double, timingFunction: ChatAnimationTimingFunction) -> CABasicAnimation {
    let animation = CABasicAnimation(keyPath: "position.x")
    animation.fromValue = layer.position.x
    animation.toValue = positionX
    updateAnimation(animation, duration: duration, timingFunction: timingFunction)
    return animation
}

fileprivate func setupRepositionYAnimation(layer: CALayer, positionY: CGFloat, duration: Double, timingFunction: ChatAnimationTimingFunction) -> CABasicAnimation {
    let animation = CABasicAnimation(keyPath: "position.y")
    animation.fromValue = layer.position.y
    animation.toValue = positionY
    updateAnimation(animation, duration: duration, timingFunction: timingFunction)
    return animation
}

fileprivate func addAnimations(_ layer: CALayer, _ animations: [CAAnimation], duration: Double) {
    let animationGroup = CAAnimationGroup()
    animationGroup.animations = animations
    animationGroup.duration = duration
    layer.add(animationGroup, forKey: "animationGroup")
}

struct ChatControllerAnimations {
    private init() {}
    
    static public func getAnimationCallback(chatControllerNode viewNode: ChatControllerNode) -> ChatHistoryListViewTransition.AnimationCallback {
        return { [weak viewNode = viewNode] (chatMessageNode: ListViewItemNode, completion: (() -> Void)?) in
            let completion = completion ?? {}
            
            guard let viewNode = viewNode,
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
            
            let settingsManager = ChatAnimationSettingsManager()
            var settings: ChatAnimationSettingsCommon
            // Figuring out which settings we should use for the animation
            do {
                if chatMessageWebpageContentNode != nil {
                    settings = settingsManager.getSettings(for: ChatAnimationType.link) as! ChatAnimationSettingsCommon
                } else {
                    if config.inputTextContainerNode.contentSize.height > config.inputTextContainerNode.convertedFrame.height {
                        settings = settingsManager.getSettings(for: ChatAnimationType.big) as! ChatAnimationSettingsCommon
                    } else {
                        settings = settingsManager.getSettings(for: ChatAnimationType.small) as! ChatAnimationSettingsCommon
                    }
                }
            }
            
            let backgroundNode = ASDisplayNode()
            let backgroundShapeLayer = CAShapeLayer()
            
            let tailNode = ASDisplayNode()
            
//            let maskNode = ASDisplayNode()
//            let maskShapeLayer = CAShapeLayer()
            
            // Prepare all nodes to be places and look exactly like input text view
            do {
                do { // chatMessageMainContainerNode
                    // Remove node content view from list view.
                    // Move it above input panel, but below navigation bar
                    chatMessageMainContainerNode.removeFromSupernode()
                    viewNode.insertSubnode(chatMessageMainContainerNode, aboveSubnode: viewNode.inputContextPanelContainer)
                    
                    chatMessageMainContainerNode.frame = config.inputTextContainerNode.convertedFrame
//                    chatMessageMainContainerNode.clipsToBounds = true
                }
                
                let backgroundPath = generateTextInputBackgroundPath(config, config.inputTextContainerNode.convertedFrame.size)

                do { // chatMessageMainContextNode, draws bubble background
                    chatMessageMainContextNode.frame = config.inputTextContainerNode.convertedFrame.toBounds()

                    // Create sublayer which mimics input text view background and will be transformed to bubble
                    backgroundShapeLayer.path = backgroundPath.cgPath
                    backgroundShapeLayer.strokeColor = config.textInputStyle.strokeColor.cgColor
                    backgroundShapeLayer.fillColor = config.textInputStyle.fillColor.cgColor
                    backgroundNode.layer.addSublayer(backgroundShapeLayer)
                    chatMessageMainContextNode.insertSubnode(backgroundNode, at: 0)
                    backgroundNode.frame = chatMessageMainContextNode.bounds
                    backgroundShapeLayer.frame = backgroundNode.bounds

                    // Create sublayer with tail image.
                    // Actually here are 3 ways it can be improved:
                    // 1. Draw tail as a part of the background bubble path, so it's transformation could be animated
                    // 2. Instead of UIImage draw a path
                    // 3. Stored prepared image somewhere in "theme.chat"
                    let tailMaskLayer = CALayer()
                    tailMaskLayer.contents = generateTailImage(config, config.chatMessageBackgroundNode.originalFrame.size).cgImage
                    tailNode.layer.mask = tailMaskLayer
                    tailNode.backgroundColor = config.textInputStyle.fillColor
                    chatMessageMainContextNode.insertSubnode(tailNode, at: 0)
                    tailNode.frame = CGRect(origin: CGPoint(x: chatMessageMainContextNode.bounds.width - config.chatMessageBackgroundNode.offset.x - config.chatMessageBackgroundNode.originalFrame.width,
                                                            y: chatMessageMainContextNode.bounds.height - config.chatMessageBackgroundNode.offset.y - config.chatMessageBackgroundNode.originalFrame.height),
                                            size: config.chatMessageBackgroundNode.originalFrame.size)
                    tailMaskLayer.frame = tailNode.bounds
                }

                do { // chatMessageMainContextContentNode, masks everything outside of bubble background
//                    chatMessageMainContextContentNode.frame = config.inputTextContainerNode.convertedFrame.toBounds()
//
//                    maskShapeLayer.path = backgroundPath.cgPath
//                    maskShapeLayer.fillColor = UIColor.black.cgColor
//                    chatMessageMainContextContentNode.layer.mask = maskShapeLayer
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
            
            // Preparation is done, it's time to go bananaz!!! (... and draw some animations)
            let animationDuration = 10.0 // settings.duration.rawValue
            
            CATransaction.begin()
            CATransaction.setCompletionBlock { [weak chatMessageNode,
                                                weak chatMessageMainContainerNode,
                                                weak chatMessageMainContextNode,
                                                weak chatMessageMainContextContentNode,
                                                weak chatMessageBackgroundNode,
                                                weak chatMessageTextContentNode,
                                                weak chatMessageWebpageContentNode,
                                                weak chatMessageReplyInfoNode,
                                                weak chatMessageForwardInfoNode] in
                guard let chatMessageNode = chatMessageNode else {
                    completion()
                    return
                }
                if let chatMessageMainContainerNode = chatMessageMainContainerNode {
                    chatMessageMainContainerNode.removeFromSupernode()
                    chatMessageNode.insertSubnode(chatMessageMainContainerNode, at: config.chatMessageMainContainerNode.originalSubnodeIndex)
                    chatMessageMainContainerNode.frame = config.chatMessageMainContainerNode.originalFrame
                    chatMessageMainContainerNode.clipsToBounds = config.chatMessageMainContainerNode.originalClipsToBounds
                }
                if let chatMessageMainContextNode = chatMessageMainContextNode {
                    chatMessageMainContextNode.frame = config.chatMessageMainContextNodeOriginalFrame
                }
                if let chatMessageMainContextContentNode = chatMessageMainContextContentNode {
                    chatMessageMainContextContentNode.frame = config.chatMessageMainContextContentNodeOriginalFrame
                    chatMessageMainContextContentNode.layer.mask = nil
                }
                if let chatMessageBackgroundNode = chatMessageBackgroundNode {
                    chatMessageBackgroundNode.frame = config.chatMessageBackgroundNode.originalFrame
                    chatMessageBackgroundNode.isHidden = false
                }
                if let chatMessageTextContentNode = chatMessageTextContentNode {
                    chatMessageTextContentNode.frame = config.chatMessageTextContentNodeOriginalFrame
                }
                if let chatMessageWebpageContentNode = chatMessageWebpageContentNode, let originalFrame = config.chatMessageWebpageContentNodeOriginalFrame {
                    chatMessageWebpageContentNode.frame = originalFrame
                }
                if let chatMessageReplyInfoNode = chatMessageReplyInfoNode, let originalFrame = config.chatMessageReplyInfoNodeOriginalFrame {
                    chatMessageReplyInfoNode.frame = originalFrame
                }
                if let chatMessageForwardInfoNode = chatMessageForwardInfoNode, let originalFrame = config.chatMessageForwardInfoNodeOriginalFrame {
                    chatMessageForwardInfoNode.frame = originalFrame
                }
                backgroundNode.removeFromSupernode()
                tailNode.removeFromSupernode()
                completion()
            }
            
            do { // chatMessageMainContainerNode
                let animations = [
                    setupResizeAnimation(layer: chatMessageMainContainerNode.layer,
                                         size: config.chatMessageMainContainerNode.convertedFrame.size,
                                         duration: animationDuration,
                                         timingFunction: settings.bubbleShapeFunc),
                    setupRepositionXAnimation(layer: chatMessageMainContainerNode.layer,
                                              positionX: config.chatMessageMainContainerNode.convertedFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.xPositionFunc),
                    setupRepositionYAnimation(layer: chatMessageMainContainerNode.layer,
                                              positionY: config.chatMessageMainContainerNode.convertedFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.yPositionFunc)
                ]
                chatMessageMainContainerNode.frame = config.chatMessageMainContainerNode.convertedFrame
                addAnimations(chatMessageMainContainerNode.layer, animations, duration: animationDuration)
            }
            
            do { // chatMessageMainContextNode
                let animations = [
                    setupResizeAnimation(layer: chatMessageMainContextNode.layer,
                                         size: config.chatMessageMainContextNodeOriginalFrame.size,
                                         duration: animationDuration,
                                         timingFunction: settings.bubbleShapeFunc),
                    setupRepositionXAnimation(layer: chatMessageMainContextNode.layer,
                                              positionX: config.chatMessageMainContextNodeOriginalFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.xPositionFunc),
                    setupRepositionYAnimation(layer: chatMessageMainContextNode.layer,
                                              positionY: config.chatMessageMainContextNodeOriginalFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.yPositionFunc)
                ]
                chatMessageMainContextNode.frame = config.chatMessageMainContextNodeOriginalFrame
                addAnimations(chatMessageMainContextNode.layer, animations, duration: animationDuration)
            }
            
            do { // chatMessageMainContextContentNode
                let animations = [
                    setupResizeAnimation(layer: chatMessageMainContextContentNode.layer,
                                         size: config.chatMessageMainContextContentNodeOriginalFrame.size,
                                         duration: animationDuration,
                                         timingFunction: settings.bubbleShapeFunc),
                    setupRepositionXAnimation(layer: chatMessageMainContextContentNode.layer,
                                              positionX: config.chatMessageMainContextContentNodeOriginalFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.xPositionFunc),
                    setupRepositionYAnimation(layer: chatMessageMainContextContentNode.layer,
                                              positionY: config.chatMessageMainContextContentNodeOriginalFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.yPositionFunc)
                ]
                chatMessageMainContextContentNode.frame = config.chatMessageMainContextContentNodeOriginalFrame
                addAnimations(chatMessageMainContextContentNode.layer, animations, duration: animationDuration)
            }
            
            let newBackgroundPath = generateBubbleBackgroundPath(config, config.chatMessageBackgroundNode.originalFrame.size)

//            do { // maskShapeLayer
//                let redrawPathAnimation = CABasicAnimation(keyPath: "path")
//                redrawPathAnimation.fromValue = maskShapeLayer.path
//                redrawPathAnimation.toValue = newBackgroundPath.cgPath
//                updateAnimation(redrawPathAnimation, duration: animationDuration, timingFunction: settings.bubbleShapeFunc)
//
//                let animations = [
//                    setupResizeAnimation(layer: maskShapeLayer,
//                                         size: config.chatMessageBackgroundNode.originalFrame.size,
//                                         duration: animationDuration,
//                                         timingFunction: settings.bubbleShapeFunc),
//                    setupRepositionXAnimation(layer: maskShapeLayer,
//                                              positionX: config.chatMessageBackgroundNode.originalFrame.position.x,
//                                              duration: animationDuration,
//                                              timingFunction: settings.xPositionFunc),
//                    setupRepositionYAnimation(layer: maskShapeLayer,
//                                              positionY: config.chatMessageBackgroundNode.originalFrame.position.y,
//                                              duration: animationDuration,
//                                              timingFunction: settings.yPositionFunc),
//                    redrawPathAnimation
//                ]
//                maskShapeLayer.frame = config.chatMessageBackgroundNode.originalFrame
//                maskShapeLayer.path = newBackgroundPath.cgPath
//                addAnimations(maskShapeLayer, animations, duration: animationDuration)
//            }
            
            do { // backgroundNode
                let animations = [
                    setupResizeAnimation(layer: backgroundNode.layer,
                                         size: config.chatMessageBackgroundNode.originalFrame.size,
                                         duration: animationDuration,
                                         timingFunction: settings.bubbleShapeFunc),
                    setupRepositionXAnimation(layer: backgroundNode.layer,
                                              positionX: config.chatMessageBackgroundNode.originalFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.xPositionFunc),
                    setupRepositionYAnimation(layer: backgroundNode.layer,
                                              positionY: config.chatMessageBackgroundNode.originalFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.yPositionFunc),
                ]
                backgroundNode.frame = config.chatMessageBackgroundNode.originalFrame
                addAnimations(backgroundNode.layer, animations, duration: animationDuration)
            }

            do { // backgroundShapeLayer
                let redrawPathAnimation = CABasicAnimation(keyPath: "path")
                redrawPathAnimation.fromValue = backgroundShapeLayer.path
                redrawPathAnimation.toValue = newBackgroundPath.cgPath
                updateAnimation(redrawPathAnimation, duration: animationDuration, timingFunction: settings.bubbleShapeFunc)

                let newStrokeColor = UIColor.clear.cgColor // chatMessageBackgroundNode.chatMessageBackgroundStrokeColor.cgColor
                let redrawStrokeAnimation = CABasicAnimation(keyPath: "strokeColor")
                redrawStrokeAnimation.fromValue = backgroundShapeLayer.strokeColor
                redrawStrokeAnimation.toValue = newStrokeColor
                updateAnimation(redrawStrokeAnimation, duration: animationDuration, timingFunction: settings.colorChangeFunc)

                let newFillColor = chatMessageBackgroundNode.chatMessageBackgroundFillColor.cgColor
                let redrawFillAnimation = CABasicAnimation(keyPath: "fillColor")
                redrawFillAnimation.fromValue = backgroundShapeLayer.fillColor
                redrawFillAnimation.toValue = newFillColor
                updateAnimation(redrawFillAnimation, duration: animationDuration, timingFunction: settings.colorChangeFunc)

                let animations = [
                    redrawPathAnimation,
                    redrawStrokeAnimation,
                    redrawFillAnimation
                ]
                backgroundShapeLayer.path = newBackgroundPath.cgPath
                backgroundShapeLayer.strokeColor = newStrokeColor
                backgroundShapeLayer.fillColor = newFillColor
                addAnimations(backgroundShapeLayer, animations, duration: animationDuration)
            }

            do { // tailNode
                let newFrame = CGRect(origin: CGPoint(x: config.chatMessageMainContextNodeOriginalFrame.width - config.chatMessageBackgroundNode.offset.x - config.chatMessageBackgroundNode.originalFrame.width,
                                                      y: config.chatMessageMainContextNodeOriginalFrame.height - config.chatMessageBackgroundNode.offset.y - config.chatMessageBackgroundNode.originalFrame.height),
                                      size: config.chatMessageBackgroundNode.originalFrame.size)

                let newOpacity: CGFloat = 1.0
                let showAnimation = CABasicAnimation(keyPath: "opacity")
                showAnimation.fromValue = tailNode.alpha
                showAnimation.toValue = newOpacity
                updateAnimation(showAnimation, duration: animationDuration, timingFunction: settings.bubbleShapeFunc)

                let newBackgroundColor = chatMessageBackgroundNode.chatMessageBackgroundFillColor
                let redrawFillAnimation = CABasicAnimation(keyPath: "fillColor")
                redrawFillAnimation.fromValue = tailNode.backgroundColor
                redrawFillAnimation.toValue = newBackgroundColor
                updateAnimation(redrawFillAnimation, duration: animationDuration, timingFunction: settings.colorChangeFunc)

                let animations = [
                    setupRepositionXAnimation(layer: tailNode.layer,
                                              positionX: newFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.xPositionFunc),
                    setupRepositionYAnimation(layer: tailNode.layer,
                                              positionY: newFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.yPositionFunc),
                    showAnimation,
                    redrawFillAnimation
                ]
                tailNode.frame = newFrame
                tailNode.alpha = newOpacity
                tailNode.backgroundColor = newBackgroundColor
                addAnimations(tailNode.layer, animations, duration: animationDuration)
            }

            do { // chatMessageTextContentNode
                let animations = [
                    setupResizeAnimation(layer: chatMessageTextContentNode.layer,
                                         size: config.chatMessageTextContentNodeOriginalFrame.size,
                                         duration: animationDuration,
                                         timingFunction: settings.bubbleShapeFunc),
                    setupRepositionXAnimation(layer: chatMessageTextContentNode.layer,
                                              positionX: config.chatMessageTextContentNodeOriginalFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.xPositionFunc),
                    setupRepositionYAnimation(layer: chatMessageTextContentNode.layer,
                                              positionY: config.chatMessageTextContentNodeOriginalFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.yPositionFunc)
                ]
                chatMessageTextContentNode.frame = config.chatMessageTextContentNodeOriginalFrame
                addAnimations(chatMessageTextContentNode.layer, animations, duration: animationDuration)
            }

            do { // chatMessageTextNode
                let animations = [
                    setupRepositionXAnimation(layer: chatMessageTextNode.layer,
                                              positionX: config.chatMessageTextNode.originalFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.xPositionFunc),
                    setupRepositionYAnimation(layer: chatMessageTextNode.layer,
                                              positionY: config.chatMessageTextNode.originalFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.yPositionFunc)
                ]
                chatMessageTextNode.frame = config.chatMessageTextNode.originalFrame
                addAnimations(chatMessageTextNode.layer, animations, duration: animationDuration)
            }

            do { // chatMessageStatusNode
                let showAnimation = CABasicAnimation(keyPath: "opacity")
                showAnimation.fromValue = chatMessageStatusNode.layer.opacity
                showAnimation.toValue = config.chatMessageStatusNode.originalAlpha
                updateAnimation(showAnimation, duration: animationDuration, timingFunction: settings.timeAppearsFunc)

                let animations = [
                    setupRepositionXAnimation(layer: chatMessageStatusNode.layer,
                                              positionX: config.chatMessageStatusNode.originalFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc),
                    setupRepositionYAnimation(layer: chatMessageStatusNode.layer,
                                              positionY: config.chatMessageStatusNode.originalFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc),
                    showAnimation
                ]
                chatMessageStatusNode.frame = config.chatMessageStatusNode.originalFrame
                chatMessageStatusNode.alpha = config.chatMessageStatusNode.originalAlpha
                addAnimations(chatMessageStatusNode.layer, animations, duration: animationDuration)
            }

            // chatMessageWebpageContentNode
            if let chatMessageWebpageContentNode = chatMessageWebpageContentNode,
               let originalFrame = config.chatMessageWebpageContentNodeOriginalFrame {
                let animations = [
                    setupResizeAnimation(layer: chatMessageWebpageContentNode.layer,
                                         size: originalFrame.size,
                                         duration: animationDuration,
                                         timingFunction: settings.bubbleShapeFunc),
                    setupRepositionXAnimation(layer: chatMessageWebpageContentNode.layer,
                                              positionX: originalFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.xPositionFunc),
                    setupRepositionYAnimation(layer: chatMessageWebpageContentNode.layer,
                                              positionY: originalFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.yPositionFunc)
                ]
                chatMessageWebpageContentNode.frame = originalFrame
                addAnimations(chatMessageWebpageContentNode.layer, animations, duration: animationDuration)
            }

            // chatMessageReplyInfoNode
            if let chatMessageReplyInfoNode = chatMessageReplyInfoNode,
               let originalFrame = config.chatMessageReplyInfoNodeOriginalFrame {
                let animations = [
                    setupResizeAnimation(layer: chatMessageReplyInfoNode.layer,
                                         size: originalFrame.size,
                                         duration: animationDuration,
                                         timingFunction: settings.bubbleShapeFunc),
                    setupRepositionXAnimation(layer: chatMessageReplyInfoNode.layer,
                                              positionX: originalFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.xPositionFunc),
                    setupRepositionYAnimation(layer: chatMessageReplyInfoNode.layer,
                                              positionY: originalFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.yPositionFunc)
                ]
                chatMessageReplyInfoNode.frame = originalFrame
                addAnimations(chatMessageReplyInfoNode.layer, animations, duration: animationDuration)
            }

            // chatMessageForwardInfoNode
            if let chatMessageForwardInfoNode = chatMessageForwardInfoNode,
               let originalFrame = config.chatMessageForwardInfoNodeOriginalFrame {
                let animations = [
                    setupResizeAnimation(layer: chatMessageForwardInfoNode.layer,
                                         size: originalFrame.size,
                                         duration: animationDuration,
                                         timingFunction: settings.bubbleShapeFunc),
                    setupRepositionXAnimation(layer: chatMessageForwardInfoNode.layer,
                                              positionX: originalFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.xPositionFunc),
                    setupRepositionYAnimation(layer: chatMessageForwardInfoNode.layer,
                                              positionY: originalFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.yPositionFunc)
                ]
                chatMessageForwardInfoNode.frame = originalFrame
                addAnimations(chatMessageForwardInfoNode.layer, animations, duration: animationDuration)
            }
            
            CATransaction.commit()
        }
    }
}
