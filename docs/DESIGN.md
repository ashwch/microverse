# Microverse UI Design Document v2

## Design Philosophy
- **Minimalist**: Show only essential, real battery information
- **Native**: Follow macOS design patterns and use system colors
- **Consistent**: Unified visual language across all components
- **Accessible**: Clear contrast, readable text, keyboard navigation

## Main Popover (280×Auto)

### Layout
```
┌─────────────────────────────────┐
│         [Battery Icon]          │
│            59%                  │
│          Charging               │
│                                 │
├─────────────────────────────────┤
│   30      │      100%           │
│  Cycles   │     Health          │
├─────────────────────────────────┤
│ ⚙ Settings            ↻         │
└─────────────────────────────────┘
```

### Components
1. **Battery Status** (Center-aligned)
   - Large battery icon (48pt) with dynamic fill
   - Percentage text (28pt bold)
   - Status text (15pt regular)
   - Time remaining (13pt) when applicable

2. **Stats Row** (Equal width columns)
   - Cycle count and health percentage
   - Separated by divider
   - Value (17pt semibold) above label (11pt)

3. **Action Bar**
   - Settings button (left): Icon + "Settings" text
   - Refresh button (right): Icon only
   - Flat button style with hover states

## Settings Sheet (320×400)

### Sections
1. **Display**
   - Show percentage in menu bar toggle

2. **Desktop Widget**  
   - Enable widget toggle
   - Style picker (when enabled)

3. **General**
   - Launch at startup toggle
   - Refresh interval picker

## Desktop Widgets

### Minimal (100×40)
```
┌─────────────┐
│  ⚡ 59%     │
└─────────────┘
```
- Simple percentage display
- Charging bolt when applicable
- Dark semi-transparent background

### Compact (160×60)
```
┌───────────────────┐
│ ⚡ 59%    1:45    │
└───────────────────┘
```
- Battery percentage + time remaining
- Horizontal layout
- Dark background

### Standard (180×100)
```
┌───────────────────┐
│       59%         │
│    Charging       │
│      1:45         │
└───────────────────┘
```
- Centered layout
- Large percentage (32pt)
- Vibrancy background

### Detailed (200×120)
```
┌───────────────────┐
│ ⚡ 59%   Charging │
│                   │
│ Cycles  Health    │
│   30     100%     │
└───────────────────┘
```
- Comprehensive info
- Clean grid layout
- Vibrancy background

## Colors

### Battery Status Colors
- **Normal**: System primary
- **Charging**: System green
- **Low (≤20%)**: System orange  
- **Critical (≤10%)**: System red

### Widget Colors
- **Text**: White/primary (adaptive)
- **Background**: Black 50% opacity or vibrancy
- **Border**: White 10% opacity

## Typography
- **Large numbers**: SF Pro Rounded
- **Body text**: SF Pro Text
- **All sizes**: System dynamic type

## Implementation Guidelines
1. Use SwiftUI native components
2. Respect system appearance (dark/light)
3. Use SF Symbols for all icons
4. Apply consistent spacing (8pt grid)
5. Add subtle animations (0.2s ease)
6. Ensure keyboard accessibility