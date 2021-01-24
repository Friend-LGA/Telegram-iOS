import Foundation

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
}

public struct ChatAnimationSettingsCommon: Codable {
    public let type: ChatAnimationType
    public let duration: ChatAnimationDuration
}

public struct ChatAnimationSettingsEmoji: Codable {
    public let type: ChatAnimationType
    public let duration: ChatAnimationDuration
}

public struct ChatAnimationSettingsManager: Codable {
    static private let smallSettingsKey = "ChatAnimationSettingsForSmallType"
    static private let bigSettingsKey = "ChatAnimationSettingsForBigType"
    static private let linkSettingsKey = "ChatAnimationSettingsForLinkType"
    static private let emojiSettingsKey = "ChatAnimationSettingsForEmojiType"
    static private let stickerSettingsKey = "ChatAnimationSettingsForStickerType"
    static private let voiceSettingsKey = "ChatAnimationSettingsForVoiceType"
    static private let videoSettingsKey = "ChatAnimationSettingsForVideoType"
    
    static private var _smallSettings: ChatAnimationSettingsCommon?
    static private var _bigSettings: ChatAnimationSettingsCommon?
    static private var _linkSettings: ChatAnimationSettingsCommon?
    static private var _emojiSettings: ChatAnimationSettingsEmoji?
    static private var _stickerSettings: ChatAnimationSettingsCommon?
    static private var _voiceSettings: ChatAnimationSettingsCommon?
    static private var _videoSettings: ChatAnimationSettingsCommon?
    
    private var smallSettings = ChatAnimationSettingsManager.smallSettings
    private var bigSettings = ChatAnimationSettingsManager.bigSettings
    private var linkSettings = ChatAnimationSettingsManager.linkSettings
    private var emojiSettings = ChatAnimationSettingsManager.emojiSettings
    private var stickerSettings = ChatAnimationSettingsManager.stickerSettings
    private var voiceSettings = ChatAnimationSettingsManager.voiceSettings
    private var videoSettings = ChatAnimationSettingsManager.videoSettings
    
    private init() {}
    
    static public var smallSettings: ChatAnimationSettingsCommon {
        if let settings = self._smallSettings {
            return settings
        }
        let defaults = UserDefaults.standard
        if let settings = defaults.object(forKey: smallSettingsKey) as? ChatAnimationSettingsCommon {
            self._smallSettings = settings
        } else {
            self._smallSettings = ChatAnimationSettingsCommon(type: ChatAnimationType.small, duration: ChatAnimationDuration.medium)
        }
        return self._smallSettings!
    }
    
    static public var bigSettings: ChatAnimationSettingsCommon {
        if let settings = self._bigSettings {
            return settings
        }
        let defaults = UserDefaults.standard
        if let settings = defaults.object(forKey: bigSettingsKey) as? ChatAnimationSettingsCommon {
            self._bigSettings = settings
        } else {
            self._bigSettings = ChatAnimationSettingsCommon(type: ChatAnimationType.big, duration: ChatAnimationDuration.medium)
        }
        return self._bigSettings!
    }
    
    static public var linkSettings: ChatAnimationSettingsCommon {
        if let settings = self._linkSettings {
            return settings
        }
        let defaults = UserDefaults.standard
        if let settings = defaults.object(forKey: linkSettingsKey) as? ChatAnimationSettingsCommon {
            self._linkSettings = settings
        } else {
            self._linkSettings = ChatAnimationSettingsCommon(type: ChatAnimationType.link, duration: ChatAnimationDuration.medium)
        }
        return self._linkSettings!
    }
    
    static public var emojiSettings: ChatAnimationSettingsEmoji {
        if let settings = self._emojiSettings {
            return settings
        }
        let defaults = UserDefaults.standard
        if let settings = defaults.object(forKey: emojiSettingsKey) as? ChatAnimationSettingsEmoji {
            self._emojiSettings = settings
        } else {
            self._emojiSettings = ChatAnimationSettingsEmoji(type: ChatAnimationType.emoji, duration: ChatAnimationDuration.medium)
        }
        return self._emojiSettings!
    }
    
    static public var stickerSettings: ChatAnimationSettingsCommon {
        if let settings = self._stickerSettings {
            return settings
        }
        let defaults = UserDefaults.standard
        if let settings = defaults.object(forKey: stickerSettingsKey) as? ChatAnimationSettingsCommon {
            self._stickerSettings = settings
        } else {
            self._stickerSettings = ChatAnimationSettingsCommon(type: ChatAnimationType.sticker, duration: ChatAnimationDuration.medium)
        }
        return self._stickerSettings!
    }
    
    static public var voiceSettings: ChatAnimationSettingsCommon {
        if let settings = self._voiceSettings {
            return settings
        }
        let defaults = UserDefaults.standard
        if let settings = defaults.object(forKey: voiceSettingsKey) as? ChatAnimationSettingsCommon {
            self._voiceSettings = settings
        } else {
            self._voiceSettings = ChatAnimationSettingsCommon(type: ChatAnimationType.voice, duration: ChatAnimationDuration.medium)
        }
        return self._voiceSettings!
    }
    
    static public var videoSettings: ChatAnimationSettingsCommon {
        if let settings = self._videoSettings {
            return settings
        }
        let defaults = UserDefaults.standard
        if let settings = defaults.object(forKey: videoSettingsKey) as? ChatAnimationSettingsCommon {
            self._videoSettings = settings
        } else {
            self._videoSettings = ChatAnimationSettingsCommon(type: ChatAnimationType.video, duration: ChatAnimationDuration.medium)
        }
        return self._videoSettings!
    }
        
    static public func update() {
        let defaults = UserDefaults.standard
        defaults.set(self.smallSettings, forKey: self.smallSettingsKey)
        defaults.set(self.bigSettings, forKey: self.bigSettingsKey)
        defaults.set(self.linkSettings, forKey: self.linkSettingsKey)
        defaults.set(self.emojiSettings, forKey: self.emojiSettingsKey)
        defaults.set(self.stickerSettings, forKey: self.stickerSettingsKey)
        defaults.set(self.voiceSettings, forKey: self.voiceSettingsKey)
        defaults.set(self.videoSettings, forKey: self.videoSettingsKey)
    }
    
    static private func update(_ settings: ChatAnimationSettingsManager) {
        self._smallSettings = settings.smallSettings
        self._bigSettings = settings.bigSettings
        self._linkSettings = settings.linkSettings
        self._emojiSettings = settings.emojiSettings
        self._stickerSettings = settings.stickerSettings
        self._voiceSettings = settings.voiceSettings
        self._videoSettings = settings.videoSettings
        self.update()
    }
    
    static public func generateJSONData() -> (Data?, Error?) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let settings = self.init()
        
        do {
            let data = try encoder.encode(settings)
            return (data, nil)
        } catch let error {
            return (nil, error)
        }
    }
    
    static public func generateJSONString() -> (String?, Error?) {
        let (jsonData, error) = self.generateJSONData()
        guard let data = jsonData else { return (nil, error) }
        let string = String(data: data, encoding: .utf8)
        return (string, nil)
    }
    
    static public func generateJSONFile() -> (URL?, Error?) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let path = documents?.appendingPathComponent("ChatAnimationSettings.json") else {
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
    
    static public func decodeJSON(_ data: Data) -> Error? {
        do {
            let decoder = JSONDecoder()
            let settings = try decoder.decode(self, from: data)
            self.update(settings)
            return nil
        } catch let error {
            return error
        }
    }
}
