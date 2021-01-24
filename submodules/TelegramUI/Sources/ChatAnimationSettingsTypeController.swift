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
    init() {}
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
    case small
    case big
    case link
    case emoji
    case sticker
    case voice
    case video
    
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
    
    static func <(lhs: ChatAnimationSettingsTypeControllerEntry, rhs: ChatAnimationSettingsTypeControllerEntry) -> Bool {
        return lhs.stableId.rawValue < rhs.stableId.rawValue
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChatAnimationSettingsTypeControllerArguments
        switch self {
        case .messagesHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "MESSAGES", sectionId: self.section)
        case .small:
            return ItemListActionItem(presentationData: presentationData, title: ChatAnimationType.small.description, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: { })
        case .big:
            return ItemListActionItem(presentationData: presentationData, title: ChatAnimationType.big.description, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: { })
        case .link:
            return ItemListActionItem(presentationData: presentationData, title: ChatAnimationType.link.description, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: { })
        case .emoji:
            return ItemListActionItem(presentationData: presentationData, title: ChatAnimationType.emoji.description, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: { })
        case .sticker:
            return ItemListActionItem(presentationData: presentationData, title: ChatAnimationType.sticker.description, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: { })
        case .voice:
            return ItemListActionItem(presentationData: presentationData, title: ChatAnimationType.voice.description, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: { })
        case .video:
            return ItemListActionItem(presentationData: presentationData, title: ChatAnimationType.video.description, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: { })
        }
    }
}

private func createChatAnimationSettingsTypeEntries() -> [ChatAnimationSettingsTypeControllerEntry] {
    let entries: [ChatAnimationSettingsTypeControllerEntry] = [
        .small,
        .big,
        .link,
        .emoji,
        .sticker,
        .voice,
        .video,
    ]
    return entries
}

public func createChatAnimationSettingsTypeController(context: AccountContext) -> ViewController {
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
                                              entries: createChatAnimationSettingsTypeEntries(),
                                              style: .blocks)
            
            let arguments = ChatAnimationSettingsTypeControllerArguments()
            
            return (controllerState, (listState, arguments))
        }
    
    let controller = ItemListController(context: context, state: signal)
    
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    controller.alwaysSynchronous = true
    controller.isOpaqueWhenInOverlay = true
       
    return controller
}
