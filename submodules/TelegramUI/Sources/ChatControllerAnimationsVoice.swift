import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences

private extension CGRect {
    func toBounds() -> CGRect {
        return CGRect(origin: CGPoint.zero, size: self.size)
    }
    
    var position: CGPoint {
        return CGPoint(x: self.midX, y: self.midY)
    }
}

private struct Config {
    let inputTextContainerNode: (convertedFrame: CGRect,
                                 contentOffset: CGPoint,
                                 contentSize: CGSize,
                                 insets: UIEdgeInsets,
                                 minimalInputHeight: CGFloat)
    
    let accessoryPanelFrame: CGRect
    
    let animatingNode: (startFrame: CGRect,
                        endFrame: CGRect)
    
    let audioBlob: (originalFrame: CGRect,
                    convertedStartFrame: CGRect,
                    convertedEndFrame: CGRect)
    
    init(viewNode: ChatControllerNode,
         inputPanelNode: ChatTextInputPanelNode,
         inputTextContainerNode: ASDisplayNode,
         chatMessageNode: ASDisplayNode,
         backgroundNode: ASDisplayNode,
         audioBlob: UIView,
         audioBlobFrame: CGRect) {
        self.inputTextContainerNode = (convertedFrame: viewNode.textInputLastFrame ?? inputTextContainerNode.view.convert(inputTextContainerNode.view.bounds, to: viewNode.view),
                                       contentOffset: viewNode.textInputLastContentOffset ?? inputPanelNode.textInputNode?.textView.contentOffset ?? CGPoint.zero,
                                       contentSize: viewNode.textInputLastContentSize ?? inputPanelNode.textInputNode?.textView.contentSize ?? CGSize.zero,
                                       insets: inputPanelNode.textInputNode?.textContainerInset ?? UIEdgeInsets.zero,
                                       minimalInputHeight: inputPanelNode.minimalInputHeight())
        
        self.accessoryPanelFrame = viewNode.accessoryPanelLastFrame ?? CGRect.zero
        
        let convertedFrame = chatMessageNode.view.convert(chatMessageNode.view.bounds, to: viewNode.view)
        self.animatingNode = (startFrame: convertedFrame.offsetBy(dx: CGFloat.zero, dy: chatMessageNode.bounds.height),
                             endFrame: convertedFrame)
        
        let endFrame = backgroundNode.view.convert(backgroundNode.view.bounds, to: audioBlob.superview!)
        let inset: CGFloat = 20.0
        self.audioBlob = (originalFrame: audioBlobFrame,
                          convertedStartFrame: audioBlobFrame,
                          convertedEndFrame: CGRect(origin: CGPoint(x: endFrame.origin.x - inset, y: endFrame.origin.y - inset),
                                                    size: CGSize(width: endFrame.height + inset * 2.0, height: endFrame.height + inset * 2.0)))
    }
}

public class ChatControllerAnimationsVoice {
    private init() {}
    
    static func animateVoice(chatControllerNode viewNode: ChatControllerNode,
                             inputPanelNode: ChatTextInputPanelNode,
                            chatMessageNode: ChatMessageBubbleItemNode,
                            chatMessageFileContentNode: ChatMessageFileBubbleContentNode,
                            shouldAnimateScrollView: Bool,
                            presentationData: PresentationData,
                            completion: (() -> Void)?) {
        let listNode = viewNode.historyNode
        let listContainerNode = viewNode.historyNodeContainer
        let inputTextContainerNode = inputPanelNode.textInputContainer
                
        guard let audioBlob = ChatControllerAnimations.voiceBlobView,
              let audioBlobFrame = ChatControllerAnimations.voiceBlobViewFrame else {
            completion?()
            return
        }
        
        let backgroundNode = chatMessageNode.backgroundNode
                
        let config = Config(viewNode: viewNode,
                            inputPanelNode: inputPanelNode,
                            inputTextContainerNode: inputTextContainerNode,
                            chatMessageNode: chatMessageNode,
                            backgroundNode: backgroundNode,
                            audioBlob: audioBlob,
                            audioBlobFrame: audioBlobFrame)
        
        let settingsManager = ChatAnimationSettingsManager()
        let settings = settingsManager.getSettings(for: ChatAnimationType.voice) as! ChatAnimationSettingsCommon
        
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
        
        let coverNode = ASDisplayNode()
        chatMessageNode.addSubnode(coverNode)
        let convertedBackgroundFrame = backgroundNode.view.convert(backgroundNode.view.bounds, to: chatMessageNode.view)
        let inset: CGFloat = 8.0
        coverNode.frame = CGRect(x: convertedBackgroundFrame.origin.x + inset,
                                       y: convertedBackgroundFrame.origin.y + inset,
                                       width: convertedBackgroundFrame.height - inset * 2.0,
                                       height: convertedBackgroundFrame.height - inset * 2.0)
        
        coverNode.backgroundColor = viewNode.chatPresentationInterfaceState.chatWallpaper.hasWallpaper ? presentationData.theme.chat.message.outgoing.bubble.withWallpaper.fill : presentationData.theme.chat.message.outgoing.bubble.withoutWallpaper.fill
        
        // Preparation is done, it's time to go bananaz!!! (... and draw some animations)
        let animationDuration = settings.duration.rawValue
        
        let listContainerNodeOriginalFrame = listContainerNode.frame
        let listNodeOriginalFrame = listNode.frame
        
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak listContainerNode,
                                            weak inputPanelNode,
                                            weak listNode,
                                            weak chatMessageNode,
                                            weak audioBlob,
                                            weak coverNode] in
            listNode?.layer.removeAllAnimations()
            listContainerNode?.layer.removeAllAnimations()
            
            if let audioBlob = audioBlob {
                audioBlob.removeFromSuperview()
                ChatControllerAnimations.voiceBlobView = nil
                ChatControllerAnimations.voiceBlobViewFrame = nil
            }
            
            if let coverNode = coverNode {
                coverNode.removeFromSupernode()
            }
            
            if shouldAnimateScrollView, let listContainerNode = listContainerNode, let listNode = listNode {
                listContainerNode.frame = listContainerNodeOriginalFrame
                listNode.frame = listNodeOriginalFrame
                
                listContainerNode.layer.removeAnimation(forKey: ChatControllerAnimations.animationKey)
                listNode.layer.removeAnimation(forKey: ChatControllerAnimations.animationKey)
            }
                        
            listNode?.layer.removeAllAnimations()
            listContainerNode?.layer.removeAllAnimations()
                        
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
            
            ChatControllerAnimations.animationsCounter -= 1
            if ChatControllerAnimations.animationsCounter == 0 {
                ChatControllerAnimations.isAnimating = false
            }
            
            completion?()
        }
                
        do { // audioBlob
            let fromFrame = config.audioBlob.convertedStartFrame
            let toFrame = config.audioBlob.convertedEndFrame

            let fromOpacity: CGFloat = 1.0
            let toOpacity: CGFloat = 0.0

            let animations: [CAAnimation] = [
                ChatControllerAnimations.setupResizeAnimation(fromSize: fromFrame.size,
                                                              toSize: toFrame.size,
                                                              duration: animationDuration,
                                                              timingFunction: settings.bubbleShapeFunc),
                ChatControllerAnimations.setupRepositionXAnimation(fromPosition: fromFrame.position.x,
                                                                   toPosition: toFrame.position.x,
                                                                   duration: animationDuration,
                                                                   timingFunction: settings.xPositionFunc),
                ChatControllerAnimations.setupRepositionYAnimation(fromPosition: fromFrame.position.y,
                                                                   toPosition: toFrame.position.y,
                                                                   duration: animationDuration,
                                                                   timingFunction: settings.yPositionFunc),
                ChatControllerAnimations.setupAnimation(keyPath: "opacity",
                                                        fromValue: fromOpacity,
                                                        toValue: toOpacity,
                                                        duration: animationDuration,
                                                        timingFunction: settings.timeAppearsFunc)
            ]
            ChatControllerAnimations.addAnimations(audioBlob.layer, animations, duration: animationDuration)
        }
        
        do { // coverNode
            let fromOpacity: CGFloat = 1.0
            let toOpacity: CGFloat = 0.0

            let animations: [CAAnimation] = [
                ChatControllerAnimations.setupAnimation(keyPath: "opacity",
                                                        fromValue: fromOpacity,
                                                        toValue: toOpacity,
                                                        duration: animationDuration,
                                                        timingFunction: settings.timeAppearsFunc)
            ]
            ChatControllerAnimations.addAnimations(coverNode.layer, animations, duration: animationDuration)
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
                
                let animations: [CAAnimation] = [
                    ChatControllerAnimations.setupRepositionYAnimation(fromPosition: fromFrame.position.y,
                                                                       toPosition: toFrame.position.y - toTranslateY,
                                                                       duration: animationDuration,
                                                                       timingFunction: settings.yPositionFunc),
                    ChatControllerAnimations.setupAnimation(keyPath: "transform.translation.y",
                                                            fromValue: fromTranslateY,
                                                            toValue: toTranslateY,
                                                            duration: animationDuration,
                                                            timingFunction: settings.bubbleShapeFunc),
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
