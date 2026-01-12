# Contributing to Microverse

Thank you for your interest in contributing to Microverse! This guide will help you get started with our development process and coding standards.

## 🎯 Development Philosophy

We maintain high quality standards in every aspect of the codebase:

- **Performance First**: Every change must maintain <1% CPU usage and <50MB memory footprint
- **Design Excellence**: All UI follows design system principles of clarity, deference, and depth
- **Code Quality**: Professional standards with comprehensive documentation
- **User Experience**: Intuitive, elegant interactions that feel native to macOS

## 🚀 Getting Started

### Prerequisites

- **macOS 13.0+** (Ventura or later recommended)
- **Xcode 16.0+** or **Swift 6.0+**
- **Git** for version control

### Local Development Setup

1. **Fork the repository**
   ```bash
   # Click "Fork" on GitHub, then clone your fork
   git clone https://github.com/YOUR_USERNAME/microverse.git
   cd microverse
   ```

2. **Build and run**
   ```bash
   # Development build & run
   make run
   
   # Or for release build
   make install
   ```

3. **Verify installation**
   - Look for the alien 👽 icon in your menu bar
   - Open settings to test all functionality

### Project Structure

```
Sources/
├── Microverse/                    # Main application
│   ├── MenuBarApp.swift           # App entry point
│   ├── BatteryViewModel.swift     # Primary view model
│   ├── UnifiedDesignSystem.swift # Design tokens
│   ├── MicroverseNotchSystem.swift # Smart notch integration
│   └── Views/                     # SwiftUI views
├── BatteryCore/                   # Battery monitoring framework
└── SystemCore/                    # System monitoring framework
```

## 📋 Development Guidelines

### Code Style Standards

#### SwiftUI Best Practices
- **@MainActor isolation** for all UI-related classes
- **async/await** patterns instead of completion handlers
- **@Published** properties for reactive state management
- **environmentObject** for dependency injection

#### Design System Compliance
- **ALWAYS use MicroverseDesign tokens** - never hardcode values
- **Semantic colors**: `.battery`, `.processor`, `.memory`, `.system`
- **Typography hierarchy**: `.display`, `.largeTitle`, `.title`, `.body`, `.caption`
- **Layout system**: 4px grid with predefined spacing constants

#### Performance Requirements
- **CPU Usage**: Monitor with Activity Monitor, maintain <1% average
- **Memory Footprint**: Target <50MB, measure in Memory tab
- **Responsive UI**: All actions should feel instant (<100ms perceived)
- **Adaptive refresh**: Use appropriate intervals based on battery state

### Example: Adding a New Feature

```swift
// ✅ GOOD: Uses design system, proper isolation, error handling
@MainActor
class NewFeatureViewModel: ObservableObject {
    @Published var isEnabled = false
    private let logger = Logger(subsystem: "com.microverse.app", category: "NewFeature")
    
    func toggleFeature() async {
        do {
            isEnabled.toggle()
            try await performFeatureAction()
            logger.info("Feature toggled successfully")
        } catch {
            isEnabled.toggle() // Revert on error
            logger.error("Feature toggle failed: \(error.localizedDescription)")
        }
    }
}

// View using design system tokens
struct NewFeatureView: View {
    @StateObject private var viewModel = NewFeatureViewModel()
    
    var body: some View {
        VStack(spacing: MicroverseDesign.Layout.space3) {
            Text("New Feature")
                .font(MicroverseDesign.Typography.title)
                .foregroundColor(MicroverseDesign.Colors.accent)
            
            Toggle("Enable Feature", isOn: $viewModel.isEnabled)
                .toggleStyle(ElegantToggleStyle())
        }
        .padding(MicroverseDesign.Layout.space4)
    }
}
```

```swift
// ❌ BAD: Hardcoded values, no error handling, blocking UI
class BadFeatureViewModel: ObservableObject {
    @Published var isEnabled = false
    
    func toggleFeature() {
        // Blocking operation on main thread
        Thread.sleep(forTimeInterval: 2.0)
        isEnabled.toggle()
    }
}

struct BadFeatureView: View {
    var body: some View {
        VStack(spacing: 16) { // Hardcoded spacing
            Text("Feature")
                .font(.title) // Not using design system
                .foregroundColor(.white) // Hardcoded color
        }
    }
}
```

## 🔍 Code Review Process

### Before Submitting

1. **Performance Testing**
   ```bash
   # Build and monitor performance
   make install
   # Open Activity Monitor → Check CPU/Memory usage
   ```

2. **Design System Audit**
   ```bash
   # Search for hardcoded values (should return empty)
   grep -r "\.frame.*[0-9]" Sources/
   grep -r "\.padding.*[0-9]" Sources/
   grep -r "Color\." Sources/ | grep -v "MicroverseDesign"
   ```

3. **Code Quality Check**
   - All new classes documented with /// comments
   - Error handling with graceful degradation
   - Logging for debugging and monitoring
   - No force unwrapping or force casting

### Pull Request Requirements

#### Title Format
```
feat: add smart notification system
fix: resolve memory leak in widget manager  
refactor: improve notch layout performance
docs: update architecture documentation
```

#### Description Template
```markdown
## 🎯 Purpose
Brief description of what this PR accomplishes

## 🔧 Changes
- Specific change 1
- Specific change 2

## 🧪 Testing
- [ ] Performance verified (CPU <1%, Memory <50MB)
- [ ] Design system compliance checked
- [ ] Manual testing on macOS 13.0+
- [ ] No regressions in existing functionality

## 📸 Screenshots
[Include before/after screenshots for UI changes]

## 🚨 Breaking Changes
[List any breaking changes or migration required]
```

## 🎨 Design Contributions

### UI/UX Guidelines

#### Apple Design Principles
- **Clarity**: Information hierarchy through typography and color
- **Deference**: UI serves content, never competes
- **Depth**: Layered information through materials and spacing

#### Microverse Specific
- **Semantic Colors**: Battery=green, CPU=blue, Memory=purple
- **Glass Effects**: Subtle materials with proper opacity
- **Responsive Layout**: Adapts to different screen sizes
- **Accessibility**: VoiceOver support, high contrast compatibility

### Design Review Checklist

- [ ] Follows Apple Human Interface Guidelines
- [ ] Uses MicroverseDesign tokens exclusively
- [ ] Proper contrast ratios (4.5:1 minimum)
- [ ] Consistent spacing and typography
- [ ] Smooth animations with appropriate duration
- [ ] Dark mode compatibility
- [ ] Accessibility labels and hints

## 🐛 Bug Reports

### Bug Report Template

```markdown
**Environment**
- macOS Version: [e.g., macOS 13.0]
- Microverse Version: [e.g., v1.0.0]
- Hardware: [e.g., MacBook Pro M1 2021]

**Expected Behavior**
Clear description of expected behavior

**Actual Behavior**
Clear description of what actually happens

**Steps to Reproduce**
1. Step one
2. Step two
3. Step three

**Screenshots/Logs**
[Attach relevant screenshots or log outputs]

**Additional Context**
Any other context about the problem
```

## 🏆 Recognition

### Contribution Types

- **🚀 Features**: New functionality or major improvements
- **🐛 Bug Fixes**: Resolving issues and improving stability
- **📚 Documentation**: Improving guides, comments, or examples
- **🎨 Design**: UI/UX improvements and design system enhancements
- **⚡ Performance**: Optimizations and efficiency improvements
- **🔒 Security**: Security enhancements and vulnerability fixes

### Hall of Fame

Outstanding contributors will be recognized in:
- README.md acknowledgments
- Release notes
- Annual contributor appreciation

## 📞 Getting Help

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and community discussion
- **Pull Request Reviews**: Code-specific feedback and collaboration

### Response Times

- **Critical Bugs**: 24-48 hours
- **Feature Requests**: 1-2 weeks
- **Documentation**: 3-5 days
- **Pull Reviews**: 2-3 days

## 📄 License

By contributing to Microverse, you agree that your contributions will be licensed under the same MIT License that covers the project.

---

**Thank you for helping make Microverse better! 🚀**

*Your contributions help create the most elegant and performant system monitoring tool for macOS developers.*
