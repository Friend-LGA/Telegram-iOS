import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AccountContext
import ItemListUI
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences

private final class ChatAnimationSettingsTypeControllerArguments {
    let dismiss: () -> Void
    
    init(dismiss: @escaping () -> Void) {
        self.dismiss = dismiss
    }
}

private enum ChatAnimationSettingsTypeControllerSection: Int32 {
    case messages
}

private enum ChatAnimationSettingsTypeControllerEntryId: Int32 {
    case messagesHeader
    case small
    case big
    case link
    case emoji
    case sticker
    case voice
    case video
}

private enum ChatAnimationSettingsTypeControllerEntry: ItemListNodeEntry {
    case messagesHeader
    case small(ChatAnimationType, (ChatAnimationType) -> Void)
    case big(ChatAnimationType, (ChatAnimationType) -> Void)
    case link(ChatAnimationType, (ChatAnimationType) -> Void)
    case emoji(ChatAnimationType, (ChatAnimationType) -> Void)
    case sticker(ChatAnimationType, (ChatAnimationType) -> Void)
    case voice(ChatAnimationType, (ChatAnimationType) -> Void)
    case video(ChatAnimationType, (ChatAnimationType) -> Void)
    
    var section: ItemListSectionId {
        return ChatAnimationSettingsTypeControllerSection.messages.rawValue
    }
    
    var stableId: ChatAnimationSettingsTypeControllerEntryId {
        switch self {
        case .messagesHeader:
            return .messagesHeader
        case .small:
            return .small
        case .big:
            return .big
        case .link:
            return .link
        case .emoji:
            return .emoji
        case .sticker:
            return .sticker
        case .voice:
            return .voice
        case .video:
            return .video
        }
    }
    
    var type: ChatAnimationType {
        switch self {
        case .messagesHeader:
            return .small
        case .small:
            return .small
        case .big:
            return .big
        case .link:
            return .link
        case .emoji:
            return .emoji
        case .sticker:
            return .sticker
        case .voice:
            return .voice
        case .video:
            return .video
        }
    }
    
    static func == (lhs: ChatAnimationSettingsTypeControllerEntry, rhs: ChatAnimationSettingsTypeControllerEntry) -> Bool {
        return lhs.type == rhs.type
    }
    
    static func <(lhs: ChatAnimationSettingsTypeControllerEntry, rhs: ChatAnimationSettingsTypeControllerEntry) -> Bool {
        return lhs.stableId.rawValue < rhs.stableId.rawValue
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChatAnimationSettingsTypeControllerArguments
        
        switch self {
        case .messagesHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "MESSAGES", sectionId: self.section)
        case let .small(type, onChange),
             let .big(type, onChange),
             let .link(type, onChange),
             let .emoji(type, onChange),
             let .sticker(type, onChange),
             let .voice(type, onChange),
             let .video(type, onChange):
            return ItemListActionItem(presentationData: presentationData, title: type.description, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                onChange(type)
                arguments.dismiss()
            })
        }
    }
}

private func createChatAnimationSettingsTypeEntries(onChange: @escaping (ChatAnimationType) -> Void) -> [ChatAnimationSettingsTypeControllerEntry] {
    let entries: [ChatAnimationSettingsTypeControllerEntry] = [
        .small(.small, onChange),
        .big(.big, onChange),
        .link(.link, onChange),
        .emoji(.emoji, onChange),
        .sticker(.sticker, onChange),
        .voice(.voice, onChange),
        .video(.video, onChange),
    ]
    return entries
}

public func createChatAnimationSettingsTypeController(context: AccountContext, onChange: @escaping (ChatAnimationType) -> Void) -> ViewController {
    var dismissImpl: (() -> Void)?
    
    let signal = context.sharedContext.presentationData
        |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData),
                                                          title: .text("Animation Type"),
                                                          leftNavigationButton: nil,
                                                          rightNavigationButton: nil,
                                                          backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
                                                          animateChanges: false)
            
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData),
                                              entries: createChatAnimationSettingsTypeEntries(onChange: onChange),
                                              style: .blocks,
                                              animateChanges: false)
            
            let arguments = ChatAnimationSettingsTypeControllerArguments(dismiss: {
                dismissImpl?()
            })
            
            return (controllerState, (listState, arguments))
        }
    
    let controller = ItemListController(context: context, state: signal)
    controller.alwaysSynchronous = true
    controller.isOpaqueWhenInOverlay = true
    
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    return controller
}
