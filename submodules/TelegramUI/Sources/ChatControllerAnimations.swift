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
    let animatingNode: (startFrame: CGRect,
                        endFrame: CGRect)
    
    let inputTextContainerNode: (convertedFrame: CGRect,
                                 contentOffset: CGPoint,
                                 contentSize: CGSize,
                                 insets: UIEdgeInsets)
    
    let chatMessageNode: (originalDisplaysAsync: Bool,
                          originalShouldAnimateSizeChanges: Bool)
    
    let chatMessageMainContainerNode: (originalFrame: CGRect,
                                       convertedFrame: CGRect,
                                       originalSubnodeIndex: Int,
                                       originalClipsToBounds: Bool,
                                       originalDisplaysAsync: Bool,
                                       originalShouldAnimateSizeChanges: Bool)
    
    let chatMessageMainContextNode: (originalFrame: CGRect,
                                     originalDisplaysAsync: Bool,
                                     originalShouldAnimateSizeChanges: Bool)
    
    let chatMessageMainContextContentNode: (originalFrame: CGRect,
                                            originalDisplaysAsync: Bool,
                                            originalShouldAnimateSizeChanges: Bool)
    
    let chatMessageBackgroundNode: (originalFrame: CGRect,
                                    originalDisplaysAsync: Bool,
                                    originalShouldAnimateSizeChanges: Bool)
    
    let chatMessageTextContentNode: (originalFrame: CGRect,
                                     originalDisplaysAsync: Bool,
                                     originalShouldAnimateSizeChanges: Bool)
    
    let chatMessageTextNode: (originalFrame: CGRect,
                              insets: UIEdgeInsets,
                              originalDisplaysAsync: Bool,
                              originalShouldAnimateSizeChanges: Bool)
    
    let chatMessageStatusNode: (originalFrame: CGRect,
                                offset: CGPoint,
                                originalAlpha: CGFloat,
                                originalDisplaysAsync: Bool,
                                originalShouldAnimateSizeChanges: Bool)
    
    let chatMessageWebpageContentNode: (originalFrame: CGRect,
                                        originalDisplaysAsync: Bool,
                                        originalShouldAnimateSizeChanges: Bool)
    
    let chatMessageReplyInfoNode: (originalFrame: CGRect,
                                   originalDisplaysAsync: Bool,
                                   originalShouldAnimateSizeChanges: Bool)
    
    let chatMessageForwardInfoNode: (originalFrame: CGRect,
                                     originalDisplaysAsync: Bool,
                                     originalShouldAnimateSizeChanges: Bool)
    
    let textInputStyle: (fillColor: UIColor,
                         strokeColor: UIColor,
                         minimalInputHeight: CGFloat)
    
    let bubbleStyle: (fillColor: UIColor,
                      strokeColor: UIColor,
                      minCornerRadius: CGFloat,
                      maxCornerRadius: CGFloat,
                      neighborsDirection: MessageBubbleImageNeighbors)
    
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
        
        self.animatingNode = (startFrame: self.inputTextContainerNode.convertedFrame,
                              endFrame: chatMessageBackgroundNode.view.convert(chatMessageBackgroundNode.view.bounds, to: viewNode.view))
        
        self.chatMessageNode = (originalDisplaysAsync: chatMessageNode.displaysAsynchronously,
                                originalShouldAnimateSizeChanges: chatMessageNode.shouldAnimateSizeChanges)
        
        self.chatMessageMainContainerNode = (originalFrame: chatMessageMainContainerNode.frame,
                                             convertedFrame: chatMessageMainContainerNode.view.convert(chatMessageMainContainerNode.view.bounds, to: chatMessageBackgroundNode.view),
                                             originalSubnodeIndex: chatMessageNode.subnodes!.firstIndex(of: chatMessageMainContainerNode)!,
                                             originalClipsToBounds: chatMessageMainContainerNode.clipsToBounds,
                                             originalDisplaysAsync: chatMessageMainContainerNode.displaysAsynchronously,
                                             originalShouldAnimateSizeChanges: chatMessageMainContainerNode.shouldAnimateSizeChanges)
        
        self.chatMessageMainContextNode = (originalFrame: chatMessageMainContextNode.frame,
                                           originalDisplaysAsync: chatMessageMainContextNode.displaysAsynchronously,
                                           originalShouldAnimateSizeChanges: chatMessageMainContextNode.shouldAnimateSizeChanges)
        
        self.chatMessageMainContextContentNode = (originalFrame: chatMessageMainContextContentNode.frame,
                                                  originalDisplaysAsync: chatMessageMainContextContentNode.displaysAsynchronously,
                                                  originalShouldAnimateSizeChanges: chatMessageMainContextContentNode.shouldAnimateSizeChanges)
        
        self.chatMessageBackgroundNode = (originalFrame: chatMessageBackgroundNode.frame,
                                          originalDisplaysAsync: chatMessageBackgroundNode.displaysAsynchronously,
                                          originalShouldAnimateSizeChanges: chatMessageBackgroundNode.shouldAnimateSizeChanges)
        
        self.chatMessageTextContentNode = (originalFrame: chatMessageTextContentNode.frame,
                                           originalDisplaysAsync: chatMessageTextContentNode.displaysAsynchronously,
                                           originalShouldAnimateSizeChanges: chatMessageTextContentNode.shouldAnimateSizeChanges)
        
        self.chatMessageTextNode = (originalFrame: chatMessageTextNode.frame,
                                    insets: chatMessageTextContentNode.textNodeInsets,
                                    originalDisplaysAsync: chatMessageTextNode.displaysAsynchronously,
                                    originalShouldAnimateSizeChanges: chatMessageTextNode.shouldAnimateSizeChanges)
        
        let chatMessageStatusNodeConvertedFrame = chatMessageStatusNode.view.convert(chatMessageStatusNode.view.bounds, to: chatMessageMainContextContentNode.view)
        let chatMessageStatusNodeOffsetX = chatMessageMainContextContentNode.frame.width - chatMessageStatusNodeConvertedFrame.maxX
        let chatMessageStatusNodeOffsetY = chatMessageMainContextContentNode.frame.height - chatMessageStatusNodeConvertedFrame.maxY
        self.chatMessageStatusNode = (originalFrame: chatMessageStatusNode.frame,
                                      offset: CGPoint(x: chatMessageStatusNodeOffsetX, y: chatMessageStatusNodeOffsetY),
                                      originalAlpha: chatMessageStatusNode.alpha,
                                      originalDisplaysAsync: chatMessageStatusNode.displaysAsynchronously,
                                      originalShouldAnimateSizeChanges: chatMessageStatusNode.shouldAnimateSizeChanges)
        
        self.chatMessageWebpageContentNode = (originalFrame: chatMessageWebpageContentNode?.frame ?? CGRect.zero,
                                              originalDisplaysAsync: chatMessageWebpageContentNode?.displaysAsynchronously ?? true,
                                              originalShouldAnimateSizeChanges: chatMessageWebpageContentNode?.shouldAnimateSizeChanges ?? true)
        
        self.chatMessageReplyInfoNode = (originalFrame: chatMessageReplyInfoNode?.frame ?? CGRect.zero,
                                         originalDisplaysAsync: chatMessageReplyInfoNode?.displaysAsynchronously ?? true,
                                         originalShouldAnimateSizeChanges: chatMessageReplyInfoNode?.shouldAnimateSizeChanges ?? true)
        
        self.chatMessageForwardInfoNode = (originalFrame: chatMessageForwardInfoNode?.frame ?? CGRect.zero,
                                           originalDisplaysAsync: chatMessageForwardInfoNode?.displaysAsynchronously ?? true,
                                           originalShouldAnimateSizeChanges: chatMessageForwardInfoNode?.shouldAnimateSizeChanges ?? true)
        
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

fileprivate func generateTailImage(_ config: Config) -> UIImage {
    let size = CGSize(width: 16.0, height: 16.0)
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
        context.fill(CGRect(origin: CGPoint(x: 0, y: 0),
                            size: CGSize(width: size.width - rightInset, height: ceil(bottomEllipse.midY))))
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

private let animationKey = "ChatMessageAnimations"

fileprivate func updateAnimation(_ animation: CABasicAnimation, duration: Double, timingFunction: ChatAnimationTimingFunction) {
    animation.duration = Double(timingFunction.duration) * duration
    animation.timingFunction = CAMediaTimingFunction(controlPoints: Float(timingFunction.controlPoint1.x), Float(timingFunction.controlPoint1.y), Float(timingFunction.controlPoint2.x), Float(timingFunction.controlPoint2.y))
    animation.isRemovedOnCompletion = false
    animation.fillMode = .forwards
}

fileprivate func setupResizeAnimation(layer: CALayer, fromSize: CGSize, toSize: CGSize, duration: Double, timingFunction: ChatAnimationTimingFunction) -> CABasicAnimation {
    let animation = CABasicAnimation(keyPath: "bounds")
    animation.fromValue = [CGFloat.zero, CGFloat.zero, fromSize.width, fromSize.height]
    animation.toValue = [CGFloat.zero, CGFloat.zero, toSize.width, toSize.height]
    updateAnimation(animation, duration: duration, timingFunction: timingFunction)
    return animation
}

fileprivate func setupRepositionXAnimation(layer: CALayer, fromPosition: CGFloat, toPosition: CGFloat, duration: Double, timingFunction: ChatAnimationTimingFunction) -> CABasicAnimation {
    let animation = CABasicAnimation(keyPath: "position.x")
    animation.fromValue = fromPosition
    animation.toValue = toPosition
    updateAnimation(animation, duration: duration, timingFunction: timingFunction)
    return animation
}

fileprivate func setupRepositionYAnimation(layer: CALayer, fromPosition: CGFloat, toPosition: CGFloat, duration: Double, timingFunction: ChatAnimationTimingFunction) -> CABasicAnimation {
    let animation = CABasicAnimation(keyPath: "position.y")
    animation.fromValue = fromPosition
    animation.toValue = toPosition
    updateAnimation(animation, duration: duration, timingFunction: timingFunction)
    return animation
}

fileprivate func addAnimations(_ layer: CALayer, _ animations: [CAAnimation], duration: Double) {
    let animationGroup = CAAnimationGroup()
    animationGroup.animations = animations
    animationGroup.duration = duration
    animationGroup.isRemovedOnCompletion = false
    animationGroup.fillMode = .forwards
    layer.add(animationGroup, forKey: animationKey)
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
            
            chatMessageNode.displaysAsynchronously = false
            chatMessageMainContainerNode.displaysAsynchronously = false
            chatMessageMainContextNode.displaysAsynchronously = false
            chatMessageMainContextContentNode.displaysAsynchronously = false
            chatMessageTextContentNode.displaysAsynchronously = false
            chatMessageTextNode.displaysAsynchronously = false
            chatMessageStatusNode.displaysAsynchronously = false
            chatMessageWebpageContentNode?.displaysAsynchronously = false
            chatMessageReplyInfoNode?.displaysAsynchronously = false
            chatMessageForwardInfoNode?.displaysAsynchronously = false
            
            chatMessageNode.shouldAnimateSizeChanges = false
            chatMessageMainContainerNode.shouldAnimateSizeChanges = false
            chatMessageMainContextNode.shouldAnimateSizeChanges = false
            chatMessageMainContextContentNode.shouldAnimateSizeChanges = false
            chatMessageTextContentNode.shouldAnimateSizeChanges = false
            chatMessageTextNode.shouldAnimateSizeChanges = false
            chatMessageStatusNode.shouldAnimateSizeChanges = false
            chatMessageWebpageContentNode?.shouldAnimateSizeChanges = false
            chatMessageReplyInfoNode?.shouldAnimateSizeChanges = false
            chatMessageForwardInfoNode?.shouldAnimateSizeChanges = false
            
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
            
            let animatingNode = ASDisplayNode()
            animatingNode.displaysAsynchronously = false
            animatingNode.shouldAnimateSizeChanges = false
            
            let maskNode = ASDisplayNode()
            maskNode.displaysAsynchronously = false
            maskNode.shouldAnimateSizeChanges = false
            
            let maskShapeLayer = CAShapeLayer()
            
            let backgroundNode = ASDisplayNode()
            backgroundNode.displaysAsynchronously = false
            backgroundNode.shouldAnimateSizeChanges = false
            
            let backgroundShapeLayer = CAShapeLayer()
            
            let tailNode = ASDisplayNode()
            tailNode.displaysAsynchronously = false
            tailNode.shouldAnimateSizeChanges = false
            
            let tailImage = generateTailImage(config)
            
            // Prepare all nodes to be places and look exactly like input text view
            do {
                do { // new nods setup
                    // Create node which mimics input text view background and will be transformed to bubble
                    // Move it above input panel, but below navigation bar
                    viewNode.insertSubnode(animatingNode, aboveSubnode: viewNode.inputContextPanelContainer)
                    
                    backgroundNode.layer.addSublayer(backgroundShapeLayer)
                    animatingNode.addSubnode(backgroundNode)
                    
                    // Create sublayer with tail image.
                    // Actually here are 3 ways it can be improved:
                    // 1. Draw tail as a part of the background bubble path, so it's transformation could be animated
                    // 2. Instead of UIImage draw a path
                    // 3. Stored prepared image somewhere in "theme.chat"
                    let tailMaskLayer = CALayer()
                    tailMaskLayer.contents = tailImage.cgImage
                    tailMaskLayer.frame = CGRect(origin: CGPoint.zero, size: tailImage.size)
                    tailNode.layer.mask = tailMaskLayer
                    tailNode.backgroundColor = chatMessageBackgroundNode.chatMessageBackgroundFillColor
                    animatingNode.insertSubnode(tailNode, belowSubnode: backgroundNode)
                    // TODO: Magic, but only this node's animation doesn't work without soecifying frame here
                    tailNode.frame = CGRect(origin: CGPoint.zero, size: tailImage.size)
                    
                    maskShapeLayer.strokeColor = UIColor.black.cgColor
                    maskShapeLayer.fillColor = UIColor.black.cgColor
                    maskNode.layer.mask = maskShapeLayer
                    animatingNode.addSubnode(maskNode)
                }
                
                do { // old nodes setup
                    chatMessageMainContainerNode.removeFromSupernode()
                    maskNode.addSubnode(chatMessageMainContainerNode)
                    
                    chatMessageBackgroundNode.isHidden = true
                }
            }
            
            // Preparation is done, it's time to go bananaz!!! (... and draw some animations)
            let animationDuration = settings.duration.rawValue
            
            CATransaction.begin()
            CATransaction.setCompletionBlock { [weak chatMessageNode,
                                                weak chatMessageMainContainerNode,
                                                weak chatMessageMainContextNode,
                                                weak chatMessageMainContextContentNode,
                                                weak chatMessageBackgroundNode,
                                                weak chatMessageTextContentNode,
                                                weak chatMessageTextNode,
                                                weak chatMessageStatusNode,
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
                }
                
                chatMessageBackgroundNode?.isHidden = false
                
                animatingNode.removeFromSupernode()
                maskNode.removeFromSupernode()
                backgroundNode.removeFromSupernode()
                tailNode.removeFromSupernode()
                
                chatMessageMainContainerNode?.layer.removeAnimation(forKey: animationKey)
                chatMessageMainContextNode?.layer.removeAnimation(forKey: animationKey)
                chatMessageMainContextContentNode?.layer.removeAnimation(forKey: animationKey)
                chatMessageBackgroundNode?.layer.removeAnimation(forKey: animationKey)
                chatMessageTextContentNode?.layer.removeAnimation(forKey: animationKey)
                chatMessageWebpageContentNode?.layer.removeAnimation(forKey: animationKey)
                chatMessageReplyInfoNode?.layer.removeAnimation(forKey: animationKey)
                chatMessageForwardInfoNode?.layer.removeAnimation(forKey: animationKey)
                
                chatMessageNode.displaysAsynchronously = config.chatMessageNode.originalDisplaysAsync
                chatMessageMainContainerNode?.displaysAsynchronously = config.chatMessageMainContainerNode.originalDisplaysAsync
                chatMessageMainContextNode?.displaysAsynchronously = config.chatMessageMainContextNode.originalDisplaysAsync
                chatMessageMainContextContentNode?.displaysAsynchronously = config.chatMessageMainContextContentNode.originalDisplaysAsync
                chatMessageTextContentNode?.displaysAsynchronously = config.chatMessageTextContentNode.originalDisplaysAsync
                chatMessageTextNode?.displaysAsynchronously = config.chatMessageTextNode.originalDisplaysAsync
                chatMessageStatusNode?.displaysAsynchronously = config.chatMessageStatusNode.originalDisplaysAsync
                chatMessageWebpageContentNode?.displaysAsynchronously = config.chatMessageWebpageContentNode.originalDisplaysAsync
                chatMessageReplyInfoNode?.displaysAsynchronously = config.chatMessageReplyInfoNode.originalDisplaysAsync
                chatMessageForwardInfoNode?.displaysAsynchronously = config.chatMessageForwardInfoNode.originalDisplaysAsync
                
                chatMessageNode.shouldAnimateSizeChanges = config.chatMessageNode.originalShouldAnimateSizeChanges
                chatMessageMainContainerNode?.shouldAnimateSizeChanges = config.chatMessageMainContainerNode.originalShouldAnimateSizeChanges
                chatMessageMainContextNode?.shouldAnimateSizeChanges = config.chatMessageMainContextNode.originalShouldAnimateSizeChanges
                chatMessageMainContextContentNode?.shouldAnimateSizeChanges = config.chatMessageMainContextContentNode.originalShouldAnimateSizeChanges
                chatMessageTextContentNode?.shouldAnimateSizeChanges = config.chatMessageTextContentNode.originalShouldAnimateSizeChanges
                chatMessageTextNode?.shouldAnimateSizeChanges = config.chatMessageTextNode.originalShouldAnimateSizeChanges
                chatMessageStatusNode?.shouldAnimateSizeChanges = config.chatMessageStatusNode.originalShouldAnimateSizeChanges
                chatMessageWebpageContentNode?.shouldAnimateSizeChanges = config.chatMessageWebpageContentNode.originalShouldAnimateSizeChanges
                chatMessageReplyInfoNode?.shouldAnimateSizeChanges = config.chatMessageReplyInfoNode.originalShouldAnimateSizeChanges
                chatMessageForwardInfoNode?.shouldAnimateSizeChanges = config.chatMessageForwardInfoNode.originalShouldAnimateSizeChanges
                
                completion()
            }
            
            do { // animatingNode
                let fromFrame = config.animatingNode.startFrame
                let toFrame = config.animatingNode.endFrame
                
                let animations = [
                    setupResizeAnimation(layer: animatingNode.layer,
                                         fromSize: fromFrame.size,
                                         toSize: toFrame.size,
                                         duration: animationDuration,
                                         timingFunction: settings.bubbleShapeFunc),
                    setupRepositionXAnimation(layer: animatingNode.layer,
                                              fromPosition: fromFrame.position.x,
                                              toPosition: toFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.xPositionFunc),
                    setupRepositionYAnimation(layer: animatingNode.layer,
                                              fromPosition: fromFrame.position.y,
                                              toPosition: toFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.yPositionFunc)
                ]
                addAnimations(animatingNode.layer, animations, duration: animationDuration)
            }
            
            do { // maskNode
                let fromFrame = config.animatingNode.startFrame.toBounds()
                let toFrame = config.animatingNode.endFrame.toBounds()
                
                let animations = [
                    setupResizeAnimation(layer: maskNode.layer,
                                         fromSize: fromFrame.size,
                                         toSize: toFrame.size,
                                         duration: animationDuration,
                                         timingFunction: settings.bubbleShapeFunc),
                    setupRepositionXAnimation(layer: maskNode.layer,
                                              fromPosition: fromFrame.position.x,
                                              toPosition: toFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc),
                    setupRepositionYAnimation(layer: maskNode.layer,
                                              fromPosition: fromFrame.position.y,
                                              toPosition: toFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc),
                ]
                addAnimations(maskNode.layer, animations, duration: animationDuration)
            }
            
            let fromPath = generateTextInputBackgroundPath(config, config.inputTextContainerNode.convertedFrame.size).cgPath
            let toPath = generateBubbleBackgroundPath(config, config.chatMessageBackgroundNode.originalFrame.size).cgPath
            
            do { // maskShapeLayer
                let redrawPathAnimation = CABasicAnimation(keyPath: "path")
                redrawPathAnimation.fromValue = fromPath
                redrawPathAnimation.toValue = toPath
                updateAnimation(redrawPathAnimation, duration: animationDuration, timingFunction: settings.bubbleShapeFunc)
                
                let animations = [redrawPathAnimation]
                addAnimations(maskShapeLayer, animations, duration: animationDuration)
            }
            
            do { // backgroundNode
                let fromFrame = config.animatingNode.startFrame.toBounds()
                let toFrame = config.animatingNode.endFrame.toBounds()
                
                let animations = [
                    setupResizeAnimation(layer: backgroundNode.layer,
                                         fromSize: fromFrame.size,
                                         toSize: toFrame.size,
                                         duration: animationDuration,
                                         timingFunction: settings.bubbleShapeFunc),
                    setupRepositionXAnimation(layer: backgroundNode.layer,
                                              fromPosition: fromFrame.position.x,
                                              toPosition: toFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc),
                    setupRepositionYAnimation(layer: backgroundNode.layer,
                                              fromPosition: fromFrame.position.y,
                                              toPosition: toFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc),
                ]
                addAnimations(backgroundNode.layer, animations, duration: animationDuration)
            }
            
            do { // backgroundShapeLayer
                let fromStrokeColor = config.textInputStyle.strokeColor.cgColor
                // TODO: We need to combine path with tail node to be able to stroke them together
                // chatMessageBackgroundNode.chatMessageBackgroundStrokeColor.cgColor
                let toStrokeColor = UIColor.clear.cgColor
                
                let fromFillColor = config.textInputStyle.fillColor.cgColor
                let toFillColor = chatMessageBackgroundNode.chatMessageBackgroundFillColor.cgColor
                
                let redrawPathAnimation = CABasicAnimation(keyPath: "path")
                redrawPathAnimation.fromValue = fromPath
                redrawPathAnimation.toValue = toPath
                updateAnimation(redrawPathAnimation, duration: animationDuration, timingFunction: settings.bubbleShapeFunc)
                
                let redrawStrokeAnimation = CABasicAnimation(keyPath: "strokeColor")
                redrawStrokeAnimation.fromValue = fromStrokeColor
                redrawStrokeAnimation.toValue = toStrokeColor
                updateAnimation(redrawStrokeAnimation, duration: animationDuration, timingFunction: settings.colorChangeFunc)
                
                let redrawFillAnimation = CABasicAnimation(keyPath: "fillColor")
                redrawFillAnimation.fromValue = fromFillColor
                redrawFillAnimation.toValue = toFillColor
                updateAnimation(redrawFillAnimation, duration: animationDuration, timingFunction: settings.colorChangeFunc)
                
                let animations = [
                    redrawPathAnimation,
                    redrawStrokeAnimation,
                    redrawFillAnimation
                ]
                addAnimations(backgroundShapeLayer, animations, duration: animationDuration)
            }
            
            do { // tailNode
                let fromFrame = CGRect(origin: CGPoint(x: config.animatingNode.startFrame.width - tailImage.size.width,
                                                       y: config.animatingNode.startFrame.height - tailImage.size.height * 2.0),
                                       size: tailImage.size)
                let toFrame = CGRect(origin: CGPoint(x: config.animatingNode.endFrame.width - tailImage.size.width,
                                                     y: config.animatingNode.endFrame.height - tailImage.size.height),
                                     size: tailImage.size)
                
                let fromOpacity: CGFloat = 0.0
                let toOpacity: CGFloat = 1.0
                
                let showAnimation = CABasicAnimation(keyPath: "opacity")
                showAnimation.fromValue = fromOpacity
                showAnimation.toValue = toOpacity
                updateAnimation(showAnimation, duration: animationDuration, timingFunction: settings.bubbleShapeFunc)
                
                // TODO: Doesn't work, probably because of the mask layer, but backgroundColor is working, which is strange
                // let fromFillColor = config.textInputStyle.fillColor.cgColor
                // let toFillColor = chatMessageBackgroundNode.chatMessageBackgroundFillColor.cgColor
                // let redrawFillAnimation = CABasicAnimation(keyPath: "fillColor")
                // redrawFillAnimation.fromValue = fromFillColor
                // redrawFillAnimation.toValue = toFillColor
                // updateAnimation(redrawFillAnimation, duration: animationDuration, timingFunction: settings.colorChangeFunc)
                
                let animations = [
                    setupRepositionXAnimation(layer: tailNode.layer,
                                              fromPosition: fromFrame.position.x,
                                              toPosition: toFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc),
                    setupRepositionYAnimation(layer: tailNode.layer,
                                              fromPosition: fromFrame.position.y,
                                              toPosition: toFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc),
                    showAnimation
                ]
                addAnimations(tailNode.layer, animations, duration: animationDuration)
            }
            
            do { // chatMessageMainContainerNode
                let fromFrame = config.animatingNode.startFrame.toBounds()
                let toFrame = config.chatMessageMainContainerNode.convertedFrame
                
                let animations = [
                    setupResizeAnimation(layer: chatMessageMainContainerNode.layer,
                                         fromSize: fromFrame.size,
                                         toSize: toFrame.size,
                                         duration: animationDuration,
                                         timingFunction: settings.bubbleShapeFunc),
                    setupRepositionXAnimation(layer: chatMessageMainContainerNode.layer,
                                              fromPosition: fromFrame.position.x,
                                              toPosition: toFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc),
                    setupRepositionYAnimation(layer: chatMessageMainContainerNode.layer,
                                              fromPosition: fromFrame.position.y,
                                              toPosition: toFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc)
                ]
                addAnimations(chatMessageMainContainerNode.layer, animations, duration: animationDuration)
            }
            
            do { // chatMessageMainContextNode
                let fromFrame = config.animatingNode.startFrame.toBounds()
                let toFrame = config.chatMessageMainContextNode.originalFrame
                
                let animations = [
                    setupResizeAnimation(layer: chatMessageMainContextNode.layer,
                                         fromSize: fromFrame.size,
                                         toSize: toFrame.size,
                                         duration: animationDuration,
                                         timingFunction: settings.bubbleShapeFunc),
                    setupRepositionXAnimation(layer: chatMessageMainContextNode.layer,
                                              fromPosition: fromFrame.position.x,
                                              toPosition: toFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc),
                    setupRepositionYAnimation(layer: chatMessageMainContextNode.layer,
                                              fromPosition: fromFrame.position.y,
                                              toPosition: toFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc)
                ]
                addAnimations(chatMessageMainContextNode.layer, animations, duration: animationDuration)
            }
            
            do { // chatMessageMainContextContentNode
                let fromFrame = config.animatingNode.startFrame.toBounds()
                let toFrame = config.chatMessageMainContextContentNode.originalFrame
                
                let animations = [
                    setupResizeAnimation(layer: chatMessageMainContextContentNode.layer,
                                         fromSize: fromFrame.size,
                                         toSize: toFrame.size,
                                         duration: animationDuration,
                                         timingFunction: settings.bubbleShapeFunc),
                    setupRepositionXAnimation(layer: chatMessageMainContextContentNode.layer,
                                              fromPosition: fromFrame.position.x,
                                              toPosition: toFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc),
                    setupRepositionYAnimation(layer: chatMessageMainContextContentNode.layer,
                                              fromPosition: fromFrame.position.y,
                                              toPosition: toFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc)
                ]
                addAnimations(chatMessageMainContextContentNode.layer, animations, duration: animationDuration)
            }
            
            do { // chatMessageTextContentNode
                let fromFrame = config.animatingNode.startFrame.toBounds()
                let toFrame = config.chatMessageTextContentNode.originalFrame
                
                let animations = [
                    setupResizeAnimation(layer: chatMessageTextContentNode.layer,
                                         fromSize: fromFrame.size,
                                         toSize: toFrame.size,
                                         duration: animationDuration,
                                         timingFunction: settings.bubbleShapeFunc),
                    setupRepositionXAnimation(layer: chatMessageTextContentNode.layer,
                                              fromPosition: fromFrame.position.x,
                                              toPosition: toFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc),
                    setupRepositionYAnimation(layer: chatMessageTextContentNode.layer,
                                              fromPosition: fromFrame.position.y,
                                              toPosition: toFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc)
                ]
                addAnimations(chatMessageTextContentNode.layer, animations, duration: animationDuration)
            }
            
            do { // chatMessageTextNode
                // Actually we should calculate difference in insets here to match content,
                // but apparently it is working fine without it. Needs to be investigated.
                // let insetsOffsetY = config.chatMessageTextNode.insets.top - config.inputTextNode.insets.top
                let insetsOffsetY: CGFloat = 0.0
                let fromFrame = chatMessageTextNode.frame.offsetBy(dx: CGFloat.zero, dy: -config.inputTextContainerNode.contentOffset.y + insetsOffsetY)
                let toFrame = config.chatMessageTextNode.originalFrame
                
                let animations = [
                    setupRepositionXAnimation(layer: chatMessageTextNode.layer,
                                              fromPosition: fromFrame.position.x,
                                              toPosition: toFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc),
                    setupRepositionYAnimation(layer: chatMessageTextNode.layer,
                                              fromPosition: fromFrame.position.y,
                                              toPosition: toFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc)
                ]
                addAnimations(chatMessageTextNode.layer, animations, duration: animationDuration)
            }
            
            do { // chatMessageStatusNode
                let origin = CGPoint(x: config.animatingNode.startFrame.width - config.chatMessageStatusNode.offset.x - config.chatMessageStatusNode.originalFrame.width,
                                     y: config.animatingNode.startFrame.height - config.chatMessageStatusNode.offset.y - config.chatMessageStatusNode.originalFrame.height)
                let convertedOrigin = chatMessageTextContentNode.view.convert(origin, to: chatMessageStatusNode.supernode!.view)
                let fromFrame = CGRect(origin: convertedOrigin, size: chatMessageStatusNode.bounds.size)
                let toFrame = config.chatMessageStatusNode.originalFrame
                
                let fromOpacity: CGFloat = 0.0
                let toOpacity = config.chatMessageStatusNode.originalAlpha
                
                let showAnimation = CABasicAnimation(keyPath: "opacity")
                showAnimation.fromValue = fromOpacity
                showAnimation.toValue = toOpacity
                updateAnimation(showAnimation, duration: animationDuration, timingFunction: settings.timeAppearsFunc)
                
                let animations = [
                    setupRepositionXAnimation(layer: chatMessageStatusNode.layer,
                                              fromPosition: fromFrame.position.x,
                                              toPosition: toFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc),
                    setupRepositionYAnimation(layer: chatMessageStatusNode.layer,
                                              fromPosition: fromFrame.position.y,
                                              toPosition: toFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc),
                    showAnimation
                ]
                addAnimations(chatMessageStatusNode.layer, animations, duration: animationDuration)
            }
            
            // chatMessageWebpageContentNode
            if let chatMessageWebpageContentNode = chatMessageWebpageContentNode {
                let originalFrame = config.chatMessageWebpageContentNode.originalFrame
                let fromFrame = CGRect(origin: CGPoint(x: CGFloat.zero, y: originalFrame.minY), size: config.animatingNode.startFrame.size)
                let toFrame = originalFrame
                
                let animations = [
                    setupResizeAnimation(layer: chatMessageWebpageContentNode.layer,
                                         fromSize: fromFrame.size,
                                         toSize: toFrame.size,
                                         duration: animationDuration,
                                         timingFunction: settings.bubbleShapeFunc),
                    setupRepositionXAnimation(layer: chatMessageWebpageContentNode.layer,
                                              fromPosition: fromFrame.position.x,
                                              toPosition: toFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc),
                    setupRepositionYAnimation(layer: chatMessageWebpageContentNode.layer,
                                              fromPosition: fromFrame.position.y,
                                              toPosition: toFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc)
                ]
                addAnimations(chatMessageWebpageContentNode.layer, animations, duration: animationDuration)
            }
            
            // chatMessageReplyInfoNode
            if let chatMessageReplyInfoNode = chatMessageReplyInfoNode {
                let originalFrame = config.chatMessageReplyInfoNode.originalFrame
                let offsetY = config.chatMessageTextContentNode.originalFrame.minY - originalFrame.minY
                let fromFrame = CGRect(origin: CGPoint(x: 0.0, y: -offsetY), size: chatMessageReplyInfoNode.bounds.size)
                let toFrame = originalFrame
                
                let animations = [
                    setupResizeAnimation(layer: chatMessageReplyInfoNode.layer,
                                         fromSize: fromFrame.size,
                                         toSize: toFrame.size,
                                         duration: animationDuration,
                                         timingFunction: settings.bubbleShapeFunc),
                    setupRepositionXAnimation(layer: chatMessageReplyInfoNode.layer,
                                              fromPosition: fromFrame.position.x,
                                              toPosition: toFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc),
                    setupRepositionYAnimation(layer: chatMessageReplyInfoNode.layer,
                                              fromPosition: fromFrame.position.y,
                                              toPosition: toFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc)
                ]
                addAnimations(chatMessageReplyInfoNode.layer, animations, duration: animationDuration)
            }
            
            // chatMessageForwardInfoNode
            if let chatMessageForwardInfoNode = chatMessageForwardInfoNode {
                let originalFrame = config.chatMessageForwardInfoNode.originalFrame
                let offsetY = config.chatMessageTextContentNode.originalFrame.minY - originalFrame.minY
                let fromFrame = CGRect(origin: CGPoint(x: 0.0, y: -offsetY), size: chatMessageForwardInfoNode.bounds.size)
                let toFrame = originalFrame
                
                let animations = [
                    setupResizeAnimation(layer: chatMessageForwardInfoNode.layer,
                                         fromSize: fromFrame.size,
                                         toSize: toFrame.size,
                                         duration: animationDuration,
                                         timingFunction: settings.bubbleShapeFunc),
                    setupRepositionXAnimation(layer: chatMessageForwardInfoNode.layer,
                                              fromPosition: fromFrame.position.x,
                                              toPosition: toFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc),
                    setupRepositionYAnimation(layer: chatMessageForwardInfoNode.layer,
                                              fromPosition: fromFrame.position.y,
                                              toPosition: toFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.bubbleShapeFunc)
                ]
                addAnimations(chatMessageForwardInfoNode.layer, animations, duration: animationDuration)
            }
            
            CATransaction.commit()
        }
    }
}
