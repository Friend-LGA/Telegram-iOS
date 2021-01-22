import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import MediaResources
import AccountContext
import TemporaryCachedPeerDataManager
import ChatListSearchItemNode
import Emoji
import AppBundle
import ListMessageItem
import AccountContext
import ChatInterfaceState

extension ChatReplyThreadMessage {
    var effectiveTopId: MessageId {
        return self.channelMessageId ?? self.messageId
    }
}

struct ChatTopVisibleMessageRange: Equatable {
    var lowerBound: MessageId
    var upperBound: MessageId
    var isLast: Bool
}

private class ChatHistoryListSelectionRecognizer: UIPanGestureRecognizer {
    private let selectionGestureActivationThreshold: CGFloat = 5.0
    
    var recognized: Bool? = nil
    var initialLocation: CGPoint = CGPoint()
    
    var shouldBegin: (() -> Bool)?
    
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.minimumNumberOfTouches = 2
        self.maximumNumberOfTouches = 2
    }
    
    override func reset() {
        super.reset()
        
        self.recognized = nil
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if let shouldBegin = self.shouldBegin, !shouldBegin() {
            self.state = .failed
        } else {
            let touch = touches.first!
            self.initialLocation = touch.location(in: self.view)
        }
    }
    
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let location = touches.first!.location(in: self.view)
        let translation = location.offsetBy(dx: -self.initialLocation.x, dy: -self.initialLocation.y)
        
        if self.recognized == nil {
            if (abs(translation.y) >= selectionGestureActivationThreshold) {
                self.recognized = true
            }
        }
        
        if let recognized = self.recognized, recognized {
            super.touchesMoved(touches, with: event)
        }
    }
}

private let historyMessageCount: Int = 90

public enum ChatHistoryListDisplayHeaders {
    case none
    case all
    case allButLast
}

public enum ChatHistoryListMode: Equatable {
    case bubbles
    case list(search: Bool, reversed: Bool, displayHeaders: ChatHistoryListDisplayHeaders, hintLinks: Bool, isGlobalSearch: Bool)
}

enum ChatHistoryViewScrollPosition {
    case unread(index: MessageIndex)
    case positionRestoration(index: MessageIndex, relativeOffset: CGFloat)
    case index(index: MessageHistoryAnchorIndex, position: ListViewScrollPosition, directionHint: ListViewScrollToItemDirectionHint, animated: Bool, highlight: Bool)
}

enum ChatHistoryViewUpdateType {
    case Initial(fadeIn: Bool)
    case Generic(type: ViewUpdateType)
}

public struct ChatHistoryCombinedInitialReadStateData {
    public let unreadCount: Int32
    public let totalState: ChatListTotalUnreadState?
    public let notificationSettings: PeerNotificationSettings?
}

public struct ChatHistoryCombinedInitialData {
    var initialData: InitialMessageHistoryData?
    var buttonKeyboardMessage: Message?
    var cachedData: CachedPeerData?
    var cachedDataMessages: [MessageId: Message]?
    var readStateData: [PeerId: ChatHistoryCombinedInitialReadStateData]?
}

enum ChatHistoryViewUpdate {
    case Loading(initialData: ChatHistoryCombinedInitialData?, type: ChatHistoryViewUpdateType)
    case HistoryView(view: MessageHistoryView, type: ChatHistoryViewUpdateType, scrollPosition: ChatHistoryViewScrollPosition?, flashIndicators: Bool, originalScrollPosition: ChatHistoryViewScrollPosition?, initialData: ChatHistoryCombinedInitialData, id: Int32)
}

struct ChatHistoryView {
    let originalView: MessageHistoryView
    let filteredEntries: [ChatHistoryEntry]
    let associatedData: ChatMessageItemAssociatedData
    let lastHeaderId: Int64
    let id: Int32
}

enum ChatHistoryViewTransitionReason {
    case Initial(fadeIn: Bool)
    case InteractiveChanges
    case Reload
    case HoleReload
}

struct ChatHistoryViewTransitionInsertEntry {
    let index: Int
    let previousIndex: Int?
    let entry: ChatHistoryEntry
    let directionHint: ListViewItemOperationDirectionHint?
}

struct ChatHistoryViewTransitionUpdateEntry {
    let index: Int
    let previousIndex: Int
    let entry: ChatHistoryEntry
    let directionHint: ListViewItemOperationDirectionHint?
}

struct ChatHistoryViewTransition {
    let historyView: ChatHistoryView
    let deleteItems: [ListViewDeleteItem]
    let insertEntries: [ChatHistoryViewTransitionInsertEntry]
    let updateEntries: [ChatHistoryViewTransitionUpdateEntry]
    let options: ListViewDeleteAndInsertOptions
    let scrollToItem: ListViewScrollToItem?
    let stationaryItemRange: (Int, Int)?
    let initialData: InitialMessageHistoryData?
    let keyboardButtonsMessage: Message?
    let cachedData: CachedPeerData?
    let cachedDataMessages: [MessageId: Message]?
    let readStateData: [PeerId: ChatHistoryCombinedInitialReadStateData]?
    let scrolledToIndex: MessageHistoryAnchorIndex?
    let scrolledToSomeIndex: Bool
    let animateIn: Bool
    let reason: ChatHistoryViewTransitionReason
    let flashIndicators: Bool
}

struct ChatHistoryListViewTransition {
    // Takes arguments as node and completion callback
    typealias AnimationCallback = (ListViewItemNode, (() -> Void)?) -> Void

    let historyView: ChatHistoryView
    let deleteItems: [ListViewDeleteItem]
    let insertItems: [ListViewInsertItem]
    let updateItems: [ListViewUpdateItem]
    let options: ListViewDeleteAndInsertOptions
    let scrollToItem: ListViewScrollToItem?
    let stationaryItemRange: (Int, Int)?
    let initialData: InitialMessageHistoryData?
    let keyboardButtonsMessage: Message?
    let cachedData: CachedPeerData?
    let cachedDataMessages: [MessageId: Message]?
    let readStateData: [PeerId: ChatHistoryCombinedInitialReadStateData]?
    let scrolledToIndex: MessageHistoryAnchorIndex?
    let scrolledToSomeIndex: Bool
    let peerType: MediaAutoDownloadPeerType
    let networkType: MediaAutoDownloadNetworkType
    let animateIn: Bool
    let reason: ChatHistoryViewTransitionReason
    let flashIndicators: Bool
    let animationCallback: AnimationCallback?
}

private func maxMessageIndexForEntries(_ view: ChatHistoryView, indexRange: (Int, Int)) -> (incoming: MessageIndex?, overall: MessageIndex?) {
    var incoming: MessageIndex?
    var overall: MessageIndex?
    var nextLowestIndex: MessageIndex?
    if indexRange.0 >= 0 && indexRange.0 < view.filteredEntries.count {
        if indexRange.0 > 0 {
            nextLowestIndex = view.filteredEntries[indexRange.0 - 1].index
        }
    }
    var nextHighestIndex: MessageIndex?
    if indexRange.1 >= 0 && indexRange.1 < view.filteredEntries.count {
        if indexRange.1 < view.filteredEntries.count - 1 {
            nextHighestIndex = view.filteredEntries[indexRange.1 + 1].index
        }
    }
    for i in (0 ..< view.originalView.entries.count).reversed() {
        let index = view.originalView.entries[i].index
        if let nextLowestIndex = nextLowestIndex {
            if index <= nextLowestIndex {
                continue
            }
        }
        if let nextHighestIndex = nextHighestIndex {
            if index >= nextHighestIndex {
                continue
            }
        }
        let messageEntry = view.originalView.entries[i]
        if overall == nil || overall! < index {
            overall = index
        }
        if !messageEntry.message.flags.intersection(.IsIncomingMask).isEmpty {
            if incoming == nil || incoming! < index {
                incoming = index
            }
        }
        if incoming != nil {
            return (incoming, overall)
        }
    }
    return (incoming, overall)
}

extension ListMessageItemInteraction {
    convenience init(controllerInteraction: ChatControllerInteraction) {
        self.init(openMessage: { message, mode -> Bool in
            return controllerInteraction.openMessage(message, mode)
        }, openMessageContextMenu: { message, bool, node, rect, gesture in
            controllerInteraction.openMessageContextMenu(message, bool, node, rect, gesture)
        }, toggleMessagesSelection: { messageId, selected in
            controllerInteraction.toggleMessagesSelection(messageId, selected)
        }, openUrl: { url, param1, param2, message in
            controllerInteraction.openUrl(url, param1, param2, message)
        }, openInstantPage: { message, data in
            controllerInteraction.openInstantPage(message, data)
        }, longTap: { action, message in
            controllerInteraction.longTap(action, message)
        }, getHiddenMedia: {
            return controllerInteraction.hiddenMedia
        })
    }
}

private func mappedInsertEntries(context: AccountContext, chatLocation: ChatLocation, associatedData: ChatMessageItemAssociatedData, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode, lastHeaderId: Int64, entries: [ChatHistoryViewTransitionInsertEntry], reason: ChatHistoryViewTransitionReason? = nil) -> [ListViewInsertItem] {
    return entries.map { entry -> ListViewInsertItem in
        switch entry.entry {
            case let .MessageEntry(message, presentationData, read, _, selection, attributes):
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        var animatedFromTextPanel = false
                        if let reason = reason, case ChatHistoryViewTransitionReason.InteractiveChanges = reason {
                            animatedFromTextPanel = true
                        }
                        item = ChatMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, content: .message(message: message, read: read, selection: selection, attributes: attributes), animatedFromTextPanel: animatedFromTextPanel)
                    case let .list(_, _, displayHeaders, hintLinks, isGlobalSearch):
                        let displayHeader: Bool
                        switch displayHeaders {
                        case .none:
                            displayHeader = false
                        case .all:
                            displayHeader = true
                        case .allButLast:
                            displayHeader = listMessageDateHeaderId(timestamp: message.timestamp) != lastHeaderId
                        }
                        item = ListMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, interaction: ListMessageItemInteraction(controllerInteraction: controllerInteraction), message: message, selection: selection, displayHeader: displayHeader, hintIsLink: hintLinks, isGlobalSearchResult: isGlobalSearch)
                }
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case let .MessageGroupEntry(_, messages, presentationData):
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, content: .group(messages: messages))
                    case .list:
                        assertionFailure()
                        item = ListMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, interaction: ListMessageItemInteraction(controllerInteraction: controllerInteraction), message: messages[0].0, selection: .none, displayHeader: false)
                }
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case let .UnreadEntry(_, presentationData):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatUnreadItem(index: entry.entry.index, presentationData: presentationData, context: context), directionHint: entry.directionHint)
            case let .ReplyCountEntry(_, isComments, count, presentationData):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatReplyCountItem(index: entry.entry.index, isComments: isComments, count: count, presentationData: presentationData, context: context), directionHint: entry.directionHint)
            case let .ChatInfoEntry(title, text, presentationData):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatBotInfoItem(title: title, text: text, controllerInteraction: controllerInteraction, presentationData: presentationData), directionHint: entry.directionHint)
            case let .SearchEntry(theme, strings):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListSearchItem(theme: theme, placeholder: strings.Common_Search, activate: {
                    controllerInteraction.openSearch()
                }), directionHint: entry.directionHint)
        }
    }
}

private func mappedUpdateEntries(context: AccountContext, chatLocation: ChatLocation, associatedData: ChatMessageItemAssociatedData, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode, lastHeaderId: Int64, entries: [ChatHistoryViewTransitionUpdateEntry]) -> [ListViewUpdateItem] {
    return entries.map { entry -> ListViewUpdateItem in
        switch entry.entry {
            case let .MessageEntry(message, presentationData, read, _, selection, attributes):
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, content: .message(message: message, read: read, selection: selection, attributes: attributes))
                    case let .list(_, _, displayHeaders, hintLinks, isGlobalSearch):
                        let displayHeader: Bool
                        switch displayHeaders {
                        case .none:
                            displayHeader = false
                        case .all:
                            displayHeader = true
                        case .allButLast:
                            displayHeader = listMessageDateHeaderId(timestamp: message.timestamp) != lastHeaderId
                        }
                        item = ListMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, interaction: ListMessageItemInteraction(controllerInteraction: controllerInteraction), message: message, selection: selection, displayHeader: displayHeader, hintIsLink: hintLinks, isGlobalSearchResult: isGlobalSearch)
                }
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case let .MessageGroupEntry(_, messages, presentationData):
                let item: ListViewItem
                switch mode {
                    case .bubbles:
                        item = ChatMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, content: .group(messages: messages))
                    case .list:
                        assertionFailure()
                        item = ListMessageItem(presentationData: presentationData, context: context, chatLocation: chatLocation, interaction: ListMessageItemInteraction(controllerInteraction: controllerInteraction), message: messages[0].0, selection: .none, displayHeader: false)
                }
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: item, directionHint: entry.directionHint)
            case let .UnreadEntry(_, presentationData):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatUnreadItem(index: entry.entry.index, presentationData: presentationData, context: context), directionHint: entry.directionHint)
            case let .ReplyCountEntry(_, isComments, count, presentationData):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatReplyCountItem(index: entry.entry.index, isComments: isComments, count: count, presentationData: presentationData, context: context), directionHint: entry.directionHint)
            case let .ChatInfoEntry(title, text, presentationData):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatBotInfoItem(title: title, text: text, controllerInteraction: controllerInteraction, presentationData: presentationData), directionHint: entry.directionHint)
            case let .SearchEntry(theme, strings):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListSearchItem(theme: theme, placeholder: strings.Common_Search, activate: {
                    controllerInteraction.openSearch()
                }), directionHint: entry.directionHint)
        }
    }
}

private func mappedChatHistoryViewListTransition(context: AccountContext, chatLocation: ChatLocation, associatedData: ChatMessageItemAssociatedData, controllerInteraction: ChatControllerInteraction, mode: ChatHistoryListMode, lastHeaderId: Int64, transition: ChatHistoryViewTransition, animationCallback: ChatHistoryListViewTransition.AnimationCallback? = nil) -> ChatHistoryListViewTransition {
    return ChatHistoryListViewTransition(historyView: transition.historyView, deleteItems: transition.deleteItems, insertItems: mappedInsertEntries(context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, mode: mode, lastHeaderId: lastHeaderId, entries: transition.insertEntries, reason: transition.reason), updateItems: mappedUpdateEntries(context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, mode: mode, lastHeaderId: lastHeaderId, entries: transition.updateEntries), options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange, initialData: transition.initialData, keyboardButtonsMessage: transition.keyboardButtonsMessage, cachedData: transition.cachedData, cachedDataMessages: transition.cachedDataMessages, readStateData: transition.readStateData, scrolledToIndex: transition.scrolledToIndex, scrolledToSomeIndex: transition.scrolledToSomeIndex, peerType: associatedData.automaticDownloadPeerType, networkType: associatedData.automaticDownloadNetworkType, animateIn: transition.animateIn, reason: transition.reason, flashIndicators: transition.flashIndicators, animationCallback: animationCallback)
}

private final class ChatHistoryTransactionOpaqueState {
    let historyView: ChatHistoryView
    
    init(historyView: ChatHistoryView) {
        self.historyView = historyView
    }
}

private func extractAssociatedData(chatLocation: ChatLocation, view: MessageHistoryView, automaticDownloadNetworkType: MediaAutoDownloadNetworkType, animatedEmojiStickers: [String: [StickerPackItem]], subject: ChatControllerSubject?) -> ChatMessageItemAssociatedData {
    var automaticMediaDownloadPeerType: MediaAutoDownloadPeerType = .channel
    var contactsPeerIds: Set<PeerId> = Set()
    var channelDiscussionGroup: ChatMessageItemAssociatedData.ChannelDiscussionGroupStatus = .unknown
    if case let .peer(peerId) = chatLocation {
        if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.SecretChat {
            var isContact = false
            for entry in view.additionalData {
                if case let .peerIsContact(_, value) = entry {
                    isContact = value
                    break
                }
            }
            automaticMediaDownloadPeerType = isContact ? .contact : .otherPrivate
        } else if peerId.namespace == Namespaces.Peer.CloudGroup {
            automaticMediaDownloadPeerType = .group
            
            for entry in view.entries {
                if entry.attributes.authorIsContact, let peerId = entry.message.author?.id {
                    contactsPeerIds.insert(peerId)
                }
            }
        } else if peerId.namespace == Namespaces.Peer.CloudChannel {
            for entry in view.additionalData {
                if case let .peer(_, value) = entry {
                    if let channel = value as? TelegramChannel, case .group = channel.info {
                        automaticMediaDownloadPeerType = .group
                    }
                } else if case let .cachedPeerData(dataPeerId, cachedData) = entry, dataPeerId == peerId {
                    if let cachedData = cachedData as? CachedChannelData {
                        switch cachedData.linkedDiscussionPeerId {
                        case let .known(value):
                            channelDiscussionGroup = .known(value)
                        case .unknown:
                            channelDiscussionGroup = .unknown
                        }
                    }
                }
            }
            if automaticMediaDownloadPeerType == .group {
                for entry in view.entries {
                    if entry.attributes.authorIsContact, let peerId = entry.message.author?.id {
                        contactsPeerIds.insert(peerId)
                    }
                }
            }
        }
    }
    
    let associatedData = ChatMessageItemAssociatedData(automaticDownloadPeerType: automaticMediaDownloadPeerType, automaticDownloadNetworkType: automaticDownloadNetworkType, isRecentActions: false, subject: subject, contactsPeerIds: contactsPeerIds, channelDiscussionGroup: channelDiscussionGroup, animatedEmojiStickers: animatedEmojiStickers)
    return associatedData
}

private extension ChatHistoryLocationInput {
    var isAtUpperBound: Bool {
        switch self.content {
        case .Navigation(index: .upperBound, anchorIndex: .upperBound, count: _, highlight: _):
                return true
        case .Scroll(index: .upperBound, anchorIndex: .upperBound, sourceIndex: _, scrollPosition: _, animated: _, highlight: _):
                return true
            default:
                return false
        }
    }
}

private struct ChatHistoryAnimatedEmojiConfiguration {
    static var defaultValue: ChatHistoryAnimatedEmojiConfiguration {
        return ChatHistoryAnimatedEmojiConfiguration(scale: 0.625)
    }
    
    public let scale: CGFloat
    
    fileprivate init(scale: CGFloat) {
        self.scale = scale
    }
    
    static func with(appConfiguration: AppConfiguration) -> ChatHistoryAnimatedEmojiConfiguration {
        if let data = appConfiguration.data, let scale = data["emojies_animated_zoom"] as? Double {
            return ChatHistoryAnimatedEmojiConfiguration(scale: CGFloat(scale))
        } else {
            return .defaultValue
        }
    }
}

private var nextClientId: Int32 = 1

public enum ChatHistoryListSource {
    case `default`
    case custom(messages: Signal<([Message], Int32, Bool), NoError>, messageId: MessageId, loadMore: (() -> Void)?)
}

public final class ChatHistoryListNode: ListView, ChatHistoryNode {
    private let context: AccountContext
    private let chatLocation: ChatLocation
    private let chatLocationContextHolder: Atomic<ChatLocationContextHolder?>
    private let subject: ChatControllerSubject?
    private let tagMask: MessageTags?
    private let controllerInteraction: ChatControllerInteraction
    private let mode: ChatHistoryListMode
    
    private var historyView: ChatHistoryView?
    
    private let historyDisposable = MetaDisposable()
    private let readHistoryDisposable = MetaDisposable()
    
    private let messageViewQueue = Queue(name: "ChatHistoryListNode processing")
    
    private var dequeuedInitialTransitionOnLayout = false
    private var enqueuedHistoryViewTransitions: [ChatHistoryListViewTransition] = []
    private var hasActiveTransition = false
    var layoutActionOnViewTransition: ((ChatHistoryListViewTransition) -> (ChatHistoryListViewTransition, ListViewUpdateSizeAndInsets?))?
    
    public let historyState = ValuePromise<ChatHistoryNodeHistoryState>()
    public var currentHistoryState: ChatHistoryNodeHistoryState?
    
    private let _initialData = Promise<ChatHistoryCombinedInitialData?>()
    private var didSetInitialData = false
    public var initialData: Signal<ChatHistoryCombinedInitialData?, NoError> {
        return self._initialData.get()
    }
    
    private let _cachedPeerDataAndMessages = Promise<(CachedPeerData?, [MessageId: Message]?)>()
    public var cachedPeerDataAndMessages: Signal<(CachedPeerData?, [MessageId: Message]?), NoError> {
        return self._cachedPeerDataAndMessages.get()
    }
    
    private var _buttonKeyboardMessage = Promise<Message?>(nil)
    private var currentButtonKeyboardMessage: Message?
    public var buttonKeyboardMessage: Signal<Message?, NoError> {
        return self._buttonKeyboardMessage.get()
    }
    
    private let maxVisibleIncomingMessageIndex = ValuePromise<MessageIndex>(ignoreRepeated: true)
    let canReadHistory = Promise<Bool>()
    private var canReadHistoryValue: Bool = false
    private var canReadHistoryDisposable: Disposable?
    
    private var chatHistoryLocationValue: ChatHistoryLocationInput? {
        didSet {
            if let chatHistoryLocationValue = self.chatHistoryLocationValue, chatHistoryLocationValue != oldValue {
                chatHistoryLocationPromise.set(chatHistoryLocationValue)
            }
        }
    }
    private let chatHistoryLocationPromise = ValuePromise<ChatHistoryLocationInput>()
    private var nextHistoryLocationId: Int32 = 1
    private func takeNextHistoryLocationId() -> Int32 {
        let id = self.nextHistoryLocationId
        self.nextHistoryLocationId += 5
        return id
    }
    
    private let galleryHiddenMesageAndMediaDisposable = MetaDisposable()
    
    private let messageProcessingManager = ChatMessageThrottledProcessingManager()
    private let messageReactionsProcessingManager = ChatMessageThrottledProcessingManager()
    private let seenLiveLocationProcessingManager = ChatMessageThrottledProcessingManager()
    private let unsupportedMessageProcessingManager = ChatMessageThrottledProcessingManager()
    private let refreshMediaProcessingManager = ChatMessageThrottledProcessingManager()
    private let messageMentionProcessingManager = ChatMessageThrottledProcessingManager(delay: 0.2)
    let prefetchManager: InChatPrefetchManager
    private var currentEarlierPrefetchMessages: [(Message, Media)] = []
    private var currentLaterPrefetchMessages: [(Message, Media)] = []
    private var currentPrefetchDirectionIsToLater: Bool = true
    
    private var maxVisibleMessageIndexReported: MessageIndex?
    var maxVisibleMessageIndexUpdated: ((MessageIndex) -> Void)?
    
    var scrolledToIndex: ((MessageHistoryAnchorIndex) -> Void)?
    var scrolledToSomeIndex: (() -> Void)?
    var beganDragging: (() -> Void)?
    
    private let hasVisiblePlayableItemNodesPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    var hasVisiblePlayableItemNodes: Signal<Bool, NoError> {
        return self.hasVisiblePlayableItemNodesPromise.get()
    }
    
    private var isInteractivelyScrollingValue: Bool = false
    private let isInteractivelyScrollingPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    var isInteractivelyScrolling: Signal<Bool, NoError> {
        return self.isInteractivelyScrollingPromise.get()
    }
    
    private var currentPresentationData: ChatPresentationData
    private var chatPresentationDataPromise: Promise<ChatPresentationData>
    private var presentationDataDisposable: Disposable?
    
    private let historyAppearsClearedPromise = ValuePromise<Bool>(false)
    var historyAppearsCleared: Bool = false {
        didSet {
            if self.historyAppearsCleared != oldValue {
                self.historyAppearsClearedPromise.set(self.historyAppearsCleared)
            }
        }
    }
    
    private let pendingUnpinnedAllMessagesPromise = ValuePromise<Bool>(false)
    var pendingUnpinnedAllMessages: Bool = false {
        didSet {
            if self.pendingUnpinnedAllMessages != oldValue {
                self.pendingUnpinnedAllMessagesPromise.set(self.pendingUnpinnedAllMessages)
            }
        }
    }
    
    private let pendingRemovedMessagesPromise = ValuePromise<Set<MessageId>>(Set())
    var pendingRemovedMessages: Set<MessageId> = Set() {
        didSet {
            if self.pendingRemovedMessages != oldValue {
                self.pendingRemovedMessagesPromise.set(self.pendingRemovedMessages)
            }
        }
    }
    
    private(set) var isScrollAtBottomPosition = false
    public var isScrollAtBottomPositionUpdated: (() -> Void)?
    
    private var interactiveReadActionDisposable: Disposable?
    
    public var contentPositionChanged: (ListViewVisibleContentOffset) -> Void = { _ in }
    
    public private(set) var loadState: ChatHistoryNodeLoadState?
    private var loadStateUpdated: ((ChatHistoryNodeLoadState, Bool) -> Void)?
    
    private var loadedMessagesFromCachedDataDisposable: Disposable?
    
    let isTopReplyThreadMessageShown = ValuePromise<Bool>(false, ignoreRepeated: true)
    let topVisibleMessageRange = ValuePromise<ChatTopVisibleMessageRange?>(nil, ignoreRepeated: true)
    
    private let clientId: Atomic<Int32>
    
    public init(context: AccountContext, chatLocation: ChatLocation, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>, tagMask: MessageTags?, source: ChatHistoryListSource = .default, subject: ChatControllerSubject?, controllerInteraction: ChatControllerInteraction, selectedMessages: Signal<Set<MessageId>?, NoError>, mode: ChatHistoryListMode = .bubbles) {
        var tagMask = tagMask
        var appendMessagesFromTheSameGroup = false
        if case .pinnedMessages = subject {
            tagMask = .pinned
            appendMessagesFromTheSameGroup = true
        }
        
        self.context = context
        self.chatLocation = chatLocation
        self.chatLocationContextHolder = chatLocationContextHolder
        self.subject = subject
        self.tagMask = tagMask
        self.controllerInteraction = controllerInteraction
        self.mode = mode
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.currentPresentationData = ChatPresentationData(theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper), fontSize: presentationData.chatFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: presentationData.disableAnimations, largeEmoji: presentationData.largeEmoji, chatBubbleCorners: presentationData.chatBubbleCorners, animatedEmojiScale: 1.0)
        
        self.chatPresentationDataPromise = Promise(self.currentPresentationData)
        
        self.prefetchManager = InChatPrefetchManager(context: context)
        
        let clientId = Atomic<Int32>(value: nextClientId)
        self.clientId = clientId
        nextClientId += 1
        
        super.init()
        
        self.dynamicBounceEnabled = !self.currentPresentationData.disableAnimations
        self.experimentalSnapScrollToItem = true
        
        //self.debugInfo = true
        
        self.messageProcessingManager.process = { [weak context] messageIds in
            context?.account.viewTracker.updateViewCountForMessageIds(messageIds: messageIds, clientId: clientId.with { $0 })
        }
        self.messageReactionsProcessingManager.process = { [weak context] messageIds in
            context?.account.viewTracker.updateReactionsForMessageIds(messageIds: messageIds)
        }
        self.seenLiveLocationProcessingManager.process = { [weak context] messageIds in
            context?.account.viewTracker.updateSeenLiveLocationForMessageIds(messageIds: messageIds)
        }
        self.unsupportedMessageProcessingManager.process = { [weak context] messageIds in
            context?.account.viewTracker.updateUnsupportedMediaForMessageIds(messageIds: messageIds)
        }
        self.refreshMediaProcessingManager.process = { [weak context] messageIds in
            context?.account.viewTracker.refreshSecretMediaMediaForMessageIds(messageIds: messageIds)
        }
        
        self.messageMentionProcessingManager.process = { [weak self, weak context] messageIds in
            if let strongSelf = self {
                let _ = (strongSelf.canReadHistory.get()
                |> take(1)).start(next: { [weak context] canReadHistory in
                    if canReadHistory {
                        context?.account.viewTracker.updateMarkMentionsSeenForMessageIds(messageIds: messageIds)
                    }
                })
            }
        }
        
        self.preloadPages = false
        switch self.mode {
            case .bubbles:
                self.transform = CATransform3DMakeRotation(CGFloat(Double.pi), 0.0, 0.0, 1.0)
            case .list:
                break
        }
        //self.snapToBottomInsetUntilFirstInteraction = true
        
        let messageViewQueue = Queue.mainQueue() //self.messageViewQueue
        
        let fixedCombinedReadStates = Atomic<MessageHistoryViewReadState?>(value: nil)
        
        var isScheduledMessages = false
        if let subject = subject, case .scheduledMessages = subject {
            isScheduledMessages = true
        }
        var isAuxiliaryChat = isScheduledMessages
        if case .replyThread = chatLocation {
            isAuxiliaryChat = true
        }
        
        var additionalData: [AdditionalMessageHistoryViewData] = []
        if case let .peer(peerId) = chatLocation {
            additionalData.append(.cachedPeerData(peerId))
            additionalData.append(.cachedPeerDataMessages(peerId))
            additionalData.append(.peerNotificationSettings(peerId))
            if peerId.namespace == Namespaces.Peer.CloudChannel {
                additionalData.append(.cacheEntry(cachedChannelAdminRanksEntryId(peerId: peerId)))
                additionalData.append(.peer(peerId))
            }
            if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.SecretChat {
                additionalData.append(.peerIsContact(peerId))
            }
        }
        if !isAuxiliaryChat {
            additionalData.append(.totalUnreadState)
        }
        if case let .replyThread(replyThreadMessage) = chatLocation {
            additionalData.append(.cachedPeerData(replyThreadMessage.messageId.peerId))
            additionalData.append(.peerNotificationSettings(replyThreadMessage.messageId.peerId))
            if replyThreadMessage.messageId.peerId.namespace == Namespaces.Peer.CloudChannel {
                additionalData.append(.cacheEntry(cachedChannelAdminRanksEntryId(peerId: replyThreadMessage.messageId.peerId)))
                additionalData.append(.peer(replyThreadMessage.messageId.peerId))
            }
            
            additionalData.append(.message(replyThreadMessage.effectiveTopId))
        }

        let currentViewVersion = Atomic<Int?>(value: nil)
        
        let historyViewUpdate: Signal<(ChatHistoryViewUpdate, Int), NoError>
        var isFirstTime = true
        if case let .custom(messages, at, _) = source {
            historyViewUpdate = messages
            |> map { messages, _, hasMore in
                let version = currentViewVersion.modify({ value in
                    if let value = value {
                        return value + 1
                    } else {
                        return 0
                    }
                })!
                
                let scrollPosition: ChatHistoryViewScrollPosition?
                if isFirstTime, let messageIndex = messages.first(where: { $0.id == at })?.index {
                    scrollPosition = .index(index: .message(messageIndex), position: .center(.bottom), directionHint: .Down, animated: false, highlight: false)
                    isFirstTime = false
                } else {
                    scrollPosition = nil
                }
                
                return (ChatHistoryViewUpdate.HistoryView(view: MessageHistoryView(tagMask: nil, namespaces: .all, entries: messages.reversed().map { MessageHistoryEntry(message: $0, isRead: false, location: nil, monthLocation: nil, attributes: MutableMessageHistoryEntryAttributes(authorIsContact: false)) }, holeEarlier: hasMore), type: .Generic(type: ViewUpdateType.Initial), scrollPosition: scrollPosition, flashIndicators: false, originalScrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: nil, buttonKeyboardMessage: nil, cachedData: nil, cachedDataMessages: nil, readStateData: nil), id: 0), version)
            }
        } else {
            historyViewUpdate = self.chatHistoryLocationPromise.get()
            |> distinctUntilChanged
            |> mapToSignal { location in
                return chatHistoryViewForLocation(location, context: context, chatLocation: chatLocation, chatLocationContextHolder: chatLocationContextHolder, scheduled: isScheduledMessages, fixedCombinedReadStates: fixedCombinedReadStates.with { $0 }, tagMask: tagMask, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, additionalData: additionalData)
                |> beforeNext { viewUpdate in
                    switch viewUpdate {
                        case let .HistoryView(view, _, _, _, _, _, _):
                            let _ = fixedCombinedReadStates.swap(view.fixedReadStates)
                        default:
                            break
                    }
                }
            }
            |> map { view -> (ChatHistoryViewUpdate, Int) in
                let version = currentViewVersion.modify({ value in
                    if let value = value {
                        return value + 1
                    } else {
                        return 0
                    }
                })!
                return (view, version)
            }
        }
        
        let previousView = Atomic<(ChatHistoryView, Int, Set<MessageId>?)?>(value: nil)
        let automaticDownloadNetworkType = context.account.networkType
        |> map { type -> MediaAutoDownloadNetworkType in
            switch type {
                case .none, .wifi:
                    return .wifi
                case .cellular:
                    return .cellular
            }
        }
        |> distinctUntilChanged
                
        let animatedEmojiStickers = loadedStickerPack(postbox: context.account.postbox, network: context.account.network, reference: .animatedEmoji, forceActualized: false)
        |> map { animatedEmoji -> [String: [StickerPackItem]] in
            var animatedEmojiStickers: [String: [StickerPackItem]] = [:]
            switch animatedEmoji {
                case let .result(_, items, _):
                    for case let item as StickerPackItem in items {
                        if let emoji = item.getStringRepresentationsOfIndexKeys().first {
                            animatedEmojiStickers[emoji.basicEmoji.0] = [item]
                            let strippedEmoji = emoji.basicEmoji.0.strippedEmoji
                            if animatedEmojiStickers[strippedEmoji] == nil {
                                animatedEmojiStickers[strippedEmoji] = [item]
                            }
                        }
                    }
                default:
                    break
            }
            return animatedEmojiStickers
        }
        
        let previousHistoryAppearsCleared = Atomic<Bool?>(value: nil)
                
        let updatingMedia = context.account.pendingUpdateMessageManager.updatingMessageMedia
        |> map { value -> [MessageId: ChatUpdatingMessageMedia] in
            var result = value
            for id in value.keys {
                if id.peerId != chatLocation.peerId {
                    result.removeValue(forKey: id)
                }
            }
            return result
        }
        |> distinctUntilChanged
        
        let customChannelDiscussionReadState: Signal<MessageId?, NoError>
        if case let .peer(peerId) = chatLocation, peerId.namespace == Namespaces.Peer.CloudChannel {
            let cachedDataKey = PostboxViewKey.cachedPeerData(peerId: chatLocation.peerId)
            let peerKey = PostboxViewKey.basicPeer(peerId)
            customChannelDiscussionReadState = context.account.postbox.combinedView(keys: [cachedDataKey, peerKey])
            |> mapToSignal { views -> Signal<PeerId?, NoError> in
                guard let view = views.views[cachedDataKey] as? CachedPeerDataView else {
                    return .single(nil)
                }
                guard let peer = (views.views[peerKey] as? BasicPeerView)?.peer as? TelegramChannel, case .broadcast = peer.info else {
                    return .single(nil)
                }
                guard let cachedData = view.cachedPeerData as? CachedChannelData else {
                    return .single(nil)
                }
                guard case let .known(value) = cachedData.linkedDiscussionPeerId else {
                    return .single(nil)
                }
                return .single(value)
            }
            |> distinctUntilChanged
            |> mapToSignal { discussionPeerId -> Signal<MessageId?, NoError> in
                guard let discussionPeerId = discussionPeerId else {
                    return .single(nil)
                }
                let key = PostboxViewKey.combinedReadState(peerId: discussionPeerId)
                return context.account.postbox.combinedView(keys: [key])
                |> map { views -> MessageId? in
                    guard let view = views.views[key] as? CombinedReadStateView else {
                        return nil
                    }
                    guard let state = view.state else {
                        return nil
                    }
                    for (namespace, namespaceState) in state.states {
                        if namespace == Namespaces.Message.Cloud {
                            switch namespaceState {
                            case let .idBased(maxIncomingReadId, _, _, _, _):
                                return MessageId(peerId: discussionPeerId, namespace: Namespaces.Message.Cloud, id: maxIncomingReadId)
                            default:
                                break
                            }
                        }
                    }
                    return nil
                }
                |> distinctUntilChanged
            }
        } else {
            customChannelDiscussionReadState = .single(nil)
        }
        
        let customThreadOutgoingReadState: Signal<MessageId?, NoError>
        if case .replyThread = chatLocation {
            customThreadOutgoingReadState = context.chatLocationOutgoingReadState(for: chatLocation, contextHolder: chatLocationContextHolder)
        } else {
            customThreadOutgoingReadState = .single(nil)
        }
        
        let historyViewTransitionDisposable = combineLatest(queue: messageViewQueue,
            historyViewUpdate,
            self.chatPresentationDataPromise.get(),
            selectedMessages,
            updatingMedia,
            automaticDownloadNetworkType,
            self.historyAppearsClearedPromise.get(),
            self.pendingUnpinnedAllMessagesPromise.get(),
            self.pendingRemovedMessagesPromise.get(),
            animatedEmojiStickers,
            customChannelDiscussionReadState,
            customThreadOutgoingReadState
        ).start(next: { [weak self] update, chatPresentationData, selectedMessages, updatingMedia, networkType, historyAppearsCleared, pendingUnpinnedAllMessages, pendingRemovedMessages, animatedEmojiStickers, customChannelDiscussionReadState, customThreadOutgoingReadState in
            func applyHole() {
                Queue.mainQueue().async {
                    if let strongSelf = self {
                        let historyView = (strongSelf.opaqueTransactionState as? ChatHistoryTransactionOpaqueState)?.historyView
                        let displayRange = strongSelf.displayedItemRange
                        if let filteredEntries = historyView?.filteredEntries, let visibleRange = displayRange.visibleRange {
                            let lastEntry = filteredEntries[filteredEntries.count - 1 - visibleRange.lastIndex]
                            
                            strongSelf.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Navigation(index: .message(lastEntry.index), anchorIndex: .message(lastEntry.index), count: historyMessageCount, highlight: false), id: (strongSelf.chatHistoryLocationValue?.id).flatMap({ $0 + 1 }) ?? 0)
                        } else {
                            if let subject = subject, case let .message(messageId, highlight) = subject {
                                strongSelf.chatHistoryLocationValue = ChatHistoryLocationInput(content: .InitialSearch(location: .id(messageId), count: 60, highlight: highlight), id: (strongSelf.chatHistoryLocationValue?.id).flatMap({ $0 + 1 }) ?? 0)
                            } else if let subject = subject, case let .pinnedMessages(maybeMessageId) = subject, let messageId = maybeMessageId {
                                strongSelf.chatHistoryLocationValue = ChatHistoryLocationInput(content: .InitialSearch(location: .id(messageId), count: 60, highlight: true), id: (strongSelf.chatHistoryLocationValue?.id).flatMap({ $0 + 1 }) ?? 0)
                            } else if var chatHistoryLocation = strongSelf.chatHistoryLocationValue {
                                chatHistoryLocation.id += 1
                                strongSelf.chatHistoryLocationValue = chatHistoryLocation
                            } else {
                                strongSelf.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Initial(count: 60), id: (strongSelf.chatHistoryLocationValue?.id).flatMap({ $0 + 1 }) ?? 0)
                            }
                        }
                    }
                }
            }
            
            let initialData: ChatHistoryCombinedInitialData?
            switch update.0 {
            case let .Loading(combinedInitialData, type):
                if case .Generic(.FillHole) = type {
                    applyHole()
                    return
                }
                
                initialData = combinedInitialData
                Queue.mainQueue().async {
                    if let strongSelf = self {
                        if !strongSelf.didSetInitialData {
                            strongSelf.didSetInitialData = true
                            var combinedInitialData = combinedInitialData
                            combinedInitialData?.cachedData = nil
                            strongSelf._initialData.set(.single(combinedInitialData))
                        }
                        
                        let cachedData = initialData?.cachedData
                        let cachedDataMessages = initialData?.cachedDataMessages
                        
                        strongSelf._cachedPeerDataAndMessages.set(.single((cachedData, cachedDataMessages)))
                        
                        let loadState: ChatHistoryNodeLoadState = .loading
                        if strongSelf.loadState != loadState {
                            strongSelf.loadState = loadState
                            strongSelf.loadStateUpdated?(loadState, false)
                        }
                        
                        let historyState: ChatHistoryNodeHistoryState = .loading
                        if strongSelf.currentHistoryState != historyState {
                            strongSelf.currentHistoryState = historyState
                            strongSelf.historyState.set(historyState)
                        }
                    }
                }
                return
            case let .HistoryView(view, type, scrollPosition, flashIndicators, originalScrollPosition, data, id):
                if case .Generic(.FillHole) = type {
                    applyHole()
                    return
                }
                
                initialData = data
                var updatedScrollPosition = scrollPosition
                
                var reverse = false
                var includeSearchEntry = false
                if case let .list(search, reverseValue, _, _, _) = mode {
                    includeSearchEntry = search
                    reverse = reverseValue
                }
                
                let associatedData = extractAssociatedData(chatLocation: chatLocation, view: view, automaticDownloadNetworkType: networkType, animatedEmojiStickers: animatedEmojiStickers, subject: subject)
                
                let filteredEntries = chatHistoryEntriesForView(location: chatLocation, view: view, includeUnreadEntry: mode == .bubbles, includeEmptyEntry: mode == .bubbles && tagMask == nil, includeChatInfoEntry: mode == .bubbles, includeSearchEntry: includeSearchEntry && tagMask != nil, reverse: reverse, groupMessages: mode == .bubbles, selectedMessages: selectedMessages, presentationData: chatPresentationData, historyAppearsCleared: historyAppearsCleared, pendingUnpinnedAllMessages: pendingUnpinnedAllMessages, pendingRemovedMessages: pendingRemovedMessages, associatedData: associatedData, updatingMedia: updatingMedia, customChannelDiscussionReadState: customChannelDiscussionReadState, customThreadOutgoingReadState: customThreadOutgoingReadState)
                let lastHeaderId = filteredEntries.last.flatMap { listMessageDateHeaderId(timestamp: $0.index.timestamp) } ?? 0
                let processedView = ChatHistoryView(originalView: view, filteredEntries: filteredEntries, associatedData: associatedData, lastHeaderId: lastHeaderId, id: id)
                let previousValueAndVersion = previousView.swap((processedView, update.1, selectedMessages))
                let previous = previousValueAndVersion?.0
                let previousSelectedMessages = previousValueAndVersion?.2
                
                if let previousVersion = previousValueAndVersion?.1 {
                    if !GlobalExperimentalSettings.isAppStoreBuild {
                        precondition(update.1 >= previousVersion)
                    }
                    assert(update.1 >= previousVersion)
                }
                
                if scrollPosition == nil, let originalScrollPosition = originalScrollPosition {
                    switch originalScrollPosition {
                    case let .index(index, position, _, _, highlight):
                        if case .upperBound = index {
                            if let previous = previous, previous.filteredEntries.isEmpty {
                                updatedScrollPosition = .index(index: index, position: position, directionHint: .Down, animated: false, highlight: highlight)
                            }
                        }
                    default:
                        break
                    }
                }
                
                let reason: ChatHistoryViewTransitionReason
                
                let previousHistoryAppearsClearedValue = previousHistoryAppearsCleared.swap(historyAppearsCleared)
                if previousHistoryAppearsClearedValue != nil && previousHistoryAppearsClearedValue != historyAppearsCleared && !historyAppearsCleared {
                    reason = ChatHistoryViewTransitionReason.Initial(fadeIn: !processedView.filteredEntries.isEmpty)
                } else if let previous = previous, previous.id == processedView.id, previous.originalView.entries == processedView.originalView.entries {
                    reason = ChatHistoryViewTransitionReason.InteractiveChanges
                    updatedScrollPosition = nil
                } else {
                    switch type {
                        case let .Initial(fadeIn):
                            reason = ChatHistoryViewTransitionReason.Initial(fadeIn: fadeIn)
                        case let .Generic(genericType):
                            switch genericType {
                                case .InitialUnread, .Initial:
                                    reason = ChatHistoryViewTransitionReason.Initial(fadeIn: false)
                                case .Generic:
                                    reason = ChatHistoryViewTransitionReason.InteractiveChanges
                                case .UpdateVisible:
                                    reason = ChatHistoryViewTransitionReason.Reload
                                case .FillHole:
                                    reason = ChatHistoryViewTransitionReason.HoleReload
                            }
                    }
                }
                let rawTransition = preparedChatHistoryViewTransition(from: previous, to: processedView, reason: reason, reverse: reverse, chatLocation: chatLocation, controllerInteraction: controllerInteraction, scrollPosition: updatedScrollPosition, initialData: initialData?.initialData, keyboardButtonsMessage: view.topTaggedMessages.first, cachedData: initialData?.cachedData, cachedDataMessages: initialData?.cachedDataMessages, readStateData: initialData?.readStateData, flashIndicators: flashIndicators, updatedMessageSelection: previousSelectedMessages != selectedMessages)
                let mappedTransition = mappedChatHistoryViewListTransition(context: context, chatLocation: chatLocation, associatedData: associatedData, controllerInteraction: controllerInteraction, mode: mode, lastHeaderId: lastHeaderId, transition: rawTransition)
                Queue.mainQueue().async {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.enqueueHistoryViewTransition(mappedTransition)
                }
            }
        })
        
        self.historyDisposable.set(historyViewTransitionDisposable)
        
        let previousMaxIncomingMessageIndexByNamespace = Atomic<[MessageId.Namespace: MessageIndex]>(value: [:])
        let readHistory = combineLatest(self.maxVisibleIncomingMessageIndex.get(), self.canReadHistory.get())
        |> map { messageIndex, canRead in
            if canRead {
                var apply = false
                let _ = previousMaxIncomingMessageIndexByNamespace.modify { dict in
                    let previousIndex = dict[messageIndex.id.namespace]
                    if previousIndex == nil || previousIndex! < messageIndex {
                        apply = true
                        var dict = dict
                        dict[messageIndex.id.namespace] = messageIndex
                        return dict
                    }
                    return dict
                }
                if apply {
                    switch chatLocation {
                    case .peer, .replyThread:
                        if !context.sharedContext.immediateExperimentalUISettings.skipReadHistory {
                            context.applyMaxReadIndex(for: chatLocation, contextHolder: chatLocationContextHolder, messageIndex: messageIndex)
                        }
                    }
                }
            }
        }
        
        self.readHistoryDisposable.set(readHistory.start())
        
        self.canReadHistoryDisposable = (self.canReadHistory.get() |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                if strongSelf.canReadHistoryValue != value {
                    strongSelf.canReadHistoryValue = value
                    strongSelf.updateReadHistoryActions()
                }
            }
        })
        
        if let subject = subject, case let .message(messageId, highlight) = subject {
            self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .InitialSearch(location: .id(messageId), count: 60, highlight: highlight), id: 0)
        } else if let subject = subject, case let .pinnedMessages(maybeMessageId) = subject, let messageId = maybeMessageId {
            self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .InitialSearch(location: .id(messageId), count: 60, highlight: true), id: 0)
        } else {
            self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Initial(count: 60), id: 0)
        }
        self.chatHistoryLocationPromise.set(self.chatHistoryLocationValue!)
        
        self.generalScrollDirectionUpdated = { [weak self] direction in
            guard let strongSelf = self else {
                return
            }
            let prefetchDirectionIsToLater = direction == .up
            if strongSelf.currentPrefetchDirectionIsToLater != prefetchDirectionIsToLater {
                strongSelf.currentPrefetchDirectionIsToLater = prefetchDirectionIsToLater
                if strongSelf.currentPrefetchDirectionIsToLater {
                    strongSelf.prefetchManager.updateMessages(strongSelf.currentLaterPrefetchMessages, directionIsToLater: strongSelf.currentPrefetchDirectionIsToLater)
                } else {
                    strongSelf.prefetchManager.updateMessages(strongSelf.currentEarlierPrefetchMessages, directionIsToLater: strongSelf.currentPrefetchDirectionIsToLater)
                }
            }
        }
        
        self.displayedItemRangeChanged = { [weak self] displayedRange, opaqueTransactionState in
            if let strongSelf = self, let transactionState = opaqueTransactionState as? ChatHistoryTransactionOpaqueState {
                strongSelf.processDisplayedItemRangeChanged(displayedRange: displayedRange, transactionState: transactionState)
            }
        }
        
        let appConfiguration = context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
        |> take(1)
        |> map { view in
            return view.values[PreferencesKeys.appConfiguration] as? AppConfiguration ?? .defaultValue
        }
        
        self.presentationDataDisposable = (
            combineLatest(queue: .mainQueue(),
                context.sharedContext.presentationData,
                appConfiguration)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData, appConfiguration in
            if let strongSelf = self {
                let previousTheme = strongSelf.currentPresentationData.theme
                let previousStrings = strongSelf.currentPresentationData.strings
                let previousWallpaper = strongSelf.currentPresentationData.theme.wallpaper
                let previousDisableAnimations = strongSelf.currentPresentationData.disableAnimations
                let previousAnimatedEmojiScale = strongSelf.currentPresentationData.animatedEmojiScale
                
                let animatedEmojiConfig = ChatHistoryAnimatedEmojiConfiguration.with(appConfiguration: appConfiguration)
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings || previousWallpaper != presentationData.chatWallpaper || previousDisableAnimations != presentationData.disableAnimations || previousAnimatedEmojiScale != animatedEmojiConfig.scale {
                    let themeData = ChatPresentationThemeData(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper)
                    let chatPresentationData = ChatPresentationData(theme: themeData, fontSize: presentationData.chatFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: presentationData.disableAnimations, largeEmoji: presentationData.largeEmoji, chatBubbleCorners: presentationData.chatBubbleCorners, animatedEmojiScale: animatedEmojiConfig.scale)
                    
                    strongSelf.currentPresentationData = chatPresentationData
                    strongSelf.dynamicBounceEnabled = !presentationData.disableAnimations
                    
                    strongSelf.forEachItemHeaderNode { itemHeaderNode in
                        if let dateNode = itemHeaderNode as? ChatMessageDateHeaderNode {
                            dateNode.updatePresentationData(chatPresentationData, context: context)
                        } else if let dateNode = itemHeaderNode as? ListMessageDateHeaderNode {
                            dateNode.updateThemeAndStrings(theme: presentationData.theme, strings: presentationData.strings)
                        }
                    }
                    strongSelf.chatPresentationDataPromise.set(.single(chatPresentationData))
                }
            }
        })
        
        self.visibleContentOffsetChanged = { [weak self] offset in
            if let strongSelf = self {
                strongSelf.contentPositionChanged(offset)
                
                if strongSelf.tagMask == nil {
                    var atBottom = false
                    switch offset {
                        case let .known(offsetValue):
                            if offsetValue.isLessThanOrEqualTo(0.0) {
                                atBottom = true
                            }
                        default:
                            break
                    }
                    
                    if atBottom != strongSelf.isScrollAtBottomPosition {
                        strongSelf.isScrollAtBottomPosition = atBottom
                        strongSelf.updateReadHistoryActions()
                        
                        strongSelf.isScrollAtBottomPositionUpdated?()
                    }
                }
            }
        }
        
        self.loadedMessagesFromCachedDataDisposable = (self._cachedPeerDataAndMessages.get() |> map { dataAndMessages -> MessageId? in
            return dataAndMessages.0?.messageIds.first
        } |> distinctUntilChanged(isEqual: { $0 == $1 })
        |> mapToSignal { messageId -> Signal<Void, NoError> in
            if let messageId = messageId {
                return getMessagesLoadIfNecessary([messageId], postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId) |> map { _ -> Void in return Void() }
            } else {
                return .complete()
            }
        }).start()
        
        self.beganInteractiveDragging = { [weak self] in
            self?.isInteractivelyScrollingValue = true
            self?.isInteractivelyScrollingPromise.set(true)
            self?.beganDragging?()
        }
        
        self.didEndScrolling = { [weak self] in
            self?.isInteractivelyScrollingValue = false
            self?.isInteractivelyScrollingPromise.set(false)
        }
        
        let selectionRecognizer = ChatHistoryListSelectionRecognizer(target: self, action: #selector(self.selectionPanGesture(_:)))
        selectionRecognizer.shouldBegin = { [weak self] in
            guard let strongSelf = self else {
                return false
            }
            if case .pinnedMessages = strongSelf.subject {
                return false
            }
            return true
        }
        self.view.addGestureRecognizer(selectionRecognizer)
    }
    
    deinit {
        self.historyDisposable.dispose()
        self.readHistoryDisposable.dispose()
        self.interactiveReadActionDisposable?.dispose()
        self.canReadHistoryDisposable?.dispose()
        self.loadedMessagesFromCachedDataDisposable?.dispose()
    }
    
    public func setLoadStateUpdated(_ f: @escaping (ChatHistoryNodeLoadState, Bool) -> Void) {
        self.loadStateUpdated = f
    }
    
    func refreshPollActionsForVisibleMessages() {
        let _ = self.clientId.swap(nextClientId)
        nextClientId += 1
        
        self.updateVisibleItemRange(force: true)
    }
    
    func refocusOnUnreadMessagesIfNeeded() {
        self.forEachItemNode({ itemNode in
            if let itemNode = itemNode as? ChatUnreadItemNode {
                self.ensureItemNodeVisible(itemNode, animated: false, overflow: 0.0, curve: .Default(duration: nil))
            }
        })
    }
    
    private func processDisplayedItemRangeChanged(displayedRange: ListViewDisplayedItemRange, transactionState: ChatHistoryTransactionOpaqueState) {
        let historyView = transactionState.historyView
        var isTopReplyThreadMessageShownValue = false
        var topVisibleMessageRange: ChatTopVisibleMessageRange?
        if let visible = displayedRange.visibleRange {
            let indexRange = (historyView.filteredEntries.count - 1 - visible.lastIndex, historyView.filteredEntries.count - 1 - visible.firstIndex)
            if indexRange.0 > indexRange.1 {
                assert(false)
                return
            }
            
            let readIndexRange = (0, historyView.filteredEntries.count - 1 - visible.firstIndex)
            
            let toEarlierRange = (0, historyView.filteredEntries.count - 1 - visible.lastIndex - 1)
            let toLaterRange = (historyView.filteredEntries.count - 1 - (visible.firstIndex - 1), historyView.filteredEntries.count - 1)
            
            var messageIdsWithViewCount: [MessageId] = []
            var messageIdsWithUpdateableReactions: [MessageId] = []
            var messageIdsWithLiveLocation: [MessageId] = []
            var messageIdsWithUnsupportedMedia: [MessageId] = []
            var messageIdsWithRefreshMedia: [MessageId] = []
            var messageIdsWithUnseenPersonalMention: [MessageId] = []
            var messagesWithPreloadableMediaToEarlier: [(Message, Media)] = []
            var messagesWithPreloadableMediaToLater: [(Message, Media)] = []
            
            if indexRange.0 <= indexRange.1 {
                for i in (indexRange.0 ... indexRange.1) {
                    switch historyView.filteredEntries[i] {
                    case let .MessageEntry(message, _, _, _, _, _):
                        var hasUnconsumedMention = false
                        var hasUnconsumedContent = false
                        if message.tags.contains(.unseenPersonalMessage) {
                            for attribute in message.attributes {
                                if let attribute = attribute as? ConsumablePersonalMentionMessageAttribute, !attribute.pending {
                                    hasUnconsumedMention = true
                                }
                            }
                        }
                        var contentRequiredValidation = false
                        var mediaRequiredValidation = false
                        for attribute in message.attributes {
                            if attribute is ViewCountMessageAttribute {
                                if message.id.namespace == Namespaces.Message.Cloud {
                                    messageIdsWithViewCount.append(message.id)
                                }
                            } else if attribute is ReplyThreadMessageAttribute {
                                if message.id.namespace == Namespaces.Message.Cloud {
                                    messageIdsWithViewCount.append(message.id)
                                }
                            } else if let attribute = attribute as? ConsumableContentMessageAttribute, !attribute.consumed {
                                hasUnconsumedContent = true
                            } else if let _ = attribute as? ContentRequiresValidationMessageAttribute {
                                contentRequiredValidation = true
                            }
                        }
                        var isAction = false
                        for media in message.media {
                            if let _ = media as? TelegramMediaUnsupported {
                                contentRequiredValidation = true
                            } else if message.flags.contains(.Incoming), let media = media as? TelegramMediaMap, let liveBroadcastingTimeout = media.liveBroadcastingTimeout {
                                let timestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                                if message.timestamp + liveBroadcastingTimeout > timestamp {
                                    messageIdsWithLiveLocation.append(message.id)
                                }
                            } else if let _ = media as? TelegramMediaAction {
                                isAction = true
                            } else if let telegramFile = media as? TelegramMediaFile {
                                if telegramFile.isAnimatedSticker, (message.id.peerId.namespace == Namespaces.Peer.SecretChat || !telegramFile.previewRepresentations.isEmpty), let size = telegramFile.size, size > 0 && size <= 128 * 1024 {
                                    if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                                        if telegramFile.fileId.namespace == Namespaces.Media.CloudFile {
                                            var isValidated = false
                                            attributes: for attribute in telegramFile.attributes {
                                                if case .hintIsValidated = attribute {
                                                    isValidated = true
                                                    break attributes
                                                }
                                            }
                                            
                                            if !isValidated {
                                                mediaRequiredValidation = true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        if !isAction && message.id.peerId.namespace == Namespaces.Peer.CloudChannel {
                            messageIdsWithUpdateableReactions.append(message.id)
                        }
                        if contentRequiredValidation {
                            messageIdsWithUnsupportedMedia.append(message.id)
                        }
                        if mediaRequiredValidation {
                            messageIdsWithRefreshMedia.append(message.id)
                        }
                        if hasUnconsumedMention && !hasUnconsumedContent {
                            messageIdsWithUnseenPersonalMention.append(message.id)
                        }
                        if case let .replyThread(replyThreadMessage) = self.chatLocation, replyThreadMessage.effectiveTopId == message.id {
                            isTopReplyThreadMessageShownValue = true
                        }
                        if let topVisibleMessageRangeValue = topVisibleMessageRange {
                            topVisibleMessageRange = ChatTopVisibleMessageRange(lowerBound: topVisibleMessageRangeValue.lowerBound, upperBound: message.id, isLast: i == historyView.filteredEntries.count - 1)
                        } else {
                            topVisibleMessageRange = ChatTopVisibleMessageRange(lowerBound: message.id, upperBound: message.id, isLast: i == historyView.filteredEntries.count - 1)
                        }
                    case let .MessageGroupEntry(_, messages, _):
                        for (message, _, _, _) in messages {
                            var hasUnconsumedMention = false
                            var hasUnconsumedContent = false
                            if message.tags.contains(.unseenPersonalMessage) {
                                for attribute in message.attributes {
                                    if let attribute = attribute as? ConsumablePersonalMentionMessageAttribute, !attribute.pending {
                                        hasUnconsumedMention = true
                                    }
                                }
                            }
                            for attribute in message.attributes {
                                if attribute is ViewCountMessageAttribute {
                                    if message.id.namespace == Namespaces.Message.Cloud {
                                        messageIdsWithViewCount.append(message.id)
                                    }
                                } else if attribute is ReplyThreadMessageAttribute {
                                    if message.id.namespace == Namespaces.Message.Cloud {
                                        messageIdsWithViewCount.append(message.id)
                                    }
                                } else if let attribute = attribute as? ConsumableContentMessageAttribute, !attribute.consumed {
                                    hasUnconsumedContent = true
                                }
                            }
                            if hasUnconsumedMention && !hasUnconsumedContent {
                                messageIdsWithUnseenPersonalMention.append(message.id)
                            }
                            if case let .replyThread(replyThreadMessage) = self.chatLocation, replyThreadMessage.effectiveTopId == message.id {
                                isTopReplyThreadMessageShownValue = true
                            }
                            if let topVisibleMessageRangeValue = topVisibleMessageRange {
                                topVisibleMessageRange = ChatTopVisibleMessageRange(lowerBound: topVisibleMessageRangeValue.lowerBound, upperBound: message.id, isLast: i == historyView.filteredEntries.count - 1)
                            } else {
                                topVisibleMessageRange = ChatTopVisibleMessageRange(lowerBound: message.id, upperBound: message.id, isLast: i == historyView.filteredEntries.count - 1)
                            }
                        }
                    default:
                        break
                    }
                }
            }
            
            func addMediaToPrefetch(_ message: Message, _ media: Media, _ messages: inout [(Message, Media)]) -> Bool {
                if media is TelegramMediaImage || media is TelegramMediaFile {
                    messages.append((message, media))
                }
                if messages.count >= 3 {
                    return false
                } else {
                    return true
                }
            }
            
            var toEarlierMediaMessages: [(Message, Media)] = []
            if toEarlierRange.0 <= toEarlierRange.1 {
                outer: for i in (toEarlierRange.0 ... toEarlierRange.1).reversed() {
                    switch historyView.filteredEntries[i] {
                    case let .MessageEntry(message, _, _, _, _, _):
                        for media in message.media {
                            if !addMediaToPrefetch(message, media, &toEarlierMediaMessages) {
                                break outer
                            }
                        }
                    case let .MessageGroupEntry(_, messages, _):
                        for (message, _, _, _) in messages {
                            var stop = false
                            for media in message.media {
                                if !addMediaToPrefetch(message, media, &toEarlierMediaMessages) {
                                    stop = true
                                }
                            }
                            if stop {
                                break outer
                            }
                        }
                    default:
                        break
                    }
                }
            }
            
            var toLaterMediaMessages: [(Message, Media)] = []
            if toLaterRange.0 <= toLaterRange.1 {
                outer: for i in (toLaterRange.0 ... toLaterRange.1) {
                    switch historyView.filteredEntries[i] {
                    case let .MessageEntry(message, _, _, _, _, _):
                        for media in message.media {
                            if !addMediaToPrefetch(message, media, &toLaterMediaMessages) {
                                break outer
                            }
                        }
                    case let .MessageGroupEntry(_, messages, _):
                        for (message, _, _, _) in messages {
                            for media in message.media {
                                if !addMediaToPrefetch(message, media, &toLaterMediaMessages) {
                                    break outer
                                }
                            }
                        }
                    default:
                        break
                    }
                }
            }
            
            if !messageIdsWithViewCount.isEmpty {
                self.messageProcessingManager.add(messageIdsWithViewCount)
            }
            if !messageIdsWithUpdateableReactions.isEmpty {
                self.messageReactionsProcessingManager.add(messageIdsWithUpdateableReactions)
            }
            if !messageIdsWithLiveLocation.isEmpty {
                self.seenLiveLocationProcessingManager.add(messageIdsWithLiveLocation)
            }
            if !messageIdsWithUnsupportedMedia.isEmpty {
                self.unsupportedMessageProcessingManager.add(messageIdsWithUnsupportedMedia)
            }
            if !messageIdsWithRefreshMedia.isEmpty {
                self.refreshMediaProcessingManager.add(messageIdsWithRefreshMedia)
            }
            if !messageIdsWithUnseenPersonalMention.isEmpty {
                self.messageMentionProcessingManager.add(messageIdsWithUnseenPersonalMention)
            }
            
            self.currentEarlierPrefetchMessages = toEarlierMediaMessages
            self.currentLaterPrefetchMessages = toLaterMediaMessages
            if self.currentPrefetchDirectionIsToLater {
                self.prefetchManager.updateMessages(toLaterMediaMessages, directionIsToLater: self.currentPrefetchDirectionIsToLater)
            } else {
                self.prefetchManager.updateMessages(toEarlierMediaMessages, directionIsToLater: self.currentPrefetchDirectionIsToLater)
            }
            
            if readIndexRange.0 <= readIndexRange.1 {
                let (maxIncomingIndex, maxOverallIndex) = maxMessageIndexForEntries(historyView, indexRange: readIndexRange)
                
                let messageIndex: MessageIndex?
                switch self.chatLocation {
                case .peer:
                    messageIndex = maxIncomingIndex
                case .replyThread:
                    messageIndex = maxOverallIndex
                }
                
                if let messageIndex = messageIndex {
                    self.updateMaxVisibleReadIncomingMessageIndex(messageIndex)
                }
                
                if let maxOverallIndex = maxOverallIndex, maxOverallIndex != self.maxVisibleMessageIndexReported {
                    self.maxVisibleMessageIndexReported = maxOverallIndex
                    self.maxVisibleMessageIndexUpdated?(maxOverallIndex)
                }
            }
        }
        self.isTopReplyThreadMessageShown.set(isTopReplyThreadMessageShownValue)
        self.topVisibleMessageRange.set(topVisibleMessageRange)
        
        if let loaded = displayedRange.loadedRange, let firstEntry = historyView.filteredEntries.first, let lastEntry = historyView.filteredEntries.last {
            if loaded.firstIndex < 5 && historyView.originalView.laterId != nil {
                let locationInput: ChatHistoryLocation = .Navigation(index: .message(lastEntry.index), anchorIndex: .message(lastEntry.index), count: historyMessageCount, highlight: false)
                if self.chatHistoryLocationValue?.content != locationInput {
                    self.chatHistoryLocationValue = ChatHistoryLocationInput(content: locationInput, id: self.takeNextHistoryLocationId())
                }
            } else if loaded.firstIndex < 5, historyView.originalView.laterId == nil, !historyView.originalView.holeLater, let chatHistoryLocationValue = self.chatHistoryLocationValue, !chatHistoryLocationValue.isAtUpperBound, historyView.originalView.anchorIndex != .upperBound {
                self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Navigation(index: .upperBound, anchorIndex: .upperBound, count: historyMessageCount, highlight: false), id: self.takeNextHistoryLocationId())
            } else if loaded.lastIndex >= historyView.filteredEntries.count - 5 && historyView.originalView.earlierId != nil {
                let locationInput: ChatHistoryLocation = .Navigation(index: .message(firstEntry.index), anchorIndex: .message(firstEntry.index), count: historyMessageCount, highlight: false)
                if self.chatHistoryLocationValue?.content != locationInput {
                    self.chatHistoryLocationValue = ChatHistoryLocationInput(content: locationInput, id: self.takeNextHistoryLocationId())
                }
            }
        }
        
        var containsPlayableWithSoundItemNode = false
        self.forEachVisibleItemNode { itemNode in
            if let chatItemView = itemNode as? ChatMessageItemView, chatItemView.playMediaWithSound() != nil {
                containsPlayableWithSoundItemNode = true
            }
        }
        self.hasVisiblePlayableItemNodesPromise.set(containsPlayableWithSoundItemNode)
        
        if containsPlayableWithSoundItemNode && !self.isInteractivelyScrollingValue {
            self.isInteractivelyScrollingPromise.set(true)
            self.isInteractivelyScrollingPromise.set(false)
        }
    }
    
    public func scrollScreenToTop() {
        if let subject = self.subject, case .scheduledMessages = subject {
            if let historyView = self.historyView {
                if let entry = historyView.filteredEntries.first {
                    var currentMessage: Message?
                    if case let .MessageEntry(message, _, _, _, _, _) = entry {
                        currentMessage = message
                    } else if case let .MessageGroupEntry(_, messages, _) = entry {
                        currentMessage = messages.first?.0
                    }
                    if let message = currentMessage, let anchorMessage = self.anchorMessageInCurrentHistoryView() {
                        self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Scroll(index: .message(message.index), anchorIndex: .message(message.index), sourceIndex: .upperBound, scrollPosition: .bottom(0.0), animated: true, highlight: false), id: self.takeNextHistoryLocationId())
                    }
                }
            }
        } else {
            var currentMessage: Message?
            if let historyView = self.historyView {
                if let visibleRange = self.displayedItemRange.loadedRange {
                    var index = historyView.filteredEntries.count - 1
                    loop: for entry in historyView.filteredEntries {
                        let isVisible = index >= visibleRange.firstIndex && index <= visibleRange.lastIndex
                        if case let .MessageEntry(message, _, _, _, _, _) = entry {
                            if !isVisible || currentMessage == nil {
                                currentMessage = message
                            }
                        } else if case let .MessageGroupEntry(_, messages, _) = entry {
                            if !isVisible || currentMessage == nil {
                                currentMessage = messages.first?.0
                            }
                        }
                        if isVisible {
                            break loop
                        }
                        index -= 1
                    }
                }
            }
            
            if let currentMessage = currentMessage {
                self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Scroll(index: .message(currentMessage.index), anchorIndex: .message(currentMessage.index), sourceIndex: .upperBound, scrollPosition: .top(0.0), animated: true, highlight: true), id: self.takeNextHistoryLocationId())
            }
        }
    }
    
    public func scrollToStartOfHistory() {
        self.beganDragging?()
        self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Scroll(index: .lowerBound, anchorIndex: .lowerBound, sourceIndex: .upperBound, scrollPosition: .bottom(0.0), animated: true, highlight: false), id: self.takeNextHistoryLocationId())
    }
    
    public func scrollToEndOfHistory() {
        self.beganDragging?()
        switch self.visibleContentOffset() {
            case .known(0.0):
                break
            default:
                let locationInput = ChatHistoryLocationInput(content: .Scroll(index: .upperBound, anchorIndex: .upperBound, sourceIndex: .lowerBound, scrollPosition: .top(0.0), animated: true, highlight: false), id: self.takeNextHistoryLocationId())
                self.chatHistoryLocationValue = locationInput
        }
    }
    
    public func scrollToMessage(from fromIndex: MessageIndex, to toIndex: MessageIndex, animated: Bool, highlight: Bool = true, scrollPosition: ListViewScrollPosition = .center(.bottom)) {
        self.chatHistoryLocationValue = ChatHistoryLocationInput(content: .Scroll(index: .message(toIndex), anchorIndex: .message(toIndex), sourceIndex: .message(fromIndex), scrollPosition: scrollPosition, animated: animated, highlight: highlight), id: self.takeNextHistoryLocationId())
    }
    
    public func anchorMessageInCurrentHistoryView() -> Message? {
        if let historyView = self.historyView {
            if let visibleRange = self.displayedItemRange.visibleRange {
                var index = 0
                for entry in historyView.filteredEntries.reversed() {
                    if index >= visibleRange.firstIndex && index <= visibleRange.lastIndex {
                        if case let .MessageEntry(message, _, _, _, _, _) = entry {
                            return message
                        }
                    }
                    index += 1
                }
            }
            
            for case let .MessageEntry(message, _, _, _, _, _) in historyView.filteredEntries {
                return message
            }
        }
        return nil
    }
    
    public func isMessageVisibleOnScreen(_ id: MessageId) -> Bool {
        var result = false
        self.forEachItemNode({ itemNode in
            if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item, item.content.contains(where: { $0.0.id == id }) {
                if self.itemNodeVisibleInsideInsets(itemNode) {
                    result = true
                }
            }
        })
        return result
    }
    
    public func latestMessageInCurrentHistoryView() -> Message? {
        if let historyView = self.historyView {
            if historyView.originalView.laterId == nil, let firstEntry = historyView.filteredEntries.last {
                if case let .MessageEntry(message, _, _, _, _, _) = firstEntry {
                    return message
                }
            }
        }
        return nil
    }
    
    public func firstMessageForEditInCurrentHistoryView() -> Message? {
        if let historyView = self.historyView {
            if historyView.originalView.laterId == nil {
                for entry in historyView.filteredEntries.reversed()  {
                    if case let .MessageEntry(message, _, _, _, _, _) = entry {
                        if canEditMessage(context: context, limitsConfiguration: context.currentLimitsConfiguration.with { $0 }, message: message) {
                            return message
                        }
                    }
                }
            }
        }
        return nil
    }
    
    public func messageInCurrentHistoryView(_ id: MessageId) -> Message? {
        if let historyView = self.historyView {
            for entry in historyView.filteredEntries {
                if case let .MessageEntry(message, _, _, _, _, _) = entry {
                    if message.id == id {
                        return message
                    }
                } else if case let .MessageGroupEntry(_, messages, _) = entry {
                    for (message, _, _, _) in messages {
                        if message.id == id {
                            return message
                        }
                    }
                }
            }
        }
        return nil
    }
    
    public func messageGroupInCurrentHistoryView(_ id: MessageId) -> [Message]? {
        if let historyView = self.historyView {
            for entry in historyView.filteredEntries {
                if case let .MessageEntry(message, _, _, _, _, _) = entry {
                    if message.id == id {
                        return [message]
                    }
                } else if case let .MessageGroupEntry(_, messages, _) = entry {
                    for (message, _, _, _) in messages {
                        if message.id == id {
                            return messages.map { $0.0 }
                        }
                    }
                }
            }
        }
        return nil
    }
    
    public func forEachMessageInCurrentHistoryView(_ f: (Message) -> Bool) {
        if let historyView = self.historyView {
            for entry in historyView.filteredEntries {
                if case let .MessageEntry(message, _, _, _, _, _) = entry {
                    if !f(message) {
                        return
                    }
                } else if case let .MessageGroupEntry(_, messages, _) = entry {
                    for (message, _, _, _) in messages {
                        if !f(message) {
                            return
                        }
                    }
                }
            }
        }
    }
    
    private func updateMaxVisibleReadIncomingMessageIndex(_ index: MessageIndex) {
        self.maxVisibleIncomingMessageIndex.set(index)
    }
    
    private func enqueueHistoryViewTransition(_ transition: ChatHistoryListViewTransition) {
        self.enqueuedHistoryViewTransitions.append(transition)
        self.prefetchManager.updateOptions(InChatPrefetchOptions(networkType: transition.networkType, peerType: transition.peerType))
                
        if !self.didSetInitialData {
            self.didSetInitialData = true
            self._initialData.set(.single(ChatHistoryCombinedInitialData(initialData: transition.initialData, buttonKeyboardMessage: transition.keyboardButtonsMessage, cachedData: transition.cachedData, cachedDataMessages: transition.cachedDataMessages, readStateData: transition.readStateData)))
        }
                
        if self.isNodeLoaded {
            self.dequeueHistoryViewTransitions()
        } else {
            self._cachedPeerDataAndMessages.set(.single((transition.cachedData, transition.cachedDataMessages)))
            
            let loadState: ChatHistoryNodeLoadState
            if transition.historyView.filteredEntries.isEmpty {
                loadState = .empty
            } else {
                loadState = .messages
            }
            if self.loadState != loadState {
                self.loadState = loadState
                self.loadStateUpdated?(loadState, transition.options.contains(.AnimateInsertion))
            }
            
            let historyState: ChatHistoryNodeHistoryState = .loaded(isEmpty: transition.historyView.originalView.entries.isEmpty)
            if self.currentHistoryState != historyState {
                self.currentHistoryState = historyState
                self.historyState.set(historyState)
            }
        }
    }
    
    private func dequeueHistoryViewTransitions() {
        if self.enqueuedHistoryViewTransitions.isEmpty || self.hasActiveTransition {
            return
        }
        self.hasActiveTransition = true
        let transition = self.enqueuedHistoryViewTransitions.removeFirst()
        
        let animated = transition.options.contains(.AnimateInsertion)
        
        let completion: (ListViewDisplayedItemRange) -> Void = { [weak self] visibleRange in
            if let strongSelf = self {
                strongSelf.historyView = transition.historyView
                
                let loadState: ChatHistoryNodeLoadState
                if let historyView = strongSelf.historyView {
                    if historyView.filteredEntries.isEmpty {
                        loadState = .empty
                    } else {
                        loadState = .messages
                    }
                } else {
                    loadState = .loading
                }
                
                var animateIn = false
                if strongSelf.loadState != loadState {
                    if case .loading = strongSelf.loadState {
                        if case .messages = loadState {
                            animateIn = true
                        }
                    }
                    strongSelf.loadState = loadState
                    strongSelf.loadStateUpdated?(loadState, animated || transition.animateIn || animateIn)
                }
                
                if let _ = visibleRange.loadedRange {
                    if let visible = visibleRange.visibleRange {
                        let visibleFirstIndex = visible.firstIndex
                        if visibleFirstIndex <= visible.lastIndex {
                            let (incomingIndex, overallIndex) =  maxMessageIndexForEntries(transition.historyView, indexRange: (transition.historyView.filteredEntries.count - 1 - visible.lastIndex, transition.historyView.filteredEntries.count - 1 - visibleFirstIndex))
                            
                            let messageIndex: MessageIndex?
                            switch strongSelf.chatLocation {
                            case .peer:
                                messageIndex = incomingIndex
                            case .replyThread:
                                messageIndex = overallIndex
                            }
                            
                            if let messageIndex = messageIndex {
                                strongSelf.updateMaxVisibleReadIncomingMessageIndex(messageIndex)
                            }
                        }
                    }
                }
                if !strongSelf.didSetInitialData {
                    strongSelf.didSetInitialData = true
                    strongSelf._initialData.set(.single(ChatHistoryCombinedInitialData(initialData: transition.initialData, buttonKeyboardMessage: transition.keyboardButtonsMessage, cachedData: transition.cachedData, cachedDataMessages: transition.cachedDataMessages, readStateData: transition.readStateData)))
                }
                strongSelf._cachedPeerDataAndMessages.set(.single((transition.cachedData, transition.cachedDataMessages)))
                let historyState: ChatHistoryNodeHistoryState = .loaded(isEmpty: transition.historyView.originalView.entries.isEmpty)
                if strongSelf.currentHistoryState != historyState {
                    strongSelf.currentHistoryState = historyState
                    strongSelf.historyState.set(historyState)
                }
                
                var buttonKeyboardMessageUpdated = false
                if let currentButtonKeyboardMessage = strongSelf.currentButtonKeyboardMessage, let buttonKeyboardMessage = transition.keyboardButtonsMessage {
                    if currentButtonKeyboardMessage.id != buttonKeyboardMessage.id || currentButtonKeyboardMessage.stableVersion != buttonKeyboardMessage.stableVersion {
                        buttonKeyboardMessageUpdated = true
                    }
                } else if (strongSelf.currentButtonKeyboardMessage != nil) != (transition.keyboardButtonsMessage != nil) {
                    buttonKeyboardMessageUpdated = true
                }
                if buttonKeyboardMessageUpdated {
                    strongSelf.currentButtonKeyboardMessage = transition.keyboardButtonsMessage
                    strongSelf._buttonKeyboardMessage.set(.single(transition.keyboardButtonsMessage))
                }
                
                if transition.animateIn || animateIn {
                    let heightNorm = strongSelf.bounds.height - strongSelf.insets.top
                    strongSelf.forEachVisibleItemNode { itemNode in
                        let delayFactor = itemNode.frame.minY / heightNorm
                        let delay = Double(delayFactor * 0.1)
                        
                        if let itemNode = itemNode as? ChatMessageItemView {
                            itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
                            itemNode.layer.animateScale(from: 0.94, to: 1.0, duration: 0.4, delay: delay, timingFunction: kCAMediaTimingFunctionSpring)
                        } else if let itemNode = itemNode as? ChatUnreadItemNode {
                            itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
                        } else if let itemNode = itemNode as? ChatReplyCountItemNode {
                            itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
                        }
                    }
                    strongSelf.forEachItemHeaderNode { itemNode in
                        let delayFactor = itemNode.frame.minY / heightNorm
                        let delay = Double(delayFactor * 0.2)
                        
                        itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
                        itemNode.layer.animateScale(from: 0.94, to: 1.0, duration: 0.4, delay: delay, timingFunction: kCAMediaTimingFunctionSpring)
                    }
                }
                
                if let scrolledToIndex = transition.scrolledToIndex {
                    if let strongSelf = self {
                        strongSelf.scrolledToIndex?(scrolledToIndex)
                    }
                } else if transition.scrolledToSomeIndex {
                    self?.scrolledToSomeIndex?()
                }
                
                strongSelf.hasActiveTransition = false
                strongSelf.dequeueHistoryViewTransitions()
            }
        }
        
        if let layoutActionOnViewTransition = self.layoutActionOnViewTransition {
            self.layoutActionOnViewTransition = nil
            let (mappedTransition, updateSizeAndInsets) = layoutActionOnViewTransition(transition)
            
            self.transaction(deleteIndices: mappedTransition.deleteItems, insertIndicesAndItems: transition.insertItems, updateIndicesAndItems: transition.updateItems, options: mappedTransition.options, scrollToItem: mappedTransition.scrollToItem, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: mappedTransition.stationaryItemRange, updateOpaqueState: ChatHistoryTransactionOpaqueState(historyView: transition.historyView), completion: { visibleRange in
                guard let animationCallback = mappedTransition.animationCallback, transition.insertItems.count == 1, let node = self.itemNodeAtIndex(transition.insertItems[0].index) else {
                    completion(visibleRange)
                    return
                }
                
                animationCallback(node, { completion(visibleRange) })
            })
        } else {
            self.transaction(deleteIndices: transition.deleteItems, insertIndicesAndItems: transition.insertItems, updateIndicesAndItems: transition.updateItems, options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange, updateOpaqueState: ChatHistoryTransactionOpaqueState(historyView: transition.historyView), completion: completion)
        }
        
        if transition.flashIndicators {
            //self.flashHeaderItems()
        }
    }
    
    public func updateLayout(transition: ContainedViewLayoutTransition, updateSizeAndInsets: ListViewUpdateSizeAndInsets) {
        self.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets, additionalScrollDistance: 0.0, scrollToTop: false, completion: {})
    }
        
    public func updateLayout(transition: ContainedViewLayoutTransition, updateSizeAndInsets: ListViewUpdateSizeAndInsets, additionalScrollDistance: CGFloat, scrollToTop: Bool, completion: @escaping () -> Void) {
        var scrollToItem: ListViewScrollToItem?
        if scrollToTop, case .known = self.visibleContentOffset() {
            scrollToItem = ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Spring(duration: updateSizeAndInsets.duration), directionHint: .Up)
        }
        self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: scrollToItem, additionalScrollDistance: scrollToTop ? 0.0 : additionalScrollDistance, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in
            completion()
        })
        
        if !self.dequeuedInitialTransitionOnLayout {
            self.dequeuedInitialTransitionOnLayout = true
            self.dequeueHistoryViewTransitions()
        }
    }
    
    public func disconnect() {
        self.historyDisposable.set(nil)
    }
    
    private func updateReadHistoryActions() {
        let canRead = self.canReadHistoryValue && self.isScrollAtBottomPosition
        if canRead != (self.interactiveReadActionDisposable != nil) {
            if let interactiveReadActionDisposable = self.interactiveReadActionDisposable {
                if !canRead {
                    interactiveReadActionDisposable.dispose()
                    self.interactiveReadActionDisposable = nil
                }
            } else if self.interactiveReadActionDisposable == nil {
                if case let .peer(peerId) = self.chatLocation {
                    if !self.context.sharedContext.immediateExperimentalUISettings.skipReadHistory {
                        self.interactiveReadActionDisposable = installInteractiveReadMessagesAction(postbox: self.context.account.postbox, stateManager: self.context.account.stateManager, peerId: peerId)
                    }
                }
            }
        }
    }
    
    func lastVisbleMesssage() -> Message? {
        var currentMessage: Message?
        if let historyView = self.historyView {
            if let visibleRange = self.displayedItemRange.visibleRange {
                var index = 0
                loop: for entry in historyView.filteredEntries.reversed() {
                    if index >= visibleRange.firstIndex && index <= visibleRange.lastIndex {
                        if case let .MessageEntry(message, _, _, _, _, _) = entry {
                            currentMessage = message
                            break loop
                        } else if case let .MessageGroupEntry(_, messages, _) = entry {
                            currentMessage = messages.first?.0
                            break loop
                        }
                    }
                    index += 1
                }
            }
        }
        return currentMessage
    }
    
    func immediateScrollState() -> ChatInterfaceHistoryScrollState? {
        var currentMessage: Message?
        if let historyView = self.historyView {
            if let visibleRange = self.displayedItemRange.visibleRange {
                var index = 0
                loop: for entry in historyView.filteredEntries.reversed() {
                    if index >= visibleRange.firstIndex && index <= visibleRange.lastIndex {
                        if case let .MessageEntry(message, _, _, _, _, _) = entry {
                            if index != 0 || historyView.originalView.laterId != nil {
                                currentMessage = message
                            }
                            break loop
                        } else if case let .MessageGroupEntry(_, messages, _) = entry {
                            if index != 0 || historyView.originalView.laterId != nil {
                                currentMessage = messages.first?.0
                            }
                            break loop
                        }
                    }
                    index += 1
                }
            }
        }
        
        if let message = currentMessage {
            var relativeOffset: CGFloat = 0.0
            self.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item, item.message.id == message.id {
                    if let offsetValue = self.itemNodeRelativeOffset(itemNode) {
                        relativeOffset = offsetValue
                    }
                }
            }
            return ChatInterfaceHistoryScrollState(messageIndex: message.index, relativeOffset: Double(relativeOffset))
        }
        return nil
    }
    
    func scrollToNextMessage() {
        if let historyView = self.historyView {
            var scrolled = false
            if let scrollState = self.immediateScrollState() {
                var index = historyView.filteredEntries.count - 1
                loop: for entry in historyView.filteredEntries.reversed() {
                    if entry.index == scrollState.messageIndex {
                        break loop
                    }
                    index -= 1
                }
                
                if index != 0 {
                    var nextItem = false
                    self.forEachItemNode { itemNode in
                        if let itemNode = itemNode as? ChatMessageItemView, itemNode.item?.content.index == scrollState.messageIndex {
                            if itemNode.frame.maxY >= self.bounds.size.height - self.insets.bottom - 4.0 {
                                nextItem = true
                            }
                        }
                    }
                    
                    if !nextItem {
                        scrolled = true
                        self.scrollToMessage(from: scrollState.messageIndex, to: scrollState.messageIndex, animated: true, highlight: false)
                    } else {
                        loop: for i in (index + 1) ..< historyView.filteredEntries.count {
                            let entry = historyView.filteredEntries[i]
                            switch entry {
                                case .MessageEntry, .MessageGroupEntry:
                                    scrolled = true
                                    self.scrollToMessage(from: scrollState.messageIndex, to: entry.index, animated: true, highlight: false)
                                    break loop
                                default:
                                    break
                            }
                        }
                    }
                }
            }
            
            if !scrolled {
                self.scrollToEndOfHistory()
            }
        }
    }
    
    func requestMessageUpdate(_ id: MessageId) {
        if let historyView = self.historyView {
            var messageItem: ChatMessageItem?
            self.forEachItemNode({ itemNode in
                if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item {
                    for (message, _) in item.content {
                        if message.id == id {
                            messageItem = item
                            break
                        }
                    }
                }
            })
            
            if let messageItem = messageItem {
                let associatedData = messageItem.associatedData
                
                loop: for i in 0 ..< historyView.filteredEntries.count {
                    switch historyView.filteredEntries[i] {
                        case let .MessageEntry(message, presentationData, read, _, selection, attributes):
                            if message.id == id {
                                let index = historyView.filteredEntries.count - 1 - i
                                let item: ListViewItem
                                switch self.mode {
                                    case .bubbles:
                                        item = ChatMessageItem(presentationData: presentationData, context: self.context, chatLocation: self.chatLocation, associatedData: associatedData, controllerInteraction: self.controllerInteraction, content: .message(message: message, read: read, selection: selection, attributes: attributes))
                                    case let .list(_, _, displayHeaders, hintLinks, isGlobalSearch):
                                        let displayHeader: Bool
                                        switch displayHeaders {
                                        case .none:
                                            displayHeader = false
                                        case .all:
                                            displayHeader = true
                                        case .allButLast:
                                            displayHeader = listMessageDateHeaderId(timestamp: message.timestamp) != historyView.lastHeaderId
                                        }
                                        item = ListMessageItem(presentationData: presentationData, context: self.context, chatLocation: self.chatLocation, interaction: ListMessageItemInteraction(controllerInteraction: self.controllerInteraction), message: message, selection: selection, displayHeader: displayHeader, hintIsLink: hintLinks, isGlobalSearchResult: isGlobalSearch)
                                }
                                let updateItem = ListViewUpdateItem(index: index, previousIndex: index, item: item, directionHint: nil)
                                self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [updateItem], options: [.AnimateInsertion], scrollToItem: nil, additionalScrollDistance: 0.0, updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                                break loop
                            }
                        default:
                            break
                    }
                }
            }
        }
    }

    private func messagesAtPoint(_ point: CGPoint) -> [Message]? {
        var resultMessages: [Message]?
        self.forEachVisibleItemNode { itemNode in
            if resultMessages == nil, let itemNode = itemNode as? ListViewItemNode, itemNode.frame.contains(point) {
                if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item {
                    switch item.content {
                        case let .message(message, _, _ , _):
                            resultMessages = [message]
                        case let .group(messages):
                            resultMessages = messages.map { $0.0 }
                    }
                }
            }
        }
        return resultMessages
    }
    
    private var selectionPanState: (selecting: Bool, initialMessageId: MessageId, toggledMessageIds: [[MessageId]])?
    private var selectionScrollActivationTimer: SwiftSignalKit.Timer?
    private var selectionScrollDisplayLink: ConstantDisplayLinkAnimator?
    private var selectionScrollDelta: CGFloat?
    private var selectionLastLocation: CGPoint?
    
    @objc private func selectionPanGesture(_ recognizer: UIGestureRecognizer) -> Void {
        let location = recognizer.location(in: self.view)
        switch recognizer.state {
            case .began:
                if let messages = self.messagesAtPoint(location), let message = messages.first {
                    let selecting = !(self.controllerInteraction.selectionState?.selectedIds.contains(message.id) ?? false)
                    self.selectionPanState = (selecting, message.id, [])
                    self.controllerInteraction.toggleMessagesSelection(messages.map { $0.id }, selecting)
                }
            case .changed:
                self.handlePanSelection(location: location)
                self.selectionLastLocation = location
            case .ended, .failed, .cancelled:
                self.selectionPanState = nil
                self.selectionScrollDisplayLink = nil
                self.selectionScrollActivationTimer?.invalidate()
                self.selectionScrollActivationTimer = nil
                self.selectionScrollDelta = nil
                self.selectionLastLocation = nil
                self.selectionScrollSkipUpdate = false
            case .possible:
                break
            @unknown default:
                fatalError()
        }
    }
    
    private func handlePanSelection(location: CGPoint) {
        if let state = self.selectionPanState {
            if let messages = self.messagesAtPoint(location), let message = messages.first {
                if message.id == state.initialMessageId {
                    if !state.toggledMessageIds.isEmpty {
                        self.controllerInteraction.toggleMessagesSelection(state.toggledMessageIds.flatMap { $0 }, !state.selecting)
                        self.selectionPanState = (state.selecting, state.initialMessageId, [])
                    }
                } else if state.toggledMessageIds.last?.first != message.id {
                    var updatedToggledMessageIds: [[MessageId]] = []
                    var previouslyToggled = false
                    for i in (0 ..< state.toggledMessageIds.count) {
                        if let messageId = state.toggledMessageIds[i].first {
                            if messageId == message.id {
                                previouslyToggled = true
                                updatedToggledMessageIds = Array(state.toggledMessageIds.prefix(i + 1))
                                
                                let messageIdsToToggle = Array(state.toggledMessageIds.suffix(state.toggledMessageIds.count - i - 1)).flatMap { $0 }
                                self.controllerInteraction.toggleMessagesSelection(messageIdsToToggle, !state.selecting)
                                break
                            }
                        }
                    }
                    
                    if !previouslyToggled {
                        updatedToggledMessageIds = state.toggledMessageIds
                        let isSelected = (self.controllerInteraction.selectionState?.selectedIds.contains(message.id) ?? false)
                        if state.selecting != isSelected {
                            let messageIds = messages.map { $0.id }
                            updatedToggledMessageIds.append(messageIds)
                            self.controllerInteraction.toggleMessagesSelection(messageIds, state.selecting)
                        }
                    }
                    
                    self.selectionPanState = (state.selecting, state.initialMessageId, updatedToggledMessageIds)
                }
            }
        
            let scrollingAreaHeight: CGFloat = 50.0
            if location.y < scrollingAreaHeight + self.insets.top || location.y > self.frame.height - scrollingAreaHeight - self.insets.bottom {
                if location.y < self.frame.height / 2.0 {
                    self.selectionScrollDelta = (scrollingAreaHeight - (location.y - self.insets.top)) / scrollingAreaHeight
                } else {
                    self.selectionScrollDelta = -(scrollingAreaHeight - min(scrollingAreaHeight, max(0.0, (self.frame.height - self.insets.bottom - location.y)))) / scrollingAreaHeight
                }
                if let displayLink = self.selectionScrollDisplayLink {
                    displayLink.isPaused = false
                } else {
                    if let _ = self.selectionScrollActivationTimer {
                    } else {
                        let timer = SwiftSignalKit.Timer(timeout: 0.45, repeat: false, completion: { [weak self] in
                            self?.setupSelectionScrolling()
                        }, queue: .mainQueue())
                        timer.start()
                        self.selectionScrollActivationTimer = timer
                    }
                }
            } else {
                self.selectionScrollDisplayLink?.isPaused = true
                self.selectionScrollActivationTimer?.invalidate()
                self.selectionScrollActivationTimer = nil
            }
        }
    }
    
    private var selectionScrollSkipUpdate = false
    private func setupSelectionScrolling() {
        self.selectionScrollDisplayLink = ConstantDisplayLinkAnimator(update: { [weak self] in
            self?.selectionScrollActivationTimer = nil
            if let strongSelf = self, let delta = strongSelf.selectionScrollDelta {
                let distance: CGFloat = 15.0 * min(1.0, 0.15 + abs(delta * delta))
                let direction: ListViewScrollDirection = delta > 0.0 ? .up : .down
                let _ = strongSelf.scrollWithDirection(direction, distance: distance)
                
                if let location = strongSelf.selectionLastLocation {
                    if !strongSelf.selectionScrollSkipUpdate {
                        strongSelf.handlePanSelection(location: location)
                    }
                    strongSelf.selectionScrollSkipUpdate = !strongSelf.selectionScrollSkipUpdate
                }
            }
        })
        self.selectionScrollDisplayLink?.isPaused = false
    }
}
