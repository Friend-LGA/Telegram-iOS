import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AccountContext
import TelegramPresentationData
import ItemListUI
import SwiftSignalKit

private enum ChatAnimationSettingsControllerSection: Int32 {
    case common
    case yPositgion
    case xPosition
    case bubbleShape
    case textPosition
    case colorChange
    case timeAppears
}

private enum ChatAnimationSettingsControllerEntryId: Int32 {
    case type
    case duration
    case share
    case importParams
    case restore
    case yPosition
    case xPosition
    case bubbleShape
    case textPosition
    case colorChange
    case timeAppears
}

private final class ChatAnimationSettingsControllerArguments {
    let placeholder: () -> Void

    init(placeholder: @escaping () -> Void) {
        self.placeholder = placeholder
    }
}

private enum ChatAnimationSettingsControllerEntry: ItemListNodeEntry {
    case type
    case duration
    case share
    case importParams
    case restore
    case yPositionHeader
    case yPosition
    case xPositionHeader
    case xPosition
    case bubbleShapeHeader
    case bubbleShape
    case textPositionHeader
    case textPosition
    case colorChangeHeader
    case colorChange
    case timeAppearsHeader
    case timeAppears
    
    var section: ItemListSectionId {
        switch self {
        case .type, .duration, .share, .importParams, .restore:
            return ChatAnimationSettingsControllerSection.common.rawValue
        case .yPositionHeader, .yPosition:
            return ChatAnimationSettingsControllerSection.yPositgion.rawValue
        case .xPositionHeader, .xPosition:
            return ChatAnimationSettingsControllerSection.xPosition.rawValue
        case .bubbleShapeHeader, .bubbleShape:
            return ChatAnimationSettingsControllerSection.bubbleShape.rawValue
        case .textPositionHeader, .textPosition:
            return ChatAnimationSettingsControllerSection.textPosition.rawValue
        case .colorChangeHeader, .colorChange:
            return ChatAnimationSettingsControllerSection.colorChange.rawValue
        case .timeAppearsHeader, .timeAppears:
            return ChatAnimationSettingsControllerSection.timeAppears.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .type:
            return 0
        case .duration:
            return 1
        case .share:
            return 2
        case .importParams:
            return 3
        case .restore:
            return 4
        case .yPositionHeader:
            return 5
        case .yPosition:
            return 6
        case .xPositionHeader:
            return 7
        case .xPosition:
            return 8
        case .bubbleShapeHeader:
            return 9
        case .bubbleShape:
            return 10
        case .textPositionHeader:
            return 11
        case .textPosition:
            return 12
        case .colorChangeHeader:
            return 13
        case .colorChange:
            return 14
        case .timeAppearsHeader:
            return 15
        case .timeAppears:
            return 16
        }
    }
    
    static func <(lhs: ChatAnimationSettingsControllerEntry, rhs: ChatAnimationSettingsControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        // let arguments = arguments as! ChatAnimationSettingsControllerArguments
        switch self {
        case .type:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Animation Type", label: "Small Message", labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {})
        case .duration:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Duration", label: "30f", labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {})
        case .share:
            return ItemListActionItem(presentationData: presentationData, title: "Share Parameters", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: { })
        case .importParams:
            return ItemListActionItem(presentationData: presentationData, title: "Import Parameters", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: { })
        case .restore:
            return ItemListActionItem(presentationData: presentationData, title: "Restore to Default", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: { })
        case .yPositionHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Y POSITION", sectionId: self.section)
        case .yPosition:
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: "", placeholder: "", sectionId: self.section, textUpdated: {_ in}, action: {})
        case .xPositionHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "X POSITION", sectionId: self.section)
        case .xPosition:
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: "", placeholder: "", sectionId: self.section, textUpdated: {_ in}, action: {})
        case .bubbleShapeHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "BUBBLE SHAPE", sectionId: self.section)
        case .bubbleShape:
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: "", placeholder: "", sectionId: self.section, textUpdated: {_ in}, action: {})
        case .textPositionHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "TEXT POSITION", sectionId: self.section)
        case .textPosition:
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: "", placeholder: "", sectionId: self.section, textUpdated: {_ in}, action: {})
        case .colorChangeHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "COLOR CHANGE", sectionId: self.section)
        case .colorChange:
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: "", placeholder: "", sectionId: self.section, textUpdated: {_ in}, action: {})
        case .timeAppearsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "TIME APPEARS", sectionId: self.section)
        case .timeAppears:
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: "", placeholder: "", sectionId: self.section, textUpdated: {_ in}, action: {})
        }
    }
}

private func createPollControllerEntries(presentationData: PresentationData) -> [ChatAnimationSettingsControllerEntry] {
    let entries: [ChatAnimationSettingsControllerEntry] = [
        .type,
        .duration,
        .share,
        .importParams,
        .restore,
        .yPositionHeader,
        .yPosition,
        .xPositionHeader,
        .xPosition,
        .bubbleShapeHeader,
        .bubbleShape,
        .textPositionHeader,
        .textPosition,
        .colorChangeHeader,
        .colorChange,
        .timeAppearsHeader,
        .timeAppears
    ]
    return entries
}

public func createChatAnimationSettingsController(context: AccountContext) -> ViewController {
    var dismissImpl: (() -> Void)?
    
    let signal = context.sharedContext.presentationData
        |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        
        let rightNavigationButton = ItemListNavigationButton(content: .text("Apply"), style: .bold, enabled: true, action: {
            dismissImpl?()
        })
        
        let title = "Animation Settings"

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData),
                                                      title: .text(title),
                                                      leftNavigationButton: leftNavigationButton,
                                                      rightNavigationButton: rightNavigationButton,
                                                      backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
                                                      animateChanges: false)
        
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData),
                                          entries: createPollControllerEntries(presentationData: presentationData),
                                          style: .blocks)
        
        let arguments = ChatAnimationSettingsControllerArguments(placeholder: {})
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    controller.navigationPresentation = .modal
    controller.alwaysSynchronous = true
    controller.isOpaqueWhenInOverlay = true
       
    return controller
}
