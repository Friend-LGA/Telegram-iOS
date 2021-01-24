import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AccountContext
import ItemListUI
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences

private final class ChatAnimationSettingsControllerArguments {
    let openType: () -> Void
    let openDuration: () -> Void
    let share: () -> Void
    let importParams: () -> Void
    let restore: () -> Void

    init(openType: @escaping () -> Void,
         openDuration: @escaping () -> Void,
         share: @escaping () -> Void,
         importParams: @escaping () -> Void,
         restore: @escaping () -> Void) {
        self.openType = openType
        self.openDuration = openDuration
        self.share = share
        self.importParams = importParams
        self.restore = restore
    }
}

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
}

private enum ChatAnimationSettingsControllerEntry: ItemListNodeEntry {
    case type(ChatAnimationType)
    case duration(ChatAnimationDuration)
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
    
    var stableId: ChatAnimationSettingsControllerEntryId {
        switch self {
        case .type:
            return .type
        case .duration:
            return .duration
        case .share:
            return .share
        case .importParams:
            return .importParams
        case .restore:
            return .restore
        case .yPositionHeader:
            return .yPositionHeader
        case .yPosition:
            return .yPosition
        case .xPositionHeader:
            return .xPositionHeader
        case .xPosition:
            return .xPosition
        case .bubbleShapeHeader:
            return .bubbleShapeHeader
        case .bubbleShape:
            return .bubbleShape
        case .textPositionHeader:
            return .textPositionHeader
        case .textPosition:
            return .textPosition
        case .colorChangeHeader:
            return .colorChangeHeader
        case .colorChange:
            return .colorChange
        case .timeAppearsHeader:
            return .timeAppearsHeader
        case .timeAppears:
            return .timeAppears
        }
    }
    
    static func <(lhs: ChatAnimationSettingsControllerEntry, rhs: ChatAnimationSettingsControllerEntry) -> Bool {
        return lhs.stableId.rawValue < rhs.stableId.rawValue
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChatAnimationSettingsControllerArguments
        switch self {
        case let .type(value):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Animation Type", label: value.rawValue, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: { arguments.openType()
            })
        case let .duration(value):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Duration", label: value.description, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: { arguments.openDuration()
            })
        case .share:
            return ItemListActionItem(presentationData: presentationData, title: "Share Parameters", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.share()
            })
        case .importParams:
            return ItemListActionItem(presentationData: presentationData, title: "Import Parameters", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.importParams()
            })
        case .restore:
            return ItemListActionItem(presentationData: presentationData, title: "Restore to Default", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.restore()
            })
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

private func createChatAnimationSettingsControllerEntries() -> [ChatAnimationSettingsControllerEntry] {
    let entries: [ChatAnimationSettingsControllerEntry] = [
        .type(ChatAnimationType.small),
        .duration(ChatAnimationDuration.medium),
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
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentActionSheetImpl: ((ActionSheetController) -> Void)?
    var presentAvivityControllerImpl: ((UIActivityViewController) -> Void)?
    
    let signal = context.sharedContext.presentationData
        |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
            
            let rightNavigationButton = ItemListNavigationButton(content: .text("Apply"), style: .bold, enabled: true, action: {
                dismissImpl?()
            })
                        
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData),
                                                          title: .text("Animation Settings"),
                                                          leftNavigationButton: leftNavigationButton,
                                                          rightNavigationButton: rightNavigationButton,
                                                          backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
                                                          animateChanges: false)
            
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData),
                                              entries: createChatAnimationSettingsControllerEntries(),
                                              style: .blocks)
            
            let arguments = ChatAnimationSettingsControllerArguments(openType: {
                pushControllerImpl?(createChatAnimationSettingsTypeController(context: context))
            },
            openDuration: {
                let actionSheet = ActionSheetController(presentationData: presentationData)
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetTextItem(title: "Duration"),
                        ActionSheetButtonItem(title: ChatAnimationDuration.fast.description, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        }),
                        ActionSheetButtonItem(title: ChatAnimationDuration.medium.description, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        }),
                        ActionSheetButtonItem(title: ChatAnimationDuration.slow.description, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ]),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                presentActionSheetImpl?(actionSheet)
            },
            share: {
                let (path, error) = ChatAnimationSettingsManager.generateJSONFile()
                guard let filePath = path, error == nil else {
                    // show error
                    return
                }
                
                let activityController = UIActivityViewController(activityItems: ["Check out this book! I like using Book Tracker.", filePath], applicationActivities: nil)
                presentAvivityControllerImpl?(activityController)
                
//                if let window = strongSelf.view.window, let rootViewController = window.rootViewController {
//                    activityController.popoverPresentationController?.sourceView = window
//                    activityController.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
//                    rootViewController.present(activityController, animated: true, completion: nil)
//                }
            },
            importParams: {
                print(ChatAnimationSettingsManager.generateJSONString())
            },
            restore: {
                print(ChatAnimationSettingsManager.generateJSONString())
            })
            
            return (controllerState, (listState, arguments))
        }
    
    let controller = ItemListController(context: context, state: signal)
    
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    pushControllerImpl = { [weak controller] newController in
        (controller?.navigationController as? NavigationController)?.pushViewController(newController)
    }
    presentActionSheetImpl = { [weak controller] actionSheet in
        controller?.present(actionSheet, in: .window(.root))
    }
    presentAvivityControllerImpl = { [weak controller] activityController in
//        guard let window = controller?.navigationController?.window, let rootVC = window.rootViewController else { return }
//        activityController.popoverPresentationController?.sourceView = window
        (controller?.navigationController as? NavigationController)?.present(activityController, animated: true, completion: nil)
    }
    
    controller.navigationPresentation = .modal
    controller.alwaysSynchronous = true
    controller.isOpaqueWhenInOverlay = true
       
    return controller
}
