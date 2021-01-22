import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

enum ChatMessageBackgroundMergeType: Equatable {
    case None, Side, Top(side: Bool), Bottom, Both, Extracted
    
    init(top: Bool, bottom: Bool, side: Bool) {
        if top && bottom {
            self = .Both
        } else if top {
            self = .Top(side: side)
        } else if bottom {
            if side {
                self = .Side
            } else {
                self = .Bottom
            }
        } else {
            if side {
                self = .Side
            } else {
                self = .None
            }
        }
    }
}

enum ChatMessageBackgroundType: Equatable {
    case none
    case incoming(ChatMessageBackgroundMergeType)
    case outgoing(ChatMessageBackgroundMergeType)

    static func ==(lhs: ChatMessageBackgroundType, rhs: ChatMessageBackgroundType) -> Bool {
        switch lhs {
            case .none:
                if case .none = rhs {
                    return true
                } else {
                    return false
                }
            case let .incoming(mergeType):
                if case .incoming(mergeType) = rhs {
                    return true
                } else {
                    return false
                }
            case let .outgoing(mergeType):
                if case .outgoing(mergeType) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

class ChatMessageBackground: ASDisplayNode {
    private(set) var type: ChatMessageBackgroundType?
    private var currentHighlighted: Bool?
    private var hasWallpaper: Bool?
    private var graphics: PrincipalThemeEssentialGraphics?
    private var maskMode: Bool?
    private let imageNode: ASImageNode
    private let outlineImageNode: ASImageNode
    private var imagesAreHidden: Bool
    
    var hasImage: Bool {
        self.imageNode.image != nil
    }
    
    public var chatMessageBackgroundFillColor: UIColor {
        guard let graphics = self.graphics else { return UIColor.clear }
        return graphics.chatMessageBackgroundFillColor
    }

    public var chatMessageBackgroundStrokeColor: UIColor {
        guard let graphics = self.graphics else { return UIColor.clear }
        return graphics.chatMessageBackgroundStrokeColor
    }

    public var chatMessageBackgroundMinCornerRadius: CGFloat {
        guard let graphics = self.graphics else { return 8.0 } // Hooray to magic numbers!!!
        return graphics.chatMessageBackgroundMinCornerRadius
    }

    public var chatMessageBackgroundMaxCornerRadius: CGFloat {
        guard let graphics = self.graphics else { return 16.0 }
        return graphics.chatMessageBackgroundMaxCornerRadius
    }

    public var neighborsDirection: MessageBubbleImageNeighbors {
        switch self.type {
        case let .outgoing(mergeType):
            switch mergeType {
            case .Bottom:
                return .bottom
            default:
                return .none
            }
        default:
            return .none
        }
    }

    override convenience init() {
        self.init(animatedFromTextPanel: false)
    }

    init(animatedFromTextPanel: Bool = false) {
        self.imageNode = ASImageNode()
        self.imageNode.displaysAsynchronously = false
        self.imageNode.displayWithoutProcessing = true
        
        self.outlineImageNode = ASImageNode()
        self.outlineImageNode.displaysAsynchronously = false
        self.outlineImageNode.displayWithoutProcessing = true
        
        self.imagesAreHidden = animatedFromTextPanel

        super.init()
        
        self.isUserInteractionEnabled = false

        if self.imagesAreHidden {
            self.imageNode.isHidden = true
            self.outlineImageNode.isHidden = true
        } else {
            self.addSubnode(self.outlineImageNode)
            self.addSubnode(self.imageNode)
        }
    }

    public func showImages() {
        guard self.imagesAreHidden else { return }
        self.imageNode.isHidden = false
        self.outlineImageNode.isHidden = false
        self.addSubnode(self.outlineImageNode)
        self.addSubnode(self.imageNode)
        self.imagesAreHidden = false
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let newFrame = CGRect(origin: CGPoint(), size: size).insetBy(dx: -1.0, dy: -1.0)
        if self.imagesAreHidden {
            self.imageNode.frame = newFrame
            self.outlineImageNode.frame = newFrame
        } else {
            transition.updateFrame(node: self.imageNode, frame: newFrame)
            transition.updateFrame(node: self.outlineImageNode, frame: newFrame)
        }
    }
    
    func setMaskMode(_ maskMode: Bool) {
        if let type = self.type, let hasWallpaper = self.hasWallpaper, let highlighted = self.currentHighlighted, let graphics = self.graphics {
            self.setType(type: type, highlighted: highlighted, graphics: graphics, maskMode: maskMode, hasWallpaper: hasWallpaper, transition: .immediate)
        }
    }
    
    func setType(type: ChatMessageBackgroundType, highlighted: Bool, graphics: PrincipalThemeEssentialGraphics, maskMode: Bool, hasWallpaper: Bool, transition: ContainedViewLayoutTransition) {
        let previousType = self.type
        if let currentType = previousType, currentType == type, self.currentHighlighted == highlighted, self.graphics === graphics, self.maskMode == maskMode, self.hasWallpaper == hasWallpaper {
            return
        }
        self.type = type
        self.currentHighlighted = highlighted
        self.graphics = graphics
        self.hasWallpaper = hasWallpaper
        
        let image: UIImage?
        
        switch type {
        case .none:
            image = nil
        case let .incoming(mergeType):
            if maskMode && graphics.incomingBubbleGradientImage != nil {
                image = nil
            } else {
                switch mergeType {
                case .None:
                    image = highlighted ? graphics.chatMessageBackgroundIncomingHighlightedImage : graphics.chatMessageBackgroundIncomingImage
                case let .Top(side):
                    if side {
                        image = highlighted ? graphics.chatMessageBackgroundIncomingMergedTopSideHighlightedImage : graphics.chatMessageBackgroundIncomingMergedTopSideImage
                    } else {
                        image = highlighted ? graphics.chatMessageBackgroundIncomingMergedTopHighlightedImage : graphics.chatMessageBackgroundIncomingMergedTopImage
                    }
                case .Bottom:
                    image = highlighted ? graphics.chatMessageBackgroundIncomingMergedBottomHighlightedImage : graphics.chatMessageBackgroundIncomingMergedBottomImage
                case .Both:
                    image = highlighted ? graphics.chatMessageBackgroundIncomingMergedBothHighlightedImage : graphics.chatMessageBackgroundIncomingMergedBothImage
                case .Side:
                    image = highlighted ? graphics.chatMessageBackgroundIncomingMergedSideHighlightedImage : graphics.chatMessageBackgroundIncomingMergedSideImage
                case .Extracted:
                    image = graphics.chatMessageBackgroundIncomingExtractedImage
                }
            }
        case let .outgoing(mergeType):
            if maskMode && graphics.outgoingBubbleGradientImage != nil {
                image = nil
            } else {
                switch mergeType {
                case .None:
                    image = highlighted ? graphics.chatMessageBackgroundOutgoingHighlightedImage : graphics.chatMessageBackgroundOutgoingImage
                case let .Top(side):
                    if side {
                        image = highlighted ? graphics.chatMessageBackgroundOutgoingMergedTopSideHighlightedImage : graphics.chatMessageBackgroundOutgoingMergedTopSideImage
                    } else {
                        image = highlighted ? graphics.chatMessageBackgroundOutgoingMergedTopHighlightedImage : graphics.chatMessageBackgroundOutgoingMergedTopImage
                    }
                case .Bottom:
                    image = highlighted ? graphics.chatMessageBackgroundOutgoingMergedBottomHighlightedImage : graphics.chatMessageBackgroundOutgoingMergedBottomImage
                case .Both:
                    image = highlighted ? graphics.chatMessageBackgroundOutgoingMergedBothHighlightedImage : graphics.chatMessageBackgroundOutgoingMergedBothImage
                case .Side:
                    image = highlighted ? graphics.chatMessageBackgroundOutgoingMergedSideHighlightedImage : graphics.chatMessageBackgroundOutgoingMergedSideImage
                case .Extracted:
                    image = graphics.chatMessageBackgroundOutgoingExtractedImage
                }
            }
        }
        
        let outlineImage: UIImage?
        
        if hasWallpaper {
            switch type {
            case .none:
                outlineImage = nil
            case let .incoming(mergeType):
                switch mergeType {
                case .None:
                    outlineImage = graphics.chatMessageBackgroundIncomingOutlineImage
                case let .Top(side):
                    if side {
                        outlineImage = graphics.chatMessageBackgroundIncomingMergedTopSideOutlineImage
                    } else {
                        outlineImage = graphics.chatMessageBackgroundIncomingMergedTopOutlineImage
                    }
                case .Bottom:
                    outlineImage = graphics.chatMessageBackgroundIncomingMergedBottomOutlineImage
                case .Both:
                    outlineImage = graphics.chatMessageBackgroundIncomingMergedBothOutlineImage
                case .Side:
                    outlineImage = graphics.chatMessageBackgroundIncomingMergedSideOutlineImage
                case .Extracted:
                    outlineImage = graphics.chatMessageBackgroundIncomingExtractedOutlineImage
                }
            case let .outgoing(mergeType):
                switch mergeType {
                case .None:
                    outlineImage = graphics.chatMessageBackgroundOutgoingOutlineImage
                case let .Top(side):
                    if side {
                        outlineImage = graphics.chatMessageBackgroundOutgoingMergedTopSideOutlineImage
                    } else {
                        outlineImage = graphics.chatMessageBackgroundOutgoingMergedTopOutlineImage
                    }
                case .Bottom:
                    outlineImage = graphics.chatMessageBackgroundOutgoingMergedBottomOutlineImage
                case .Both:
                    outlineImage = graphics.chatMessageBackgroundOutgoingMergedBothOutlineImage
                case .Side:
                    outlineImage = graphics.chatMessageBackgroundOutgoingMergedSideOutlineImage
                case .Extracted:
                    outlineImage = graphics.chatMessageBackgroundOutgoingExtractedOutlineImage
                }
            }
        } else {
            outlineImage = nil
        }
        
        if !self.imagesAreHidden {
            if let previousType = previousType, previousType != .none, type == .none {
                if transition.isAnimated {
                    let tempLayer = CALayer()
                    tempLayer.contents = self.imageNode.layer.contents
                    tempLayer.contentsScale = self.imageNode.layer.contentsScale
                    tempLayer.rasterizationScale = self.imageNode.layer.rasterizationScale
                    tempLayer.contentsGravity = self.imageNode.layer.contentsGravity
                    tempLayer.contentsCenter = self.imageNode.layer.contentsCenter

                    tempLayer.frame = self.bounds
                    self.layer.insertSublayer(tempLayer, above: self.imageNode.layer)
                    transition.updateAlpha(layer: tempLayer, alpha: 0.0, completion: { [weak tempLayer] _ in
                        tempLayer?.removeFromSuperlayer()
                    })
                }
            } else if transition.isAnimated {
                if let previousContents = self.imageNode.layer.contents, let image = image {
                    self.imageNode.layer.animate(from: previousContents as AnyObject, to: image.cgImage! as AnyObject, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.42)
                }
            }
        }
        
        self.imageNode.image = image
        self.outlineImageNode.image = outlineImage
    }
}

final class ChatMessageShadowNode: ASDisplayNode {
    private let contentNode: ASImageNode
    private var graphics: PrincipalThemeEssentialGraphics?
    
    override init() {
        self.contentNode = ASImageNode()
        self.contentNode.isLayerBacked = true
        self.contentNode.displaysAsynchronously = false
        self.contentNode.displayWithoutProcessing = true
        
        super.init()
        
        self.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
        
        self.isLayerBacked = true
        
        self.addSubnode(self.contentNode)
    }
    
    func setType(type: ChatMessageBackgroundType, hasWallpaper: Bool, graphics: PrincipalThemeEssentialGraphics) {
        let shadowImage: UIImage?
        
        if hasWallpaper {
            switch type {
            case .none:
                shadowImage = nil
            case let .incoming(mergeType):
                switch mergeType {
                case .None:
                    shadowImage = graphics.chatMessageBackgroundIncomingShadowImage
                case let .Top(side):
                    if side {
                        shadowImage = graphics.chatMessageBackgroundIncomingMergedTopSideShadowImage
                    } else {
                        shadowImage = graphics.chatMessageBackgroundIncomingMergedTopShadowImage
                    }
                case .Bottom:
                    shadowImage = graphics.chatMessageBackgroundIncomingMergedBottomShadowImage
                case .Both:
                    shadowImage = graphics.chatMessageBackgroundIncomingMergedBothShadowImage
                case .Side:
                    shadowImage = graphics.chatMessageBackgroundIncomingMergedSideShadowImage
                case .Extracted:
                    shadowImage = nil
                }
            case let .outgoing(mergeType):
                switch mergeType {
                case .None:
                    shadowImage = graphics.chatMessageBackgroundOutgoingShadowImage
                case let .Top(side):
                    if side {
                        shadowImage = graphics.chatMessageBackgroundOutgoingMergedTopSideShadowImage
                    } else {
                        shadowImage = graphics.chatMessageBackgroundOutgoingMergedTopShadowImage
                    }
                case .Bottom:
                    shadowImage = graphics.chatMessageBackgroundOutgoingMergedBottomShadowImage
                case .Both:
                    shadowImage = graphics.chatMessageBackgroundOutgoingMergedBothShadowImage
                case .Side:
                    shadowImage = graphics.chatMessageBackgroundOutgoingMergedSideShadowImage
                case .Extracted:
                    shadowImage = nil
                }
            }
        } else {
            shadowImage = nil
        }
        
        self.contentNode.image = shadowImage
    }
    
    func updateLayout(backgroundFrame: CGRect, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX - 10.0, y: backgroundFrame.minY - 10.0), size: CGSize(width: backgroundFrame.width + 20.0, height: backgroundFrame.height + 20.0)))
    }
}
