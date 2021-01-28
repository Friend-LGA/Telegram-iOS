import Foundation
import CoreGraphics

public enum ChatAnimationType: String, Codable {
    case small = "Small Message"
    case big = "Big Message"
    case link = "Link with Preview"
    case emoji = "Single Emoji"
    case sticker = "Sticker"
    case voice = "Voice Message"
    case video = "Video Message"
    
    public var description: String {
        switch self {
        case .small:
            return "Small Message (fits in the input field)"
        case .big:
            return "Big Message (doesn't fit into the input field)"
        default:
            return self.rawValue
        }
    }
}

public enum ChatAnimationDuration: Double, Codable {
    case fast = 0.5
    case medium = 0.75
    case slow = 1.0
    
    public var description: String {
        switch self {
        case .fast:
            return "30f"
        case .medium:
            return "45f"
        case .slow:
            return "60f (1 sec)"
        }
    }
    
    public var maxValue: CGFloat {
        switch self {
        case .fast:
            return 30.0
        case .medium:
            return 45.0
        case .slow:
            return 60.0
        }
    }
}

final public class ChatAnimationTimingFunction: Codable {
    public var startTimeOffset: CGFloat
    public var endTimeOffset: CGFloat
    public var controlPoint1: CGPoint
    public var controlPoint2: CGPoint
    
    init(startTimeOffset: CGFloat = 0.0,
         endTimeOffset: CGFloat = 0.0,
         controlPoint1: CGPoint = CGPoint(x: 0.5, y: 0.0),
         controlPoint2: CGPoint = CGPoint(x: 0.5, y: 1.0)) {
        self.startTimeOffset = startTimeOffset
        self.endTimeOffset = endTimeOffset
        self.controlPoint1 = controlPoint1
        self.controlPoint2 = controlPoint2
    }
    
    public var startPoint: CGPoint {
        return CGPoint.zero
    }
    
    public var endPoint: CGPoint {
        return CGPoint(x: 1.0, y: 1.0)
    }
    
    public var duration: CGFloat {
        return 1.0 - endTimeOffset - startTimeOffset
    }
    
    public func restoreDefaults() {
        self.update(from: ChatAnimationTimingFunction())
    }
    
    public func update(from other: ChatAnimationTimingFunction) {
        self.startTimeOffset = other.startTimeOffset
        self.endTimeOffset = other.endTimeOffset
        self.controlPoint1 = other.controlPoint1
        self.controlPoint2 = other.controlPoint2
    }
}

public protocol ChatAnimationSettings: class {
    var type: ChatAnimationType { get }
    var duration: ChatAnimationDuration { get set }
    var yPositionFunc: ChatAnimationTimingFunction { get set }
    var xPositionFunc: ChatAnimationTimingFunction { get set }
    var timeAppearsFunc: ChatAnimationTimingFunction { get set }
}

final public class ChatAnimationSettingsCommon: ChatAnimationSettings, Codable {
    public let type: ChatAnimationType
    public var duration: ChatAnimationDuration
    public var yPositionFunc: ChatAnimationTimingFunction
    public var xPositionFunc: ChatAnimationTimingFunction
    public var bubbleShapeFunc: ChatAnimationTimingFunction
    public var textPositionFunc: ChatAnimationTimingFunction
    public var colorChangeFunc: ChatAnimationTimingFunction
    public var timeAppearsFunc: ChatAnimationTimingFunction
    
    init(_ type: ChatAnimationType,
         duration: ChatAnimationDuration = ChatAnimationDuration.fast,
         yPositionFunc: ChatAnimationTimingFunction = ChatAnimationTimingFunction(startTimeOffset: 0.0,
                                                                                  endTimeOffset: 0.0,
                                                                                  controlPoint1: CGPoint(x: 0.33, y: 0.0),
                                                                                  controlPoint2: CGPoint(x: 0.0, y: 1.0)),
         xPositionFunc: ChatAnimationTimingFunction = ChatAnimationTimingFunction(startTimeOffset: 0.0,
                                                                                  endTimeOffset: 0.5,
                                                                                  controlPoint1: CGPoint(x: 0.33, y: 0.0),
                                                                                  controlPoint2: CGPoint(x: 0.0, y: 1.0)),
         bubbleShapeFunc: ChatAnimationTimingFunction = ChatAnimationTimingFunction(startTimeOffset: 0.0,
                                                                                    endTimeOffset: 0.67,
                                                                                    controlPoint1: CGPoint(x: 0.33, y: 0.0),
                                                                                    controlPoint2: CGPoint(x: 0.0, y: 1.0)),
         textPositionFunc: ChatAnimationTimingFunction = ChatAnimationTimingFunction(startTimeOffset: 0.0,
                                                                                     endTimeOffset: 0.67,
                                                                                     controlPoint1: CGPoint(x: 0.33, y: 0.0),
                                                                                     controlPoint2: CGPoint(x: 0.0, y: 1.0)),
         colorChangeFunc: ChatAnimationTimingFunction = ChatAnimationTimingFunction(startTimeOffset: 0.0,
                                                                                    endTimeOffset: 0.5,
                                                                                    controlPoint1: CGPoint(x: 0.33, y: 0.0),
                                                                                    controlPoint2: CGPoint(x: 0.67, y: 1.0)),
         timeAppearsFunc: ChatAnimationTimingFunction = ChatAnimationTimingFunction(startTimeOffset: 0.0,
                                                                                    endTimeOffset: 0.5,
                                                                                    controlPoint1: CGPoint(x: 0.33, y: 0.0),
                                                                                    controlPoint2: CGPoint(x: 0.67, y: 1.0))) {
        self.type = type
        self.duration = duration
        self.yPositionFunc = yPositionFunc
        self.xPositionFunc = xPositionFunc
        self.bubbleShapeFunc = bubbleShapeFunc
        self.textPositionFunc = textPositionFunc
        self.colorChangeFunc = colorChangeFunc
        self.timeAppearsFunc = timeAppearsFunc
    }
    
    public func restoreDefaults() {
        self.update(from: ChatAnimationSettingsCommon(self.type))
    }
    
    public func update(from other: ChatAnimationSettingsCommon) {
        self.duration = other.duration
        self.yPositionFunc.update(from: other.yPositionFunc)
        self.xPositionFunc.update(from: other.xPositionFunc)
        self.bubbleShapeFunc.update(from: other.bubbleShapeFunc)
        self.textPositionFunc.update(from: other.textPositionFunc)
        self.colorChangeFunc.update(from: other.colorChangeFunc)
        self.timeAppearsFunc.update(from: other.timeAppearsFunc)
    }
    
    public func generateJSONData() -> (data: Data?, error: Error?) {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            return (data, nil)
        } catch let error {
            return (nil, error)
        }
    }
    
    static public func decodeJSON(_ data: Data) -> (result: ChatAnimationSettingsCommon?, error: Error?) {
        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode(self, from: data)
            return (result, nil)
        } catch let error {
            return (nil, error)
        }
    }
}

final public class ChatAnimationSettingsEmoji: ChatAnimationSettings, Codable {
    public let type: ChatAnimationType
    public var duration: ChatAnimationDuration
    public var yPositionFunc: ChatAnimationTimingFunction
    public var xPositionFunc: ChatAnimationTimingFunction
    public var emojiScaleFunc: ChatAnimationTimingFunction
    public var timeAppearsFunc: ChatAnimationTimingFunction
    
    init(duration: ChatAnimationDuration = ChatAnimationDuration.fast,
         yPositionFunc: ChatAnimationTimingFunction = ChatAnimationTimingFunction(startTimeOffset: 0.0,
                                                                                  endTimeOffset: 0.0,
                                                                                  controlPoint1: CGPoint(x: 0.33, y: 0.0),
                                                                                  controlPoint2: CGPoint(x: 0.0, y: 1.0)),
         xPositionFunc: ChatAnimationTimingFunction = ChatAnimationTimingFunction(startTimeOffset: 0.0,
                                                                                  endTimeOffset: 0.5,
                                                                                  controlPoint1: CGPoint(x: 0.33, y: 0.0),
                                                                                  controlPoint2: CGPoint(x: 0.0, y: 1.0)),
         emojiScaleFunc: ChatAnimationTimingFunction = ChatAnimationTimingFunction(startTimeOffset: 0.17,
                                                                                   endTimeOffset: 0.5,
                                                                                   controlPoint1: CGPoint(x: 0.33, y: 0.0),
                                                                                   controlPoint2: CGPoint(x: 0.0, y: 1.0)),
         timeAppearsFunc: ChatAnimationTimingFunction = ChatAnimationTimingFunction(startTimeOffset: 0.17,
                                                                                    endTimeOffset: 0.5,
                                                                                    controlPoint1: CGPoint(x: 0.33, y: 0.0),
                                                                                    controlPoint2: CGPoint(x: 0.67, y: 1.0))) {
        self.type = ChatAnimationType.emoji
        self.duration = duration
        self.yPositionFunc = yPositionFunc
        self.xPositionFunc = xPositionFunc
        self.emojiScaleFunc = emojiScaleFunc
        self.timeAppearsFunc = timeAppearsFunc
    }
    
    public func restoreDefaults() {
        self.update(from: ChatAnimationSettingsEmoji())
    }
    
    public func update(from other: ChatAnimationSettingsEmoji) {
        self.duration = other.duration
        self.yPositionFunc.update(from: other.yPositionFunc)
        self.xPositionFunc.update(from: other.xPositionFunc)
        self.emojiScaleFunc.update(from: other.emojiScaleFunc)
        self.timeAppearsFunc.update(from: other.timeAppearsFunc)
    }
    
    public func generateJSONData() -> (data: Data?, error: Error?) {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            return (data, nil)
        } catch let error {
            return (nil, error)
        }
    }
    
    static public func decodeJSON(_ data: Data) -> (result: ChatAnimationSettingsEmoji?, error: Error?) {
        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode(self, from: data)
            return (result, nil)
        } catch let error {
            return (nil, error)
        }
    }
}

final public class ChatAnimationSettingsManager: Codable {
    static private let smallSettingsKey = "ChatAnimationSettingsForSmallType"
    static private let bigSettingsKey = "ChatAnimationSettingsForBigType"
    static private let linkSettingsKey = "ChatAnimationSettingsForLinkType"
    static private let emojiSettingsKey = "ChatAnimationSettingsForEmojiType"
    static private let stickerSettingsKey = "ChatAnimationSettingsForStickerType"
    static private let voiceSettingsKey = "ChatAnimationSettingsForVoiceType"
    static private let videoSettingsKey = "ChatAnimationSettingsForVideoType"
    
    static private func keyForType(_ type: ChatAnimationType) -> String {
        switch type {
        case .small:
            return smallSettingsKey
        case .big:
            return bigSettingsKey
        case .link:
            return linkSettingsKey
        case .emoji:
            return emojiSettingsKey
        case .sticker:
            return stickerSettingsKey
        case .voice:
            return voiceSettingsKey
        case .video:
            return videoSettingsKey
        }
    }
    
    static private func getCommonSettings(for type: ChatAnimationType) -> ChatAnimationSettingsCommon {
        if let settingsData = UserDefaults.standard.object(forKey: self.keyForType(type)) as? Data,
           let settings = ChatAnimationSettingsCommon.decodeJSON(settingsData).result {
            return settings
        }
        
        return ChatAnimationSettingsCommon(type)
    }
    
    static private func getEmojiSettings() -> ChatAnimationSettingsEmoji {
        if let settingsData = UserDefaults.standard.object(forKey: self.keyForType(.emoji)) as? Data,
           let settings = ChatAnimationSettingsEmoji.decodeJSON(settingsData).result {
            return settings
        }
        
        return ChatAnimationSettingsEmoji()
    }
    
    public var smallSettings = ChatAnimationSettingsManager.getCommonSettings(for: .small)
    public var bigSettings = ChatAnimationSettingsManager.getCommonSettings(for: .big)
    public var linkSettings = ChatAnimationSettingsManager.getCommonSettings(for: .link)
    public var emojiSettings = ChatAnimationSettingsManager.getEmojiSettings()
    public var stickerSettings = ChatAnimationSettingsManager.getCommonSettings(for: .sticker)
    public var voiceSettings = ChatAnimationSettingsManager.getCommonSettings(for: .voice)
    public var videoSettings = ChatAnimationSettingsManager.getCommonSettings(for: .video)
    
    public init() {}
    
    public func getSettings(for type: ChatAnimationType) -> ChatAnimationSettings {
        switch type {
        case .small:
            return self.smallSettings
        case .big:
            return self.bigSettings
        case .link:
            return self.linkSettings
        case .emoji:
            return self.emojiSettings
        case .sticker:
            return self.stickerSettings
        case .voice:
            return self.voiceSettings
        case .video:
            return self.videoSettings
        }
    }
    
    public func applyChanges() {
        let defaults = UserDefaults.standard
        defaults.set(self.smallSettings.generateJSONData().data, forKey: ChatAnimationSettingsManager.smallSettingsKey)
        defaults.set(self.bigSettings.generateJSONData().data, forKey: ChatAnimationSettingsManager.bigSettingsKey)
        defaults.set(self.linkSettings.generateJSONData().data, forKey: ChatAnimationSettingsManager.linkSettingsKey)
        defaults.set(self.emojiSettings.generateJSONData().data, forKey: ChatAnimationSettingsManager.emojiSettingsKey)
        defaults.set(self.stickerSettings.generateJSONData().data, forKey: ChatAnimationSettingsManager.stickerSettingsKey)
        defaults.set(self.voiceSettings.generateJSONData().data, forKey: ChatAnimationSettingsManager.voiceSettingsKey)
        defaults.set(self.videoSettings.generateJSONData().data, forKey: ChatAnimationSettingsManager.videoSettingsKey)
    }
    
    public func update(from other: ChatAnimationSettingsManager, type: ChatAnimationType? = nil) {
        if let type = type {
            switch type {
            case .small:
                self.smallSettings.update(from: other.smallSettings)
            case .big:
                self.bigSettings.update(from: other.bigSettings)
            case .link:
                self.linkSettings.update(from: other.linkSettings)
            case .emoji:
                self.emojiSettings.update(from: other.emojiSettings)
            case .sticker:
                self.stickerSettings.update(from: other.stickerSettings)
            case .voice:
                self.voiceSettings.update(from: other.voiceSettings)
            case .video:
                self.videoSettings.update(from: other.videoSettings)
            }
        } else {
            self.smallSettings.update(from: other.smallSettings)
            self.bigSettings.update(from: other.bigSettings)
            self.linkSettings.update(from: other.linkSettings)
            self.emojiSettings.update(from: other.emojiSettings)
            self.stickerSettings.update(from: other.stickerSettings)
            self.voiceSettings.update(from: other.voiceSettings)
            self.videoSettings.update(from: other.videoSettings)
        }
    }
    
    public func restoreDefaults(type: ChatAnimationType? = nil) {
        if let type = type {
            switch type {
            case .small:
                self.smallSettings.restoreDefaults()
            case .big:
                self.bigSettings.restoreDefaults()
            case .link:
                self.linkSettings.restoreDefaults()
            case .emoji:
                self.emojiSettings.restoreDefaults()
            case .sticker:
                self.stickerSettings.restoreDefaults()
            case .voice:
                self.voiceSettings.restoreDefaults()
            case .video:
                self.videoSettings.restoreDefaults()
            }
        } else {
            self.smallSettings.restoreDefaults()
            self.bigSettings.restoreDefaults()
            self.linkSettings.restoreDefaults()
            self.emojiSettings.restoreDefaults()
            self.stickerSettings.restoreDefaults()
            self.voiceSettings.restoreDefaults()
            self.videoSettings.restoreDefaults()
        }
    }
    
    public func generateJSONData() -> (data: Data?, error: Error?) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(self)
            return (data, nil)
        } catch let error {
            return (nil, error)
        }
    }
    
    public func generateJSONString() -> (result: String?, error: Error?) {
        let (jsonData, error) = self.generateJSONData()
        guard let data = jsonData else { return (nil, error) }
        let string = String(data: data, encoding: .utf8)
        return (string, nil)
    }
    
    public func generateJSONFile() -> (url: URL?, error: Error?) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let path = documents?.appendingPathComponent("TelegramChatAnimationSettings.tgios-anim") else {
            return (nil, nil) // TODO: Should return custom error
        }
        
        let (jsonData, error) = self.generateJSONData()
        guard let data = jsonData else { return (nil, error) }
        
        do {
            try data.write(to: path)
            return (path, nil)
        } catch let error {
            return (nil, error)
        }
    }
    
    static public func decodeJSON(_ data: Data) -> (result: ChatAnimationSettingsManager?, error: Error?) {
        do {
            let decoder = JSONDecoder()
            let settings = try decoder.decode(self, from: data)
            return (settings, nil)
        } catch let error {
            return (nil, error)
        }
    }
}
