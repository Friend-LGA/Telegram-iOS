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

private var currentAnimationType = ChatAnimationType.small

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
    case emojiScale
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
    case emojiScaleHeader
    case emojiScale
    case timeAppearsHeader
    case timeAppears
}

private enum ChatAnimationSettingsControllerEntry: ItemListNodeEntry {
    case type(ChatAnimationType, Int)
    case duration(ChatAnimationDuration, Int)
    case share
    case importParams
    case restore
    case yPositionHeader
    case yPosition(ChatAnimationDuration, ChatAnimationTimingFunction, Int)
    case xPositionHeader
    case xPosition(ChatAnimationDuration, ChatAnimationTimingFunction, Int)
    case bubbleShapeHeader
    case bubbleShape(ChatAnimationDuration, ChatAnimationTimingFunction, Int)
    case textPositionHeader
    case textPosition(ChatAnimationDuration, ChatAnimationTimingFunction, Int)
    case colorChangeHeader
    case colorChange(ChatAnimationDuration, ChatAnimationTimingFunction, Int)
    case emojiScaleHeader
    case emojiScale(ChatAnimationDuration, ChatAnimationTimingFunction, Int)
    case timeAppearsHeader
    case timeAppears(ChatAnimationDuration, ChatAnimationTimingFunction, Int)
    
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
        case .emojiScaleHeader, .emojiScale:
            return ChatAnimationSettingsControllerSection.emojiScale.rawValue
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
        case .emojiScaleHeader:
            return .emojiScaleHeader
        case .emojiScale:
            return .emojiScale
        case .timeAppearsHeader:
            return .timeAppearsHeader
        case .timeAppears:
            return .timeAppears
        }
    }
    
    var dirtyCounter: Int {
        switch self {
        case let .type(_, value):
            return value
        case let .duration(_, value):
            return value
        case .share:
            return 0
        case .importParams:
            return 0
        case .restore:
            return 0
        case .yPositionHeader:
            return 0
        case let .yPosition(_, _, value):
            return value
        case .xPositionHeader:
            return 0
        case let .xPosition(_, _, value):
            return value
        case .bubbleShapeHeader:
            return 0
        case let .bubbleShape(_, _, value):
            return value
        case .textPositionHeader:
            return 0
        case let .textPosition(_, _, value):
            return value
        case .colorChangeHeader:
            return 0
        case let .colorChange(_, _, value):
            return value
        case .emojiScaleHeader:
            return 0
        case let .emojiScale(_, _, value):
            return value
        case .timeAppearsHeader:
            return 0
        case let .timeAppears(_, _, value):
            return value
        }
    }
    
    static func == (lhs: ChatAnimationSettingsControllerEntry, rhs: ChatAnimationSettingsControllerEntry) -> Bool {
        return lhs.dirtyCounter == rhs.dirtyCounter
    }
    
    static func < (lhs: ChatAnimationSettingsControllerEntry, rhs: ChatAnimationSettingsControllerEntry) -> Bool {
        return lhs.stableId.rawValue < rhs.stableId.rawValue
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChatAnimationSettingsControllerArguments
        switch self {
        case let .type(value, _):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Animation Type", label: value.rawValue, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: { arguments.openType()
            })
        case let .duration(value, _):
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
        case .xPositionHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "X POSITION", sectionId: self.section)
        case .bubbleShapeHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "BUBBLE SHAPE", sectionId: self.section)
        case .textPositionHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "TEXT POSITION", sectionId: self.section)
        case .colorChangeHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "COLOR CHANGE", sectionId: self.section)
        case .emojiScaleHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "EMOJI SCALE", sectionId: self.section)
        case .timeAppearsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "TIME APPEARS", sectionId: self.section)
        case let .yPosition(duration, timingFunction, _),
             let .xPosition(duration, timingFunction, _),
             let .bubbleShape(duration, timingFunction, _),
             let .textPosition(duration, timingFunction, _),
             let .colorChange(duration, timingFunction, _),
             let .emojiScale(duration, timingFunction, _),
             let .timeAppears(duration, timingFunction, _):
            return ChatAnimationSettingsCurveItem(presentationData: presentationData, sectionId: self.section, duration: duration, timingFunction: timingFunction)
        }
    }
}

private struct ChatAnimationSettingsControllerState: Equatable {
    // to force pipeline to update
    var dirtyCounter = 0
    
    static func == (lhs: ChatAnimationSettingsControllerState, rhs: ChatAnimationSettingsControllerState) -> Bool {
        return lhs.dirtyCounter == rhs.dirtyCounter
    }
}

private func createChatAnimationSettingsControllerEntries(_ state: ChatAnimationSettingsControllerState, settings: ChatAnimationSettings) -> [ChatAnimationSettingsControllerEntry] {
    var entries: [ChatAnimationSettingsControllerEntry] = [
        .type(settings.type, state.dirtyCounter),
        .duration(settings.duration, state.dirtyCounter),
        .share,
        .importParams,
        .restore,
    ]
    
    if let settings = settings as? ChatAnimationSettingsCommon {
        entries += [
            .yPositionHeader,
            .yPosition(settings.duration, settings.yPositionFunc, state.dirtyCounter),
            .xPositionHeader,
            .xPosition(settings.duration, settings.xPositionFunc, state.dirtyCounter),
            .bubbleShapeHeader,
            .bubbleShape(settings.duration, settings.bubbleShapeFunc, state.dirtyCounter),
            .textPositionHeader,
            .textPosition(settings.duration, settings.textPositionFunc, state.dirtyCounter),
            .colorChangeHeader,
            .colorChange(settings.duration, settings.colorChangeFunc, state.dirtyCounter),
            .timeAppearsHeader,
            .timeAppears(settings.duration, settings.timeAppearsFunc, state.dirtyCounter)
        ]
    } else if let settings = settings as? ChatAnimationSettingsEmoji {
        entries += [
            .yPositionHeader,
            .yPosition(settings.duration, settings.yPositionFunc, state.dirtyCounter),
            .xPositionHeader,
            .xPosition(settings.duration, settings.xPositionFunc, state.dirtyCounter),
            .emojiScaleHeader,
            .emojiScale(settings.duration, settings.emojiScaleFunc, state.dirtyCounter),
            .timeAppearsHeader,
            .timeAppears(settings.duration, settings.timeAppearsFunc, state.dirtyCounter)
        ]
    }
    return entries
}

public func createChatAnimationSettingsController(context: AccountContext) -> ViewController {
    let settingsManager = ChatAnimationSettingsManager()
        
    let initialState = ChatAnimationSettingsControllerState()
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((ChatAnimationSettingsControllerState) -> ChatAnimationSettingsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
        
    var dismissImpl: (() -> Void)?
    var reloadImpl: (() -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    var presentActivityControllerImpl: ((UIActivityViewController) -> Void)?
        
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get() |> deliverOnMainQueue)
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
            
            let rightNavigationButton = ItemListNavigationButton(content: .text("Apply"), style: .bold, enabled: true, action: {
                settingsManager.applyChanges()
                dismissImpl?()
            })
                        
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData),
                                                          title: .text("Animation Settings"),
                                                          leftNavigationButton: leftNavigationButton,
                                                          rightNavigationButton: rightNavigationButton,
                                                          backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
                                                          animateChanges: false)
            
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData),
                                              entries: createChatAnimationSettingsControllerEntries(state, settings: settingsManager.getSettings(for: currentAnimationType)),
                                              style: .blocks,
                                              animateChanges: false)
            
            let arguments = ChatAnimationSettingsControllerArguments(openType: {
                pushControllerImpl?(createChatAnimationSettingsTypeController(context: context, onChange: { type in
                    currentAnimationType = type
                    reloadImpl?()
                }))
            },
            openDuration: {
                let actionSheet = ActionSheetController(presentationData: presentationData)
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetTextItem(title: "Duration"),
                        ActionSheetButtonItem(title: ChatAnimationDuration.fast.description, color: .accent, action: { [weak actionSheet] in
                            settingsManager.getSettings(for: currentAnimationType).duration = ChatAnimationDuration.fast
                            reloadImpl?()
                            actionSheet?.dismissAnimated()
                        }),
                        ActionSheetButtonItem(title: ChatAnimationDuration.medium.description, color: .accent, action: { [weak actionSheet] in
                            settingsManager.getSettings(for: currentAnimationType).duration = ChatAnimationDuration.medium
                            reloadImpl?()
                            actionSheet?.dismissAnimated()
                        }),
                        ActionSheetButtonItem(title: ChatAnimationDuration.slow.description, color: .accent, action: { [weak actionSheet] in
                            settingsManager.getSettings(for: currentAnimationType).duration = ChatAnimationDuration.slow
                            reloadImpl?()
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
                let (path, error) = settingsManager.generateJSONFile()
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
                                                            let (settingsSnapshotDecoded, decoderError) = ChatAnimationSettingsManager.decodeJSON(data)
                                                            guard let settingsSnapshot = settingsSnapshotDecoded, decoderError == nil else {
                                                                let action = TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                                                                let alertController = textAlertController(context: context, title: nil, text: "Failed to import properties from the file.", actions: [action])
                                                                presentControllerImpl?(alertController)
                                                                return
                                                            }
                                                            
                                                            let action1 = TextAlertAction(type: .genericAction, title: "All types", action: {
                                                                settingsManager.update(from: settingsSnapshot)
                                                                reloadImpl?()
                                                            })
                                                            let action2 = TextAlertAction(type: .defaultAction, title: "This type", action: {
                                                                settingsManager.update(from: settingsSnapshot, type: currentAnimationType)
                                                                reloadImpl?()
                                                            })
                                                            let alertController = textAlertController(context: context, title: nil, text: "Do you want to import parameters only for current animation type, or for all types?", actions: [action1, action2])
                                                            presentControllerImpl?(alertController)
                                                        })
                presentControllerImpl?(pickerController)
            },
            restore: {
                let action1 = TextAlertAction(type: .genericAction, title: "All types", action: {
                    settingsManager.restoreDefaults()
                    reloadImpl?()
                })
                let action2 = TextAlertAction(type: .defaultAction, title: "This type", action: {
                    settingsManager.restoreDefaults(type: currentAnimationType)
                    reloadImpl?()
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
    controller.additionalInsets = UIEdgeInsets(top: CGFloat.zero, left: CGFloat.zero, bottom: 64.0, right: CGFloat.zero)
    
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    reloadImpl = {
        updateState { state in
            var state = state
            // make it dirty to trigger update chain for signal
            state.dirtyCounter += 1
            return state
        }
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
