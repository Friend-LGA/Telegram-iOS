import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AccountContext
import ItemListUI
import SwiftSignalKit
import LegacyMediaPickerUI
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils

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
            return ChatAnimationSettingsCurveItem(presentationData: presentationData, sectionId: self.section)
        case .xPositionHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "X POSITION", sectionId: self.section)
        case .xPosition:
            return ChatAnimationSettingsCurveItem(presentationData: presentationData, sectionId: self.section)
        case .bubbleShapeHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "BUBBLE SHAPE", sectionId: self.section)
        case .bubbleShape:
            return ChatAnimationSettingsCurveItem(presentationData: presentationData, sectionId: self.section)
        case .textPositionHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "TEXT POSITION", sectionId: self.section)
        case .textPosition:
            return ChatAnimationSettingsCurveItem(presentationData: presentationData, sectionId: self.section)
        case .colorChangeHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "COLOR CHANGE", sectionId: self.section)
        case .colorChange:
            return ChatAnimationSettingsCurveItem(presentationData: presentationData, sectionId: self.section)
        case .timeAppearsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "TIME APPEARS", sectionId: self.section)
        case .timeAppears:
            return ChatAnimationSettingsCurveItem(presentationData: presentationData, sectionId: self.section)
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
    var presentControllerImpl: ((ViewController) -> Void)?
    var presentActivityControllerImpl: ((UIActivityViewController) -> Void)?
    let chatAnimationSettings = ChatAnimationSettingsManager()
    let animationType = ChatAnimationType.small
    
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
                presentControllerImpl?(actionSheet)
            },
            share: {
                let (path, error) = ChatAnimationSettingsManager.generateJSONFile()
                guard let filePath = path, error == nil else {
                    let action = TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                    let alertController = textAlertController(context: context, title: nil, text: "Failed to generate JSON file", actions: [action])
                    presentControllerImpl?(alertController)
                    return
                }
                
                let activityController = UIActivityViewController(activityItems: [filePath], applicationActivities: nil)
                activityController.completionWithItemsHandler = { (activityType, completed: Bool, returnedItems: [Any]?, error: Error?) in
                    try? FileManager.default.removeItem(at: filePath)
                }
                presentActivityControllerImpl?(activityController)
            },
            importParams: {
                let pickerController = legacyICloudFilePicker(theme: presentationData.theme,
                                                        mode: .import,
                                                        documentTypes: ["org.telegram.Telegram-iOS.chat-animation"],
                                                        allowsMultipleSelection: false,
                                                        completion: { urls in
                                                            guard let url = urls.first else { return }
                                                            guard let data = try? Data(contentsOf: url) else {
                                                                let action = TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                                                                let alertController = textAlertController(context: context, title: nil, text: "Failed to read file", actions: [action])
                                                                presentControllerImpl?(alertController)
                                                                return
                                                            }
                                                            let (animationSettings, decoderError) = ChatAnimationSettingsManager.decodeJSON(data)
                                                            guard let settings = animationSettings, decoderError == nil else {
                                                                let action = TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                                                                let alertController = textAlertController(context: context, title: nil, text: "Failed to import properties from the file.", actions: [action])
                                                                presentControllerImpl?(alertController)
                                                                return
                                                            }
                                                            
                                                            let action1 = TextAlertAction(type: .genericAction, title: "All types", action: {
                                                                chatAnimationSettings.update(settings)
                                                            })
                                                            let action2 = TextAlertAction(type: .defaultAction, title: "This type", action: {
                                                                chatAnimationSettings.update(settings, type: animationType)
                                                            })
                                                            let alertController = textAlertController(context: context, title: nil, text: "Do you want to import parameters only for current animation type, or for all types?", actions: [action1, action2])
                                                            presentControllerImpl?(alertController)
                                                        })
                presentControllerImpl?(pickerController)
            },
            restore: {
                let action1 = TextAlertAction(type: .genericAction, title: "All types", action: {
                    chatAnimationSettings.restore()
                })
                let action2 = TextAlertAction(type: .defaultAction, title: "This type", action: {
                    chatAnimationSettings.restore(type: animationType)
                })
                let alertController = textAlertController(context: context, title: nil, text: "Do you want to restore parameters only for current animation type, or for all types?", actions: [action1, action2])
                presentControllerImpl?(alertController)
            })
            
            return (controllerState, (listState, arguments))
        }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    controller.alwaysSynchronous = true
    controller.isOpaqueWhenInOverlay = true
    controller.blocksBackgroundWhenInOverlay = true
    controller.acceptsFocusWhenInOverlay = true
    
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    pushControllerImpl = { [weak controller] newController in
        (controller?.navigationController as? NavigationController)?.pushViewController(newController)
    }
    presentControllerImpl = { [weak controller] newController in
        controller?.present(newController, in: .window(.root))
    }
    presentActivityControllerImpl = { [weak controller] activityController in
        guard let window = controller?.view.window, let rootVC = window.rootViewController else { return }
        activityController.popoverPresentationController?.sourceView = window
        rootVC.present(activityController, animated: true, completion: nil)
    }
       
    return controller
}
