import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import AnimatedStickerNode
import SlotMachineAnimationNode

private extension CGRect {
    func toBounds() -> CGRect {
        return CGRect(origin: CGPoint.zero, size: self.size)
    }
    
    var position: CGPoint {
        return CGPoint(x: self.midX, y: self.midY)
    }
}

private struct Config {
    let animatingNode: (startFrame: CGRect,
                        endFrame: CGRect)
    
    let inputTextContainerNode: (convertedFrame: CGRect,
                                 contentOffset: CGPoint,
                                 contentSize: CGSize,
                                 insets: UIEdgeInsets,
                                 minimalInputHeight: CGFloat,
                                 emojiFrame: CGRect,
                                 emojiCharacter: Character)
    
    let accessoryPanelFrame: CGRect
    
    let chatMessageContentNode: (originalFrame: CGRect,
                                 convertedFrameStart: CGRect,
                                 convertedFrameEnd: CGRect,
                                 originalSubnodeIndex: Int,
                                 originalTransform: CATransform3D)
    
    let chatMessageImageNode: (originalFrame: CGRect,
                               convertedFrame: CGRect,
                               originalSubnodeIndex: Int,
                               originalTransform: CATransform3D)
    
    let chatMessageStatusNode: (originalFrame: CGRect,
                                convertedFrame: CGRect,
                                originalAlpha: CGFloat,
                                originalSubnodeIndex: Int)
    
    let replyInfoNode: (originalFrame: CGRect, convertedFrameStart: CGRect, convertedFrameEnd: CGRect, originalSubnodeIndex: Int)
    let replyBackgroundNode: (originalFrame: CGRect, convertedFrameStart: CGRect, convertedFrameEnd: CGRect, originalSubnodeIndex: Int)
    
    init(viewNode: ChatControllerNode,
         inputPanelNode: ChatTextInputPanelNode,
         inputTextContainerNode: ASDisplayNode,
         chatMessageNode: ASDisplayNode,
         chatMessageContentNode: ASDisplayNode,
         chatMessagePlaceholderNode: ASDisplayNode?,
         chatMessageImageNode: ASDisplayNode,
         chatMessageStatusNode: ASDisplayNode,
         replyInfoNode: ASDisplayNode?,
         replyBackgroundNode: ASDisplayNode?) {
        // ASDisplayNode.convert() is giving wrong values, using UIView.convert() instead
        self.inputTextContainerNode = (convertedFrame: viewNode.textInputLastFrame ?? inputTextContainerNode.view.convert(inputTextContainerNode.view.bounds, to: viewNode.view),
                                       contentOffset: viewNode.textInputLastContentOffset ?? inputPanelNode.textInputNode?.textView.contentOffset ?? CGPoint.zero,
                                       contentSize: viewNode.textInputLastContentSize ?? inputPanelNode.textInputNode?.textView.contentSize ?? CGSize.zero,
                                       insets: inputPanelNode.textInputNode?.textContainerInset ?? UIEdgeInsets.zero,
                                       minimalInputHeight: inputPanelNode.minimalInputHeight(),
                                       emojiFrame: viewNode.emojiLastFrame ?? CGRect.zero,
                                       emojiCharacter: viewNode.emojiLastCharacter ?? Character(""))
        
        self.accessoryPanelFrame = viewNode.accessoryPanelLastFrame ?? CGRect.zero
        
        let bigEmojiSize = chatMessageImageNode.bounds.size
        var smallEmojiFrame = inputPanelNode.textInputNode?.view.convert(self.inputTextContainerNode.emojiFrame, to: viewNode.view) ?? CGRect.zero
        var scaleFactor = smallEmojiFrame.width / bigEmojiSize.width
        smallEmojiFrame.size.height = bigEmojiSize.height * scaleFactor
        
        scaleFactor = (self.inputTextContainerNode.minimalInputHeight - self.inputTextContainerNode.insets.top - self.inputTextContainerNode.insets.bottom) / smallEmojiFrame.height
        smallEmojiFrame.size.width *= scaleFactor
        smallEmojiFrame.size.height *= scaleFactor
        let emojiWidth = smallEmojiFrame.width
        let emojiHeight = smallEmojiFrame.height
        
        scaleFactor = 1.6
        if let chatMessageNode = chatMessageNode as? ChatMessageAnimatedStickerItemNode,
           let _ = chatMessageNode.animationNode as? AnimatedStickerNode {
            scaleFactor = 1.1
        }
        smallEmojiFrame.size.width *= scaleFactor
        smallEmojiFrame.size.height *= scaleFactor
        smallEmojiFrame.origin.x -= ((smallEmojiFrame.width - emojiWidth) / 4.0)
        smallEmojiFrame.origin.y -= ((smallEmojiFrame.height - emojiHeight) / 4.0)
        
        smallEmojiFrame.origin.x -= 1.0 // some dark magick
        
        self.animatingNode = (startFrame: smallEmojiFrame,
                              endFrame: chatMessageImageNode.view.convert(chatMessageImageNode.view.bounds, to: viewNode.view))
        
        let contentConvertedFrame = chatMessageContentNode.view.convert(chatMessageContentNode.view.bounds, to: viewNode.view)
        let imageConvertedFrame = chatMessageImageNode.view.convert(chatMessageImageNode.view.bounds, to: viewNode.view)
        let offsetX = self.animatingNode.startFrame.origin.x - imageConvertedFrame.origin.x
        let offsetY = self.animatingNode.startFrame.origin.y - imageConvertedFrame.origin.y
        self.chatMessageContentNode = (originalFrame: chatMessageContentNode.frame,
                                       convertedFrameStart: contentConvertedFrame.offsetBy(dx: offsetX, dy: offsetY),
                                       convertedFrameEnd: contentConvertedFrame,
                                       originalSubnodeIndex: chatMessageContentNode.supernode!.subnodes!.firstIndex(of: chatMessageContentNode)!,
                                       originalTransform: chatMessageContentNode.transform)
        
        self.chatMessageImageNode = (originalFrame: chatMessageImageNode.frame,
                                     convertedFrame: CGRect(origin: chatMessageImageNode.frame.origin, size: self.animatingNode.startFrame.size),
                                     originalSubnodeIndex: chatMessageImageNode.supernode!.subnodes!.firstIndex(of: chatMessageImageNode)!,
                                     originalTransform: chatMessageImageNode.transform)
        
        self.chatMessageStatusNode = (originalFrame: chatMessageStatusNode.frame,
                                      convertedFrame: CGRect(origin: CGPoint(x: self.chatMessageImageNode.convertedFrame.maxX - chatMessageStatusNode.bounds.width / 2.0,
                                                                             y: self.chatMessageImageNode.convertedFrame.maxY - chatMessageStatusNode.bounds.height / 2.0),
                                                                  size: chatMessageStatusNode.bounds.size),
                                      originalAlpha: chatMessageStatusNode.alpha,
                                      originalSubnodeIndex: chatMessageStatusNode.supernode!.subnodes!.firstIndex(of: chatMessageStatusNode)!)
        
        if let replyInfoNode = replyInfoNode, let replyBackgroundNode = replyBackgroundNode {
            let lineNodeFrame = viewNode.lastReplyLineNodeFrame ?? CGRect.zero
            
            self.replyInfoNode = (originalFrame: replyInfoNode.frame,
                                  convertedFrameStart: CGRect(origin: lineNodeFrame.origin, size: replyInfoNode.frame.size),
                                  convertedFrameEnd: replyInfoNode.view.convert(replyInfoNode.view.bounds, to: viewNode.view),
                                  originalSubnodeIndex: replyInfoNode.supernode!.subnodes!.firstIndex(of: replyInfoNode)!)
            
            self.replyBackgroundNode = (originalFrame: replyBackgroundNode.frame,
                                        convertedFrameStart: self.replyInfoNode.convertedFrameStart,
                                        convertedFrameEnd: self.replyInfoNode.convertedFrameEnd,
                                        originalSubnodeIndex: replyBackgroundNode.supernode!.subnodes!.firstIndex(of: replyBackgroundNode)!)
        } else {
            self.replyInfoNode = (originalFrame: CGRect.zero,
                                  convertedFrameStart: CGRect.zero,
                                  convertedFrameEnd: CGRect.zero,
                                  originalSubnodeIndex: 0)
            
            self.replyBackgroundNode = (originalFrame: CGRect.zero,
                                        convertedFrameStart: CGRect.zero,
                                        convertedFrameEnd: CGRect.zero,
                                  originalSubnodeIndex: 0)
        }
    }
}

public class ChatControllerAnimationsEmoji {
    private init() {}
    
    static func animateEmoji(chatControllerNode viewNode: ChatControllerNode,
                             inputPanelNode: ChatTextInputPanelNode,
                             chatMessageNode: ChatMessageSticker,
                             shouldAnimateScrollView: Bool,
                             completion: (() -> Void)?) {
        let listNode = viewNode.historyNode
        let listContainerNode = viewNode.historyNodeContainer
        let inputTextContainerNode = inputPanelNode.textInputContainer
        let chatMessageContentNode = chatMessageNode.contextSourceNode.contentNode
        let chatMessagePlaceholderNode = chatMessageNode.placeholderNode
        let chatMessageImageNode = chatMessageNode.imageNode
        let chatMessageStatusNode = chatMessageNode.dateAndStatusNode
        let replyInfoNode = chatMessageNode.replyInfoNode
        let replyBackgroundNode = chatMessageNode.replyBackgroundNode
                
        if let chatMessageAnimatedNode = chatMessageNode as? ChatMessageAnimatedStickerItemNode {
            guard let _ = chatMessageAnimatedNode.animationNode as? AnimatedStickerNode else {
                // if it is not normal animated sticker, then return
                completion?()
                return
            }
        }
        
        // Node Hierarhy
        //
        // |- viewNode
        //   |- inputPanelNode
        //     |- inputTextContainerNode
        //   |- chatMessageNode: ChatMessageAnimatedStickerItemNode
        //     |- containerNode: ContextControllerSourceNode
        //       |- contextSourceNode: ContextExtractedContentContainingNode
        //         |- contentNode: ContextExtractedContentNode
        //           |- chatMessagePlaceholderNode (placeholderNode: StickerShimmerEffectNode)
        //           |- chatMessageImageNode (imageNode: TransformImageNode)
        //           |- chatMessageStatusNode (dateAndStatusNode: ChatMessageDateAndStatusNode)
        //     |- replyInfoNode (replyInfoNode: ChatMessageReplyInfoNode?)
        
        let config = Config(viewNode: viewNode,
                            inputPanelNode: inputPanelNode,
                            inputTextContainerNode: inputTextContainerNode,
                            chatMessageNode: chatMessageNode,
                            chatMessageContentNode: chatMessageContentNode,
                            chatMessagePlaceholderNode: chatMessagePlaceholderNode,
                            chatMessageImageNode: chatMessageImageNode,
                            chatMessageStatusNode: chatMessageStatusNode,
                            replyInfoNode: replyInfoNode,
                            replyBackgroundNode: replyBackgroundNode)
        
        let settingsManager = ChatAnimationSettingsManager()
        let settings = settingsManager.getSettings(for: ChatAnimationType.emoji) as! ChatAnimationSettingsEmoji
        
        chatMessageNode.isUserInteractionEnabled = false
        listContainerNode.isUserInteractionEnabled = false
        inputPanelNode.actionButtons.isUserInteractionEnabled = false
        inputPanelNode.attachmentButton.isUserInteractionEnabled = false
        inputPanelNode.accessoryItemButtons.forEach({ $0.1.isUserInteractionEnabled = false })
        
        listNode.displaysAsynchronously = false
        listNode.shouldAnimateSizeChanges = false
        listContainerNode.displaysAsynchronously = false
        listContainerNode.shouldAnimateSizeChanges = false
        chatMessageNode.displaysAsynchronously = false
        chatMessageNode.shouldAnimateSizeChanges = false
        chatMessageContentNode.displaysAsynchronously = false
        chatMessageContentNode.shouldAnimateSizeChanges = false
        chatMessagePlaceholderNode?.displaysAsynchronously = false
        chatMessagePlaceholderNode?.shouldAnimateSizeChanges = false
        chatMessageImageNode.displaysAsynchronously = false
        chatMessageImageNode.shouldAnimateSizeChanges = false
        chatMessageStatusNode.displaysAsynchronously = false
        chatMessageStatusNode.shouldAnimateSizeChanges = false
                
        let inputPlaceholderTransitionNode = ASDisplayNode()
        inputPlaceholderTransitionNode.displaysAsynchronously = false
        inputPlaceholderTransitionNode.shouldAnimateSizeChanges = false
        inputPlaceholderTransitionNode.isUserInteractionEnabled = false
        
        let chatMessageContentNodeSupernode: ASDisplayNode
        let replyInfoNodeSupernode: ASDisplayNode?
        let replyBackgroundNodeSupernode: ASDisplayNode?
        
        // Prepare all nodes to be places and look exactly like input text view
        do {
            chatMessageContentNodeSupernode = chatMessageContentNode.supernode!
            replyInfoNodeSupernode = replyInfoNode?.supernode
            replyBackgroundNodeSupernode = replyBackgroundNode?.supernode
            
            chatMessageContentNode.removeFromSupernode()
            viewNode.insertSubnode(chatMessageContentNode, aboveSubnode: viewNode.inputContextPanelContainer)
            
            if let replyInfoNode = replyInfoNode, let replyBackgroundNode = replyBackgroundNode {
                replyInfoNode.removeFromSupernode()
                viewNode.insertSubnode(replyInfoNode, aboveSubnode: listContainerNode)
                
                replyBackgroundNode.removeFromSupernode()
                viewNode.insertSubnode(replyBackgroundNode, belowSubnode: replyInfoNode)
            }
            
            let textNode = inputPanelNode.textInputNode!
            inputPlaceholderTransitionNode.backgroundColor = inputTextContainerNode.backgroundColor
            inputPlaceholderTransitionNode.frame = textNode.view.convert(textNode.view.bounds, to: viewNode.view)
            viewNode.insertSubnode(inputPlaceholderTransitionNode, aboveSubnode: viewNode.inputContextPanelContainer)
        }

        // Preparation is done, it's time to go bananaz!!! (... and draw some animations)
        let animationDuration = settings.duration.rawValue
        
        let listContainerNodeOriginalFrame = listContainerNode.frame
        let listNodeOriginalFrame = listNode.frame
        
        if let chatMessageNode = chatMessageNode as? ChatMessageAnimatedStickerItemNode,
           let animationNode = chatMessageNode.animationNode as? AnimatedStickerNode {
            chatMessageNode.imageNode.alpha = 1.0
            animationNode.alpha = 0.0
            chatMessagePlaceholderNode?.alpha = 0.0
        }
                
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak listContainerNode,
                                            weak inputPanelNode,
                                            weak listNode,
                                            weak chatMessageNode,
                                            weak chatMessageContentNode,
                                            weak chatMessagePlaceholderNode,
                                            weak chatMessageImageNode,
                                            weak chatMessageStatusNode,
                                            weak inputPlaceholderTransitionNode,
                                            weak chatMessageContentNodeSupernode,
                                            weak replyInfoNode,
                                            weak replyInfoNodeSupernode,
                                            weak replyBackgroundNode,
                                            weak replyBackgroundNodeSupernode] in
            listNode?.layer.removeAllAnimations()
            listContainerNode?.layer.removeAllAnimations()
            
            if let chatMessageContentNode = chatMessageContentNode, let chatMessageContentNodeSupernode = chatMessageContentNodeSupernode {
                chatMessageContentNode.removeFromSupernode()
                chatMessageContentNodeSupernode.insertSubnode(chatMessageContentNode, at: config.chatMessageContentNode.originalSubnodeIndex)
                chatMessageContentNode.frame = config.chatMessageContentNode.originalFrame
                chatMessageContentNode.transform = config.chatMessageContentNode.originalTransform
                chatMessageContentNode.layer.removeAnimation(forKey: ChatControllerAnimations.animationKey)
            }
            
            if let chatMessageImageNode = chatMessageImageNode {
                chatMessageImageNode.frame = config.chatMessageImageNode.originalFrame
                chatMessageImageNode.transform = config.chatMessageImageNode.originalTransform
                chatMessageImageNode.layer.removeAnimation(forKey: ChatControllerAnimations.animationKey)
            }
            
            if let chatMessageStatusNode = chatMessageStatusNode {
                chatMessageStatusNode.alpha = config.chatMessageStatusNode.originalAlpha
                chatMessageStatusNode.frame = config.chatMessageStatusNode.originalFrame
                chatMessageStatusNode.layer.removeAnimation(forKey: ChatControllerAnimations.animationKey)
            }
            
            if let replyBackgroundNode = replyBackgroundNode, let replyBackgroundNodeSupernode = replyBackgroundNodeSupernode {
                replyBackgroundNode.removeFromSupernode()
                replyBackgroundNodeSupernode.insertSubnode(replyBackgroundNode, at: config.replyBackgroundNode.originalSubnodeIndex)
                replyBackgroundNode.frame = config.replyBackgroundNode.originalFrame
                replyBackgroundNode.layer.removeAnimation(forKey: ChatControllerAnimations.animationKey)
            }
            
            if let replyInfoNode = replyInfoNode, let replyInfoNodeSupernode = replyInfoNodeSupernode {
                replyInfoNode.removeFromSupernode()
                replyInfoNodeSupernode.insertSubnode(replyInfoNode, at: config.replyInfoNode.originalSubnodeIndex)
                replyInfoNode.frame = config.replyInfoNode.originalFrame
                replyInfoNode.layer.removeAnimation(forKey: ChatControllerAnimations.animationKey)
            }
                        
            inputPlaceholderTransitionNode?.removeFromSupernode()
            
            if shouldAnimateScrollView {
                listContainerNode?.frame = listContainerNodeOriginalFrame
                listNode?.frame = listNodeOriginalFrame

                listContainerNode?.layer.removeAnimation(forKey: ChatControllerAnimations.animationKey)
                listNode?.layer.removeAnimation(forKey: ChatControllerAnimations.animationKey)
            }
            
            listNode?.layer.removeAllAnimations()
            listContainerNode?.layer.removeAllAnimations()
            
            if let chatMessageNode = chatMessageNode as? ChatMessageAnimatedStickerItemNode,
               let animationNode = chatMessageNode.animationNode as? AnimatedStickerNode {
                chatMessageNode.imageNode.alpha = 0.0
                animationNode.alpha = 1.0
                animationNode.layer.removeAnimation(forKey: ChatControllerAnimations.animationKey)
                chatMessageNode.updateVisibility()
                chatMessageNode.imitateTap()
            }
            
            chatMessageNode?.isUserInteractionEnabled = true
            listContainerNode?.isUserInteractionEnabled = true
            inputPanelNode?.actionButtons.isUserInteractionEnabled = true
            inputPanelNode?.attachmentButton.isUserInteractionEnabled = true
            inputPanelNode?.accessoryItemButtons.forEach({ $0.1.isUserInteractionEnabled = true })
            
            // listNode?.displaysAsynchronously = true
            listNode?.shouldAnimateSizeChanges = true
            listContainerNode?.displaysAsynchronously = true
            listContainerNode?.shouldAnimateSizeChanges = true
            chatMessageNode?.displaysAsynchronously = true
            chatMessageNode?.shouldAnimateSizeChanges = true
            chatMessageContentNode?.displaysAsynchronously = true
            chatMessageContentNode?.shouldAnimateSizeChanges = true
            chatMessagePlaceholderNode?.displaysAsynchronously = true
            chatMessagePlaceholderNode?.shouldAnimateSizeChanges = true
            chatMessageImageNode?.displaysAsynchronously = true
            chatMessageImageNode?.shouldAnimateSizeChanges = true
            chatMessageStatusNode?.displaysAsynchronously = true
            chatMessageStatusNode?.shouldAnimateSizeChanges = true
            
            ChatControllerAnimations.animationsCounter -= 1
            if ChatControllerAnimations.animationsCounter == 0 {
                ChatControllerAnimations.isAnimating = false
            }
            
            completion?()
        }
        
        do { // chatMessageContentNode
            let fromFrame = config.chatMessageContentNode.convertedFrameStart
            let toFrame = config.chatMessageContentNode.convertedFrameEnd
            
            let fromTranslateX = -(config.chatMessageImageNode.originalFrame.width - config.chatMessageImageNode.convertedFrame.width) / 2.0
            let toTranslateX = config.chatMessageImageNode.originalFrame.width / 2.0
            
            let fromTranslateY = -(config.chatMessageImageNode.originalFrame.height - config.chatMessageImageNode.convertedFrame.height) / 2.0
            let toTranslateY = -config.chatMessageImageNode.originalFrame.height / 2.0

            let animations = [
                ChatControllerAnimations.setupRepositionXAnimation(layer: chatMessageContentNode.layer,
                                                                   fromPosition: fromFrame.position.x,
                                                                   toPosition: toFrame.position.x - toTranslateX,
                                                                   duration: animationDuration,
                                                                   timingFunction: settings.xPositionFunc),
                ChatControllerAnimations.setupRepositionYAnimation(layer: chatMessageContentNode.layer,
                                                                   fromPosition: fromFrame.position.y,
                                                                   toPosition: toFrame.position.y - toTranslateY,
                                                                   duration: animationDuration,
                                                                   timingFunction: settings.yPositionFunc),
                                ChatControllerAnimations.setupAnimation(keyPath: "transform.translation.x",
                                                                        fromValue: fromTranslateX,
                                                                        toValue: toTranslateX,
                                                                        duration: animationDuration,
                                                                        timingFunction: settings.emojiScaleFunc),
                                ChatControllerAnimations.setupAnimation(keyPath: "transform.translation.y",
                                                                        fromValue: fromTranslateY,
                                                                        toValue: toTranslateY,
                                                                        duration: animationDuration,
                                                                        timingFunction: settings.emojiScaleFunc)
            ]
            ChatControllerAnimations.addAnimations(chatMessageContentNode.layer, animations, duration: animationDuration)
        }
        
        do { // chatMessageImageNode
            let fromFrame = config.chatMessageImageNode.convertedFrame
            let toFrame = config.chatMessageImageNode.originalFrame
            
            let scaleFactor = fromFrame.width / toFrame.width
            
            let fromScale = scaleFactor
            let toScale: CGFloat = 1.0

            let animations = [
                ChatControllerAnimations.setupAnimation(keyPath: "transform.scale",
                                                        fromValue: fromScale,
                                                        toValue: toScale,
                                                        duration: animationDuration,
                                                        timingFunction: settings.emojiScaleFunc),
                ChatControllerAnimations.setupAnimation(keyPath: "opacity",
                                                        fromValue: 1.0,
                                                        toValue: 1.0,
                                                        duration: animationDuration,
                                                        isRemovedOnCompletion: true)
            ]
            ChatControllerAnimations.addAnimations(chatMessageImageNode.layer, animations, duration: animationDuration)
        }
        
      
        if let chatMessageAnimatedNode = chatMessageNode as? ChatMessageAnimatedStickerItemNode,
           let animationNode = chatMessageAnimatedNode.animationNode {
            do { // animationNode
                let animations = [
                    ChatControllerAnimations.setupAnimation(keyPath: "opacity",
                                                            fromValue: 0.0,
                                                            toValue: 0.0,
                                                            duration: animationDuration,
                                                            isRemovedOnCompletion: true)
                ]
                ChatControllerAnimations.addAnimations(animationNode.layer, animations, duration: animationDuration)
            }
        }
        
        
        do { // chatMessageStatusNode
            let fromFrame = config.chatMessageStatusNode.convertedFrame
            let toFrame = config.chatMessageStatusNode.originalFrame

            let fromOpacity: CGFloat = 0.0
            let toOpacity = config.chatMessageStatusNode.originalAlpha

            let animations = [
                ChatControllerAnimations.setupRepositionXAnimation(layer: chatMessageStatusNode.layer,
                                                                   fromPosition: fromFrame.position.x,
                                                                   toPosition: toFrame.position.x,
                                                                   duration: animationDuration,
                                                                   timingFunction: settings.emojiScaleFunc),
                ChatControllerAnimations.setupRepositionYAnimation(layer: chatMessageStatusNode.layer,
                                                                   fromPosition: fromFrame.position.y,
                                                                   toPosition: toFrame.position.y,
                                                                   duration: animationDuration,
                                                                   timingFunction: settings.emojiScaleFunc),
                ChatControllerAnimations.setupAnimation(keyPath: "opacity",
                                                        fromValue: fromOpacity,
                                                        toValue: toOpacity,
                                                        duration: animationDuration,
                                                        timingFunction: settings.timeAppearsFunc)
            ]
            ChatControllerAnimations.addAnimations(chatMessageStatusNode.layer, animations, duration: animationDuration)
        }
        
        do { // inputPlaceholderTransitionNode
            let fromOpacity: CGFloat = 1.0
            let toOpacity = 0.0

            let animations = [
                ChatControllerAnimations.setupAnimation(keyPath: "opacity",
                                                        fromValue: fromOpacity,
                                                        toValue: toOpacity,
                                                        duration: 0.5)
            ]
            ChatControllerAnimations.addAnimations(inputPlaceholderTransitionNode.layer, animations, duration: animationDuration)
        }
        
        // replyInfoNode
        if let replyInfoNode = replyInfoNode {
            let fromFrame = config.replyInfoNode.convertedFrameStart
            let toFrame = config.replyInfoNode.convertedFrameEnd

            let animations = [
                ChatControllerAnimations.setupRepositionXAnimation(layer: replyInfoNode.layer,
                                                                   fromPosition: fromFrame.position.x,
                                                                   toPosition: toFrame.position.x,
                                                                   duration: animationDuration,
                                                                   timingFunction: settings.xPositionFunc),
                ChatControllerAnimations.setupRepositionYAnimation(layer: replyInfoNode.layer,
                                                                   fromPosition: fromFrame.position.y,
                                                                   toPosition: toFrame.position.y,
                                                                   duration: animationDuration,
                                                                   timingFunction: settings.yPositionFunc)
            ]
            ChatControllerAnimations.addAnimations(replyInfoNode.layer, animations, duration: animationDuration)
        }
        
        // replyBackgroundNode
        if let replyBackgroundNode = replyBackgroundNode {
            let fromFrame = config.replyBackgroundNode.convertedFrameStart
            let toFrame = config.replyBackgroundNode.convertedFrameEnd

            let animations = [
                ChatControllerAnimations.setupRepositionXAnimation(layer: replyBackgroundNode.layer,
                                                                   fromPosition: fromFrame.position.x,
                                                                   toPosition: toFrame.position.x,
                                                                   duration: animationDuration,
                                                                   timingFunction: settings.xPositionFunc),
                ChatControllerAnimations.setupRepositionYAnimation(layer: replyBackgroundNode.layer,
                                                                   fromPosition: fromFrame.position.y,
                                                                   toPosition: toFrame.position.y,
                                                                   duration: animationDuration,
                                                                   timingFunction: settings.yPositionFunc)
            ]
            ChatControllerAnimations.addAnimations(replyBackgroundNode.layer, animations, duration: animationDuration)
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
                    ChatControllerAnimations.setupRepositionYAnimation(layer: listContainerNode.layer,
                                                                       fromPosition: fromFrame.position.y,
                                                                       toPosition: toFrame.position.y - toTranslateY,
                                                                       duration: animationDuration,
                                                                       timingFunction: settings.yPositionFunc),
                    ChatControllerAnimations.setupAnimation(keyPath: "transform.translation.y",
                                                            fromValue: fromTranslateY,
                                                            toValue: toTranslateY,
                                                            duration: animationDuration,
                                                            timingFunction: settings.emojiScaleFunc),
                ]
                listNode.layer.removeAllAnimations()
                listContainerNode.layer.removeAllAnimations()
                ChatControllerAnimations.addAnimations(listContainerNode.layer, animations, duration: animationDuration)
            }
        }

        ChatControllerAnimations.isAnimating = true
        ChatControllerAnimations.animationsCounter += 1

        CATransaction.commit()
    }
}
