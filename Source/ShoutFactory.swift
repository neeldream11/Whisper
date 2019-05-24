import UIKit

let shoutView = ShoutView()

class ShoutWindow: UIWindow {
    internal override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        if hitView == self {
            return nil
        } else {
            return hitView
        }
    }
}

open class ShoutView: UIView {
    
    public struct Dimensions {
        public static let imageSize: CGFloat = 48
        public static let imageOffset: CGFloat = 18
        public static var textOffset: CGFloat = 75
        public static var touchOffset: CGFloat = 40
    }
    
    open fileprivate(set) lazy var backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = ColorList.Shout.errorBackground
        view.alpha = 0.98
        view.clipsToBounds = true
        
        return view
    }()

    
    open fileprivate(set) lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.layer.cornerRadius = Dimensions.imageSize / 2
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        
        return imageView
    }()
    
    open fileprivate(set) lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = FontList.Shout.title
        label.textColor = ColorList.Shout.title
        label.numberOfLines = 0
        
        return label
    }()
    
    open fileprivate(set) lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = FontList.Shout.subtitle
        label.textColor = ColorList.Shout.subtitle
        label.numberOfLines = 0
        
        return label
    }()
    
    open fileprivate(set) lazy var tapGestureRecognizer: UITapGestureRecognizer = { [unowned self] in
        let gesture = UITapGestureRecognizer()
        gesture.addTarget(self, action: #selector(ShoutView.handleTapGestureRecognizer))
        
        return gesture
        }()
    
    open fileprivate(set) lazy var panGestureRecognizer: UIPanGestureRecognizer = { [unowned self] in
        let gesture = UIPanGestureRecognizer()
        gesture.addTarget(self, action: #selector(ShoutView.handlePanGestureRecognizer))
        
        return gesture
        }()
    
    open fileprivate(set) var announcement: Announcement?
    open fileprivate(set) var displayTimer = Timer()
    open fileprivate(set) var panGestureActive = false
    open fileprivate(set) var shouldSilent = false
    open fileprivate(set) var completion: (() -> ())?
    private lazy var shoutWindow: ShoutWindow = {
        let window = ShoutWindow(frame: UIScreen.main.bounds)
        window.windowLevel = UIWindow.Level.statusBar
        window.rootViewController = UIViewController()
        return window
    }()
    private var subtitleLabelOriginalHeight: CGFloat = 0
    private var internalHeight: CGFloat = 0
    
    // MARK: - Initializers
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(backgroundView)
        [imageView, titleLabel, subtitleLabel].forEach {
            ($0 ).autoresizingMask = []
            backgroundView.addSubview($0 )
        }
        
        clipsToBounds = false
        isUserInteractionEnabled = true
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 0.5)
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 0.5
        
        backgroundView.addGestureRecognizer(tapGestureRecognizer)
        addGestureRecognizer(panGestureRecognizer)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ShoutView.orientationDidChange), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    // MARK: - Configuration
    
    open func craft(_ announcement: Announcement, to: UIViewController, completion: (() -> ())?) {
        panGestureActive = false
        shouldSilent = false
        configureView(announcement)
        shout(to: to)
        
        self.completion = completion
    }
    
    open func configureView(_ announcement: Announcement) {
        self.announcement = announcement
        imageView.image = announcement.image
        titleLabel.text = announcement.title
        subtitleLabel.text = announcement.subtitle
        
        let bgColor: UIColor
        switch announcement.status! {
        case .success:
            bgColor = ColorList.Shout.successBackground
        case .error:
            bgColor = ColorList.Shout.errorBackground
        case .warning:
            bgColor = ColorList.Shout.warningBackground
        case .info:
            bgColor = ColorList.Shout.infoBackground
        }
        
        backgroundView.backgroundColor = bgColor
        
        displayTimer.invalidate()
        displayTimer = Timer.scheduledTimer(timeInterval: announcement.duration,
                                            target: self, selector: #selector(ShoutView.displayTimerDidFire), userInfo: nil, repeats: false)
        
        setupFrames()
    }
    
    open func shout(to controller: UIViewController) {
        //        UIApplication.shared.keyWindow?.addSubview(sel
        let height = self.internalHeight + Dimensions.touchOffset
        shoutWindow.frame = CGRect(x: 0, y: -height, width: UIScreen.main.bounds.size.width, height: height)
        shoutWindow.rootViewController?.view.addSubview(self)
        shoutWindow.makeKeyAndVisible()
        self.shoutWindow.rootViewController?.view.isUserInteractionEnabled = true
        self.shoutWindow.isUserInteractionEnabled = true
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.0, options: .curveEaseOut, animations: {
            self.shoutWindow.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: height)
        }) { _ in
            self.shoutWindow.resignKey()
            self.mainWindow()?.makeKey()
            
        }
        
    }
    
    // MARK: - Setup
    
    public func setupFrames() {
        internalHeight = (UIApplication.shared.isStatusBarHidden ? 55 : 65)
        
        let totalWidth = UIScreen.main.bounds.width
        let offset: CGFloat = UIApplication.shared.isStatusBarHidden ? 2.5 : 5
        let textOffsetX: CGFloat = imageView.image != nil ? Dimensions.textOffset : 18
        let imageSize: CGFloat = imageView.image != nil ? Dimensions.imageSize : 0
        
        [titleLabel, subtitleLabel].forEach {
            $0.frame.size.width = totalWidth - imageSize - (Dimensions.imageOffset * 3)
            $0.sizeToFit()
        }
        
        internalHeight += subtitleLabel.frame.height
        
        imageView.frame = CGRect(x: Dimensions.imageOffset, y: (internalHeight - imageSize) / 2 + offset,
                                 width: imageSize, height: imageSize)
        
        let textOffsetY = imageView.image != nil ? imageView.frame.origin.x + 3 : textOffsetX + 5
        
        titleLabel.frame.origin = CGPoint(x: textOffsetX, y: textOffsetY)
        subtitleLabel.frame.origin = CGPoint(x: textOffsetX, y: titleLabel.frame.maxY + 2.5)
        
        if subtitleLabel.text?.isEmpty ?? true {
            titleLabel.center.y = imageView.center.y - 2.5
        }
        
        var height = internalHeight + Dimensions.touchOffset
        if height < 70 {
            height = 70
        }
        frame = CGRect(x: 0, y: 0, width: totalWidth, height: height)
    }
    
    // MARK: - Frame
    
    open override var frame: CGRect {
        didSet {
            let horizontalPadding: CGFloat = 10
            var topPadding: CGFloat = 15
            
            if #available(iOS 11.0, *) {
                topPadding = topPadding + self.mainWindow()!.safeAreaInsets.top
            }
            
            
            backgroundView.frame = CGRect(x: horizontalPadding, y: topPadding,
                                          width: frame.size.width - 2 * horizontalPadding,
                                          height: frame.size.height - Dimensions.touchOffset)
            
            backgroundView.layer.cornerRadius = horizontalPadding
        }
    }
    
    // MARK: - Actions
    
    open func silent() {
        UIView.animate(withDuration: 0.35, animations: {
            self.frame.size.height = 0
        }, completion: { finished in
            self.completion?()
            self.displayTimer.invalidate()
            self.removeFromSuperview()
            
            self.shoutWindow.removeFromSuperview()
            self.shoutWindow.rootViewController?.view.isUserInteractionEnabled = false
            self.shoutWindow.isUserInteractionEnabled = false
        })
    }
    
    func mainWindow() -> UIWindow? {
        for window in UIApplication.shared.windows.reversed() {
            if window.windowLevel == UIWindow.Level.normal {
                return window
            } else {
                
            }
        }
        
        return nil
    }
    
    // MARK: - Timer methods
    
    @objc open func displayTimerDidFire() {
        shouldSilent = true
        
        if panGestureActive { return }
        silent()
    }
    
    // MARK: - Gesture methods
    
    @objc fileprivate func handleTapGestureRecognizer() {
        guard let announcement = announcement else { return }
        announcement.action?()
        silent()
    }
    
    @objc private func handlePanGestureRecognizer() {
        let translation = panGestureRecognizer.translation(in: self)
        
        if panGestureRecognizer.state == .began {
            subtitleLabelOriginalHeight = subtitleLabel.bounds.size.height
            subtitleLabel.numberOfLines = 0
            subtitleLabel.sizeToFit()
        } else if panGestureRecognizer.state == .changed {
            panGestureActive = true
            
            let maxTranslation = subtitleLabel.bounds.size.height - subtitleLabelOriginalHeight
            
            if translation.y >= maxTranslation {
                frame.size.height = internalHeight + maxTranslation
                    + (translation.y - maxTranslation) / 25 + Dimensions.touchOffset
            } else {
                frame.size.height = internalHeight + translation.y + Dimensions.touchOffset
            }
        } else {
            panGestureActive = false
            let height = translation.y < -5 || shouldSilent ? 0 : internalHeight
            
            subtitleLabel.numberOfLines = 0
            subtitleLabel.sizeToFit()
            
            UIView.animate(withDuration: 0.2, animations: {
                self.frame.size.height = height + Dimensions.touchOffset
            }, completion: { _ in
                if translation.y < -5 {
                    self.completion?()
                    self.removeFromSuperview()
                    self.shoutWindow.removeFromSuperview()
                    self.shoutWindow.rootViewController?.view.isUserInteractionEnabled = false
                    self.shoutWindow.isUserInteractionEnabled = false
                }
            })
        }
    }
    
    
    // MARK: - Handling screen orientation
    
    @objc func orientationDidChange() {
        setupFrames()
    }
}
