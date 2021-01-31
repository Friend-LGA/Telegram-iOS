import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import CoreImage
import TelegramPresentationData
import Compression
import TextFormat
import AccountContext
import MediaResources
import StickerResources
import ContextUI
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import Emoji
import Markdown
import ManagedAnimationNode
import SlotMachineAnimationNode
import UniversalMediaPlayer
import ShimmerEffect

private let nameFont = Font.medium(14.0)
private let inlineBotPrefixFont = Font.regular(14.0)
private let inlineBotNameFont = nameFont

protocol GenericAnimatedStickerNode: ASDisplayNode {
    func setOverlayColor(_ color: UIColor?, animated: Bool)
}

extension AnimatedStickerNode: GenericAnimatedStickerNode {
    
}

extension SlotMachineAnimationNode: GenericAnimatedStickerNode {
    
}

class ChatMessageShareButton: HighlightableButtonNode {
    private let backgroundNode: ASImageNode
    private let iconNode: ASImageNode
    
    private var theme: PresentationTheme?
    private var isReplies: Bool = false
    
    private var textNode: ImmediateTextNode?
    
    init() {
        self.backgroundNode = ASImageNode()
        self.iconNode = ASImageNode()
        
        super.init(pointerStyle: nil)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.iconNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(presentationData: ChatPresentationData, chatLocation: ChatLocation, subject: ChatControllerSubject?, message: Message, account: Account) -> CGSize {
        var isReplies = false
        var replyCount = 0
        if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
            for attribute in message.attributes {
                if let attribute = attribute as? ReplyThreadMessageAttribute {
                    replyCount = Int(attribute.count)
                    isReplies = true
                    break
                }
            }
        }
        if case let .replyThread(replyThreadMessage) = chatLocation, replyThreadMessage.effectiveTopId == message.id {
            replyCount = 0
            isReplies = false
        }
        
        if self.theme !== presentationData.theme.theme || self.isReplies != isReplies {
            self.theme = presentationData.theme.theme
            self.isReplies = isReplies
            
            let graphics = PresentationResourcesChat.additionalGraphics(presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper, bubbleCorners: presentationData.chatBubbleCorners)
            var updatedShareButtonBackground: UIImage?
            var updatedIconImage: UIImage?
            if case .pinnedMessages = subject {
                updatedShareButtonBackground = graphics.chatBubbleNavigateButtonImage
            } else if isReplies {
                updatedShareButtonBackground = PresentationResourcesChat.chatFreeCommentButtonBackground(presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                updatedIconImage = PresentationResourcesChat.chatFreeCommentButtonIcon(presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
            } else if message.id.peerId.isRepliesOrSavedMessages(accountPeerId: account.peerId) {
                updatedShareButtonBackground = graphics.chatBubbleNavigateButtonImage
            } else {
                updatedShareButtonBackground = graphics.chatBubbleShareButtonImage
            }
            self.backgroundNode.image = updatedShareButtonBackground
            self.iconNode.image = updatedIconImage
        }
        var size = CGSize(width: 30.0, height: 30.0)
        var offsetIcon = false
        if isReplies, replyCount > 0 {
            offsetIcon = true
            
            let textNode: ImmediateTextNode
            if let current = self.textNode {
                textNode = current
            } else {
                textNode = ImmediateTextNode()
                self.textNode = textNode
                self.addSubnode(textNode)
            }
            
            let textColor = bubbleVariableColor(variableColor: presentationData.theme.theme.chat.message.shareButtonForegroundColor, wallpaper: presentationData.theme.wallpaper)
            
            let countString: String
            if replyCount >= 1000 * 1000 {
                countString = "\(replyCount / 1000_000)M"
            } else if replyCount >= 1000 {
                countString = "\(replyCount / 1000)K"
            } else {
                countString = "\(replyCount)"
            }
            
            textNode.attributedText = NSAttributedString(string: countString, font: Font.regular(11.0), textColor: textColor)
            let textSize = textNode.updateLayout(CGSize(width: 100.0, height: 100.0))
            size.height += textSize.height - 1.0
            textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: size.height - textSize.height - 4.0), size: textSize)
        } else if let textNode = self.textNode {
            self.textNode = nil
            textNode.removeFromSupernode()
        }
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.width - image.size.width) / 2.0) - (offsetIcon ? 1.0 : 0.0)), size: image.size)
        }
        return size
    }
}

class ChatMessageAnimatedStickerItemNode: ChatMessageItemView, ChatMessageSticker {
    public let contextSourceNode: ContextExtractedContentContainingNode
    public let containerNode: ContextControllerSourceNode
    public let imageNode: TransformImageNode
    public private(set) var placeholderNode: StickerShimmerEffectNode?
    public private(set) var animationNode: GenericAnimatedStickerNode?
    private var didSetUpAnimationNode = false
    private var isPlaying = false
    private var animateGreeting = false
    private weak var greetingStickerParentNode: ASDisplayNode?
    private weak var greetingStickerListNode: ASDisplayNode?
    private var greetingCompletion: (() -> Void)?
    
    private var swipeToReplyNode: ChatMessageSwipeToReplyNode?
    private var swipeToReplyFeedback: HapticFeedback?
    
    private var selectionNode: ChatMessageSelectionNode?
    private var deliveryFailedNode: ChatMessageDeliveryFailedNode?
    private var shareButtonNode: ChatMessageShareButton?
    
    var telegramFile: TelegramMediaFile?
    var emojiFile: TelegramMediaFile?
    var telegramDice: TelegramMediaDice?
    private let disposable = MetaDisposable()
    
    private var forwardInfoNode: ChatMessageForwardInfoNode?
    private var forwardBackgroundNode: ASImageNode?
    
    private var viaBotNode: TextNode?
    public let dateAndStatusNode: ChatMessageDateAndStatusNode
    public private(set) var replyInfoNode: ChatMessageReplyInfoNode?
    public private(set) var replyBackgroundNode: ASImageNode?
    
    private var actionButtonsNode: ChatMessageActionButtonsNode?
    
    private var highlightedState: Bool = false
    
    private var haptic: EmojiHaptic?
    private var mediaPlayer: MediaPlayer?
    private let mediaStatusDisposable = MetaDisposable()
    
    private var currentSwipeToReplyTranslation: CGFloat = 0.0
    
    private var appliedForwardInfo: (Peer?, String?)?
    
    private var currentSwipeAction: ChatControllerInteractionSwipeAction?
    
    public func imitateTap() {
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        if let action = self.gestureRecognized(gesture: .tap, location: self.imageNode.frame.center, recognizer: recognizer, withHaptic: false) {
            switch action {
            case let .action(f):
                f()
            case let .optionalAction(f):
                f()
            case .openContextMenu:
                break
            }
        }
    }
    
    required init() {
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        self.imageNode = TransformImageNode()
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        
        self.placeholderNode = StickerShimmerEffectNode()
        self.placeholderNode?.isUserInteractionEnabled = false
        
        super.init(layerBacked: false)
        
        self.containerNode.shouldBegin = { [weak self] location in
            guard let strongSelf = self else {
                return false
            }
            if !strongSelf.imageNode.frame.contains(location) {
                return false
            }
            if let action = strongSelf.gestureRecognized(gesture: .tap, location: location, recognizer: nil) {
                if case .action = action {
                    return false
                }
            }
            if let action = strongSelf.gestureRecognized(gesture: .longTap, location: location, recognizer: nil) {
                switch action {
                case .action, .optionalAction:
                    return false
                case .openContextMenu:
                    return true
                }
            }
            return true
        }
        
        self.containerNode.activated = { [weak self] gesture, location in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            
            if let action = strongSelf.gestureRecognized(gesture: .longTap, location: location, recognizer: nil) {
                switch action {
                case .action, .optionalAction:
                    break
                case let .openContextMenu(tapMessage, selectAll, subFrame):
                    item.controllerInteraction.openMessageContextMenu(tapMessage, selectAll, strongSelf, subFrame, gesture)
                }
            }
        }
        
        var firstTime = true
        self.imageNode.imageUpdated = { [weak self] image in
            guard let strongSelf = self else {
                return
            }
            if image != nil {
                strongSelf.removePlaceholder(animated: !firstTime)
                if firstTime {
                    if ChatControllerAnimations.isAnimating {
                        strongSelf.animationNode?.alpha = 0.0
                        strongSelf.imageNode.alpha = 1.0
                    } else {
                        strongSelf.animationNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
            }
            firstTime = false
        }
                
        self.imageNode.displaysAsynchronously = false
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        self.contextSourceNode.contentNode.addSubnode(self.imageNode)
        
        if let placeholderNode = self.placeholderNode {
            self.contextSourceNode.contentNode.addSubnode(placeholderNode)
        }
        
        self.contextSourceNode.contentNode.addSubnode(self.dateAndStatusNode)
        
        self.dateAndStatusNode.openReactions = { [weak self] in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            item.controllerInteraction.openMessageReactions(item.message.id)
        }
    }
    
    deinit {
        self.disposable.dispose()
        self.mediaStatusDisposable.set(nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func removePlaceholder(animated: Bool) {
        if let placeholderNode = self.placeholderNode {
            self.placeholderNode = nil
            if !animated {
                placeholderNode.removeFromSupernode()
            } else {
                placeholderNode.alpha = 0.0
                placeholderNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak placeholderNode] _ in
                    placeholderNode?.removeFromSupernode()
                })
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] point in
            if let strongSelf = self {
                if let shareButtonNode = strongSelf.shareButtonNode, shareButtonNode.frame.contains(point) {
                    return .fail
                }
                
                if strongSelf.telegramFile == nil {
                    if let animationNode = strongSelf.animationNode, animationNode.frame.contains(point) {
                        return .waitForDoubleTap
                    }
                }
            }
            return .waitForSingleTap
        }
        recognizer.longTap = { [weak self] point, recognizer in
            guard let strongSelf = self else {
                return
            }
            //strongSelf.reactionRecognizer?.cancel()
            if let action = strongSelf.gestureRecognized(gesture: .longTap, location: point, recognizer: recognizer) {
                switch action {
                case let .action(f):
                    f()
                    recognizer.cancel()
                case let .optionalAction(f):
                    f()
                    recognizer.cancel()
                case .openContextMenu:
                    break
                }
            }
        }
        self.view.addGestureRecognizer(recognizer)
        
        let replyRecognizer = ChatSwipeToReplyRecognizer(target: self, action: #selector(self.swipeToReplyGesture(_:)))
        replyRecognizer.shouldBegin = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item {
                if strongSelf.selectionNode != nil {
                    return false
                }
                let action = item.controllerInteraction.canSetupReply(item.message)
                strongSelf.currentSwipeAction = action
                if case .none = action {
                    return false
                } else {
                    return true
                }
            }
            return false
        }
        self.view.addGestureRecognizer(replyRecognizer)
    }
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            let wasVisible = oldValue != .none
            let isVisible = self.visibility != .none
            
            if wasVisible != isVisible {
                self.visibilityStatus = isVisible
            }
        }
    }
    
    private var visibilityStatus: Bool = false {
        didSet {
            if self.visibilityStatus != oldValue {
                self.updateVisibility()
                self.haptic?.enabled = self.visibilityStatus
            }
        }
    }
    
    private func setupNode(item: ChatMessageItem) {
        guard self.animationNode == nil else {
            return
        }
        
        if let telegramDice = self.telegramDice {
            if telegramDice.emoji == "🎰" {
                let animationNode = SlotMachineAnimationNode()
                if !item.message.effectivelyIncoming(item.context.account.peerId) {
                    animationNode.success = { [weak self] onlyHaptic in
                        if let strongSelf = self, let item = strongSelf.item {
                            item.controllerInteraction.animateDiceSuccess(onlyHaptic)
                        }
                    }
                }
                self.animationNode = animationNode
            } else {
                let animationNode = ManagedDiceAnimationNode(context: item.context, emoji: telegramDice.emoji.strippedEmoji)
                if !item.message.effectivelyIncoming(item.context.account.peerId) {
                    animationNode.success = { [weak self] in
                        if let strongSelf = self, let item = strongSelf.item {
                            item.controllerInteraction.animateDiceSuccess(false)
                        }
                    }
                }
                self.animationNode = animationNode
            }
        } else {
            let animationNode: AnimatedStickerNode
            if let (node, parentNode, listNode, greetingCompletion)  = item.controllerInteraction.greetingStickerNode(), let greetingStickerNode = node as? AnimatedStickerNode {
                animationNode = greetingStickerNode
                self.imageNode.alpha = 0.0
                self.animateGreeting = true
                self.greetingStickerParentNode = parentNode
                self.greetingStickerListNode = listNode
                self.greetingCompletion = greetingCompletion
                self.dateAndStatusNode.alpha = 0.0
            } else {
                animationNode = AnimatedStickerNode()
                animationNode.started = { [weak self] in
                    if let strongSelf = self {
                        strongSelf.imageNode.alpha = 0.0
                        
                        if let item = strongSelf.item {
                            if let _ = strongSelf.emojiFile {
                                item.controllerInteraction.seenOneTimeAnimatedMedia.insert(item.message.id)
                            }
                        }
                    }
                }
            }
            
            self.animationNode = animationNode
        }
        
        if let animationNode = self.animationNode, !self.animateGreeting {
            if let placeholderNode = self.placeholderNode {
                self.contextSourceNode.contentNode.insertSubnode(animationNode, aboveSubnode: placeholderNode)
            } else {
                self.contextSourceNode.contentNode.insertSubnode(animationNode, aboveSubnode: self.imageNode)
            }
        }
    }
    
    override func setupItem(_ item: ChatMessageItem) {
        super.setupItem(item)
                
        for media in item.message.media {
            if let telegramFile = media as? TelegramMediaFile {
                if self.telegramFile?.id != telegramFile.id {
                    self.telegramFile = telegramFile
                    let dimensions = telegramFile.dimensions ?? PixelDimensions(width: 512, height: 512)
                    self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: item.context.account.postbox, file: telegramFile, small: false, size: dimensions.cgSize.aspectFitted(CGSize(width: 384.0, height: 384.0)), thumbnail: false))
                    self.updateVisibility()
                    self.disposable.set(freeMediaFileInteractiveFetched(account: item.context.account, fileReference: .message(message: MessageReference(item.message), media: telegramFile)).start())
                }
                break
            } else if let telegramDice = media as? TelegramMediaDice {
                self.telegramDice = telegramDice
            }
        }
        
        self.setupNode(item: item)

        if let telegramDice = self.telegramDice, let diceNode = self.animationNode as? SlotMachineAnimationNode {
            if let value = telegramDice.value {
                diceNode.setState(value == 0 ? .rolling : .value(value, true))
            } else {
                diceNode.setState(.rolling)
            }
        } else if let telegramDice = self.telegramDice, let diceNode = self.animationNode as? ManagedDiceAnimationNode {
            if let value = telegramDice.value {
                diceNode.setState(value == 0 ? .rolling : .value(value, true))
            } else {
                diceNode.setState(.rolling)
            }
        } else if self.telegramFile == nil && self.telegramDice == nil {
            let (emoji, fitz) = item.message.text.basicEmoji
            var emojiFile: TelegramMediaFile?
            
            emojiFile = item.associatedData.animatedEmojiStickers[emoji]?.first?.file
            if emojiFile == nil {
                emojiFile = item.associatedData.animatedEmojiStickers[emoji.strippedEmoji]?.first?.file
            }
            
            if self.emojiFile?.id != emojiFile?.id {
                self.emojiFile = emojiFile
                if let emojiFile = emojiFile {
                    let dimensions = emojiFile.dimensions ?? PixelDimensions(width: 512, height: 512)
                    var fitzModifier: EmojiFitzModifier?
                    if let fitz = fitz {
                        fitzModifier = EmojiFitzModifier(emoji: fitz)
                    }
                    self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: item.context.account.postbox, file: emojiFile, small: false, size: dimensions.cgSize.aspectFilled(CGSize(width: 384.0, height: 384.0)), fitzModifier: fitzModifier, thumbnail: false))
                    self.disposable.set(freeMediaFileInteractiveFetched(account: item.context.account, fileReference: .standalone(media: emojiFile)).start())
                }
                self.updateVisibility()
            }
        }
    }
    
    public func updateVisibility() {
        guard let item = self.item else {
            return
        }
        
        if let animationNode = self.animationNode as? AnimatedStickerNode {
            let isPlaying = self.visibilityStatus
            if self.isPlaying != isPlaying {
                self.isPlaying = isPlaying
                
                var alreadySeen = false
                if isPlaying, let _ = self.emojiFile {
                    if item.controllerInteraction.seenOneTimeAnimatedMedia.contains(item.message.id) {
                        alreadySeen = true
                    }
                }
                
                animationNode.visibility = isPlaying && !alreadySeen
                
                if self.didSetUpAnimationNode && alreadySeen {
                    if let emojiFile = self.emojiFile, emojiFile.resource is LocalFileReferenceMediaResource {
                    } else {
                        animationNode.seekTo(.start)
                    }
                }
                
                if self.isPlaying && !self.didSetUpAnimationNode {
                    self.didSetUpAnimationNode = true
                    
                    var file: TelegramMediaFile?
                    var playbackMode: AnimatedStickerPlaybackMode = .loop
                    var isEmoji = false
                    var fitzModifier: EmojiFitzModifier?
                    
                    if let telegramFile = self.telegramFile {
                        file = telegramFile
                        if !item.controllerInteraction.stickerSettings.loopAnimatedStickers {
                            playbackMode = .once
                        }
                    } else if let emojiFile = self.emojiFile {
                        isEmoji = true
                        file = emojiFile
                        if alreadySeen && emojiFile.resource is LocalFileReferenceMediaResource {
                            playbackMode = .still(.end)
                        } else {
                            playbackMode = .once
                        }
                        let (_, fitz) = item.message.text.basicEmoji
                        if let fitz = fitz {
                            fitzModifier = EmojiFitzModifier(emoji: fitz)
                        }
                    }
                    
                    if let file = file {
                        let dimensions = file.dimensions ?? PixelDimensions(width: 512, height: 512)
                        let fittedSize = isEmoji ? dimensions.cgSize.aspectFilled(CGSize(width: 384.0, height: 384.0)) : dimensions.cgSize.aspectFitted(CGSize(width: 384.0, height: 384.0))
                        
                        let pathPrefix = item.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.resource.id)
                        let mode: AnimatedStickerMode = .direct(cachePathPrefix: pathPrefix)
                        
                        animationNode.setup(source: AnimatedStickerResourceSource(account: item.context.account, resource: file.resource, fitzModifier: fitzModifier), width: Int(fittedSize.width), height: Int(fittedSize.height), playbackMode: playbackMode, mode: mode)
                    }
                }
            }
        }
    }
    
    override func updateStickerSettings() {
        self.updateVisibility()
    }
    
    
    private var absoluteRect: (CGRect, CGSize)?
    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)
        if !self.contextSourceNode.isExtractedToContextPreview {
            var rect = rect
            rect.origin.y = containerSize.height - rect.maxY + self.insets.top

            if let placeholderNode = self.placeholderNode {
                placeholderNode.updateAbsoluteRect(CGRect(origin: CGPoint(x: rect.minX + placeholderNode.frame.minX, y: rect.minY + placeholderNode.frame.minY), size: placeholderNode.frame.size), within: containerSize)
            }
        }
    }
    
    override func asyncLayout() -> (_ item: ChatMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: ChatMessageMerge, _ mergedBottom: ChatMessageMerge, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation, Bool) -> Void) {
        let displaySize = CGSize(width: 184.0, height: 184.0)
        let telegramFile = self.telegramFile
        let emojiFile = self.emojiFile
        let telegramDice = self.telegramDice
        let layoutConstants = self.layoutConstants
        let imageLayout = self.imageNode.asyncLayout()
        let makeDateAndStatusLayout = self.dateAndStatusNode.asyncLayout()
        let actionButtonsLayout = ChatMessageActionButtonsNode.asyncLayout(self.actionButtonsNode)
        
        let makeForwardInfoLayout = ChatMessageForwardInfoNode.asyncLayout(self.forwardInfoNode)
        let currentForwardBackgroundNode = self.forwardBackgroundNode
        
        let viaBotLayout = TextNode.asyncLayout(self.viaBotNode)
        let makeReplyInfoLayout = ChatMessageReplyInfoNode.asyncLayout(self.replyInfoNode)
        let currentReplyBackgroundNode = self.replyBackgroundNode
        let currentShareButtonNode = self.shareButtonNode
        let currentItem = self.item
        let currentForwardInfo = self.appliedForwardInfo
        
        return { item, params, mergedTop, mergedBottom, dateHeaderAtBottom in
            let layoutConstants = chatMessageItemLayoutConstants(layoutConstants, params: params, presentationData: item.presentationData)
            let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
            var imageSize: CGSize = CGSize(width: 200.0, height: 200.0)
            var isEmoji = false
            if let _ = telegramDice {
                imageSize = displaySize
            } else if let telegramFile = telegramFile {
                if let dimensions = telegramFile.dimensions {
                    imageSize = dimensions.cgSize.aspectFitted(displaySize)
                } else if let thumbnailSize = telegramFile.previewRepresentations.first?.dimensions {
                    imageSize = thumbnailSize.cgSize.aspectFitted(displaySize)
                }
            } else if let emojiFile = emojiFile {
                isEmoji = true
                
                let displaySize = CGSize(width: floor(displaySize.width * item.presentationData.animatedEmojiScale), height: floor(displaySize.height * item.presentationData.animatedEmojiScale))
                if let dimensions = emojiFile.dimensions {
                    imageSize = CGSize(width: displaySize.width * CGFloat(dimensions.width) / 512.0, height: displaySize.height * CGFloat(dimensions.height) / 512.0)
                } else if let thumbnailSize = emojiFile.previewRepresentations.first?.dimensions {
                    imageSize = thumbnailSize.cgSize.aspectFitted(displaySize)
                }
            }
            
            let avatarInset: CGFloat
            var hasAvatar = false
            
            switch item.chatLocation {
            case let .peer(peerId):
                if peerId != item.context.account.peerId {
                    if peerId.isGroupOrChannel && item.message.author != nil {
                        var isBroadcastChannel = false
                        if let peer = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                            isBroadcastChannel = true
                        }
                        
                        if !isBroadcastChannel {
                            hasAvatar = true
                        }
                    }
                } else if incoming {
                    hasAvatar = true
                }
            case let .replyThread(replyThreadMessage):
                if replyThreadMessage.messageId.peerId != item.context.account.peerId {
                    if replyThreadMessage.messageId.peerId.isGroupOrChannel && item.message.author != nil {
                        var isBroadcastChannel = false
                        if let peer = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                            isBroadcastChannel = true
                        }
                        
                        if replyThreadMessage.isChannelPost, replyThreadMessage.effectiveTopId == item.message.id {
                            isBroadcastChannel = true
                        }
                        
                        if !isBroadcastChannel {
                            hasAvatar = true
                        }
                    }
                } else if incoming {
                    hasAvatar = true
                }
            }
            
            if hasAvatar {
                avatarInset = layoutConstants.avatarDiameter
            } else {
                avatarInset = 0.0
            }
            
            let isFailed = item.content.firstMessage.effectivelyFailed(timestamp: item.context.account.network.getApproximateRemoteTimestamp())
            
            var needShareButton = false
            if case .pinnedMessages = item.associatedData.subject {
                needShareButton = true
            } else if isFailed || Namespaces.Message.allScheduled.contains(item.message.id.namespace) {
                needShareButton = false
            } else if item.message.id.peerId.isRepliesOrSavedMessages(accountPeerId: item.context.account.peerId) {
                for attribute in item.content.firstMessage.attributes {
                    if let _ = attribute as? SourceReferenceMessageAttribute {
                        needShareButton = true
                        break
                    }
                }
            } else if item.message.effectivelyIncoming(item.context.account.peerId) {
                if let peer = item.message.peers[item.message.id.peerId] {
                    if let channel = peer as? TelegramChannel {
                        if case .broadcast = channel.info {
                            needShareButton = true
                        }
                    }
                }
                if !needShareButton, let author = item.message.author as? TelegramUser, let _ = author.botInfo, !item.message.media.isEmpty {
                    needShareButton = true
                }
                if !needShareButton {
                    loop: for media in item.message.media {
                        if media is TelegramMediaGame || media is TelegramMediaInvoice {
                            needShareButton = true
                            break loop
                        } else if let media = media as? TelegramMediaWebpage, case .Loaded = media.content {
                            needShareButton = true
                            break loop
                        }
                    }
                } else {
                    loop: for media in item.message.media {
                        if media is TelegramMediaAction {
                            needShareButton = false
                            break loop
                        }
                    }
                }
            }
            
            var layoutInsets = UIEdgeInsets(top: mergedTop.merged ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, left: 0.0, bottom: mergedBottom.merged ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, right: 0.0)
            if dateHeaderAtBottom {
                layoutInsets.top += layoutConstants.timestampHeaderHeight
            }
            
            var deliveryFailedInset: CGFloat = 0.0
            if isFailed {
                deliveryFailedInset += 24.0
            }
            
            let displayLeftInset = params.leftInset + layoutConstants.bubble.edgeInset + avatarInset
            
            let imageInset: CGFloat = 10.0
            var innerImageSize = imageSize
            imageSize = CGSize(width: imageSize.width + imageInset * 2.0, height: imageSize.height + imageInset * 2.0)
            let imageFrame = CGRect(origin: CGPoint(x: 0.0 + (incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + avatarInset + layoutConstants.bubble.contentInsets.left) : (params.width - params.rightInset - imageSize.width - layoutConstants.bubble.edgeInset - layoutConstants.bubble.contentInsets.left - deliveryFailedInset)), y: 0.0), size: CGSize(width: imageSize.width, height: imageSize.height))
            if isEmoji {
                innerImageSize = imageSize
            }
            
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: innerImageSize, boundingSize: innerImageSize, intrinsicInsets: UIEdgeInsets(top: imageInset, left: imageInset, bottom: imageInset, right: imageInset))
            
            let imageApply = imageLayout(arguments)
            
            let statusType: ChatMessageDateAndStatusType
            if item.message.effectivelyIncoming(item.context.account.peerId) {
                statusType = .FreeIncoming
            } else {
                if isFailed {
                    statusType = .FreeOutgoing(.Failed)
                } else if item.message.flags.isSending && !item.message.isSentOrAcknowledged {
                    statusType = .FreeOutgoing(.Sending)
                } else {
                    statusType = .FreeOutgoing(.Sent(read: item.read))
                }
            }
            
            var edited = false
            var viewCount: Int? = nil
            var dateReplies = 0
            for attribute in item.message.attributes {
                if let _ = attribute as? EditedMessageAttribute, isEmoji {
                    edited = true
                } else if let attribute = attribute as? ViewCountMessageAttribute {
                    viewCount = attribute.count
                } else if let attribute = attribute as? ReplyThreadMessageAttribute, case .peer = item.chatLocation {
                    if let channel = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .group = channel.info {
                        dateReplies = Int(attribute.count)
                    }
                }
            }
            
            var dateReactions: [MessageReaction] = []
            var dateReactionCount = 0
            if let reactionsAttribute = mergedMessageReactions(attributes: item.message.attributes), !reactionsAttribute.reactions.isEmpty {
                for reaction in reactionsAttribute.reactions {
                    if reaction.isSelected {
                        dateReactions.insert(reaction, at: 0)
                    } else {
                        dateReactions.append(reaction)
                    }
                    dateReactionCount += Int(reaction.count)
                }
            }
            
            let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, format: .regular, reactionCount: dateReactionCount)
            
            var isReplyThread = false
            if case .replyThread = item.chatLocation {
                isReplyThread = true
            }
            
            let (dateAndStatusSize, dateAndStatusApply) = makeDateAndStatusLayout(item.context, item.presentationData, edited, viewCount, dateText, statusType, CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), dateReactions, dateReplies, item.message.tags.contains(.pinned) && !item.associatedData.isInPinnedListMode && !isReplyThread)
            
            var viaBotApply: (TextNodeLayout, () -> TextNode)?
            var replyInfoApply: (CGSize, () -> ChatMessageReplyInfoNode)?
            var updatedReplyBackgroundNode: ASImageNode?
            var replyBackgroundImage: UIImage?
            var replyMarkup: ReplyMarkupMessageAttribute?
            
            var ignoreForward = self.telegramDice == nil
            var ignoreSource = false
            
            let availableContentWidth = max(60.0, params.width - params.leftInset - params.rightInset - max(imageSize.width, 160.0) - 20.0 - layoutConstants.bubble.edgeInset * 2.0 - avatarInset - layoutConstants.bubble.contentInsets.left)
            
            if let forwardInfo = item.message.forwardInfo {
                if item.message.id.peerId != item.context.account.peerId {
                    for attribute in item.message.attributes {
                        if let attribute = attribute as? SourceReferenceMessageAttribute {
                            if attribute.messageId.peerId == forwardInfo.author?.id {
                                ignoreForward = true
                            } else {
                                ignoreSource = true
                            }
                            break
                        }
                    }
                }
            }
            
            for attribute in item.message.attributes {
                if let attribute = attribute as? InlineBotMessageAttribute {
                    var inlineBotNameString: String?
                    if let peerId = attribute.peerId, let bot = item.message.peers[peerId] as? TelegramUser {
                        inlineBotNameString = bot.username
                    } else {
                        inlineBotNameString = attribute.title
                    }
                    
                    if let inlineBotNameString = inlineBotNameString {
                        let inlineBotNameColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
                        
                        let bodyAttributes = MarkdownAttributeSet(font: nameFont, textColor: inlineBotNameColor)
                        let boldAttributes = MarkdownAttributeSet(font: inlineBotPrefixFont, textColor: inlineBotNameColor)
                        let botString = addAttributesToStringWithRanges(item.presentationData.strings.Conversation_MessageViaUser("@\(inlineBotNameString)"), body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                        
                        viaBotApply = viaBotLayout(TextNodeLayoutArguments(attributedString: botString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0, availableContentWidth), height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                    }
                }
                if let replyAttribute = attribute as? ReplyMessageAttribute, let replyMessage = item.message.associatedMessages[replyAttribute.messageId] {
                    if case let .replyThread(replyThreadMessage) = item.chatLocation, replyThreadMessage.messageId == replyAttribute.messageId {
                    } else {
                        replyInfoApply = makeReplyInfoLayout(item.presentationData, item.presentationData.strings, item.context, .standalone, replyMessage, CGSize(width: availableContentWidth, height: CGFloat.greatestFiniteMagnitude))
                    }
                } else if let attribute = attribute as? ReplyMarkupMessageAttribute, attribute.flags.contains(.inline), !attribute.rows.isEmpty {
                    replyMarkup = attribute
                }
            }
            
            if item.message.id.peerId != item.context.account.peerId && !item.message.id.peerId.isReplies {
                for attribute in item.message.attributes {
                    if let attribute = attribute as? SourceReferenceMessageAttribute {
                        if let sourcePeer = item.message.peers[attribute.messageId.peerId] {
                            let inlineBotNameColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
                            
                            let nameString = NSAttributedString(string: sourcePeer.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder), font: inlineBotPrefixFont, textColor: inlineBotNameColor)
                            viaBotApply = viaBotLayout(TextNodeLayoutArguments(attributedString: nameString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0, availableContentWidth), height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                        }
                    }
                }
            }
            
            if replyInfoApply != nil || viaBotApply != nil {
                if let currentReplyBackgroundNode = currentReplyBackgroundNode {
                    updatedReplyBackgroundNode = currentReplyBackgroundNode
                } else {
                    updatedReplyBackgroundNode = ASImageNode()
                }
                
                let graphics = PresentationResourcesChat.additionalGraphics(item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper, bubbleCorners: item.presentationData.chatBubbleCorners)
                replyBackgroundImage = graphics.chatFreeformContentAdditionalInfoBackgroundImage
            }
            
            var updatedShareButtonNode: ChatMessageShareButton?
            if needShareButton {
                if let currentShareButtonNode = currentShareButtonNode {
                    updatedShareButtonNode = currentShareButtonNode
                } else {
                    let buttonNode = ChatMessageShareButton()
                    updatedShareButtonNode = buttonNode
                }
            }
            
            let contentHeight = max(imageSize.height, layoutConstants.image.minDimensions.height)
            
            var forwardSource: Peer?
            var forwardAuthorSignature: String?
            var forwardPsaType: String?
            
            var forwardInfoSizeApply: (CGSize, (CGFloat) -> ChatMessageForwardInfoNode)?
            var updatedForwardBackgroundNode: ASImageNode?
            var forwardBackgroundImage: UIImage?
            
            if !ignoreForward, let forwardInfo = item.message.forwardInfo {
                forwardPsaType = forwardInfo.psaType
                
                if let source = forwardInfo.source {
                    forwardSource = source
                    if let authorSignature = forwardInfo.authorSignature {
                        forwardAuthorSignature = authorSignature
                    } else if let forwardInfoAuthor = forwardInfo.author, forwardInfoAuthor.id != source.id {
                        forwardAuthorSignature = forwardInfoAuthor.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                    } else {
                        forwardAuthorSignature = nil
                    }
                } else {
                    if let currentForwardInfo = currentForwardInfo, forwardInfo.author == nil && currentForwardInfo.0 != nil {
                        forwardSource = nil
                        forwardAuthorSignature = currentForwardInfo.0?.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                    } else {
                        forwardSource = forwardInfo.author
                        forwardAuthorSignature = forwardInfo.authorSignature
                    }
                }
                let availableWidth = max(60.0, availableContentWidth + 6.0)
                forwardInfoSizeApply = makeForwardInfoLayout(item.presentationData, item.presentationData.strings, .standalone, forwardSource, forwardAuthorSignature, forwardPsaType, CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude))
                
                if let currentForwardBackgroundNode = currentForwardBackgroundNode {
                    updatedForwardBackgroundNode = currentForwardBackgroundNode
                } else {
                    updatedForwardBackgroundNode = ASImageNode()
                }
                
                let graphics = PresentationResourcesChat.additionalGraphics(item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper, bubbleCorners: item.presentationData.chatBubbleCorners)
                forwardBackgroundImage = graphics.chatServiceBubbleFillImage
            }
            
            var maxContentWidth = imageSize.width
            var actionButtonsFinalize: ((CGFloat) -> (CGSize, (_ animated: Bool) -> ChatMessageActionButtonsNode))?
            if let replyMarkup = replyMarkup {
                let (minWidth, buttonsLayout) = actionButtonsLayout(item.context, item.presentationData.theme, item.presentationData.chatBubbleCorners, item.presentationData.strings, replyMarkup, item.message, maxContentWidth)
                maxContentWidth = max(maxContentWidth, minWidth)
                actionButtonsFinalize = buttonsLayout
            }
            
            var actionButtonsSizeAndApply: (CGSize, (Bool) -> ChatMessageActionButtonsNode)?
            if let actionButtonsFinalize = actionButtonsFinalize {
                actionButtonsSizeAndApply = actionButtonsFinalize(maxContentWidth)
            }
            
            var layoutSize = CGSize(width: params.width, height: contentHeight)
            if let actionButtonsSizeAndApply = actionButtonsSizeAndApply {
                layoutSize.height += actionButtonsSizeAndApply.0.height
            }
            
            return (ListViewItemNodeLayout(contentSize: layoutSize, insets: layoutInsets), { [weak self] animation, _ in
                if let strongSelf = self {
                    strongSelf.appliedForwardInfo = (forwardSource, forwardAuthorSignature)
                    
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    strongSelf.contextSourceNode.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    strongSelf.contextSourceNode.contentNode.frame = CGRect(origin: CGPoint(), size: layoutSize)
                    
                    var transition: ContainedViewLayoutTransition = .immediate
                    if case let .System(duration) = animation {
                        transition = .animated(duration: duration, curve: .spring)
                    }
                    
                    let updatedImageFrame = imageFrame.offsetBy(dx: 0.0, dy: floor((contentHeight - imageSize.height) / 2.0))
                    var updatedContentFrame = updatedImageFrame
                    if isEmoji {
                        updatedContentFrame = updatedContentFrame.insetBy(dx: -imageInset, dy: -imageInset)
                    }
                    
                    strongSelf.imageNode.frame = updatedContentFrame
                    
                    let animationNodeFrame = updatedContentFrame.insetBy(dx: imageInset, dy: imageInset)

                    var file: TelegramMediaFile?
                    if let emojiFile = emojiFile {
                        file = emojiFile
                    } else if let telegramFile = telegramFile {
                        file = telegramFile
                    }
                    
                    if let file = file, let immediateThumbnailData = file.immediateThumbnailData, let placeholderNode = strongSelf.placeholderNode {
                        let foregroundColor = bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.stickerPlaceholderColor, wallpaper: item.presentationData.theme.wallpaper)
                        let shimmeringColor = bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.stickerPlaceholderShimmerColor, wallpaper: item.presentationData.theme.wallpaper)
                        placeholderNode.update(backgroundColor: nil, foregroundColor: foregroundColor, shimmeringColor: shimmeringColor, data: immediateThumbnailData, size: animationNodeFrame.size, imageSize: file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0))
                        placeholderNode.frame = animationNodeFrame
                    }
                    
                    if let animationNode = strongSelf.animationNode, let parentNode = strongSelf.greetingStickerParentNode, strongSelf.animateGreeting {
                        strongSelf.animateGreeting = false
                        
                        let initialFrame = animationNode.view.convert(animationNode.bounds, to: parentNode.view)
                        parentNode.addSubnode(animationNode)
                        animationNode.frame = initialFrame
                        
                        var targetPosition = initialFrame.center.y
                        if let listNode = strongSelf.greetingStickerListNode as? ListView {
                            targetPosition = listNode.frame.height - listNode.insets.top - animationNodeFrame.height / 2.0 - 12.0
                        }
                        
                        let targetScale = animationNodeFrame.width / initialFrame.width
                        animationNode.layer.animateScale(from: 1.0, to: targetScale, duration: 0.3, removeOnCompletion: false)
                        animationNode.layer.animatePosition(from: initialFrame.center, to: CGPoint(x: animationNodeFrame.midX, y: targetPosition), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak self] finished in
                            if let strongSelf = self {
                                animationNode.layer.removeAllAnimations()
                                strongSelf.animationNode?.frame = animationNodeFrame
                                strongSelf.contextSourceNode.contentNode.insertSubnode(animationNode, aboveSubnode: strongSelf.imageNode)
                                
                                if let animationNode = strongSelf.animationNode as? AnimatedStickerNode {
                                    animationNode.updateLayout(size: updatedContentFrame.insetBy(dx: imageInset, dy: imageInset).size)
                                }
                                
                                strongSelf.dateAndStatusNode.alpha = 1.0
                                strongSelf.dateAndStatusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                
                                strongSelf.greetingCompletion?()
                            }
                        })
                        
                    } else if strongSelf.animationNode?.supernode === strongSelf.contextSourceNode.contentNode {
                        strongSelf.animationNode?.frame = animationNodeFrame
                    }
                    if let animationNode = strongSelf.animationNode as? AnimatedStickerNode, strongSelf.animationNode?.supernode === strongSelf.contextSourceNode.contentNode {
                        animationNode.updateLayout(size: updatedContentFrame.insetBy(dx: imageInset, dy: imageInset).size)
                    }
                    imageApply()
                    
                    strongSelf.contextSourceNode.contentRect = strongSelf.imageNode.frame
                    strongSelf.containerNode.targetNodeForActivationProgressContentRect = strongSelf.contextSourceNode.contentRect
                    
                    if let updatedShareButtonNode = updatedShareButtonNode {
                        if updatedShareButtonNode !== strongSelf.shareButtonNode {
                            if let shareButtonNode = strongSelf.shareButtonNode {
                                shareButtonNode.removeFromSupernode()
                            }
                            strongSelf.shareButtonNode = updatedShareButtonNode
                            strongSelf.addSubnode(updatedShareButtonNode)
                            updatedShareButtonNode.addTarget(strongSelf, action: #selector(strongSelf.shareButtonPressed), forControlEvents: .touchUpInside)
                        }
                        let buttonSize = updatedShareButtonNode.update(presentationData: item.presentationData, chatLocation: item.chatLocation, subject: item.associatedData.subject, message: item.message, account: item.context.account)
                        updatedShareButtonNode.frame = CGRect(origin: CGPoint(x: updatedImageFrame.maxX + 8.0, y: updatedImageFrame.maxY - buttonSize.height - 4.0), size: buttonSize)
                    } else if let shareButtonNode = strongSelf.shareButtonNode {
                        shareButtonNode.removeFromSupernode()
                        strongSelf.shareButtonNode = nil
                    }
                    
                    dateAndStatusApply(false)
                    strongSelf.dateAndStatusNode.frame = CGRect(origin: CGPoint(x: max(displayLeftInset, updatedImageFrame.maxX - dateAndStatusSize.width - 4.0), y: updatedImageFrame.maxY - dateAndStatusSize.height - 4.0), size: dateAndStatusSize)
                    
                    if let updatedReplyBackgroundNode = updatedReplyBackgroundNode {
                        if strongSelf.replyBackgroundNode == nil {
                            strongSelf.replyBackgroundNode = updatedReplyBackgroundNode
                            strongSelf.addSubnode(updatedReplyBackgroundNode)
                            updatedReplyBackgroundNode.image = replyBackgroundImage
                        } else {
                            strongSelf.replyBackgroundNode?.image = replyBackgroundImage
                        }
                    } else if let replyBackgroundNode = strongSelf.replyBackgroundNode {
                        replyBackgroundNode.removeFromSupernode()
                        strongSelf.replyBackgroundNode = nil
                    }
                    
                    if let (viaBotLayout, viaBotApply) = viaBotApply {
                        let viaBotNode = viaBotApply()
                        if strongSelf.viaBotNode == nil {
                            strongSelf.viaBotNode = viaBotNode
                            strongSelf.addSubnode(viaBotNode)
                        }
                        let viaBotFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 15.0) : (params.width - params.rightInset - viaBotLayout.size.width - layoutConstants.bubble.edgeInset - 14.0)), y: 8.0), size: viaBotLayout.size)
                        viaBotNode.frame = viaBotFrame
                        strongSelf.replyBackgroundNode?.frame = CGRect(origin: CGPoint(x: viaBotFrame.minX - 6.0, y: viaBotFrame.minY - 2.0 - UIScreenPixel), size: CGSize(width: viaBotFrame.size.width + 11.0, height: viaBotFrame.size.height + 5.0))
                    } else if let viaBotNode = strongSelf.viaBotNode {
                        viaBotNode.removeFromSupernode()
                        strongSelf.viaBotNode = nil
                    }
                    
                    if let (replyInfoSize, replyInfoApply) = replyInfoApply {
                        let replyInfoNode = replyInfoApply()
                        if strongSelf.replyInfoNode == nil {
                            strongSelf.replyInfoNode = replyInfoNode
                            strongSelf.addSubnode(replyInfoNode)
                        }
                        var viaBotSize = CGSize()
                        if let viaBotNode = strongSelf.viaBotNode {
                            viaBotSize = viaBotNode.frame.size
                        }
                        let replyInfoFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 10.0) : (params.width - params.rightInset - max(replyInfoSize.width, viaBotSize.width) - layoutConstants.bubble.edgeInset - 10.0)), y: 8.0 + viaBotSize.height), size: replyInfoSize)
                        if let viaBotNode = strongSelf.viaBotNode {
                            if replyInfoFrame.minX < viaBotNode.frame.minX {
                                viaBotNode.frame = viaBotNode.frame.offsetBy(dx: replyInfoFrame.minX - viaBotNode.frame.minX, dy: 0.0)
                            }
                        }
                        replyInfoNode.frame = replyInfoFrame
                        strongSelf.replyBackgroundNode?.frame = CGRect(origin: CGPoint(x: replyInfoFrame.minX - 4.0, y: replyInfoFrame.minY - viaBotSize.height - 2.0), size: CGSize(width: max(replyInfoFrame.size.width, viaBotSize.width) + 8.0, height: replyInfoFrame.size.height + viaBotSize.height + 5.0))
                        
                        if let _ = item.controllerInteraction.selectionState, isEmoji {
                            replyInfoNode.alpha = 0.0
                            strongSelf.replyBackgroundNode?.alpha = 0.0
                        }
                    } else if let replyInfoNode = strongSelf.replyInfoNode {
                        replyInfoNode.removeFromSupernode()
                        strongSelf.replyInfoNode = nil
                    }
                    
                    if isFailed {
                        let deliveryFailedNode: ChatMessageDeliveryFailedNode
                        var isAppearing = false
                        if let current = strongSelf.deliveryFailedNode {
                            deliveryFailedNode = current
                        } else {
                            isAppearing = true
                            deliveryFailedNode = ChatMessageDeliveryFailedNode(tapped: {
                                if let item = self?.item {
                                    item.controllerInteraction.requestRedeliveryOfFailedMessages(item.content.firstMessage.id)
                                }
                            })
                            strongSelf.deliveryFailedNode = deliveryFailedNode
                            strongSelf.addSubnode(deliveryFailedNode)
                        }
                        let deliveryFailedSize = deliveryFailedNode.updateLayout(theme: item.presentationData.theme.theme)
                        let deliveryFailedFrame = CGRect(origin: CGPoint(x: imageFrame.maxX + deliveryFailedInset - deliveryFailedSize.width, y: imageFrame.maxY - deliveryFailedSize.height - imageInset), size: deliveryFailedSize)
                        if isAppearing {
                            deliveryFailedNode.frame = deliveryFailedFrame
                            transition.animatePositionAdditive(node: deliveryFailedNode, offset: CGPoint(x: deliveryFailedInset, y: 0.0))
                        } else {
                            transition.updateFrame(node: deliveryFailedNode, frame: deliveryFailedFrame)
                        }
                    } else if let deliveryFailedNode = strongSelf.deliveryFailedNode {
                        strongSelf.deliveryFailedNode = nil
                        transition.updateAlpha(node: deliveryFailedNode, alpha: 0.0)
                        transition.updateFrame(node: deliveryFailedNode, frame: deliveryFailedNode.frame.offsetBy(dx: 24.0, dy: 0.0), completion: { [weak deliveryFailedNode] _ in
                            deliveryFailedNode?.removeFromSupernode()
                        })
                    }
                    
                    if let updatedForwardBackgroundNode = updatedForwardBackgroundNode {
                        if strongSelf.forwardBackgroundNode == nil {
                            strongSelf.forwardBackgroundNode = updatedForwardBackgroundNode
                            strongSelf.addSubnode(updatedForwardBackgroundNode)
                            updatedForwardBackgroundNode.image = forwardBackgroundImage
                        }
                    } else if let forwardBackgroundNode = strongSelf.forwardBackgroundNode {
                        forwardBackgroundNode.removeFromSupernode()
                        strongSelf.forwardBackgroundNode = nil
                    }
                    
                    if let (forwardInfoSize, forwardInfoApply) = forwardInfoSizeApply {
                        let forwardInfoNode = forwardInfoApply(forwardInfoSize.width)
                        if strongSelf.forwardInfoNode == nil {
                            strongSelf.forwardInfoNode = forwardInfoNode
                            strongSelf.addSubnode(forwardInfoNode)
                        }
                        let forwardInfoFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 12.0) : (params.width - params.rightInset - forwardInfoSize.width - layoutConstants.bubble.edgeInset - 12.0)), y: 8.0), size: forwardInfoSize)
                        forwardInfoNode.frame = forwardInfoFrame
                        strongSelf.forwardBackgroundNode?.frame = CGRect(origin: CGPoint(x: forwardInfoFrame.minX - 6.0, y: forwardInfoFrame.minY - 2.0), size: CGSize(width: forwardInfoFrame.size.width + 10.0, height: forwardInfoFrame.size.height + 4.0))
                    } else if let forwardInfoNode = strongSelf.forwardInfoNode {
                        forwardInfoNode.removeFromSupernode()
                        strongSelf.forwardInfoNode = nil
                    }
                    
                    if let actionButtonsSizeAndApply = actionButtonsSizeAndApply {
                        var animated = false
                        if let _ = strongSelf.actionButtonsNode {
                            if case .System = animation {
                                animated = true
                            }
                        }
                        let actionButtonsNode = actionButtonsSizeAndApply.1(animated)
                        let previousFrame = actionButtonsNode.frame
                        let actionButtonsFrame = CGRect(origin: CGPoint(x: imageFrame.minX, y: imageFrame.maxY), size: actionButtonsSizeAndApply.0)
                        actionButtonsNode.frame = actionButtonsFrame
                        if actionButtonsNode !== strongSelf.actionButtonsNode {
                            strongSelf.actionButtonsNode = actionButtonsNode
                            actionButtonsNode.buttonPressed = { button in
                                if let strongSelf = self {
                                    strongSelf.performMessageButtonAction(button: button)
                                }
                            }
                            actionButtonsNode.buttonLongTapped = { button in
                                if let strongSelf = self {
                                    strongSelf.presentMessageButtonContextMenu(button: button)
                                }
                            }
                            strongSelf.addSubnode(actionButtonsNode)
                        } else {
                            if case let .System(duration) = animation {
                                actionButtonsNode.layer.animateFrame(from: previousFrame, to: actionButtonsFrame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                            }
                        }
                    } else if let actionButtonsNode = strongSelf.actionButtonsNode {
                        actionButtonsNode.removeFromSupernode()
                        strongSelf.actionButtonsNode = nil
                    }
                }
            })
        }
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                if let action = self.gestureRecognized(gesture: gesture, location: location, recognizer: recognizer) {
                    if case .doubleTap = gesture {
                        self.containerNode.cancelGesture()
                    }
                    switch action {
                    case let .action(f):
                        f()
                    case let .optionalAction(f):
                        f()
                    case let .openContextMenu(tapMessage, selectAll, subFrame):
                        self.item?.controllerInteraction.openMessageContextMenu(tapMessage, selectAll, self, subFrame, nil)
                    }
                } else if case .tap = gesture {
                    self.item?.controllerInteraction.clickThroughMessage()
                }
            }
        default:
            break
        }
    }
    
    private func gestureRecognized(gesture: TapLongTapOrDoubleTapGesture, location: CGPoint, recognizer: TapLongTapOrDoubleTapGestureRecognizer?, withHaptic: Bool = true) -> InternalBubbleTapAction? {
        switch gesture {
        case .tap:
            if let avatarNode = self.accessoryItemNode as? ChatMessageAvatarAccessoryItemNode, avatarNode.frame.contains(location) {
                if let item = self.item, let author = item.content.firstMessage.author {
                    return .optionalAction({
                        var openPeerId = item.effectiveAuthorId ?? author.id
                        var navigate: ChatControllerInteractionNavigateToPeer
                        
                        if item.content.firstMessage.id.peerId == item.context.account.peerId {
                            navigate = .chat(textInputState: nil, subject: nil, peekData: nil)
                        } else {
                            navigate = .info
                        }
                        
                        for attribute in item.content.firstMessage.attributes {
                            if let attribute = attribute as? SourceReferenceMessageAttribute {
                                openPeerId = attribute.messageId.peerId
                                navigate = .chat(textInputState: nil, subject: .message(id: attribute.messageId, highlight: true), peekData: nil)
                            }
                        }
                        
                        if item.effectiveAuthorId?.namespace == Namespaces.Peer.Empty {
                            item.controllerInteraction.displayMessageTooltip(item.content.firstMessage.id,  item.presentationData.strings.Conversation_ForwardAuthorHiddenTooltip, self, avatarNode.frame)
                        } else {
                            if !item.message.id.peerId.isReplies, let channel = item.content.firstMessage.forwardInfo?.author as? TelegramChannel, channel.username == nil {
                                if case .member = channel.participationStatus {
                                } else {
                                    item.controllerInteraction.displayMessageTooltip(item.message.id, item.presentationData.strings.Conversation_PrivateChannelTooltip, self, avatarNode.frame)
                                }
                            }
                            item.controllerInteraction.openPeer(openPeerId, navigate, item.message)
                        }
                    })
                }
                return nil
            }
            
            if let viaBotNode = self.viaBotNode, viaBotNode.frame.contains(location) {
                if let item = self.item {
                    for attribute in item.message.attributes {
                        if let attribute = attribute as? InlineBotMessageAttribute {
                            var botAddressName: String?
                            if let peerId = attribute.peerId, let botPeer = item.message.peers[peerId], let addressName = botPeer.addressName {
                                botAddressName = addressName
                            } else {
                                botAddressName = attribute.title
                            }
                            
                            if let botAddressName = botAddressName {
                                return .optionalAction({
                                    item.controllerInteraction.updateInputState { textInputState in
                                        return ChatTextInputState(inputText: NSAttributedString(string: "@" + botAddressName + " "))
                                    }
                                    item.controllerInteraction.updateInputMode { _ in
                                        return .text
                                    }
                                })
                            }
                        }
                    }
                }
            }
            
            if let replyInfoNode = self.replyInfoNode, replyInfoNode.frame.contains(location) {
                if let item = self.item {
                    for attribute in item.message.attributes {
                        if let attribute = attribute as? ReplyMessageAttribute {
                            return .optionalAction({
                                item.controllerInteraction.navigateToMessage(item.message.id, attribute.messageId)
                            })
                        }
                    }
                }
            }
            
            if let item = self.item, self.imageNode.frame.contains(location) {
                if let _ = self.telegramFile {
                    return .optionalAction({
                        let _ = item.controllerInteraction.openMessage(item.message, .default)
                    })
                } else if let dice = self.telegramDice {
                    return .optionalAction({
                        item.controllerInteraction.displayDiceTooltip(dice)
                    })
                } else if let _ = self.emojiFile {
                    if let animationNode = self.animationNode as? AnimatedStickerNode, let _ = recognizer {
                        var startTime: Signal<Double, NoError>
                        var shouldPlay = false
                        if !animationNode.isPlaying {
                            shouldPlay = true
                            startTime = .single(0.0)
                        } else {
                            startTime = animationNode.status
                            |> map { $0.timestamp }
                            |> take(1)
                            |> deliverOnMainQueue
                        }
                        
                        let beatingHearts: [UInt32] = [0x2764, 0x1F90E, 0x1F9E1, 0x1F499, 0x1F49A, 0x1F49C, 0x1F49B, 0x1F5A4, 0x1F90D]
                        let heart = 0x2764
                        let peach = 0x1F351
                        let coffin = 0x26B0
                        
                        let appConfiguration = item.context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
                        |> take(1)
                        |> map { view in
                            return view.values[PreferencesKeys.appConfiguration] as? AppConfiguration ?? .defaultValue
                        }
                                                
                        if let text = self.item?.message.text, var firstScalar = text.unicodeScalars.first {
                            var textEmoji = text.strippedEmoji
                            if beatingHearts.contains(firstScalar.value) {
                                textEmoji = "❤️"
                                firstScalar = UnicodeScalar(heart)!
                            }
                            return .optionalAction({
                                if shouldPlay {
                                    let _ = (appConfiguration
                                    |> deliverOnMainQueue).start(next: { [weak self, weak animationNode] appConfiguration in
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        let emojiSounds = AnimatedEmojiSoundsConfiguration.with(appConfiguration: appConfiguration, account: item.context.account)
                                        for (emoji, file) in emojiSounds.sounds {
                                            if emoji.strippedEmoji == textEmoji.strippedEmoji {
                                                let mediaManager = item.context.sharedContext.mediaManager
                                                let mediaPlayer = MediaPlayer(audioSessionManager: mediaManager.audioSession, postbox: item.context.account.postbox, resourceReference: .standalone(resource: file.resource), streamable: .none, video: false, preferSoftwareDecoding: false, enableSound: true, fetchAutomatically: true, ambient: true)
                                                mediaPlayer.togglePlayPause()
                                                mediaPlayer.actionAtEnd = .action({ [weak self] in
                                                    self?.mediaPlayer = nil
                                                })
                                                strongSelf.mediaPlayer = mediaPlayer
                                                
                                                strongSelf.mediaStatusDisposable.set((mediaPlayer.status
                                                |> deliverOnMainQueue).start(next: { [weak self, weak animationNode] status in
                                                    if let strongSelf = self {
                                                        
                                                        var haptic: EmojiHaptic?
                                                        if let current = strongSelf.haptic {
                                                            haptic = current
                                                        } else {
                                                            if firstScalar.value == heart {
                                                                haptic = HeartbeatHaptic()
                                                            } else if firstScalar.value == coffin {
                                                                haptic = CoffinHaptic()
                                                            } else if firstScalar.value == peach {
                                                                haptic = PeachHaptic()
                                                            }
                                                            haptic?.enabled = true
                                                            strongSelf.haptic = haptic
                                                        }
                                                        
                                                        if let haptic = haptic, withHaptic, !haptic.active {
                                                            haptic.start(time: 0.0)
                                                        }
                                                        
                                                        switch status.status {
                                                            case .playing:
                                                                animationNode?.play()
                                                                strongSelf.mediaStatusDisposable.set(nil)
                                                            default:
                                                                break
                                                        }
                                                    }
                                                }))
                                                return
                                            }
                                        }
                                        animationNode?.play()
                                    })
                                }
                            })
                        }
                    }
                }
            }
            return nil
        case .longTap, .doubleTap:
            if let item = self.item, self.imageNode.frame.contains(location) {
                return .openContextMenu(tapMessage: item.message, selectAll: false, subFrame: self.imageNode.frame)
            }
        case .hold:
            break
        }
        return nil
    }
    
    @objc private func shareButtonPressed() {
        if let item = self.item {
            if case .pinnedMessages = item.associatedData.subject {
                item.controllerInteraction.navigateToMessageStandalone(item.content.firstMessage.id)
                return
            }
            
            if let channel = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
                for attribute in item.message.attributes {
                    if let _ = attribute as? ReplyThreadMessageAttribute {
                        item.controllerInteraction.openMessageReplies(item.message.id, true, false)
                        return
                    }
                }
            }
            
            if item.content.firstMessage.id.peerId.isReplies {
                item.controllerInteraction.openReplyThreadOriginalMessage(item.content.firstMessage)
            } else if item.content.firstMessage.id.peerId.isRepliesOrSavedMessages(accountPeerId: item.context.account.peerId) {
                for attribute in item.content.firstMessage.attributes {
                    if let attribute = attribute as? SourceReferenceMessageAttribute {
                        item.controllerInteraction.navigateToMessage(item.content.firstMessage.id, attribute.messageId)
                        break
                    }
                }
            } else {
                item.controllerInteraction.openMessageShareMenu(item.message.id)
            }
        }
    }
    
    @objc private func swipeToReplyGesture(_ recognizer: ChatSwipeToReplyRecognizer) {
        switch recognizer.state {
        case .began:
            self.currentSwipeToReplyTranslation = 0.0
            if self.swipeToReplyFeedback == nil {
                self.swipeToReplyFeedback = HapticFeedback()
                self.swipeToReplyFeedback?.prepareImpact()
            }
            (self.view.window as? WindowHost)?.cancelInteractiveKeyboardGestures()
        case .changed:
            var translation = recognizer.translation(in: self.view)
            translation.x = max(-80.0, min(0.0, translation.x))
            var animateReplyNodeIn = false
            if (translation.x < -45.0) != (self.currentSwipeToReplyTranslation < -45.0) {
                if translation.x < -45.0, self.swipeToReplyNode == nil, let item = self.item {
                    self.swipeToReplyFeedback?.impact()
                    
                    let swipeToReplyNode = ChatMessageSwipeToReplyNode(fillColor: bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.shareButtonFillColor, wallpaper: item.presentationData.theme.wallpaper), strokeColor: bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.shareButtonStrokeColor, wallpaper: item.presentationData.theme.wallpaper), foregroundColor: bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.shareButtonForegroundColor, wallpaper: item.presentationData.theme.wallpaper), action: ChatMessageSwipeToReplyNode.Action(self.currentSwipeAction))
                    self.swipeToReplyNode = swipeToReplyNode
                    self.addSubnode(swipeToReplyNode)
                    animateReplyNodeIn = true
                }
            }
            self.currentSwipeToReplyTranslation = translation.x
            var bounds = self.bounds
            bounds.origin.x = -translation.x
            self.bounds = bounds
            
            if let swipeToReplyNode = self.swipeToReplyNode {
                swipeToReplyNode.frame = CGRect(origin: CGPoint(x: bounds.size.width, y: floor((self.contentSize.height - 33.0) / 2.0)), size: CGSize(width: 33.0, height: 33.0))
                if animateReplyNodeIn {
                    swipeToReplyNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.12)
                    swipeToReplyNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
                } else {
                    swipeToReplyNode.alpha = min(1.0, abs(translation.x / 45.0))
                }
            }
        case .cancelled, .ended:
            self.swipeToReplyFeedback = nil
            
            let translation = recognizer.translation(in: self.view)
            if case .ended = recognizer.state, translation.x < -45.0 {
                if let item = self.item {
                    if let currentSwipeAction = currentSwipeAction {
                        switch currentSwipeAction {
                        case .none:
                            break
                        case .reply:
                            item.controllerInteraction.setupReply(item.message.id)
                        case .like:
                            item.controllerInteraction.updateMessageLike(item.message.id, true)
                        case .unlike:
                            item.controllerInteraction.updateMessageLike(item.message.id, true)
                        }
                    }
                }
            }
            var bounds = self.bounds
            let previousBounds = bounds
            bounds.origin.x = 0.0
            self.bounds = bounds
            self.layer.animateBounds(from: previousBounds, to: bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
            if let swipeToReplyNode = self.swipeToReplyNode {
                self.swipeToReplyNode = nil
                swipeToReplyNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak swipeToReplyNode] _ in
                    swipeToReplyNode?.removeFromSupernode()
                })
                swipeToReplyNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
            }
        default:
            break
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let shareButtonNode = self.shareButtonNode, shareButtonNode.frame.contains(point) {
            return shareButtonNode.view
        }
        
        return super.hitTest(point, with: event)
    }
    
    override func updateSelectionState(animated: Bool) {
        guard let item = self.item else {
            return
        }
        
        if case let .replyThread(replyThreadMessage) = item.chatLocation, replyThreadMessage.effectiveTopId == item.message.id {
            return
        }
        
        if let selectionState = item.controllerInteraction.selectionState {
            var selected = false
            var incoming = true
            
            selected = selectionState.selectedIds.contains(item.message.id)
            incoming = item.message.effectivelyIncoming(item.context.account.peerId)
            
            let offset: CGFloat = incoming ? 42.0 : 0.0
            
            if let selectionNode = self.selectionNode {
                selectionNode.updateSelected(selected, animated: false)
                let selectionFrame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.contentBounds.size.width, height: self.contentBounds.size.height))
                selectionNode.frame = selectionFrame
                selectionNode.updateLayout(size: selectionFrame.size)
                self.subnodeTransform = CATransform3DMakeTranslation(offset, 0.0, 0.0);
            } else {
                let selectionNode = ChatMessageSelectionNode(wallpaper: item.presentationData.theme.wallpaper, theme: item.presentationData.theme.theme, toggle: { [weak self] value in
                    if let strongSelf = self, let item = strongSelf.item {
                        item.controllerInteraction.toggleMessagesSelection([item.message.id], value)
                    }
                })
                
                let selectionFrame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.contentBounds.size.width, height: self.contentBounds.size.height))
                selectionNode.frame = selectionFrame
                selectionNode.updateLayout(size: selectionFrame.size)
                self.addSubnode(selectionNode)
                self.selectionNode = selectionNode
                selectionNode.updateSelected(selected, animated: false)
                let previousSubnodeTransform = self.subnodeTransform
                self.subnodeTransform = CATransform3DMakeTranslation(offset, 0.0, 0.0);
                if animated {
                    selectionNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    self.layer.animate(from: NSValue(caTransform3D: previousSubnodeTransform), to: NSValue(caTransform3D: self.subnodeTransform), keyPath: "sublayerTransform", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2)
                    
                    if !incoming {
                        let position = selectionNode.layer.position
                        selectionNode.layer.animatePosition(from: CGPoint(x: position.x - 42.0, y: position.y), to: position, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
                    }
                }
            }
        } else {
            if let selectionNode = self.selectionNode {
                self.selectionNode = nil
                let previousSubnodeTransform = self.subnodeTransform
                self.subnodeTransform = CATransform3DIdentity
                if animated {
                    self.layer.animate(from: NSValue(caTransform3D: previousSubnodeTransform), to: NSValue(caTransform3D: self.subnodeTransform), keyPath: "sublayerTransform", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2, completion: { [weak selectionNode]_ in
                        selectionNode?.removeFromSupernode()
                    })
                    selectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                    if CGFloat(0.0).isLessThanOrEqualTo(selectionNode.frame.origin.x) {
                        let position = selectionNode.layer.position
                        selectionNode.layer.animatePosition(from: position, to: CGPoint(x: position.x - 42.0, y: position.y), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false)
                    }
                } else {
                    selectionNode.removeFromSupernode()
                }
            }
        }
    }
    
    override func updateHighlightedState(animated: Bool) {
        super.updateHighlightedState(animated: animated)
        
        if let item = self.item {
            var highlighted = false
            if let highlightedState = item.controllerInteraction.highlightedState {
                if highlightedState.messageStableId == item.message.stableId {
                    highlighted = true
                }
            }
            
            if self.highlightedState != highlighted {
                self.highlightedState = highlighted
                
                if highlighted {
                    self.imageNode.setOverlayColor(item.presentationData.theme.theme.chat.message.mediaHighlightOverlayColor, animated: false)
                    self.animationNode?.setOverlayColor(item.presentationData.theme.theme.chat.message.mediaHighlightOverlayColor, animated: false)
                } else {
                    self.imageNode.setOverlayColor(nil, animated: animated)
                    self.animationNode?.setOverlayColor(nil, animated: false)
                }
            }
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        if let telegramDice = self.telegramDice, let item = self.item, item.message.effectivelyIncoming(item.context.account.peerId) {
            if let value = telegramDice.value, value != 0 {
                if let diceNode = self.animationNode as? ManagedDiceAnimationNode {
                    diceNode.setState(.rolling)
                    diceNode.setState(.value(value, false))
                } else if let diceNode = self.animationNode as? SlotMachineAnimationNode {
                    diceNode.setState(.rolling)
                    diceNode.setState(.value(value, false))
                }
            }
        }
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func getMessageContextSourceNode(stableId: UInt32?) -> ContextExtractedContentContainingNode? {
        return self.contextSourceNode
    }
    
    override func addAccessoryItemNode(_ accessoryItemNode: ListViewAccessoryItemNode) {
        self.contextSourceNode.contentNode.addSubnode(accessoryItemNode)
    }
}

struct AnimatedEmojiSoundsConfiguration {
    static var defaultValue: AnimatedEmojiSoundsConfiguration {
        return AnimatedEmojiSoundsConfiguration(sounds: [:])
    }
    
    public let sounds: [String: TelegramMediaFile]
    
    fileprivate init(sounds: [String: TelegramMediaFile]) {
        self.sounds = sounds
    }
    
    static func with(appConfiguration: AppConfiguration, account: Account) -> AnimatedEmojiSoundsConfiguration {
        if let data = appConfiguration.data, let values = data["emojies_sounds"] as? [String: Any] {
            var sounds: [String: TelegramMediaFile] = [:]
            for (key, value) in values {
                if let dict = value as? [String: String], var fileReferenceString = dict["file_reference_base64"] {
                    fileReferenceString = fileReferenceString.replacingOccurrences(of: "-", with: "+")
                    fileReferenceString = fileReferenceString.replacingOccurrences(of: "_", with: "/")
                    while fileReferenceString.count % 4 != 0 {
                        fileReferenceString.append("=")
                    }
                    
                    if let idString = dict["id"], let id = Int64(idString), let accessHashString = dict["access_hash"], let accessHash = Int64(accessHashString), let fileReference = Data(base64Encoded: fileReferenceString) {
                        let resource = CloudDocumentMediaResource(datacenterId: 1, fileId: id, accessHash: accessHash, size: nil, fileReference: fileReference, fileName: nil)
                        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: nil, attributes: [])
                        sounds[key] = file
                    }
                }
            }
            return AnimatedEmojiSoundsConfiguration(sounds: sounds)
        } else {
            return .defaultValue
        }
    }
}
