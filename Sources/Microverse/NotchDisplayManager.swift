import SwiftUI
import AppKit
import BatteryCore
import SystemCore
import os.log

enum DisplayMode {
    case notch          // Stats around notch
    case floatingWidget // Traditional desktop widget
}

@MainActor
class NotchDisplayManager: ObservableObject {
    @Published var currentMode: DisplayMode = .floatingWidget
    @Published var isNotchDisplayEnabled = false
    
    private var leftWidget: NotchWidgetWindow?
    private var rightWidget: NotchWidgetWindow?
    private weak var viewModel: BatteryViewModel?
    private let logger = Logger(subsystem: "com.microverse.app", category: "NotchDisplayManager")
    
    init(viewModel: BatteryViewModel) {
        self.viewModel = viewModel
        setupDisplayMonitoring()
        detectAndSetMode()
        
        // Debug: Log initialization
        if let screen = NSScreen.main {
            logger.info("NotchDisplayManager initialized. Screen: \(String(describing: screen.frame))")
            if #available(macOS 12.0, *) {
                logger.info("Safe area insets: \(String(describing: screen.safeAreaInsets))")
                logger.info("Has notch: \(screen.hasNotch)")
            }
        }
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    func showNotchDisplay() {
        guard let _ = viewModel,
              NSScreen.main?.hasNotch == true else {
            logger.warning("Cannot show notch display: no notch detected or viewModel missing")
            return
        }
        
        isNotchDisplayEnabled = true
        currentMode = .notch
        hideNotchWidgets()
        createNotchWidgets()
        
        logger.info("Notch display enabled")
    }
    
    func hideNotchDisplay() {
        isNotchDisplayEnabled = false
        hideNotchWidgets()
        
        if currentMode == .notch {
            currentMode = .floatingWidget
        }
        
        logger.info("Notch display disabled")
    }
    
    func toggleNotchDisplay() {
        if isNotchDisplayEnabled {
            hideNotchDisplay()
        } else {
            showNotchDisplay()
        }
    }
    
    private func setupDisplayMonitoring() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(displayConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc private func displayConfigurationChanged() {
        logger.info("Display configuration changed, adapting...")
        detectAndSetMode()
    }
    
    private func detectAndSetMode() {
        guard let screen = NSScreen.main else {
            logger.warning("No main screen found")
            return
        }
        
        if screen.hasNotch && isNotchDisplayEnabled {
            if currentMode != .notch {
                logger.info("Switching to notch mode")
                currentMode = .notch
                hideNotchWidgets()
                createNotchWidgets()
            }
        } else {
            if currentMode == .notch {
                logger.info("Switching to floating widget mode")
                currentMode = .floatingWidget
                hideNotchWidgets()
            }
        }
    }
    
    private func createNotchWidgets() {
        guard let viewModel = viewModel,
              let screen = NSScreen.main,
              screen.hasNotch else {
            logger.warning("Cannot create notch widgets: requirements not met")
            return
        }
        
        let leftPosition: CGPoint
        let rightPosition: CGPoint
        
        if #available(macOS 12.0, *) {
            leftPosition = screen.notchLeftPosition
            rightPosition = screen.notchRightPosition
        } else {
            logger.warning("Notch positioning requires macOS 12.0 or later")
            return
        }
        
        // Create left widget (Battery)
        leftWidget = NotchWidgetWindow(position: leftPosition)
        let leftView = AnyView(
            NotchBatteryWidget()
                .environmentObject(viewModel)
        )
        leftWidget?.contentView = NSHostingView(rootView: leftView)
        leftWidget?.makeKeyAndOrderFront(nil)
        logger.info("Created left notch widget at position: \(String(describing: leftPosition))")
        
        // Create right widget (CPU + Memory)
        rightWidget = NotchWidgetWindow(position: rightPosition)
        let rightView = AnyView(
            NotchSystemWidget()
                .environmentObject(viewModel)
        )
        rightWidget?.contentView = NSHostingView(rootView: rightView)
        rightWidget?.makeKeyAndOrderFront(nil)
        logger.info("Created right notch widget at position: \(String(describing: rightPosition))")
        
        logger.info("Notch widgets created and positioned")
    }
    
    private func hideNotchWidgets() {
        leftWidget?.close()
        rightWidget?.close()
        leftWidget = nil
        rightWidget = nil
    }
}

// MARK: - NSScreen Extensions

extension NSScreen {
    var notchHeight: CGFloat {
        guard #available(macOS 12.0, *) else { return 0 }
        return safeAreaInsets.top
    }
    
    @available(macOS 12.0, *)
    var notchLeftPosition: CGPoint {
        guard hasNotch else { return .zero }
        
        let x = safeAreaInsets.left + MicroverseDesign.Layout.space2
        let y = frame.height - 11 // Center in menu bar (22px height)
        return CGPoint(x: x, y: y)
    }
    
    @available(macOS 12.0, *)
    var notchRightPosition: CGPoint {
        guard hasNotch else { return .zero }
        
        // Approximate notch width and position to the right
        let notchWidth: CGFloat = 160
        let x = (frame.width / 2) + (notchWidth / 2) + MicroverseDesign.Layout.space2
        let y = frame.height - 11
        return CGPoint(x: x, y: y)
    }
}
