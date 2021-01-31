import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import LegacyComponents
import AccountContext
import ChatInterfaceState
import AudioBlob

private let offsetThreshold: CGFloat = 10.0
private let dismissOffsetThreshold: CGFloat = 70.0

private func findTargetView(_ view: UIView, point: CGPoint) -> UIView? {
    if view.bounds.contains(point) && view.tag == 0x01f2bca {
        return view
    }
    for subview in view.subviews {
        let frame = subview.frame
        if let result = findTargetView(subview, point: point.offsetBy(dx: -frame.minX, dy: -frame.minY)) {
            return result
        }
    }
    return nil
}

private final class ChatTextInputMediaRecordingButtonPresenterContainer: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = findTargetView(self, point: point) {
            return result
        }
        for subview in self.subviews {
            if let result = subview.hitTest(point.offsetBy(dx: -subview.frame.minX, dy: -subview.frame.minY), with: event) {
                return result
            }
        }
        
        return super.hitTest(point, with: event)
    }
}

private final class ChatTextInputMediaRecordingButtonPresenterController: ViewController {
    private var controllerNode: ChatTextInputMediaRecordingButtonPresenterControllerNode {
        return self.displayNode as! ChatTextInputMediaRecordingButtonPresenterControllerNode
    }
    
    var containerView: UIView? {
        didSet {
            if self.isNodeLoaded {
                self.controllerNode.containerView = self.containerView
            }
        }
    }
    
    override func loadDisplayNode() {
        self.displayNode = ChatTextInputMediaRecordingButtonPresenterControllerNode()
        if let containerView = self.containerView {
            self.controllerNode.containerView = containerView
        }
    }
}

private final class ChatTextInputMediaRecordingButtonPresenterControllerNode: ViewControllerTracingNode {
    var containerView: UIView? {
        didSet {
            if self.containerView !== oldValue {
                if self.isNodeLoaded, let containerView = oldValue, containerView.superview === self.view {
                    containerView.removeFromSuperview()
                }
                if self.isNodeLoaded, let containerView = self.containerView {
                    self.view.addSubview(containerView)
                }
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        if let containerView = self.containerView {
            self.view.addSubview(containerView)
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let containerView = self.containerView {
            if let result = containerView.hitTest(point, with: event), result !== containerView {
                return result
            }
        }
        return nil
    }
}

private final class ChatTextInputMediaRecordingButtonPresenter : NSObject, TGModernConversationInputMicButtonPresentation {
    private let account: Account?
    private let presentController: (ViewController) -> Void
    private let container: ChatTextInputMediaRecordingButtonPresenterContainer
    private var presentationController: ChatTextInputMediaRecordingButtonPresenterController?
    
    init(account: Account, presentController: @escaping (ViewController) -> Void) {
        self.account = account
        self.presentController = presentController
        self.container = ChatTextInputMediaRecordingButtonPresenterContainer()
    }
    
    deinit {
        self.container.removeFromSuperview()
        if let presentationController = self.presentationController {
            presentationController.presentingViewController?.dismiss(animated: false, completion: {})
            self.presentationController = nil
        }
    }
    
    func view() -> UIView! {
        return self.container
    }
    
    func setUserInteractionEnabled(_ enabled: Bool) {
        self.container.isUserInteractionEnabled = enabled
    }
    
    func present() {
        if let keyboardWindow = LegacyComponentsGlobals.provider().applicationKeyboardWindow(), !keyboardWindow.isHidden {
            keyboardWindow.addSubview(self.container)
        } else {
            var presentNow = false
            if self.presentationController == nil {
                let presentationController = ChatTextInputMediaRecordingButtonPresenterController(navigationBarPresentationData: nil)
                presentationController.statusBar.statusBarStyle = .Ignore
                self.presentationController = presentationController
                presentNow = true
            }
            
            self.presentationController?.containerView = self.container
            if let presentationController = self.presentationController, presentNow {
                self.presentController(presentationController)
            }
        }
    }
    
    func dismiss() {
        self.container.removeFromSuperview()
        if let presentationController = self.presentationController {
            presentationController.presentingViewController?.dismiss(animated: false, completion: {})
            self.presentationController = nil
        }
    }
}

final class ChatTextInputMediaRecordingButton: TGModernConversationInputMicButton, TGModernConversationInputMicButtonDelegate {
    private var theme: PresentationTheme
    private let strings: PresentationStrings
    
    var mode: ChatTextInputMediaRecordingButtonMode = .audio
    var account: Account?
    let presentController: (ViewController) -> Void
    var recordingDisabled: () -> Void = { }
    var beginRecording: () -> Void = { }
    var endRecording: (Bool) -> Void = { _ in }
    var stopRecording: () -> Void = { }
    var offsetRecordingControls: () -> Void = { }
    var switchMode: () -> Void = { }
    var updateLocked: (Bool) -> Void = { _ in }
    var updateCancelTranslation: () -> Void = { }
    
    private var modeTimeoutTimer: SwiftSignalKit.Timer?
    
    private let innerIconView: UIImageView
    
    private var recordingOverlay: ChatTextInputAudioRecordingOverlay?
    private var startTouchLocation: CGPoint?
    private(set) var controlsOffset: CGFloat = 0.0
    private(set) var cancelTranslation: CGFloat = 0.0
    
    private var micLevelDisposable: MetaDisposable?
    
    var audioRecorder: ManagedAudioRecorder? {
        didSet {
            if self.audioRecorder !== oldValue {
                if self.micLevelDisposable == nil {
                    micLevelDisposable = MetaDisposable()
                }
                if let audioRecorder = self.audioRecorder {
                    self.micLevelDisposable?.set(audioRecorder.micLevel.start(next: { [weak self] level in
                        Queue.mainQueue().async {
                            //self?.recordingOverlay?.addImmediateMicLevel(CGFloat(level))
                            self?.addMicLevel(CGFloat(level))
                        }
                    }))
                } else if self.videoRecordingStatus == nil {
                    self.micLevelDisposable?.set(nil)
                }
                
                self.hasRecorder = self.audioRecorder != nil || self.videoRecordingStatus != nil
            }
        }
    }
    
    var videoRecordingStatus: InstantVideoControllerRecordingStatus? {
        didSet {
            if self.videoRecordingStatus !== oldValue {
                if self.micLevelDisposable == nil {
                    micLevelDisposable = MetaDisposable()
                }
                
                if let videoRecordingStatus = self.videoRecordingStatus {
                    self.micLevelDisposable?.set(videoRecordingStatus.micLevel.start(next: { [weak self] level in
                        Queue.mainQueue().async {
                            //self?.recordingOverlay?.addImmediateMicLevel(CGFloat(level))
                            self?.addMicLevel(CGFloat(level))
                        }
                    }))
                } else if self.audioRecorder == nil {
                    self.micLevelDisposable?.set(nil)
                }
                
                self.hasRecorder = self.audioRecorder != nil || self.videoRecordingStatus != nil
            }
        }
    }
    
    private var hasRecorder: Bool = false {
        didSet {
            if self.hasRecorder != oldValue {
                if self.hasRecorder {
                    self.animateIn()
                } else {
                    self.animateOut(false)
                }
            }
        }
    }
    
    public lazy var micDecoration: VoiceBlobView = {
        let blobView = VoiceBlobView(
            frame: CGRect(origin: CGPoint(), size: CGSize(width: 220.0, height: 220.0)),
            maxLevel: 4,
            smallBlobRange: (0.45, 0.55),
            mediumBlobRange: (0.52, 0.87),
            bigBlobRange: (0.57, 1.00)
        )
        blobView.setColor(self.theme.chat.inputPanel.actionControlFillColor)
        return blobView
    }()
    
    private lazy var micLock: (UIView & TGModernConversationInputMicButtonLock) = {
        let lockView = LockView(frame: CGRect(origin: CGPoint(), size: CGSize(width: 40.0, height: 60.0)), theme: self.theme, strings: self.strings)
        lockView.addTarget(self, action: #selector(handleStopTap), for: .touchUpInside)
        return lockView
    }()
    
    init(theme: PresentationTheme, strings: PresentationStrings, presentController: @escaping (ViewController) -> Void) {
        self.theme = theme
        self.strings = strings
        self.innerIconView = UIImageView()
        self.presentController = presentController
         
        super.init(frame: CGRect())
        
        self.disablesInteractiveTransitionGestureRecognizer = true
        
        self.pallete = legacyInputMicPalette(from: theme)
        
        self.insertSubview(self.innerIconView, at: 0)
        
        self.disablesInteractiveTransitionGestureRecognizer = true
        
        self.updateMode(mode: self.mode, animated: false, force: true)
        
        self.delegate = self
        self.isExclusiveTouch = false;
        
        self.centerOffset = CGPoint(x: 0.0, y: -1.0 + UIScreenPixel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateMode(mode: ChatTextInputMediaRecordingButtonMode, animated: Bool) {
        self.updateMode(mode: mode, animated: animated, force: false)
    }
        
    private func updateMode(mode: ChatTextInputMediaRecordingButtonMode, animated: Bool, force: Bool) {
        if mode != self.mode || force {
            self.mode = mode
            
            if animated {
                let previousView = UIImageView(image: self.innerIconView.image)
                previousView.frame = self.innerIconView.frame
                self.addSubview(previousView)
                previousView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
                previousView.layer.animateScale(from: 1.0, to: 0.3, duration: 0.15, removeOnCompletion: false, completion: { [weak previousView] _ in
                    previousView?.removeFromSuperview()
                })
            }
            
            switch self.mode {
                case .audio:
                    self.icon = PresentationResourcesChat.chatInputPanelVoiceActiveButtonImage(self.theme)
                    self.innerIconView.image = PresentationResourcesChat.chatInputPanelVoiceButtonImage(self.theme)
                case .video:
                    self.icon = PresentationResourcesChat.chatInputPanelVideoActiveButtonImage(self.theme)
                    self.innerIconView.image = PresentationResourcesChat.chatInputPanelVideoButtonImage(self.theme)
            }
            if let image = self.innerIconView.image {
                let size = self.bounds.size
                let iconSize = image.size
                self.innerIconView.frame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize)
            }
            
            if animated {
                self.innerIconView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, removeOnCompletion: false)
                self.innerIconView.layer.animateSpring(from: 0.4 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
            }
        }
    }
    
    func updateTheme(theme: PresentationTheme) {
        self.theme = theme
        
        switch self.mode {
            case .audio:
                self.icon = PresentationResourcesChat.chatInputPanelVoiceActiveButtonImage(self.theme)
                self.innerIconView.image = PresentationResourcesChat.chatInputPanelVoiceButtonImage(self.theme)
            case .video:
                self.icon = PresentationResourcesChat.chatInputPanelVideoActiveButtonImage(self.theme)
                self.innerIconView.image = PresentationResourcesChat.chatInputPanelVideoButtonImage(self.theme)
        }
        
        self.pallete = legacyInputMicPalette(from: theme)
        self.micDecoration.setColor(self.theme.chat.inputPanel.actionControlFillColor)
        (self.micLock as? LockView)?.updateTheme(theme)
    }
    
    deinit {
        if let micLevelDisposable = self.micLevelDisposable {
            micLevelDisposable.dispose()
        }
        if let recordingOverlay = self.recordingOverlay {
            recordingOverlay.dismiss()
        }
    }
    
    func cancelRecording() {
        self.isEnabled = false
        self.isEnabled = true
    }
    
    func micButtonInteractionBegan() {
        if self.fadeDisabled {
            self.recordingDisabled()
        } else {
            //print("\(CFAbsoluteTimeGetCurrent()) began")
            self.modeTimeoutTimer?.invalidate()
            let modeTimeoutTimer = SwiftSignalKit.Timer(timeout: 0.19, repeat: false, completion: { [weak self] in
                if let strongSelf = self {
                    strongSelf.modeTimeoutTimer = nil
                    strongSelf.beginRecording()
                }
            }, queue: Queue.mainQueue())
            self.modeTimeoutTimer = modeTimeoutTimer
            modeTimeoutTimer.start()
        }
    }
    
    func micButtonInteractionCancelled(_ velocity: CGPoint) {
        //print("\(CFAbsoluteTimeGetCurrent()) cancelled")
        self.modeTimeoutTimer?.invalidate()
        self.endRecording(false)
    }
    
    func micButtonInteractionCompleted(_ velocity: CGPoint) {
        //print("\(CFAbsoluteTimeGetCurrent()) completed")
        if let modeTimeoutTimer = self.modeTimeoutTimer {
            //print("\(CFAbsoluteTimeGetCurrent()) switch")
            modeTimeoutTimer.invalidate()
            self.modeTimeoutTimer = nil
            self.switchMode()
        }
        self.endRecording(true)
    }
    
    func micButtonInteractionUpdate(_ offset: CGPoint) {
        self.controlsOffset = offset.x
        self.offsetRecordingControls()
    }
    
    func micButtonInteractionUpdateCancelTranslation(_ translation: CGFloat) {
        self.cancelTranslation = translation
        self.updateCancelTranslation()
    }
    
    func micButtonInteractionLocked() {
        self.updateLocked(true)
    }
    
    func micButtonInteractionRequestedLockedAction() {
    }
    
    func micButtonInteractionStopped() {
        self.stopRecording()
    }
    
    func micButtonShouldLock() -> Bool {
        return true
    }
    
    func micButtonPresenter() -> TGModernConversationInputMicButtonPresentation! {
        return ChatTextInputMediaRecordingButtonPresenter(account: self.account!, presentController: self.presentController)
    }
    
    func micButtonDecoration() -> (UIView & TGModernConversationInputMicButtonDecoration)! {
        return micDecoration
    }
    
    func micButtonLock() -> (UIView & TGModernConversationInputMicButtonLock)! {
        return micLock
    }
    
    @objc private func handleStopTap() {
        micButtonInteractionStopped()
    }
    
    override func animateIn() {
        super.animateIn()
        
        micDecoration.startAnimating()

        innerIconView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
        innerIconView.layer.animateScale(from: 1.0, to: 0.3, duration: 0.15, removeOnCompletion: false)
    }

    override func animateOut(_ toSmallSize: Bool) {
        super.animateOut(toSmallSize)
        
        micDecoration.stopAnimating()
        
        if toSmallSize {
            micDecoration.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.03, delay: 0.15, removeOnCompletion: false)
        } else {
            micDecoration.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false)
            innerIconView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, removeOnCompletion: false)
            innerIconView.layer.animateScale(from: 0.3, to: 1.0, duration: 0.15, removeOnCompletion: false)
        }
    }
    
    private var previousSize = CGSize()
    func layoutItems() {
        let size = self.bounds.size
        if size != self.previousSize {
            self.previousSize = size
            let iconSize = self.innerIconView.bounds.size
            self.innerIconView.frame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize)
        }
    }
}
