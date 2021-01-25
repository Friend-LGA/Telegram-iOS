import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import ItemListUI
import TelegramPresentationData
import LegacyComponents

private var knobCircularImage: UIImage?
private var knobEllipsoidalImage: UIImage?
private let gapBetweenSliders: Float = 0.2
private let contentInsets = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)

private func prepareImages() {
    if knobCircularImage == nil {
        knobCircularImage = generateKnobCircularImage()
    }
    if knobEllipsoidalImage == nil {
        knobEllipsoidalImage = generateKnobEllipsoidalImage()
    }
}

private func generateKnobImage(_ knobSize: CGSize, _ offsetSize: CGSize) -> UIImage? {
    let imageSize = CGSize(width: knobSize.width + (offsetSize.width * 2.0), height: knobSize.height + (offsetSize.height * 2.0))
    let shadowColor = UIColor(white: 0.0, alpha: 0.25)
    let knobColor = UIColor.white
    let rect = CGRect(origin: CGPoint(x: offsetSize.width, y: offsetSize.height),
                      size: CGSize(width: knobSize.width, height: knobSize.height))
    let cornerRadius = min(knobSize.width, knobSize.height) / 2.0
    let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
    return generateImage(imageSize, rotatedContext: { _, context in
        context.clear(CGRect(origin: CGPoint.zero, size: imageSize))
        context.setShadow(offset: CGSize.zero, blur: 8.0, color: shadowColor.cgColor)
        context.setFillColor(knobColor.cgColor)
        context.addPath(path.cgPath)
        context.fillPath(using: .winding)
    })
}

private func generateKnobCircularImage() -> UIImage? {
    let knobSize = CGSize(width: 28.0, height: 28.0)
    let offsetSize = CGSize(width: 8.0, height: 12.0)
    return generateKnobImage(knobSize, offsetSize)
}

private func generateKnobEllipsoidalImage() -> UIImage? {
    let knobSize = CGSize(width: 20.0, height: 36.0)
    let offsetSize = CGSize(width: 12.0, height: 8.0)
    return generateKnobImage(knobSize, offsetSize)
}

class ChatAnimationSettingsCurveSlider: UISlider {
    public func getThumbRectMin(_ view: UIView) -> CGRect {
        let trackRect = self.trackRect(forBounds: self.bounds)
        let thumbRect = self.thumbRect(forBounds: self.bounds, trackRect: trackRect, value: self.minimumValue)
        return self.convert(thumbRect, to: view)
    }
    
    public func getThumbRectMax(_ view: UIView) -> CGRect {
        let trackRect = self.trackRect(forBounds: self.bounds)
        let thumbRect = self.thumbRect(forBounds: self.bounds, trackRect: trackRect, value: self.maximumValue)
        return self.convert(thumbRect, to: view)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let trackRect = self.trackRect(forBounds: self.bounds)
        let thumbRect = self.thumbRect(forBounds: self.bounds, trackRect: trackRect, value: self.value)
        if thumbRect.contains(point) {
            return super.hitTest(point, with: event)
        } else {
            return nil
        }
    }
}

class ChatAnimationSettingsCurveItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    var sectionId: ItemListSectionId
    
    init(presentationData: ItemListPresentationData, sectionId: ItemListSectionId) {
        self.presentationData = presentationData
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        Queue.mainQueue().async {
            let node = ChatAnimationSettingsCurveItemNode()
            async {
                let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                
                node.contentSize = layout.contentSize
                node.insets = layout.insets
                
                Queue.mainQueue().async {
                    completion(node, {
                        return (nil, { _ in apply() })
                    })
                }
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ChatAnimationSettingsCurveItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in apply() })
                    }
                }
            }
        }
    }
}

private final class ChatAnimationSettingsCurveNodeParams: NSObject {
    let drawingRect: CGRect?
    let topControlPointOffset: CGFloat
    let bottomControlPointOffset: CGFloat
    let leftCapOffset: CGFloat
    let rightCapOffset: CGFloat
    let curveColor: UIColor?
    let accentColor: UIColor?
    
    init(drawingRect: CGRect?,
         topControlPointOffset: CGFloat,
         bottomControlPointOffset: CGFloat,
         leftCapOffset: CGFloat,
         rightCapOffset: CGFloat,
         curveColor: UIColor?,
         accentColor: UIColor?) {
        self.drawingRect = drawingRect
        self.topControlPointOffset = topControlPointOffset
        self.bottomControlPointOffset = bottomControlPointOffset
        self.leftCapOffset = leftCapOffset
        self.rightCapOffset = rightCapOffset
        self.curveColor = curveColor
        self.accentColor = accentColor
        super.init()
    }
}

class ChatAnimationSettingsCurveNode: ASDisplayNode {
    private let topTransformSlider = ChatAnimationSettingsCurveSlider()
    private let bottomTransformSlider = ChatAnimationSettingsCurveSlider()
    private let leftBoundSlider = ChatAnimationSettingsCurveSlider()
    private let rightBoundSlider = ChatAnimationSettingsCurveSlider()
    private var contentRect: CGRect?
    private var drawingRect: CGRect?
    private var curveColor: UIColor?
    private var accentColor: UIColor?
    
    override init() {
        super.init()
        
        // Should be done somewhere in theme
        prepareImages()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        self.view.disablesInteractiveModalDismiss = true
        self.isOpaque = false
        self.backgroundColor = UIColor.clear
        
        self.topTransformSlider.isContinuous = true
        self.topTransformSlider.setThumbImage(knobCircularImage, for: .normal)
        self.topTransformSlider.addTarget(self, action: #selector(self.topTransformSliderValueChanged), for: .valueChanged)
        self.topTransformSlider.minimumValue = 0.0
        self.topTransformSlider.maximumValue = 100.0
        self.topTransformSlider.value = 100.0
        self.topTransformSlider.setMinimumTrackImage(nil, for: .normal)
        self.topTransformSlider.minimumTrackTintColor = UIColor.clear
        self.topTransformSlider.setMaximumTrackImage(nil, for: .normal)
        self.topTransformSlider.maximumTrackTintColor = UIColor.clear
        // Rotate it to get inverted slider from 100 to 1
        self.topTransformSlider.transform = CGAffineTransform(rotationAngle: .pi)
        
        self.bottomTransformSlider.isContinuous = true
        self.bottomTransformSlider.setThumbImage(knobCircularImage, for: .normal)
        self.bottomTransformSlider.addTarget(self, action: #selector(self.bottomTransformSliderValueChanged), for: .valueChanged)
        self.bottomTransformSlider.minimumValue = 0.0
        self.bottomTransformSlider.maximumValue = 100.0
        self.bottomTransformSlider.value = 100.0
        self.bottomTransformSlider.setMinimumTrackImage(nil, for: .normal)
        self.bottomTransformSlider.minimumTrackTintColor = UIColor.clear
        self.bottomTransformSlider.setMaximumTrackImage(nil, for: .normal)
        self.bottomTransformSlider.maximumTrackTintColor = UIColor.clear
        
        self.leftBoundSlider.isContinuous = true
        self.leftBoundSlider.setThumbImage(knobEllipsoidalImage, for: .normal)
        self.leftBoundSlider.addTarget(self, action: #selector(self.leftBoundSliderValueChanged), for: .valueChanged)
        self.leftBoundSlider.minimumValue = 0.0
        self.leftBoundSlider.maximumValue = 1.0
        self.leftBoundSlider.value = 0.0
        self.leftBoundSlider.setMinimumTrackImage(nil, for: .normal)
        self.leftBoundSlider.minimumTrackTintColor = UIColor.clear
        self.leftBoundSlider.setMaximumTrackImage(nil, for: .normal)
        self.leftBoundSlider.maximumTrackTintColor = UIColor.clear
        
        self.rightBoundSlider.isContinuous = true
        self.rightBoundSlider.setThumbImage(knobEllipsoidalImage, for: .normal)
        self.rightBoundSlider.addTarget(self, action: #selector(self.rightBoundSliderValueChanged), for: .valueChanged)
        self.rightBoundSlider.minimumValue = 0.0
        self.rightBoundSlider.maximumValue = 1.0
        self.rightBoundSlider.value = 1.0
        self.rightBoundSlider.setMinimumTrackImage(nil, for: .normal)
        self.rightBoundSlider.minimumTrackTintColor = UIColor.clear
        self.rightBoundSlider.setMaximumTrackImage(nil, for: .normal)
        self.rightBoundSlider.maximumTrackTintColor = UIColor.clear
    }
    
    @objc
    private func topTransformSliderValueChanged() {
        self.setNeedsDisplay()
    }
    
    @objc
    private func bottomTransformSliderValueChanged() {
        self.setNeedsDisplay()
    }
    
    @objc
    private func leftBoundSliderValueChanged() {
        if self.rightBoundSlider.value - self.leftBoundSlider.value < gapBetweenSliders {
            self.leftBoundSlider.value = self.rightBoundSlider.value - gapBetweenSliders
        }
                
        self.setNeedsDisplay()
    }
    
    @objc
    private func rightBoundSliderValueChanged() {
        if self.rightBoundSlider.value - self.leftBoundSlider.value < gapBetweenSliders {
            self.rightBoundSlider.value = self.leftBoundSlider.value + gapBetweenSliders
        }
        
        self.setNeedsDisplay()
    }
    
    @discardableResult
    private func updateCurve(generateParams: Bool = false) -> ChatAnimationSettingsCurveNodeParams? {
        guard let contentRect = self.contentRect,
              let drawingRect = self.drawingRect else {
            return nil
        }
        
        let leftCapOffset = round(CGFloat(self.leftBoundSlider.value / self.leftBoundSlider.maximumValue) * drawingRect.width)
        let rightCapOffset = round(CGFloat((self.rightBoundSlider.maximumValue - self.rightBoundSlider.value) / self.rightBoundSlider.maximumValue) * drawingRect.width)
        var width = contentRect.width - leftCapOffset - rightCapOffset
        
        self.topTransformSlider.frame = CGRect(origin: CGPoint(x: contentRect.minX + leftCapOffset, y: self.topTransformSlider.frame.minY),
                                               size: CGSize(width: width, height: self.topTransformSlider.frame.height))
        self.bottomTransformSlider.frame = CGRect(origin: CGPoint(x: contentRect.minX + leftCapOffset, y: self.bottomTransformSlider.frame.minY),
                                                  size: CGSize(width: width, height: self.bottomTransformSlider.frame.height))
        
        if (generateParams) {
            width = drawingRect.width - leftCapOffset - rightCapOffset
            let topControlPointOffset = round(CGFloat((self.topTransformSlider.maximumValue - self.topTransformSlider.value) / self.topTransformSlider.maximumValue) * width)
            let bottomControlPointOffset = round(CGFloat((self.bottomTransformSlider.maximumValue - self.bottomTransformSlider.value) / self.bottomTransformSlider.maximumValue) * width)
            
            return ChatAnimationSettingsCurveNodeParams(drawingRect: self.drawingRect,
                                                        topControlPointOffset: topControlPointOffset,
                                                        bottomControlPointOffset: bottomControlPointOffset,
                                                        leftCapOffset: leftCapOffset,
                                                        rightCapOffset: rightCapOffset,
                                                        curveColor: self.curveColor,
                                                        accentColor: self.accentColor)
        } else {
            return nil
        }
    }
    
    public func updateLayout(presentationData: ItemListPresentationData, size: CGSize) {
        guard let knobCircularImage = knobCircularImage,
              let knobEllipsoidalImage = knobEllipsoidalImage else {
            return
        }
        
        // Update colors
        self.curveColor = presentationData.theme.list.disclosureArrowColor.withAlphaComponent(0.75)
        self.accentColor = presentationData.theme.list.itemAccentColor
        
        if self.topTransformSlider.superview == nil {
            self.view.insertSubview(self.topTransformSlider, at: 0)
        }
        if self.bottomTransformSlider.superview == nil {
            self.view.insertSubview(self.bottomTransformSlider, at: 1)
        }
        if self.leftBoundSlider.superview == nil {
            self.view.insertSubview(self.leftBoundSlider, at: 2)
        }
        if self.rightBoundSlider.superview == nil {
            self.view.insertSubview(self.rightBoundSlider, at: 3)
        }
        
        let transformSliderHeight: CGFloat = knobCircularImage.size.height
        let boundSliderHeight: CGFloat = knobEllipsoidalImage.size.height
        self.topTransformSlider.frame = CGRect(origin: CGPoint(x: contentInsets.left, y: contentInsets.top),
                                               size: CGSize(width: size.width - contentInsets.left - contentInsets.right, height: transformSliderHeight))
        self.bottomTransformSlider.frame = CGRect(origin: CGPoint(x: contentInsets.left, y: size.height - contentInsets.bottom - transformSliderHeight),
                                                  size: CGSize(width: size.width - contentInsets.left - contentInsets.right, height: transformSliderHeight))
        self.leftBoundSlider.frame = CGRect(origin: CGPoint(x: contentInsets.left, y: size.height / 2.0 - boundSliderHeight / 2.0),
                                            size: CGSize(width: size.width - contentInsets.left - contentInsets.right, height: boundSliderHeight))
        self.rightBoundSlider.frame = CGRect(origin: CGPoint(x: contentInsets.left, y: size.height / 2.0 - boundSliderHeight / 2.0),
                                             size: CGSize(width: size.width - contentInsets.left - contentInsets.right, height: boundSliderHeight))
        
        var topLeft = topTransformSlider.getThumbRectMax(self.view).origin
        var topRight = topTransformSlider.getThumbRectMin(self.view).topRight
        var bottomLeft = bottomTransformSlider.getThumbRectMin(self.view).bottomLeft
        self.contentRect = CGRect(origin: CGPoint(x: round(topLeft.x), y: round(topLeft.y)),
                                  size: CGSize(width: round(topRight.x - topLeft.x), height: round(bottomLeft.y - topLeft.y)))
        
        topLeft = topTransformSlider.getThumbRectMax(self.view).center
        topRight = topTransformSlider.getThumbRectMin(self.view).center
        bottomLeft = bottomTransformSlider.getThumbRectMin(self.view).center
        self.drawingRect = CGRect(origin: CGPoint(x: round(topLeft.x), y: round(topLeft.y)),
                                  size: CGSize(width: round(topRight.x - topLeft.x), height: round(bottomLeft.y - topLeft.y)))
        
        updateCurve()
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return updateCurve(generateParams: true)
    }
    
    override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled isCancelledBlock: () -> Bool, isRasterizing: Bool) {
        guard let context = UIGraphicsGetCurrentContext(),
              let parameters = parameters as? ChatAnimationSettingsCurveNodeParams,
              let rect = parameters.drawingRect,
              let curveColor = parameters.curveColor,
              let accentColor = parameters.accentColor else {
            return
        }
        
        let topControlPointOffset = parameters.topControlPointOffset
        let bottomControlPointOffset = parameters.bottomControlPointOffset
        let leftCapOffset = parameters.leftCapOffset
        let rightCapOffset = parameters.rightCapOffset
        let lineThickness: CGFloat = 4.0
        let bigDotDiameter = lineThickness * 1.5
        let bigDotRadius = bigDotDiameter / 2.0
        let bigDotSize = CGSize(width: bigDotDiameter, height: bigDotDiameter)
        let eraseDiameter = bigDotDiameter * 1.5
        let eraseRadius = eraseDiameter / 2.0
        let eraseSize = CGSize(width: eraseDiameter, height: eraseDiameter)
        let smallDotDiameter = lineThickness / 2.0
        let smallDotRadius = smallDotDiameter / 2.0
        let smallDotSize = CGSize(width: smallDotDiameter, height: smallDotDiameter)
        // Between centers of the dots
        let smallDotsGap = smallDotDiameter * 4.0
        
        var topLeft = CGPoint(x: rect.minX, y: rect.minY)
        var topRight = CGPoint(x: rect.maxX, y: rect.minY)
        var bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        var bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        var topLeftControl = CGPoint.zero
        var bottomRightControl = CGPoint.zero
        
        context.setLineWidth(lineThickness)
        context.setLineCap(.round)
        
        // Draw gray sliders and the curve itself
        do {
            context.setStrokeColor(curveColor.cgColor)
            
            context.beginPath()
            
            context.move(to: topLeft)
            context.addLine(to: topRight)
            
            context.move(to: bottomLeft)
            context.addLine(to: bottomRight)
            
            topLeft = CGPoint(x: rect.minX + leftCapOffset, y: rect.minY)
            topRight = CGPoint(x: rect.maxX - rightCapOffset, y: rect.minY)
            bottomLeft = CGPoint(x: rect.minX + leftCapOffset, y: rect.maxY)
            bottomRight = CGPoint(x: rect.maxX - rightCapOffset, y: rect.maxY)
            
            topLeftControl = CGPoint(x: topLeft.x + topControlPointOffset, y: topLeft.y)
            bottomRightControl = CGPoint(x: bottomRight.x - bottomControlPointOffset, y: bottomRight.y)
            
            let curvePath = UIBezierPath()
            curvePath.move(to: bottomLeft)
            curvePath.addCurve(to: topRight,
                               controlPoint1: bottomRightControl,
                               controlPoint2: topLeftControl)
            context.addPath(curvePath.cgPath)
            
            context.strokePath()
        }
        
        // Draw active sections of sliders
        do {
            context.setStrokeColor(accentColor.cgColor)
            
            context.beginPath()
            
            context.move(to: topLeftControl)
            context.addLine(to: topRight)
            
            context.move(to: bottomLeft)
            context.addLine(to: bottomRightControl)
            
            context.strokePath()
        }
        
        // Erase space for big dots
        do {
            context.setBlendMode(.clear)
            context.fillEllipse(in: CGRect(origin: topLeft, size: eraseSize).offsetBy(dx: -eraseRadius, dy: -eraseRadius))
            context.fillEllipse(in: CGRect(origin: topRight, size: eraseSize).offsetBy(dx: -eraseRadius, dy: -eraseRadius))
            context.fillEllipse(in: CGRect(origin: bottomLeft, size: eraseSize).offsetBy(dx: -eraseRadius, dy: -eraseRadius))
            context.fillEllipse(in: CGRect(origin: bottomRight, size: eraseSize).offsetBy(dx: -eraseRadius, dy: -eraseRadius))
            context.setBlendMode(.normal)
        }
        
        // Draw big dots
        do {
            context.setFillColor(UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0).cgColor) // #ffcd00 // rgb(255, 205, 0) // Kinda yellow
            
            context.fillEllipse(in: CGRect(origin: topLeft, size: bigDotSize).offsetBy(dx: -bigDotRadius, dy: -bigDotRadius))
            context.fillEllipse(in: CGRect(origin: topRight, size: bigDotSize).offsetBy(dx: -bigDotRadius, dy: -bigDotRadius))
            context.fillEllipse(in: CGRect(origin: bottomLeft, size: bigDotSize).offsetBy(dx: -bigDotRadius, dy: -bigDotRadius))
            context.fillEllipse(in: CGRect(origin: bottomRight, size: bigDotSize).offsetBy(dx: -bigDotRadius, dy: -bigDotRadius))
        }
        
        // Draw small dots
        do {
            var offset = (bigDotRadius - smallDotRadius) / 2.0
            topLeft = CGPoint(x: topLeft.x, y: topLeft.y + offset)
            topRight = CGPoint(x: topRight.x, y: topRight.y + offset)
            bottomLeft = CGPoint(x: bottomLeft.x, y: bottomLeft.y - offset)
            bottomRight = CGPoint(x: bottomRight.x, y: bottomRight.y - offset)
                        
            let iterations: Int = Int(floor(rect.height / smallDotsGap / 2.0))
            for i in 0..<iterations {
                offset = smallDotsGap * CGFloat(i)
                context.fillEllipse(in: CGRect(origin: topLeft, size: smallDotSize).offsetBy(dx: -smallDotRadius, dy: -smallDotRadius + offset))
                context.fillEllipse(in: CGRect(origin: topRight, size: smallDotSize).offsetBy(dx: -smallDotRadius, dy: -smallDotRadius + offset))
                context.fillEllipse(in: CGRect(origin: bottomLeft, size: smallDotSize).offsetBy(dx: -smallDotRadius, dy: -smallDotRadius - offset))
                context.fillEllipse(in: CGRect(origin: bottomRight, size: smallDotSize).offsetBy(dx: -smallDotRadius, dy: -smallDotRadius - offset))
            }
        }
    }
}

class ChatAnimationSettingsCurveItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode = ASDisplayNode()
    private let topStripeNode = ASDisplayNode()
    private let bottomStripeNode = ASDisplayNode()
    private let curveNode = ChatAnimationSettingsCurveNode()
    
    private var item: ChatAnimationSettingsCurveItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    var tag: ItemListItemTag? {
        return nil
    }
    
    init() {
        self.backgroundNode.isLayerBacked = true
        self.topStripeNode.isLayerBacked = true
        self.bottomStripeNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false)
    }
    
    func asyncLayout() -> (_ item: ChatAnimationSettingsCurveItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        return { item, params, neighbors in
            let contentSize = CGSize(width: params.width, height: 224.0)
            let separatorHeight = UIScreenPixel
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: UIEdgeInsets.zero)
            
            return (layout, { [weak self] in
                guard let sself = self else { return }
                sself.item = item
                sself.layoutParams = params
                
                // update colors
                sself.backgroundNode.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                sself.topStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                sself.bottomStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                
                if sself.backgroundNode.supernode == nil {
                    sself.insertSubnode(sself.backgroundNode, at: 0)
                }
                if sself.topStripeNode.supernode == nil {
                    sself.insertSubnode(sself.topStripeNode, at: 1)
                }
                if sself.bottomStripeNode.supernode == nil {
                    sself.insertSubnode(sself.bottomStripeNode, at: 2)
                }
                if sself.curveNode.supernode == nil {
                    sself.insertSubnode(sself.curveNode, at: 3)
                }
                
                sself.backgroundNode.frame = CGRect(origin: CGPoint.zero, size: layout.size)
                sself.topStripeNode.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: layout.size.width, height: separatorHeight))
                sself.bottomStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - separatorHeight), size: CGSize(width: layout.size.width, height: separatorHeight))
                sself.curveNode.frame = CGRect(origin: CGPoint.zero, size: layout.size)
                
                sself.curveNode.updateLayout(presentationData: item.presentationData, size: layout.size)
            })
        }
    }
}
