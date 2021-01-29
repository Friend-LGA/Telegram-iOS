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

let tailWidth: CGFloat = 6.0

fileprivate struct Config {
    let startPath: UIBezierPath
    let endPath: UIBezierPath
    let tailImage: UIImage
    
    let animatingNode: (startFrame: CGRect,
                        endFrame: CGRect)
    
    let inputTextContainerNode: (convertedFrame: CGRect,
                                 contentOffset: CGPoint,
                                 contentSize: CGSize,
                                 insets: UIEdgeInsets,
                                 minimalInputHeight: CGFloat)
    
    let accessoryPanelFrame: CGRect
    
    let chatMessageMainContainerNode: (originalFrame: CGRect,
                                       convertedStartFrame: CGRect,
                                       convertedEndFrame: CGRect,
                                       originalSubnodeIndex: Int)
    
    let chatMessageStatusNode: (originalFrame: CGRect,
                                convertedStartFrame: CGRect,
                                convertedEndFrame: CGRect,
                                originalAlpha: CGFloat,
                                originalSupernode: ASDisplayNode,
                                originalSubnodeIndex: Int)
    
    let textInputStyle: (cornerRadius: CGFloat,
                         fillColor: UIColor,
                         strokeColor: UIColor)
    
    init(viewNode: ChatControllerNode,
         inputPanelNode: ChatTextInputPanelNode,
         inputTextContainerNode: ASDisplayNode,
         chatMessageNode: ASDisplayNode,
         chatMessageMainContainerNode: ASDisplayNode,
         chatMessageMainContextNode: ASDisplayNode,
         chatMessageMainContextContentNode: ASDisplayNode,
         chatMessageBackgroundNode: ChatMessageBackground,
         chatMessageTextContentNode: ASDisplayNode,
         chatMessageTextNode: TextNode,
         chatMessageStatusNode: ASDisplayNode) {
        // ASDisplayNode.convert() is giving wrong values, using UIView.convert() instead
        self.inputTextContainerNode = (convertedFrame: viewNode.textInputLastFrame ?? inputTextContainerNode.view.convert(inputTextContainerNode.view.bounds, to: viewNode.view),
                                       contentOffset: viewNode.textInputLastContentOffset ?? inputPanelNode.textInputNode?.textView.contentOffset ?? CGPoint.zero,
                                       contentSize: viewNode.textInputLastContentSize ?? inputPanelNode.textInputNode?.textView.contentSize ?? CGSize.zero,
                                       insets: inputPanelNode.textInputNode?.textContainerInset ?? UIEdgeInsets.zero,
                                       minimalInputHeight: inputPanelNode.minimalInputHeight())
        
        self.accessoryPanelFrame = viewNode.accessoryPanelLastFrame ?? CGRect.zero
        
        self.startPath = generateTextInputBackgroundPath(size: self.inputTextContainerNode.convertedFrame.size,
                                                         minimalInputHeight: self.inputTextContainerNode.minimalInputHeight)
        
        self.endPath = generateBubbleBackgroundPath(size: chatMessageBackgroundNode.bounds.size,
                                                    neighborsDirection: chatMessageBackgroundNode.neighborsDirection,
                                                    minCornerRadius: chatMessageBackgroundNode.chatMessageBackgroundMinCornerRadius,
                                                    maxCornerRadius: chatMessageBackgroundNode.chatMessageBackgroundMaxCornerRadius)
        
        self.tailImage = generateTailImage(maxCornerRadius: chatMessageBackgroundNode.chatMessageBackgroundMaxCornerRadius,
                                           tailColor: chatMessageBackgroundNode.chatMessageBackgroundFillColor)
        
        self.animatingNode = (startFrame: self.inputTextContainerNode.convertedFrame,
                              endFrame: chatMessageBackgroundNode.view.convert(chatMessageBackgroundNode.view.bounds, to: viewNode.view)) // .offsetBy(dx: CGFloat.zero, dy: -chatMessageNode.bounds.height))
        
        let chatMessageTextNodeConverted = chatMessageTextContentNode.view.convert(chatMessageTextContentNode.view.bounds, to: chatMessageMainContainerNode.view)
        let textInputNode = inputPanelNode.textInputNode!
        let convertedToBackgroundFrame = chatMessageMainContainerNode.view.convert(chatMessageMainContainerNode.view.bounds, to: chatMessageBackgroundNode.view)
        self.chatMessageMainContainerNode = (originalFrame: chatMessageMainContainerNode.frame,
                                             convertedStartFrame: convertedToBackgroundFrame.offsetBy(dx: (textInputNode.frame.origin.x - chatMessageTextNode.frame.origin.x),
                                                                                                      dy: -chatMessageTextNodeConverted.origin.y - self.inputTextContainerNode.contentOffset.y),
                                             convertedEndFrame: convertedToBackgroundFrame,
                                             originalSubnodeIndex: chatMessageNode.subnodes!.firstIndex(of: chatMessageMainContainerNode)!)
        
        let chatMessageStatusNodeConvertedFrame = chatMessageStatusNode.view.convert(chatMessageStatusNode.view.bounds, to: chatMessageMainContextContentNode.view)
        let chatMessageStatusNodeOffsetX = chatMessageMainContextContentNode.frame.width - chatMessageStatusNodeConvertedFrame.maxX - tailWidth
        let chatMessageStatusNodeOffsetY = chatMessageMainContextContentNode.frame.height - chatMessageStatusNodeConvertedFrame.maxY
        let chatMessageStatusNodeConvertedStartOrigin = CGPoint(x: self.animatingNode.startFrame.width - chatMessageStatusNodeOffsetX - chatMessageStatusNode.bounds.width,
                                                                y: self.animatingNode.startFrame.height - chatMessageStatusNodeOffsetY - chatMessageStatusNode.bounds.height)
        self.chatMessageStatusNode = (originalFrame: chatMessageStatusNode.frame,
                                      convertedStartFrame: CGRect(origin: chatMessageStatusNodeConvertedStartOrigin, size: chatMessageStatusNode.bounds.size),
                                      convertedEndFrame: chatMessageStatusNode.view.convert(chatMessageStatusNode.view.bounds, to: chatMessageBackgroundNode.view),
                                      originalAlpha: chatMessageStatusNode.alpha,
                                      originalSupernode: chatMessageStatusNode.supernode!,
                                      originalSubnodeIndex: chatMessageStatusNode.supernode!.subnodes!.firstIndex(of: chatMessageStatusNode)!)
        
        self.textInputStyle = (cornerRadius: min(self.inputTextContainerNode.minimalInputHeight / 2.0, self.inputTextContainerNode.convertedFrame.height / 2.0),
                               fillColor: inputPanelNode.inputBackgroundColor(),
                               strokeColor: inputPanelNode.inputStrokeColor())
    }
}

fileprivate func toRadians(_ degrees: CGFloat) -> CGFloat {
    degrees * .pi / 180.0
}

fileprivate func generateTailImage(maxCornerRadius: CGFloat, tailColor: UIColor) -> UIImage {
    let size = CGSize(width: 16.0, height: 16.0)
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

fileprivate func generateTextInputBackgroundPath(size: CGSize, minimalInputHeight: CGFloat) -> UIBezierPath {
    let path = UIBezierPath()
    let radius: CGFloat = min(minimalInputHeight / 2.0, size.height / 2.0)
    
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

fileprivate func generateBubbleBackgroundPath(size: CGSize, neighborsDirection: MessageBubbleImageNeighbors, minCornerRadius: CGFloat, maxCornerRadius: CGFloat) -> UIBezierPath {
    let path = UIBezierPath()
    let topLeftRadius: CGFloat
    let topRightRadius: CGFloat
    let bottomLeftRadius: CGFloat
    let bottomRightRadius: CGFloat
    
    switch neighborsDirection {
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

private func updateAnimation(_ animation: CAKeyframeAnimation, duration: Double, timingFunction: ChatAnimationTimingFunction) {
    animation.duration = duration
    animation.timingFunction = CAMediaTimingFunction(
        controlPoints: Float(timingFunction.controlPoint1.x), Float(timingFunction.controlPoint1.y), Float(timingFunction.controlPoint2.x), Float(timingFunction.controlPoint2.y)
    )
    animation.isRemovedOnCompletion = false
    animation.fillMode = .forwards
}

private func setupResizeAnimation(layer: CALayer, fromSize: CGSize, toSize: CGSize, duration: Double, timingFunction: ChatAnimationTimingFunction) -> CAKeyframeAnimation {
    let animation = CAKeyframeAnimation(keyPath: "bounds")
    let fromRect = [0.0, 0.0, fromSize.width, fromSize.height]
    let toRect = [0.0, 0.0, toSize.width, toSize.height]
    animation.values = [fromRect, fromRect, toRect, toRect]
    animation.keyTimes = [0, NSNumber(value: Double(timingFunction.startTimeOffset)), NSNumber(value: Double(1.0 - timingFunction.endTimeOffset)), 1]
    updateAnimation(animation, duration: duration, timingFunction: timingFunction)
    return animation
}

private func setupRepositionXAnimation(layer: CALayer, fromPosition: CGFloat, toPosition: CGFloat, duration: Double, timingFunction: ChatAnimationTimingFunction) -> CAKeyframeAnimation {
    let animation = CAKeyframeAnimation(keyPath: "position.x")
    animation.values = [fromPosition, fromPosition, toPosition, toPosition]
    animation.keyTimes = [0, NSNumber(value: Double(timingFunction.startTimeOffset)), NSNumber(value: Double(1.0 - timingFunction.endTimeOffset)), 1]
    updateAnimation(animation, duration: duration, timingFunction: timingFunction)
    return animation
}

private func setupRepositionYAnimation(layer: CALayer, fromPosition: CGFloat, toPosition: CGFloat, duration: Double, timingFunction: ChatAnimationTimingFunction) -> CAKeyframeAnimation {
    let animation = CAKeyframeAnimation(keyPath: "position.y")
    animation.values = [fromPosition, fromPosition, toPosition, toPosition]
    animation.keyTimes = [0, NSNumber(value: Double(timingFunction.startTimeOffset)), NSNumber(value: Double(1.0 - timingFunction.endTimeOffset)), 1]
    updateAnimation(animation, duration: duration, timingFunction: timingFunction)
    return animation
}

private func setupAnimation(keyPath: String, fromValue: Any, toValue: Any, duration: Double, timingFunction: ChatAnimationTimingFunction) -> CAKeyframeAnimation {
    let animation = CAKeyframeAnimation(keyPath: keyPath)
    animation.values = [fromValue, fromValue, toValue, toValue]
    animation.keyTimes = [0, NSNumber(value: Double(timingFunction.startTimeOffset)), NSNumber(value: Double(1.0 - timingFunction.endTimeOffset)), 1]
    updateAnimation(animation, duration: duration, timingFunction: timingFunction)
    return animation
}

private func addAnimations(_ layer: CALayer, _ animations: [CAKeyframeAnimation], duration: Double) {
    let animationGroup = CAAnimationGroup()
    animationGroup.animations = animations
    animationGroup.duration = duration
    animationGroup.isRemovedOnCompletion = false
    animationGroup.fillMode = .forwards
    layer.add(animationGroup, forKey: animationKey)
}

class ChatControllerAnimations {
    private init() {}
            
    static public func getAnimationCallback(chatControllerNode viewNode: ChatControllerNode, shouldAnimateScrollView: Bool) -> ChatHistoryListViewTransition.AnimationCallback {
        return { [weak viewNode = viewNode] (chatMessageNode: ListViewItemNode, completion: (() -> Void)?) in
            let completion = completion ?? {}
            
            guard let viewNode = viewNode,
                  let inputPanelNode = viewNode.inputPanelNode as? ChatTextInputPanelNode,
                  let chatMessageNode = chatMessageNode as? ChatMessageBubbleItemNode,
                  let chatMessageTextContentNode = chatMessageNode.chatMessageTextBubbleContentNode else {
                completion()
                return
            }
            
            let listNode = viewNode.historyNode
            let listContainerNode = viewNode.historyNodeContainer
            let scroller = listNode.scroller
            
            let inputTextContainerNode = inputPanelNode.textInputContainer
            let chatMessageMainContainerNode = chatMessageNode.mainContainerNode
            let chatMessageMainContextNode = chatMessageNode.mainContextSourceNode
            let chatMessageMainContextContentNode = chatMessageMainContextNode.contentNode
            let chatMessageBackgroundNode = chatMessageNode.backgroundNode
            let chatMessageTextNode = chatMessageTextContentNode.textNode
            let chatMessageWebpageContentNode = chatMessageNode.chatMessageWebpageBubbleContentNode
            let chatMessageStatusNode = chatMessageWebpageContentNode?.contentNode.statusNode ?? chatMessageTextContentNode.statusNode
            
            listNode.displaysAsynchronously = false
            listNode.shouldAnimateSizeChanges = false
            listContainerNode.displaysAsynchronously = false
            listContainerNode.shouldAnimateSizeChanges = false
            chatMessageNode.displaysAsynchronously = false
            chatMessageNode.shouldAnimateSizeChanges = false
            chatMessageMainContainerNode.displaysAsynchronously = false
            chatMessageMainContainerNode.shouldAnimateSizeChanges = false
            chatMessageMainContextNode.displaysAsynchronously = false
            chatMessageMainContextNode.shouldAnimateSizeChanges = false
            chatMessageMainContextContentNode.displaysAsynchronously = false
            chatMessageMainContextContentNode.shouldAnimateSizeChanges = false
            chatMessageTextContentNode.displaysAsynchronously = false
            chatMessageTextContentNode.shouldAnimateSizeChanges = false
            chatMessageTextNode.displaysAsynchronously = false
            chatMessageTextNode.shouldAnimateSizeChanges = false
            chatMessageWebpageContentNode?.displaysAsynchronously = false
            chatMessageWebpageContentNode?.shouldAnimateSizeChanges = false
            chatMessageStatusNode.displaysAsynchronously = false
            chatMessageStatusNode.shouldAnimateSizeChanges = false
            
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
                                chatMessageStatusNode: chatMessageStatusNode)
            
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
                    tailMaskLayer.contents = config.tailImage.cgImage
                    tailMaskLayer.frame = CGRect(origin: CGPoint.zero, size: config.tailImage.size)
                    tailNode.layer.mask = tailMaskLayer
                    animatingNode.insertSubnode(tailNode, belowSubnode: backgroundNode)
                    // TODO: Magic, but only this node's animation doesn't work without soecifying frame here
                    tailNode.frame = CGRect(origin: CGPoint.zero, size: config.tailImage.size)
                    
                    maskShapeLayer.strokeColor = UIColor.black.cgColor
                    maskShapeLayer.fillColor = UIColor.black.cgColor
                    maskNode.layer.mask = maskShapeLayer
                    animatingNode.addSubnode(maskNode)
                }
                
                do { // old nodes setup
                    chatMessageMainContainerNode.removeFromSupernode()
                    maskNode.addSubnode(chatMessageMainContainerNode)
                    
                    chatMessageStatusNode.removeFromSupernode()
                    maskNode.addSubnode(chatMessageStatusNode)
                    
                    chatMessageBackgroundNode.isHidden = true
                }
            }
            
            // Preparation is done, it's time to go bananaz!!! (... and draw some animations)
            let animationDuration = settings.duration.rawValue
            
            let listContainerNodeOriginalFrame = listContainerNode.frame
            let listNodeOriginalFrame = listNode.frame
            
            CATransaction.begin()
            CATransaction.setCompletionBlock { [weak listContainerNode,
                                                weak listNode,
                                                weak scroller,
                                                weak chatMessageNode,
                                                weak chatMessageMainContainerNode,
                                                weak chatMessageMainContextNode,
                                                weak chatMessageMainContextContentNode,
                                                weak chatMessageTextContentNode,
                                                weak chatMessageTextNode,
                                                weak chatMessageWebpageContentNode,
                                                weak chatMessageBackgroundNode,
                                                weak chatMessageStatusNode] in
                guard let chatMessageNode = chatMessageNode else {
                    completion()
                    return
                }
                
                if let chatMessageMainContainerNode = chatMessageMainContainerNode {
                    chatMessageMainContainerNode.removeFromSupernode()
                    chatMessageNode.insertSubnode(chatMessageMainContainerNode, at: config.chatMessageMainContainerNode.originalSubnodeIndex)
                    chatMessageMainContainerNode.frame = config.chatMessageMainContainerNode.originalFrame
                }
                
                if let chatMessageStatusNode = chatMessageStatusNode {
                    chatMessageStatusNode.removeFromSupernode()
                    config.chatMessageStatusNode.originalSupernode.insertSubnode(chatMessageStatusNode, at: config.chatMessageStatusNode.originalSubnodeIndex)
                    chatMessageStatusNode.frame = config.chatMessageStatusNode.originalFrame
                    chatMessageStatusNode.alpha = config.chatMessageStatusNode.originalAlpha
                }
                
                chatMessageBackgroundNode?.isHidden = false
                
                animatingNode.removeFromSupernode()
                maskNode.removeFromSupernode()
                backgroundNode.removeFromSupernode()
                tailNode.removeFromSupernode()
                
                listContainerNode?.displaysAsynchronously = true
                listContainerNode?.shouldAnimateSizeChanges = true
                // listNode?.displaysAsynchronously = true
                listNode?.shouldAnimateSizeChanges = true
                chatMessageNode.displaysAsynchronously = true
                chatMessageNode.shouldAnimateSizeChanges = true
                chatMessageMainContainerNode?.displaysAsynchronously = true
                chatMessageMainContainerNode?.shouldAnimateSizeChanges = true
                chatMessageMainContextNode?.displaysAsynchronously = true
                chatMessageMainContextNode?.shouldAnimateSizeChanges = true
                chatMessageMainContextContentNode?.displaysAsynchronously = true
                chatMessageMainContextContentNode?.shouldAnimateSizeChanges = true
                chatMessageTextContentNode?.displaysAsynchronously = true
                chatMessageTextContentNode?.shouldAnimateSizeChanges = true
                chatMessageTextNode?.displaysAsynchronously = true
                chatMessageTextNode?.shouldAnimateSizeChanges = true
                chatMessageWebpageContentNode?.displaysAsynchronously = true
                chatMessageWebpageContentNode?.shouldAnimateSizeChanges = true
                chatMessageStatusNode?.displaysAsynchronously = true
                chatMessageStatusNode?.shouldAnimateSizeChanges = true
                
                chatMessageMainContainerNode?.layer.removeAnimation(forKey: animationKey)
                chatMessageStatusNode?.layer.removeAnimation(forKey: animationKey)
                
                if shouldAnimateScrollView {
                    listContainerNode?.frame = listContainerNodeOriginalFrame
                    listNode?.frame = listNodeOriginalFrame
                    
                    listContainerNode?.layer.removeAnimation(forKey: animationKey)
                    listNode?.layer.removeAnimation(forKey: animationKey)
                    scroller?.layer.removeAnimation(forKey: animationKey)
                }
                
                completion()
            }
            
            do { // animatingNode
                let fromFrame = config.animatingNode.startFrame
                let toFrame = config.animatingNode.endFrame
                
                let fromTranslateX: CGFloat = 0.0
                let toTranslateX = (fromFrame.width - toFrame.width) / 2.0 + tailWidth

                let fromTranslateY: CGFloat = 0.0
                let toTranslateY = (fromFrame.height - toFrame.height) / 2.0
                                
                let animations = [
                    setupResizeAnimation(layer: animatingNode.layer,
                                         fromSize: fromFrame.size,
                                         toSize: toFrame.size,
                                         duration: animationDuration,
                                         timingFunction: settings.bubbleShapeFunc),
                    setupRepositionXAnimation(layer: animatingNode.layer,
                                              fromPosition: fromFrame.position.x,
                                              toPosition: toFrame.position.x - toTranslateX,
                                              duration: animationDuration,
                                              timingFunction: settings.xPositionFunc),
                    setupRepositionYAnimation(layer: animatingNode.layer,
                                              fromPosition: fromFrame.position.y,
                                              toPosition: toFrame.position.y - toTranslateY,
                                              duration: animationDuration,
                                              timingFunction: settings.yPositionFunc),
                    setupAnimation(keyPath: "transform.translation.x",
                                   fromValue: fromTranslateX,
                                   toValue: toTranslateX,
                                   duration: animationDuration,
                                   timingFunction: settings.bubbleShapeFunc),
                    setupAnimation(keyPath: "transform.translation.y",
                                   fromValue: fromTranslateY,
                                   toValue: toTranslateY,
                                   duration: animationDuration,
                                   timingFunction: settings.bubbleShapeFunc),
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
            
            do { // maskShapeLayer
                let animations = [
                    setupAnimation(keyPath: "path",
                                   fromValue: config.startPath.cgPath,
                                   toValue: config.endPath.cgPath,
                                   duration: animationDuration,
                                   timingFunction: settings.bubbleShapeFunc)
                ]
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
                
                let animations = [
                    setupAnimation(keyPath: "path",
                                   fromValue: config.startPath.cgPath,
                                   toValue: config.endPath.cgPath,
                                   duration: animationDuration,
                                   timingFunction: settings.bubbleShapeFunc),
                    setupAnimation(keyPath: "strokeColor",
                                   fromValue: fromStrokeColor,
                                   toValue: toStrokeColor,
                                   duration: animationDuration,
                                   timingFunction: settings.bubbleShapeFunc),
                    setupAnimation(keyPath: "fillColor",
                                   fromValue: fromFillColor,
                                   toValue: toFillColor,
                                   duration: animationDuration,
                                   timingFunction: settings.colorChangeFunc)
                ]
                addAnimations(backgroundShapeLayer, animations, duration: animationDuration)
            }
            
            do { // tailNode
                let fromFrame = CGRect(origin: CGPoint(x: config.animatingNode.startFrame.width - config.tailImage.size.width,
                                                       y: config.animatingNode.startFrame.height - config.tailImage.size.height - config.textInputStyle.cornerRadius),
                                       size: config.tailImage.size)
                let toFrame = CGRect(origin: CGPoint(x: config.animatingNode.endFrame.width - config.tailImage.size.width,
                                                     y: config.animatingNode.endFrame.height - config.tailImage.size.height),
                                     size: config.tailImage.size)
                
                 let fromFillColor = config.textInputStyle.fillColor.cgColor
                 let toFillColor = chatMessageBackgroundNode.chatMessageBackgroundFillColor.cgColor
                
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
                     setupAnimation(keyPath: "backgroundColor",
                                    fromValue: fromFillColor,
                                    toValue: toFillColor,
                                    duration: animationDuration,
                                    timingFunction: settings.colorChangeFunc)
                ]
                addAnimations(tailNode.layer, animations, duration: animationDuration)
            }
                        
            do { // chatMessageMainContainerNode
                // Actually we should calculate difference in insets between text views to match content,
                // but apparently it is working fine without it. Needs to be investigated.
                // let insetsOffsetY = config.chatMessageTextNode.insets.top - config.inputTextNode.insets.top
                // offsetBy(dx: CGFloat.zero, dy: -config.inputTextContainerNode.contentOffset.y)
                let fromFrame = config.chatMessageMainContainerNode.convertedStartFrame
                let toFrame = config.chatMessageMainContainerNode.convertedEndFrame
                
                let animations = [
                    setupRepositionXAnimation(layer: chatMessageMainContainerNode.layer,
                                              fromPosition: fromFrame.position.x,
                                              toPosition: toFrame.position.x,
                                              duration: animationDuration,
                                              timingFunction: settings.textPositionFunc),
                    setupRepositionYAnimation(layer: chatMessageMainContainerNode.layer,
                                              fromPosition: fromFrame.position.y,
                                              toPosition: toFrame.position.y,
                                              duration: animationDuration,
                                              timingFunction: settings.textPositionFunc)
                ]
                addAnimations(chatMessageMainContainerNode.layer, animations, duration: animationDuration)
            }
            
            do { // chatMessageStatusNode
                let fromFrame = config.chatMessageStatusNode.convertedStartFrame
                let toFrame = config.chatMessageStatusNode.convertedEndFrame
                
                let fromOpacity: CGFloat = 0.0
                let toOpacity = config.chatMessageStatusNode.originalAlpha
                
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
                    setupAnimation(keyPath: "opacity",
                                   fromValue: fromOpacity,
                                   toValue: toOpacity,
                                   duration: animationDuration,
                                   timingFunction: settings.timeAppearsFunc)
                ]
                addAnimations(chatMessageStatusNode.layer, animations, duration: animationDuration)
            }
            
            // And finally, scroll view!
            if shouldAnimateScrollView {
                do { // listContainerNode
                    listContainerNode.layer.removeAllAnimations()
                    listNode.layer.removeAllAnimations()
                    let difference = config.inputTextContainerNode.convertedFrame.height - inputTextContainerNode.bounds.height + config.accessoryPanelFrame.height
                    
                    let fromFrame = CGRect(x: listContainerNodeOriginalFrame.origin.x,
                                           y: listContainerNodeOriginalFrame.origin.y + chatMessageNode.bounds.height - difference - 2.0 - viewNode.bounds.height,
                                           width: listContainerNodeOriginalFrame.width,
                                           height: listContainerNodeOriginalFrame.height + viewNode.bounds.height)
                    
                    let toFrame = fromFrame.offsetBy(dx: CGFloat.zero, dy: -chatMessageNode.bounds.height + difference + 2.0)
                    
                    listContainerNode.frame = fromFrame
                    listNode.frame = CGRect(x: listNode.frame.origin.x,
                                            y: listNode.frame.origin.y,
                                            width: listNode.frame.size.width,
                                            height: listNode.frame.height + viewNode.bounds.height)
                    
                    let fromTranslateY: CGFloat = 0.0
                    let toTranslateY = -(config.animatingNode.endFrame.height - (config.animatingNode.startFrame.height + config.accessoryPanelFrame.height))
                    
                    let animations = [
                        setupRepositionYAnimation(layer: listContainerNode.layer,
                                                  fromPosition: fromFrame.position.y,
                                                  toPosition: toFrame.position.y - toTranslateY,
                                                  duration: animationDuration,
                                                  timingFunction: settings.yPositionFunc),
                        setupAnimation(keyPath: "transform.translation.y",
                                       fromValue: fromTranslateY,
                                       toValue: toTranslateY,
                                       duration: animationDuration,
                                       timingFunction: settings.bubbleShapeFunc),
                    ]
                    listNode.layer.removeAllAnimations()
                    listContainerNode.layer.removeAllAnimations()
                    addAnimations(listContainerNode.layer, animations, duration: animationDuration)
                }
            }

            CATransaction.commit()
        }
    }
}
