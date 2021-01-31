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
    case section1
    case section2
    case section3
    case section4
    case section5
    case section6
    case section7
}

private enum ChatAnimationSettingsControllerEntryId: Int32 {
    case type
    case duration
    case share
    case importParams
    case restore
    case header1
    case curve1
    case header2
    case curve2
    case header3
    case curve3
    case header4
    case curve4
    case header5
    case curve5
    case header6
    case curve6
    case header7
    case curve7
}

private enum ChatAnimationSettingsControllerEntry: ItemListNodeEntry {
    case type(ChatAnimationType, Int)
    case duration(ChatAnimationDuration, Int)
    case share
    case importParams
    case restore
    case header1(String, Int)
    case curve1(ChatAnimationDuration, ChatAnimationTimingFunction, Int)
    case header2(String, Int)
    case curve2(ChatAnimationDuration, ChatAnimationTimingFunction, Int)
    case header3(String, Int)
    case curve3(ChatAnimationDuration, ChatAnimationTimingFunction, Int)
    case header4(String, Int)
    case curve4(ChatAnimationDuration, ChatAnimationTimingFunction, Int)
    case header5(String, Int)
    case curve5(ChatAnimationDuration, ChatAnimationTimingFunction, Int)
    case header6(String, Int)
    case curve6(ChatAnimationDuration, ChatAnimationTimingFunction, Int)
    case header7(String, Int)
    case curve7(ChatAnimationDuration, ChatAnimationTimingFunction, Int)
    
    var section: ItemListSectionId {
        switch self {
        case .type, .duration, .share, .importParams, .restore:
            return ChatAnimationSettingsControllerSection.common.rawValue
        case .header1, .curve1:
            return ChatAnimationSettingsControllerSection.section1.rawValue
        case .header2, .curve2:
            return ChatAnimationSettingsControllerSection.section2.rawValue
        case .header3, .curve3:
            return ChatAnimationSettingsControllerSection.section3.rawValue
        case .header4, .curve4:
            return ChatAnimationSettingsControllerSection.section4.rawValue
        case .header5, .curve5:
            return ChatAnimationSettingsControllerSection.section5.rawValue
        case .header6, .curve6:
            return ChatAnimationSettingsControllerSection.section6.rawValue
        case .header7, .curve7:
            return ChatAnimationSettingsControllerSection.section7.rawValue
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
        case .header1:
            return .header1
        case .curve1:
            return .curve1
        case .header2:
            return .header2
        case .curve2:
            return .curve2
        case .header3:
            return .header3
        case .curve3:
            return .curve3
        case .header4:
            return .header4
        case .curve4:
            return .curve4
        case .header5:
            return .header5
        case .curve5:
            return .curve5
        case .header6:
            return .header6
        case .curve6:
            return .curve6
        case .header7:
            return .header7
        case .curve7:
            return .curve7
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
        case let .header1(_, value):
            return value
        case let .curve1(_, _, value):
            return value
        case let .header2(_, value):
            return value
        case let .curve2(_, _, value):
            return value
        case let .header3(_, value):
            return value
        case let .curve3(_, _, value):
            return value
        case let .header4(_, value):
            return value
        case let .curve4(_, _, value):
            return value
        case let .header5(_, value):
            return value
        case let .curve5(_, _, value):
            return value
        case let .header6(_, value):
            return value
        case let .curve6(_, _, value):
            return value
        case let .header7(_, value):
            return value
        case let .curve7(_, _, value):
            return value
        }
    }
    
    static func == (lhs: ChatAnimationSettingsControllerEntry, rhs: ChatAnimationSettingsControllerEntry) -> Bool {
        switch lhs {
        case let .type(lhsType, lhsDirtyCounter):
            if case let .type(rhsType, rhsDirtyCounter) = rhs, lhsType == rhsType, lhsDirtyCounter == rhsDirtyCounter {
                return true
            } else {
                return false
            }
        case let .duration(lhsDuration, lhsDirtyCounter):
            if case let .duration(rhsDuration, rhsDirtyCounter) = rhs, lhsDuration == rhsDuration, lhsDirtyCounter == rhsDirtyCounter {
                return true
            } else {
                return false
            }
        case let .curve1(lhsDuration, lhsFunction, lhsDirtyCounter):
            if case let .curve1(rhsDuration, rhsFunction, rhsDirtyCounter) = rhs, lhsDuration == rhsDuration, lhsFunction == rhsFunction, lhsDirtyCounter == rhsDirtyCounter {
                return true
            } else {
                return false
            }
        case let .curve2(lhsDuration, lhsFunction, lhsDirtyCounter):
            if case let .curve2(rhsDuration, rhsFunction, rhsDirtyCounter) = rhs, lhsDuration == rhsDuration, lhsFunction == rhsFunction, lhsDirtyCounter == rhsDirtyCounter {
                return true
            } else {
                return false
            }
        case let .curve3(lhsDuration, lhsFunction, lhsDirtyCounter):
            if case let .curve3(rhsDuration, rhsFunction, rhsDirtyCounter) = rhs, lhsDuration == rhsDuration, lhsFunction == rhsFunction, lhsDirtyCounter == rhsDirtyCounter {
                return true
            } else {
                return false
            }
        case let .curve4(lhsDuration, lhsFunction, lhsDirtyCounter):
            if case let .curve4(rhsDuration, rhsFunction, rhsDirtyCounter) = rhs, lhsDuration == rhsDuration, lhsFunction == rhsFunction, lhsDirtyCounter == rhsDirtyCounter {
                return true
            } else {
                return false
            }
        case let .curve5(lhsDuration, lhsFunction, lhsDirtyCounter):
            if case let .curve5(rhsDuration, rhsFunction, rhsDirtyCounter) = rhs, lhsDuration == rhsDuration, lhsFunction == rhsFunction, lhsDirtyCounter == rhsDirtyCounter {
                return true
            } else {
                return false
            }
        case let .curve6(lhsDuration, lhsFunction, lhsDirtyCounter):
            if case let .curve6(rhsDuration, rhsFunction, rhsDirtyCounter) = rhs, lhsDuration == rhsDuration, lhsFunction == rhsFunction, lhsDirtyCounter == rhsDirtyCounter {
                return true
            } else {
                return false
            }
        case let .curve7(lhsDuration, lhsFunction, lhsDirtyCounter):
            if case let .curve7(rhsDuration, rhsFunction, rhsDirtyCounter) = rhs, lhsDuration == rhsDuration, lhsFunction == rhsFunction, lhsDirtyCounter == rhsDirtyCounter {
                return true
            } else {
                return false
            }
        case let .header1(lhsTitle, lhsDirtyCounter):
            if case let .header1(rhsTitle, rhsDirtyCounter) = rhs, lhsTitle == rhsTitle, lhsDirtyCounter == rhsDirtyCounter {
                return true
            } else {
                return false
            }
        case let .header2(lhsTitle, lhsDirtyCounter):
            if case let .header2(rhsTitle, rhsDirtyCounter) = rhs, lhsTitle == rhsTitle, lhsDirtyCounter == rhsDirtyCounter {
                return true
            } else {
                return false
            }
        case let .header3(lhsTitle, lhsDirtyCounter):
            if case let .header3(rhsTitle, rhsDirtyCounter) = rhs, lhsTitle == rhsTitle, lhsDirtyCounter == rhsDirtyCounter {
                return true
            } else {
                return false
            }
        case let .header4(lhsTitle, lhsDirtyCounter):
            if case let .header4(rhsTitle, rhsDirtyCounter) = rhs, lhsTitle == rhsTitle, lhsDirtyCounter == rhsDirtyCounter {
                return true
            } else {
                return false
            }
        case let .header5(lhsTitle, lhsDirtyCounter):
            if case let .header5(rhsTitle, rhsDirtyCounter) = rhs, lhsTitle == rhsTitle, lhsDirtyCounter == rhsDirtyCounter {
                return true
            } else {
                return false
            }
        case let .header6(lhsTitle, lhsDirtyCounter):
            if case let .header6(rhsTitle, rhsDirtyCounter) = rhs, lhsTitle == rhsTitle, lhsDirtyCounter == rhsDirtyCounter {
                return true
            } else {
                return false
            }
        case let .header7(lhsTitle, lhsDirtyCounter):
            if case let .header7(rhsTitle, rhsDirtyCounter) = rhs, lhsTitle == rhsTitle, lhsDirtyCounter == rhsDirtyCounter {
                return true
            } else {
                return false
            }
        default:
            return lhs.dirtyCounter == rhs.dirtyCounter
        }
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
        case let .header1(title, _),
             let .header2(title, _),
             let .header3(title, _),
             let .header4(title, _),
             let .header5(title, _),
             let .header6(title, _),
             let .header7(title, _):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .curve1(duration, timingFunction, _),
             let .curve2(duration, timingFunction, _),
             let .curve3(duration, timingFunction, _),
             let .curve4(duration, timingFunction, _),
             let .curve5(duration, timingFunction, _),
             let .curve6(duration, timingFunction, _),
             let .curve7(duration, timingFunction, _):
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
            .header1("Y POSITION", state.dirtyCounter),
            .curve1(settings.duration, settings.yPositionFunc, state.dirtyCounter),
            .header2("X POSITION", state.dirtyCounter),
            .curve2(settings.duration, settings.xPositionFunc, state.dirtyCounter),
            .header3("BUBBLE SHAPE", state.dirtyCounter),
            .curve3(settings.duration, settings.bubbleShapeFunc, state.dirtyCounter),
            .header4("TEXT POSITION", state.dirtyCounter),
            .curve4(settings.duration, settings.textPositionFunc, state.dirtyCounter),
            .header5("COLOR CHANGE", state.dirtyCounter),
            .curve5(settings.duration, settings.colorChangeFunc, state.dirtyCounter),
            .header6("TIME APPEARS", state.dirtyCounter),
            .curve6(settings.duration, settings.timeAppearsFunc, state.dirtyCounter)
        ]
    } else if let settings = settings as? ChatAnimationSettingsEmoji {
        entries += [
            .header1("Y POSITION", state.dirtyCounter),
            .curve1(settings.duration, settings.yPositionFunc, state.dirtyCounter),
            .header2("X POSITION", state.dirtyCounter),
            .curve2(settings.duration, settings.xPositionFunc, state.dirtyCounter),
            .header3("EMOJI SCALE", state.dirtyCounter),
            .curve3(settings.duration, settings.emojiScaleFunc, state.dirtyCounter),
            .header4("TIME APPEARS", state.dirtyCounter),
            .curve4(settings.duration, settings.timeAppearsFunc, state.dirtyCounter)
        ]
    }
    else if let settings = settings as? ChatAnimationSettingsVoice {
        entries += [
            .header1("Y POSITION", state.dirtyCounter),
            .curve1(settings.duration, settings.yPositionFunc, state.dirtyCounter),
            .header2("X POSITION", state.dirtyCounter),
            .curve2(settings.duration, settings.xPositionFunc, state.dirtyCounter),
            .header3("SCALE", state.dirtyCounter),
            .curve3(settings.duration, settings.scaleFunc, state.dirtyCounter),
            .header4("FADE", state.dirtyCounter),
            .curve4(settings.duration, settings.fadeFunc, state.dirtyCounter)
        ]
    }
    else if let settings = settings as? ChatAnimationSettingsVideo {
        entries += [
            .header1("Y POSITION", state.dirtyCounter),
            .curve1(settings.duration, settings.yPositionFunc, state.dirtyCounter),
            .header2("X POSITION", state.dirtyCounter),
            .curve2(settings.duration, settings.xPositionFunc, state.dirtyCounter),
            .header3("SCALE", state.dirtyCounter),
            .curve3(settings.duration, settings.scaleFunc, state.dirtyCounter),
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
