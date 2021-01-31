import Foundation
import UIKit
import Display
import TelegramUIPreferences
import TelegramPresentationData

class ChatControllerAnimations {
    static public var isAnimating = false
    static public var animationsCounter = 0
    static public let animationKey = "ChatMessageAnimations"
    static public private(set) weak var lastStickerImageNode: TransformImageNode? = nil
    static public var lastReplyLineNodeFrame: CGRect? = nil
    static public var voiceBlobView: UIView? = nil
    static public var voiceBlobViewFrame: CGRect? = nil
    
    static public func setLastStickerImageNode(node: TransformImageNode) {
        lastStickerImageNode = node
    }
    
    static public func resetLastStickerImageNode() {
        lastStickerImageNode = nil
    }
    
    static func updateAnimation(_ animation: CAAnimation, duration: Double, timingFunction: ChatAnimationTimingFunction? = nil, isRemovedOnCompletion: Bool = false) {
        animation.duration = duration
        if let timingFunction = timingFunction {
            animation.timingFunction = CAMediaTimingFunction(
                controlPoints: Float(timingFunction.controlPoint1.x), Float(timingFunction.controlPoint1.y), Float(timingFunction.controlPoint2.x), Float(timingFunction.controlPoint2.y)
            )
        }
        if !isRemovedOnCompletion {
            animation.isRemovedOnCompletion = false
            animation.fillMode = .forwards
        }
    }
    
    static public func setupResizeAnimation(fromSize: CGSize, toSize: CGSize, duration: Double, timingFunction: ChatAnimationTimingFunction) -> CAAnimation {
        let fromRect = NSValue(cgRect: CGRect(x: 0.0, y: 0.0, width: fromSize.width, height: fromSize.height))
        let toRect = NSValue(cgRect: CGRect(x: 0.0, y: 0.0, width: toSize.width, height: toSize.height))
        let controlPoint1 = NSNumber(value: Double(timingFunction.startTimeOffset))
        let controlPoint2 = NSNumber(value: Double(1.0 - timingFunction.endTimeOffset))
        
        let animation = CAKeyframeAnimation(keyPath: "bounds")
        animation.values = [fromRect, fromRect, toRect, toRect]
        animation.keyTimes = [0.0, controlPoint1, controlPoint2, 1.0]
        updateAnimation(animation, duration: duration, timingFunction: timingFunction)
        return animation
    }
    
    static public func setupRepositionXAnimation(fromPosition: CGFloat, toPosition: CGFloat, duration: Double, timingFunction: ChatAnimationTimingFunction) -> CAAnimation {
        let controlPoint1 = NSNumber(value: Double(timingFunction.startTimeOffset))
        let controlPoint2 = NSNumber(value: Double(1.0 - timingFunction.endTimeOffset))
        
        let animation = CAKeyframeAnimation(keyPath: "position.x")
        animation.values = [fromPosition, fromPosition, toPosition, toPosition]
        animation.keyTimes = [0.0, controlPoint1, controlPoint2, 1.0]
        updateAnimation(animation, duration: duration, timingFunction: timingFunction)
        return animation
    }
    
    static public func setupRepositionYAnimation(fromPosition: CGFloat, toPosition: CGFloat, duration: Double, timingFunction: ChatAnimationTimingFunction) -> CAAnimation {
        let controlPoint1 = NSNumber(value: Double(timingFunction.startTimeOffset))
        let controlPoint2 = NSNumber(value: Double(1.0 - timingFunction.endTimeOffset))
        
        let animation = CAKeyframeAnimation(keyPath: "position.y")
        animation.values = [fromPosition, fromPosition, toPosition, toPosition]
        animation.keyTimes = [0.0, controlPoint1, controlPoint2, 1.0]
        updateAnimation(animation, duration: duration, timingFunction: timingFunction)
        return animation
    }
    
    static public func setupAnimation(keyPath: String, fromValue: Any, toValue: Any, duration: Double, timingFunction: ChatAnimationTimingFunction, isRemovedOnCompletion: Bool = false) -> CAAnimation {
        let controlPoint1 = NSNumber(value: Double(timingFunction.startTimeOffset))
        let controlPoint2 = NSNumber(value: Double(1.0 - timingFunction.endTimeOffset))
        
        let animation = CAKeyframeAnimation(keyPath: keyPath)
        animation.values = [fromValue, fromValue, toValue, toValue]
        animation.keyTimes = [0.0, controlPoint1, controlPoint2, 1.0]
        updateAnimation(animation, duration: duration, timingFunction: timingFunction, isRemovedOnCompletion: isRemovedOnCompletion)
        return animation
    }
    
    static public func setupAnimation(keyPath: String, fromValue: Any, toValue: Any, duration: Double, isRemovedOnCompletion: Bool = false) -> CAAnimation {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = fromValue
        animation.toValue = toValue
        updateAnimation(animation, duration: duration, isRemovedOnCompletion: isRemovedOnCompletion)
        return animation
    }
    
    static public func addAnimations(_ layer: CALayer, _ animations: [CAAnimation], duration: Double, isRemovedOnCompletion: Bool = false) {
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = animations
        animationGroup.duration = duration
        if !isRemovedOnCompletion {
            animationGroup.isRemovedOnCompletion = false
            animationGroup.fillMode = .forwards
        }
        layer.add(animationGroup, forKey: animationKey)
    }
    
    private init() {}
    
    static func getAnimationCallback(chatControllerNode viewNode: ChatControllerNode,
                                     shouldAnimateScrollView: Bool,
                                     presentationData: PresentationData) -> ChatHistoryListViewTransition.AnimationCallback {
        return { [weak viewNode = viewNode] (chatMessageNode: ListViewItemNode, completion: (() -> Void)?) in            
            guard let viewNode = viewNode,
                  let inputPanelNode = viewNode.inputPanelNode as? ChatTextInputPanelNode else {
                completion?()
                return
            }
            
            if let chatMessageNode = chatMessageNode as? ChatMessageBubbleItemNode {
                if let chatMessageTextContentNode = chatMessageNode.chatMessageTextBubbleContentNode {
                    ChatControllerAnimationsText.animateText(chatControllerNode: viewNode,
                                                             inputPanelNode: inputPanelNode,
                                                             chatMessageNode: chatMessageNode,
                                                             chatMessageTextContentNode: chatMessageTextContentNode,
                                                             shouldAnimateScrollView: shouldAnimateScrollView,
                                                             completion: completion)
                }
                else if let chatMessageFileContentNode = chatMessageNode.chatMessageFileBubbleContentNode {
                    ChatControllerAnimationsVoice.animateVoice(chatControllerNode: viewNode,
                                                               inputPanelNode: inputPanelNode,
                                                               chatMessageNode: chatMessageNode,
                                                               chatMessageFileContentNode: chatMessageFileContentNode,
                                                               shouldAnimateScrollView: shouldAnimateScrollView,
                                                               presentationData: presentationData,
                                                               completion: completion)
                }
                else {
                    completion?()
                }
            }
            else if let chatMessageNode = chatMessageNode as? ChatMessageSticker {
                ChatControllerAnimationsEmoji.animateEmoji(chatControllerNode: viewNode,
                                                           inputPanelNode: inputPanelNode,
                                                           chatMessageNode: chatMessageNode,
                                                           shouldAnimateScrollView: shouldAnimateScrollView,
                                                           completion: completion)
            }
            else {
                completion?()
            }
        }
    }
}
