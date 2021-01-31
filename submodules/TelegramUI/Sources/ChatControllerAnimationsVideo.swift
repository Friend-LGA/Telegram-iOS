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
    
    let videoView: (originalFrame: CGRect,
                    convertedStartFrame: CGRect,
                    convertedEndFrame: CGRect)
    
    init(viewNode: ChatControllerNode,
         inputPanelNode: ChatTextInputPanelNode,
         inputTextContainerNode: ASDisplayNode,
         chatMessageNode: ASDisplayNode,
         interactiveVideoNode: ASDisplayNode,
         videoView: UIView) {
        self.inputTextContainerNode = (convertedFrame: viewNode.textInputLastFrame ?? inputTextContainerNode.view.convert(inputTextContainerNode.view.bounds, to: viewNode.view),
                                       contentOffset: viewNode.textInputLastContentOffset ?? inputPanelNode.textInputNode?.textView.contentOffset ?? CGPoint.zero,
                                       contentSize: viewNode.textInputLastContentSize ?? inputPanelNode.textInputNode?.textView.contentSize ?? CGSize.zero,
                                       insets: inputPanelNode.textInputNode?.textContainerInset ?? UIEdgeInsets.zero,
                                       minimalInputHeight: inputPanelNode.minimalInputHeight())
        
        self.accessoryPanelFrame = viewNode.accessoryPanelLastFrame ?? CGRect.zero
        
        let convertedFrame = chatMessageNode.view.convert(chatMessageNode.view.bounds, to: viewNode.view)
        self.animatingNode = (startFrame: convertedFrame.offsetBy(dx: CGFloat.zero, dy: chatMessageNode.bounds.height),
                              endFrame: convertedFrame)
        
        let endFrame = interactiveVideoNode.view.convert(interactiveVideoNode.view.bounds, to: viewNode.view)
        let keyWindow = UIApplication.shared.keyWindow!
        let insets: CGFloat = 0.0 // endFrame.width * 0.05
        self.videoView = (originalFrame: videoView.frame,
                          convertedStartFrame: keyWindow.convert(videoView.frame, to: viewNode.view),
                          convertedEndFrame: CGRect(x: endFrame.origin.x - insets,
                                                    y: endFrame.origin.y - insets,
                                                    width: endFrame.width + insets * 2.0,
                                                    height: endFrame.height + insets * 2.0))
    }
}

public class ChatControllerAnimationsVideo {
    private init() {}
    
    static func animateVideo(chatControllerNode viewNode: ChatControllerNode,
                             inputPanelNode: ChatTextInputPanelNode,
                             chatMessageNode: ChatMessageInstantVideoItemNode,
                             shouldAnimateScrollView: Bool,
                             presentationData: PresentationData,
                             completion: (() -> Void)?) {
        let listNode = viewNode.historyNode
        let listContainerNode = viewNode.historyNodeContainer
        let inputTextContainerNode = inputPanelNode.textInputContainer
        
        guard let videoView = ChatControllerAnimations.videoView else {
            completion?()
            return
        }
        
        let interactiveVideoNode = chatMessageNode.interactiveVideoNode
        
        let config = Config(viewNode: viewNode,
                            inputPanelNode: inputPanelNode,
                            inputTextContainerNode: inputTextContainerNode,
                            chatMessageNode: chatMessageNode,
                            interactiveVideoNode: interactiveVideoNode,
                            videoView: videoView)
        
        let settingsManager = ChatAnimationSettingsManager()
        let settings = settingsManager.getSettings(for: ChatAnimationType.video) as! ChatAnimationSettingsCommon
        
        viewNode.view.addSubview(videoView)
        
        interactiveVideoNode.alpha = 0.0
        
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
        
        // Preparation is done, it's time to go bananaz!!! (... and draw some animations)
        let animationDuration = settings.duration.rawValue
        
        let listContainerNodeOriginalFrame = listContainerNode.frame
        let listNodeOriginalFrame = listNode.frame
        
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak listContainerNode,
                                            weak inputPanelNode,
                                            weak listNode,
                                            weak chatMessageNode,
                                            weak videoView,
                                            weak interactiveVideoNode] in
            listNode?.layer.removeAllAnimations()
            listContainerNode?.layer.removeAllAnimations()
            
            if let interactiveVideoNode = interactiveVideoNode {
                interactiveVideoNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, removeOnCompletion: false, completion: { [weak videoView] _ in
                    if let videoView = videoView {
                        videoView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak videoView] _ in
                            videoView?.removeFromSuperview()
                        })
                    }
                })
            }
            
            ChatControllerAnimations.videoView = nil
            
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
        
        do { // videoView
            let fromFrame = config.videoView.convertedStartFrame
            let toFrame = config.videoView.convertedEndFrame

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
            ]
            ChatControllerAnimations.addAnimations(videoView.layer, animations, duration: animationDuration)
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
