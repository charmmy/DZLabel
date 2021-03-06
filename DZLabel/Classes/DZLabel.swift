//
//  DZLabel.swift
//
//  Created by Darren Zheng on 2018/9/27.
//

import UIKit



@IBDesignable open class DZLabel: UITextView {
    
    
    open var enabledTypes: [DZKeywordType] = [.mention, .url, .phone, .address] {
        didSet { _update() }
    }
    @IBInspectable open var linkColor: UIColor = .blue {
        didSet { _setLink(color: linkColor, hasUnderscore: hasUnderscore) }
    }
    @IBInspectable open var hasUnderscore: Bool = false {
        didSet { _setLink(color: linkColor, hasUnderscore: hasUnderscore) }
    }
    
    private var _textChanged = false
    @IBInspectable open override var text: String! {
        didSet {
            _textChanged = oldValue != text
            _update()
        }
    }
    
    @IBInspectable open override var textColor: UIColor? {
        didSet { _update() }
    }
    @IBInspectable open var numberOfLines: Int = 0 {
        didSet { _setNumberOflines(numberOfLines) }
    }
    @IBInspectable open override var font: UIFont? {
        didSet { _update() }
    }
    
    private var _mentionTapHandler: ((String) -> Void)?
    open func handleMentionTap(_ handler: @escaping (String) -> Void) {
        _mentionTapHandler = handler
    }
    private var _URLTapHandler: ((String) -> Void)?
    open func handleURLTap(_ handler: @escaping (String) -> Void) {
        _URLTapHandler = handler
    }
    private var _phoneTapHandler: ((String) -> Void)?
    open func handlePhoneTap(_ handler: @escaping (String) -> Void) {
        _phoneTapHandler = handler
    }
    private var _addressTapHandler: ((String) -> Void)?
    open func handleAddressTap(_ handler: @escaping (String) -> Void) {
        _addressTapHandler = handler
    }
    
    private var _keywordLongPressHandler: (() -> Void)?
    open func handleKeywordLongPress(_ handler: @escaping () -> Void) {
        _keywordLongPressHandler = handler
    }
    
    private var _tapHandler: (() -> Void)?
    open func handleTap(_ handler: @escaping () -> Void) {
        _tapHandler = handler
    }
    
    private var _regexKeywordTapHandler: ((String) -> Void)?
    open func handleRegexKeywordTap(_ handler: @escaping (String) -> Void) {
        _regexKeywordTapHandler = handler
    }
    
//    private var _manualTapHandler: ((String) -> Void)?
//    open func handleManualTap(_ handler: @escaping (String) -> Void) {
//        _manualTapHandler = handler
//    }
//    
    private let _filePrefix = "file:///"
    
    private func _substringWithNSRange(_ range: NSRange, text: String?) -> NSString? {
        guard let text = text, range.location != NSNotFound && (range.location + range.length <= (text as NSString).length)
            else { return nil }
        return (text as NSString).substring(with: range) as NSString
    }
    
    // TODO: 优化空间：add attributes 而不是每次都copy一个attri string
//    private func currentAttributes() -> [NSAttributedString.Key : Any]? {
//        var range = NSRange(location: 0, length: 0)
//        let attributes = attributedText?.attributes(at: 0, effectiveRange: &range)
//        return attributes
//    }
    
    private func _update() {
        guard let string = text, _textChanged else {
            return
        }
        let copy = DZAttributedStringGenerator(text: text)
        copy.textColor(textColor)
        copy.font(font)
        if enabledTypes.contains(.mention) {
            for result in DZRegex.mentionResultsInText(string) {
                if let keyword = _substringWithNSRange(result.range, text: string) {
                    var pureKeyword = keyword
                    if keyword.hasPrefix("@") {
                        pureKeyword = (keyword as NSString).substring(from: 1) as NSString
                    }
                    let url = URL(fileURLWithPath: "\(DZRegex.MentionPrefix)\(pureKeyword)")
                    if result.range.location + result.range.length <= (text as NSString).length {
                        copy.link(url: url, range: result.range)
                    }
                }
            }
        }
        
        if enabledTypes.contains(.url) {
            for result in DZRegex.urlResultsInText(string) {
                if let keyword = _substringWithNSRange(result.range, text: string) {
                    if keyword.length <= 1020 {
                        let url = URL(fileURLWithPath: "\(DZRegex.URLPrefix)\(keyword)")
                        copy.link(url: url, range: result.range)
                    }
                }
            }
        }
        
        if enabledTypes.contains(.phone) {
            for result in DZRegex.phoneNumberResultsInText(string) {
                if let keyword = _substringWithNSRange(result.range, text: string) {
                    let url = URL(fileURLWithPath: "\(DZRegex.PhonePrefix)\(keyword)")
                    copy.link(url: url, range: result.range)
                }
            }
        }
        
        if enabledTypes.contains(.address) {
            for result in DZRegex.mapResultsInText(string) {
                if let keyword = _substringWithNSRange(result.range, text: string) {
                    let url = URL(fileURLWithPath: "\(DZRegex.MapPrefix)\(keyword)")
                    copy.link(url: url, range: result.range)
                }
            }
        }
        
        enabledTypes.forEach { type in
            if case .emoticon(let pattern, let bounds, let imageNameBlock) = type {
                let p = pattern ?? DZRegex.DZRegexPatternEmotion
                for result in DZRegex.emotionResultsInText(text, pattern: p).reversed() {
                    let code = (text as NSString).substring(with: result.range)
                    let imageName = imageNameBlock(code)
                    copy.replaceImage(imageName: imageName, with: result.range, bounds: bounds ?? CGRect(x: 0, y: 0, width: font?.lineHeight ?? 0, height: font?.lineHeight ?? 0))
                }
            }
            
            if case .regex(let pattern) = type {
                for result in DZRegex.resultsInText(text, pattern: pattern) {
                    if let keyword = _substringWithNSRange(result.range, text: string) {
                        let url = URL(fileURLWithPath: "\(DZRegex.CustomPrefix)\(keyword)")
                        copy.link(url: url, range: result.range)
                    }
                }
            }
            
            // TODO: 需要去掉_textChanged才不串
//            if case .manual(let range) = type {
//                if let keyword = _substringWithNSRange(range, text: string) {
//                    let url = URL(fileURLWithPath: "\(DZRegex.ManualPrefix)\(keyword)")
//                    copy.link(url: url, range: range)
//                }
//            }
            
        }
        
        
        attributedText = copy.generateAttributedString
    }
    
    
    private func _handleTapURL(_ url: URL) {
        if url.absoluteString.hasPrefix(_filePrefix + DZRegex.MentionPrefix) {
            if let str = (url.absoluteString as NSString).substring(from: (_filePrefix + DZRegex.MentionPrefix).count).removingPercentEncoding {
                _mentionTapHandler?(str)
            }
        }
        if url.absoluteString.hasPrefix(_filePrefix + DZRegex.URLPrefix) {
            _URLTapHandler?((url.absoluteString as NSString).substring(from: (_filePrefix + DZRegex.URLPrefix).count))
        }
        if url.absoluteString.hasPrefix(_filePrefix + DZRegex.PhonePrefix) {
            _phoneTapHandler?((url.absoluteString as NSString).substring(from: (_filePrefix + DZRegex.PhonePrefix).count))
        }
        if url.absoluteString.hasPrefix(_filePrefix + DZRegex.MapPrefix) {
            if let str = (url.absoluteString as NSString).substring(from: (_filePrefix + DZRegex.MapPrefix).count).removingPercentEncoding {
                _addressTapHandler?(str)
            }
        }
        if url.absoluteString.hasPrefix(_filePrefix + DZRegex.CustomPrefix) {
            if let str = (url.absoluteString as NSString).substring(from: (_filePrefix + DZRegex.CustomPrefix).count).removingPercentEncoding {
                _regexKeywordTapHandler?(str)
            }
        }
//        if url.absoluteString.hasPrefix(_filePrefix + DZRegex.ManualPrefix) {
//            if let str = (url.absoluteString as NSString).substring(from: (_filePrefix + DZRegex.ManualPrefix).count).removingPercentEncoding {
//                _manualTapHandler?(str)
//            }
//        }
    }
    
    
    // Autolayout Supporting
    open override var intrinsicContentSize: CGSize {
        let superSize = super.intrinsicContentSize
        textContainer.size = CGSize(width: superSize.width, height: CGFloat.greatestFiniteMagnitude)
        let size = layoutManager.usedRect(for: textContainer)
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }
    
    
    fileprivate var onKeywordTap: ((_ linkPrefix: String, _ keyword: String) -> Void)?
    fileprivate var tapRecognizer: UITapGestureRecognizer?
    
    
    override init(frame: CGRect, textContainer: NSTextContainer?) { super.init(frame: frame, textContainer: textContainer) }
    required public init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    public convenience init() {
        
        self.init(frame: CGRect.zero, textContainer: nil)
        backgroundColor = .clear
        textContainer.lineFragmentPadding = 0
        textContainerInset = UIEdgeInsets.zero
        bounces = false
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        isOpaque = true
        isEditable = false
        isSelectable = true
        isUserInteractionEnabled = true
        delegate = self
        isScrollEnabled = false
        if #available(iOS 11.0, *) {
            textDragDelegate = self
        }
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(DZLabel.tappedTextView))
        addGestureRecognizer(tapRecognizer!)
    }
    
    
    
    
}


// MARK: Misc
extension DZLabel {
    
    @objc fileprivate func tappedTextView() {
        var urlTapped = false
        if let tapLocation = tapRecognizer?.location(in: self) {
            if let textPosition = self.closestPosition(to: tapLocation) {
                let attr: [String : Any] = self.textStyling(at: textPosition, in: UITextStorageDirection.forward) ?? [String : Any]()
                if let url: URL = attr[NSAttributedStringKey.link.rawValue] as? URL {
                    _handleTapURL(url)
                    urlTapped = true
                }
            }
        }
        
        if !urlTapped {
            _tapHandler?()
        }
    }
    
    fileprivate func _setNumberOflines(_ lineCount: Int) {
        textContainer.maximumNumberOfLines = lineCount
    }
    
    
    fileprivate func _setLink(color: UIColor?, hasUnderscore: Bool) {
        var dict = linkTextAttributes ?? [String: Any]()
        if let color = color {
            dict[NSAttributedStringKey.foregroundColor.rawValue] = color
        }
        if hasUnderscore {
            dict[NSAttributedStringKey.underlineStyle.rawValue] = NSNumber(value: Int8(NSUnderlineStyle.styleSingle.rawValue))
        }
        linkTextAttributes = dict
    }
    
}


extension DZLabel: UITextViewDelegate {
    
    
    public func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        
        // ios 8+
        // check for long press event
        var isLongPress = false
        var longpressGesture: UILongPressGestureRecognizer?
        if let ges = textView.gestureRecognizers {
            for recognizer in ges {
                if recognizer is UILongPressGestureRecognizer {
                    if recognizer.state == UIGestureRecognizerState.began {
                        isLongPress = true
                        longpressGesture = recognizer as? UILongPressGestureRecognizer
                        
                    }
                }
            }
        }
        if isLongPress {
            if let _ = longpressGesture {
                _keywordLongPressHandler?()
            } else {
                _handleTapURL(URL)
            }
        } else {
            _handleTapURL(URL)
        }
        
        return false
    }
    
    public func textView(_ textView: UITextView, shouldInteractWith textAttachment: NSTextAttachment, in characterRange: NSRange) -> Bool {
        return false
    }
    
    // disable textview selectable
    override open var canBecomeFirstResponder : Bool {
        return false
    }
    
    public func textViewDidChangeSelection(_ textView: UITextView) {
        if NSEqualRanges(textView.selectedRange, NSMakeRange(0, 0)) == false {
            textView.selectedRange = NSMakeRange(0, 0);
        }
    }
    
    // 解决scrollEnable打开，tableViewCell的scroll事件被textView拦截，方式是检测点击的是不是关键字
    override open func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        var results = [Bool]()
        if let range = characterRange(at: point) {
            let start = range.start
            let end = range.end
            let startOffset = offset(from: beginningOfDocument, to: start)
            let endOffset = offset(from: beginningOfDocument, to: end)
            let nsrange = NSMakeRange(startOffset, endOffset - startOffset)
            attributedText.enumerateAttributes(in: nsrange, options: [], using: { (attris, range, stop) in
                if attris[NSAttributedStringKey.link] != nil {
                    results += [true]
                }
            })
        }
        return results.count > 0
    }
}

/// Disable Drag & Drop
@available(iOS 11.0, *)
extension DZLabel: UITextDragDelegate {
    @available(iOS 11.0, *)
    public func textDraggableView(_ textDraggableView: UIView & UITextDraggable, itemsForDrag dragRequest: UITextDragRequest) -> [UIDragItem] {
        return []
    }
}


