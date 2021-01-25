import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import ItemListUI
import TelegramPresentationData

private var transfromSliderKnobImage: UIImage?
private let transfromSliderKnobSize = CGSize(width: 28.0, height: 28.0)
private let transfromSliderKnobInsetSize = CGSize(width: 8.0, height: 12.0)

private var boundSliderKnobImage: UIImage?
private let boundSliderKnobSize = CGSize(width: 20.0, height: 36.0)
private let boundSliderKnobInsetSize = CGSize(width: 12.0, height: 8.0)

private let gapBetweenSliders: Float = 0.2 // In the range of it's values
private let contentInsets = UIEdgeInsets(top: 16.0, left: 8.0, bottom: 16.0, right: 8.0)
private let contentHeight: CGFloat = 288.0
private let kindaYellow = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0) // #ffcd00 // rgb(255, 205, 0)
private let labelsFont = Font.regular(12.0)
private let labelsOffset: CGFloat = 4.0 // distance between label and a knob
private let labelsGap: CGFloat = 8.0 // min distance between labels

private let lineThickness: CGFloat = 4.0
private let bigDotDiameter = lineThickness * 1.5
private let bigDotRadius = bigDotDiameter / 2.0
private let bigDotSize = CGSize(width: bigDotDiameter, height: bigDotDiameter)
private let eraseDiameter = bigDotDiameter * 1.5
private let eraseRadius = eraseDiameter / 2.0
private let eraseSize = CGSize(width: eraseDiameter, height: eraseDiameter)
private let smallDotDiameter = lineThickness / 2.0
private let smallDotRadius = smallDotDiameter / 2.0
private let smallDotSize = CGSize(width: smallDotDiameter, height: smallDotDiameter)
// Between centers of the dots
private let smallDotsGap = smallDotDiameter * 4.0

private func prepareImages() {
    if transfromSliderKnobImage == nil {
        transfromSliderKnobImage = generateTransformSliderKnobImage()
    }
    if boundSliderKnobImage == nil {
        boundSliderKnobImage = generateBoundSliderKnobImage()
    }
}

private func generateKnobImage(_ knobSize: CGSize, _ insetSize: CGSize) -> UIImage? {
    let imageSize = CGSize(width: knobSize.width + (insetSize.width * 2.0), height: knobSize.height + (insetSize.height * 2.0))
    let shadowColor = UIColor(white: 0.0, alpha: 0.25)
    let knobColor = UIColor.white
    let rect = CGRect(origin: CGPoint(x: insetSize.width, y: insetSize.height),
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

private func generateTransformSliderKnobImage() -> UIImage? {
    return generateKnobImage(transfromSliderKnobSize, transfromSliderKnobInsetSize)
}

private func generateBoundSliderKnobImage() -> UIImage? {
    return generateKnobImage(boundSliderKnobSize, boundSliderKnobInsetSize)
}

class ChatAnimationSettingsCurveSlider: UISlider {
    public func getThumbRect(_ view: UIView) -> CGRect {
        let trackRect = self.trackRect(forBounds: self.bounds)
        let thumbRect = self.thumbRect(forBounds: self.bounds, trackRect: trackRect, value: self.value)
        return self.convert(thumbRect, to: view)
    }
    
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
    private var presentationData: ItemListPresentationData?
    private let topSlider = ChatAnimationSettingsCurveSlider()
    private let bottomSlider = ChatAnimationSettingsCurveSlider()
    private let leftSlider = ChatAnimationSettingsCurveSlider()
    private let rightSlider = ChatAnimationSettingsCurveSlider()
    private let topLabel = UILabel()
    private let bottomLabel = UILabel()
    private let leftLabel = UILabel()
    private let rightLabel = UILabel()
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
        
        self.topSlider.isOpaque = false
        self.topSlider.backgroundColor = UIColor.clear
        self.topSlider.isContinuous = true
        self.topSlider.setThumbImage(transfromSliderKnobImage, for: .normal)
        self.topSlider.addTarget(self, action: #selector(self.topSliderValueChanged), for: .valueChanged)
        self.topSlider.minimumValue = 0.0
        self.topSlider.maximumValue = 100.0
        self.topSlider.value = 100.0
        self.topSlider.setMinimumTrackImage(nil, for: .normal)
        self.topSlider.minimumTrackTintColor = UIColor.clear
        self.topSlider.setMaximumTrackImage(nil, for: .normal)
        self.topSlider.maximumTrackTintColor = UIColor.clear
        // Rotate it to get inverted slider from 100 to 1
        self.topSlider.transform = CGAffineTransform(rotationAngle: .pi)
        
        self.bottomSlider.isOpaque = false
        self.bottomSlider.backgroundColor = UIColor.clear
        self.bottomSlider.isContinuous = true
        self.bottomSlider.setThumbImage(transfromSliderKnobImage, for: .normal)
        self.bottomSlider.addTarget(self, action: #selector(self.bottomSliderValueChanged), for: .valueChanged)
        self.bottomSlider.minimumValue = 0.0
        self.bottomSlider.maximumValue = 100.0
        self.bottomSlider.value = 100.0
        self.bottomSlider.setMinimumTrackImage(nil, for: .normal)
        self.bottomSlider.minimumTrackTintColor = UIColor.clear
        self.bottomSlider.setMaximumTrackImage(nil, for: .normal)
        self.bottomSlider.maximumTrackTintColor = UIColor.clear
        
        self.leftSlider.isOpaque = false
        self.leftSlider.backgroundColor = UIColor.clear
        self.leftSlider.isContinuous = true
        self.leftSlider.setThumbImage(boundSliderKnobImage, for: .normal)
        self.leftSlider.addTarget(self, action: #selector(self.leftSliderValueChanged), for: .valueChanged)
        self.leftSlider.minimumValue = 0.0
        self.leftSlider.maximumValue = 1.0
        self.leftSlider.value = 0.0
        self.leftSlider.setMinimumTrackImage(nil, for: .normal)
        self.leftSlider.minimumTrackTintColor = UIColor.clear
        self.leftSlider.setMaximumTrackImage(nil, for: .normal)
        self.leftSlider.maximumTrackTintColor = UIColor.clear
        
        self.rightSlider.isOpaque = false
        self.rightSlider.backgroundColor = UIColor.clear
        self.rightSlider.isContinuous = true
        self.rightSlider.setThumbImage(boundSliderKnobImage, for: .normal)
        self.rightSlider.addTarget(self, action: #selector(self.rightSliderValueChanged), for: .valueChanged)
        self.rightSlider.minimumValue = 0.0
        self.rightSlider.maximumValue = 1.0
        self.rightSlider.value = 1.0
        self.rightSlider.setMinimumTrackImage(nil, for: .normal)
        self.rightSlider.minimumTrackTintColor = UIColor.clear
        self.rightSlider.setMaximumTrackImage(nil, for: .normal)
        self.rightSlider.maximumTrackTintColor = UIColor.clear
        
        self.topLabel.isOpaque = false
        self.topLabel.backgroundColor = UIColor.clear
        self.topLabel.textAlignment = .center
        self.topLabel.font = labelsFont
        self.topLabel.text = "100%"
        
        self.bottomLabel.isOpaque = false
        self.bottomLabel.backgroundColor = UIColor.clear
        self.bottomLabel.textAlignment = .center
        self.bottomLabel.font = labelsFont
        self.bottomLabel.text = "100%"
        
        self.leftLabel.isOpaque = false
        self.leftLabel.backgroundColor = UIColor.clear
        self.leftLabel.textColor = kindaYellow
        self.leftLabel.textAlignment = .center
        self.leftLabel.font = labelsFont
        self.leftLabel.shadowOffset = CGSize.zero
        self.leftLabel.text = "0f"
        
        self.rightLabel.isOpaque = false
        self.rightLabel.backgroundColor = UIColor.clear
        self.rightLabel.textColor = kindaYellow
        self.rightLabel.textAlignment = .center
        self.rightLabel.font = labelsFont
        self.rightLabel.shadowOffset = CGSize.zero
        self.rightLabel.text = "60f"
    }
    
    @objc
    private func topSliderValueChanged() {
        self.setNeedsDisplay()
    }
    
    @objc
    private func bottomSliderValueChanged() {
        self.setNeedsDisplay()
    }
    
    @objc
    private func leftSliderValueChanged() {
        if self.rightSlider.value - self.leftSlider.value < gapBetweenSliders {
            self.leftSlider.value = self.rightSlider.value - gapBetweenSliders
        }
        
        self.setNeedsDisplay()
    }
    
    @objc
    private func rightSliderValueChanged() {
        if self.rightSlider.value - self.leftSlider.value < gapBetweenSliders {
            self.rightSlider.value = self.leftSlider.value + gapBetweenSliders
        }
        
        self.setNeedsDisplay()
    }
    
    @discardableResult
    private func updateCurveAndLabelsLayout(generateParams: Bool = false) -> ChatAnimationSettingsCurveNodeParams? {
        guard let contentRect = self.contentRect,
              let drawingRect = self.drawingRect else {
            return nil
        }
        
        let leftCapOffset = round(CGFloat(self.leftSlider.value / self.leftSlider.maximumValue) * drawingRect.width)
        let rightCapOffset = round(CGFloat((self.rightSlider.maximumValue - self.rightSlider.value) / self.rightSlider.maximumValue) * drawingRect.width)
        var width = contentRect.width - leftCapOffset - rightCapOffset
        
        self.topSlider.frame = CGRect(origin: CGPoint(x: contentRect.minX + leftCapOffset, y: self.topSlider.frame.minY),
                                      size: CGSize(width: width, height: self.topSlider.frame.height))
        self.bottomSlider.frame = CGRect(origin: CGPoint(x: contentRect.minX + leftCapOffset, y: self.bottomSlider.frame.minY),
                                         size: CGSize(width: width, height: self.bottomSlider.frame.height))
        
        self.updateLabelsLayout()
                
        if (generateParams) {
            width = drawingRect.width - leftCapOffset - rightCapOffset
            let topControlPointOffset = round(CGFloat((self.topSlider.maximumValue - self.topSlider.value) / self.topSlider.maximumValue) * width)
            let bottomControlPointOffset = round(CGFloat((self.bottomSlider.maximumValue - self.bottomSlider.value) / self.bottomSlider.maximumValue) * width)
            
            return ChatAnimationSettingsCurveNodeParams(drawingRect: self.drawingRect,
                                                        topControlPointOffset: topControlPointOffset,
                                                        bottomControlPointOffset: bottomControlPointOffset,
                                                        leftCapOffset: leftCapOffset,
                                                        rightCapOffset: rightCapOffset,
                                                        curveColor: self.curveColor,
                                                        accentColor: self.accentColor)
        } else {
            self.setNeedsDisplay()
            return nil
        }
    }
    
    private func updateLabelsLayout() {
        self.topLabel.text = String("\(Int(round(self.topSlider.value)))%")
        self.bottomLabel.text = String("\(Int(round(self.bottomSlider.value)))%")
        self.leftLabel.text = String("\(Int(round(self.leftSlider.value * 60.0)))f")
        self.rightLabel.text = String("\(Int(round(self.rightSlider.value * 60.0)))f")
        
        self.topLabel.sizeToFit()
        self.bottomLabel.sizeToFit()
        self.leftLabel.sizeToFit()
        self.rightLabel.sizeToFit()
        
        let topThumbRect = self.topSlider.getThumbRect(self.view)
        self.topLabel.center = topThumbRect.center.offsetBy(dx: CGFloat.zero,
                                                         dy: -((transfromSliderKnobSize.height / 2.0) + (self.topLabel.frame.height / 2.0) + labelsOffset))
        
        let bottomThumbRect = self.bottomSlider.getThumbRect(self.view)
        self.bottomLabel.center = bottomThumbRect.center.offsetBy(dx: CGFloat.zero,
                                                            dy: (transfromSliderKnobSize.height / 2.0) + (self.bottomLabel.frame.height / 2.0) + labelsOffset)
        
        let leftThumbRect = self.leftSlider.getThumbRect(self.view)
        let leftLabelOffset = (boundSliderKnobSize.width / 2.0) + (self.leftLabel.frame.width / 2.0) + labelsOffset
        self.leftLabel.center = leftThumbRect.center.offsetBy(dx: leftLabelOffset, dy: CGFloat.zero)
        
        let rightThumbRect = self.rightSlider.getThumbRect(self.view)
        let labelWithOffset = self.rightLabel.frame.width + labelsOffset
        let isRightSide = self.rightSlider.frame.maxX - (rightThumbRect.center.x + (boundSliderKnobSize.width / 2.0)) > labelWithOffset
        let rightLabelOffset = (boundSliderKnobSize.width / 2.0) + (self.rightLabel.frame.width / 2.0) + labelsOffset
        self.rightLabel.center = rightThumbRect.center.offsetBy(dx: (isRightSide ? rightLabelOffset : -rightLabelOffset), dy: CGFloat.zero)
        
        if self.rightLabel.frame.minX - self.leftLabel.frame.maxX <= labelsGap {
            self.leftLabel.center = leftThumbRect.center.offsetBy(dx: -leftLabelOffset, dy: CGFloat.zero)
        }
    }
        
    public func updateLayout(presentationData: ItemListPresentationData? = nil) {
        guard let presentationData = presentationData ?? self.presentationData,
              let transfromSliderKnobImage = transfromSliderKnobImage,
              let boundSliderKnobImage = boundSliderKnobImage else {
            return
        }
        
        self.presentationData = presentationData
        let size = self.bounds.size
        
        // Update colors
        self.curveColor = presentationData.theme.list.disclosureArrowColor.withAlphaComponent(0.5)
        self.accentColor = presentationData.theme.list.itemAccentColor
        self.topLabel.textColor = self.accentColor
        self.bottomLabel.textColor = self.accentColor
        self.leftLabel.shadowColor = presentationData.theme.list.itemBlocksBackgroundColor
        self.rightLabel.shadowColor = presentationData.theme.list.itemBlocksBackgroundColor
        
        if self.topSlider.superview == nil {
            self.view.insertSubview(self.topSlider, at: 0)
        }
        if self.bottomSlider.superview == nil {
            self.view.insertSubview(self.bottomSlider, at: 1)
        }
        if self.leftSlider.superview == nil {
            self.view.insertSubview(self.leftSlider, at: 2)
        }
        if self.rightSlider.superview == nil {
            self.view.insertSubview(self.rightSlider, at: 3)
        }
        if self.topLabel.superview == nil {
            self.view.insertSubview(self.topLabel, at: 4)
        }
        if self.bottomLabel.superview == nil {
            self.view.insertSubview(self.bottomLabel, at: 5)
        }
        if self.leftLabel.superview == nil {
            self.view.insertSubview(self.leftLabel, at: 6)
        }
        if self.rightLabel.superview == nil {
            self.view.insertSubview(self.rightLabel, at: 7)
        }
        
        let transformSliderHeight: CGFloat = transfromSliderKnobImage.size.height
        let boundSliderHeight: CGFloat = boundSliderKnobImage.size.height
        self.topSlider.frame = CGRect(origin: CGPoint(x: contentInsets.left, y: contentInsets.top),
                                      size: CGSize(width: size.width - contentInsets.left - contentInsets.right, height: transformSliderHeight))
        self.bottomSlider.frame = CGRect(origin: CGPoint(x: contentInsets.left, y: size.height - contentInsets.bottom - transformSliderHeight),
                                         size: CGSize(width: size.width - contentInsets.left - contentInsets.right, height: transformSliderHeight))
        self.leftSlider.frame = CGRect(origin: CGPoint(x: contentInsets.left, y: size.height / 2.0 - boundSliderHeight / 2.0),
                                       size: CGSize(width: size.width - contentInsets.left - contentInsets.right, height: boundSliderHeight))
        self.rightSlider.frame = CGRect(origin: CGPoint(x: contentInsets.left, y: size.height / 2.0 - boundSliderHeight / 2.0),
                                        size: CGSize(width: size.width - contentInsets.left - contentInsets.right, height: boundSliderHeight))
        
        var topLeft = topSlider.getThumbRectMax(self.view).origin
        var topRight = topSlider.getThumbRectMin(self.view).topRight
        var bottomLeft = bottomSlider.getThumbRectMin(self.view).bottomLeft
        self.contentRect = CGRect(origin: CGPoint(x: round(topLeft.x), y: round(topLeft.y)),
                                  size: CGSize(width: round(topRight.x - topLeft.x), height: round(bottomLeft.y - topLeft.y)))
        
        topLeft = topSlider.getThumbRectMax(self.view).center
        topRight = topSlider.getThumbRectMin(self.view).center
        bottomLeft = bottomSlider.getThumbRectMin(self.view).center
        self.drawingRect = CGRect(origin: CGPoint(x: round(topLeft.x), y: round(topLeft.y)),
                                  size: CGSize(width: round(topRight.x - topLeft.x), height: round(bottomLeft.y - topLeft.y)))
        
        updateCurveAndLabelsLayout()
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return updateCurveAndLabelsLayout(generateParams: true)
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
            context.setFillColor(kindaYellow.cgColor)
            
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
    private let maskNode = ASImageNode()
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
            let contentSize = CGSize(width: params.width, height: contentHeight)
            let insets = itemListNeighborsGroupedInsets(neighbors)
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
                if sself.maskNode.supernode == nil {
                    sself.insertSubnode(sself.maskNode, at: 3)
                }
                if sself.curveNode.supernode == nil {
                    sself.insertSubnode(sself.curveNode, at: 4)
                }
                
                let hasCorners = itemListHasRoundedBlockLayout(params)
                var hasTopCorners = false
                var hasBottomCorners = false
                switch neighbors.top {
                    case .sameSection(false):
                        sself.topStripeNode.isHidden = true
                    default:
                        hasTopCorners = true
                        sself.topStripeNode.isHidden = hasCorners
                }
                let bottomStripeInset: CGFloat
                let bottomStripeOffset: CGFloat
                switch neighbors.bottom {
                    case .sameSection(false):
                        bottomStripeInset = params.leftInset + 16.0
                        bottomStripeOffset = -separatorHeight
                    default:
                        bottomStripeInset = 0.0
                        bottomStripeOffset = 0.0
                        hasBottomCorners = true
                        sself.bottomStripeNode.isHidden = hasCorners
                }
                
                sself.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                
                sself.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)),
                                                         size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                sself.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)),
                                                        size: CGSize(width: layout.size.width, height: separatorHeight))
                sself.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset),
                                                      size: CGSize(width: layout.size.width - bottomStripeInset, height: separatorHeight))
                sself.maskNode.frame = sself.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                sself.curveNode.frame = sself.maskNode.frame
                
                sself.curveNode.updateLayout(presentationData: item.presentationData)
            })
        }
    }
}
