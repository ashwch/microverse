# Microverse Widget Design Specifications

## CRITICAL IMPLEMENTATION RULES

### The Golden Rules of Widget Implementation
1. **NEVER use ZStack as root container** - It causes content clipping
2. **ALWAYS set explicit frame sizes** - Must match window dimensions exactly
3. **Apply backgrounds LAST** - After content and padding, before frame
4. **Padding goes INSIDE frame** - Not outside the frame modifier
5. **Test with edge cases** - 100% battery, "Calculating...", long time strings

### Why These Rules Matter
- **ZStack Issue**: When ZStack is the root, SwiftUI's layout system can misalculate bounds
- **Frame Matching**: Any mismatch between window size and view frame = clipped content
- **Background Order**: Applying background before frame can cause unexpected clipping
- **Padding Position**: Padding outside frame increases total size beyond window bounds

## Design Principles
1. **Clarity**: All text must be fully visible with adequate padding
2. **Consistency**: Uniform spacing, typography, and visual hierarchy across all widgets
3. **Hierarchy**: Clear visual distinction between primary and secondary information
4. **Adaptability**: Content should gracefully handle edge cases (long time strings, etc.)

## Typography System
- **Large Title**: 32pt bold (percentage in Standard widget)
- **Title**: 24pt bold (percentage in Detailed widget)
- **Headline**: 18pt medium (percentage in Compact widget)
- **Body**: 16pt regular/medium (time values)
- **Caption**: 12pt regular (labels, status)
- **Small Caption**: 10pt regular (secondary labels)

## Spacing System
- **Padding**: 16px (container padding)
- **Element Spacing**: 8px (between related elements)
- **Section Spacing**: 16px (between sections)
- **Icon Spacing**: 6px (between icon and text)

## Color System
- **Critical** (≤10%): System Red
- **Warning** (≤20%): System Orange  
- **Charging**: System Green
- **Normal**: Primary/White
- **Secondary Text**: 60% opacity
- **Dividers**: 20% opacity
- **Background**: Black 50% opacity (minimal/compact), Blur effect (standard/detailed)

## Widget Specifications (UPDATED)

### Minimal Widget
- **Size**: 100×40px (compact and unobtrusive)
- **Content**: Battery percentage only
- **Layout**: HStack with optional charging icon
- **Implementation**:
  ```swift
  HStack { icon + percentage }
  .padding(8)
  .background(...)
  .frame(width: 100, height: 40)
  ```
- **Use Case**: Minimal screen real estate usage

### Compact Widget  
- **Size**: 160×50px (balanced information density)
- **Content**: Percentage + Divider + Time
- **Layout**: Horizontal with visual separator
- **Implementation**:
  ```swift
  HStack { battery% | divider | time }
  .padding(.horizontal, 10, .vertical, 8)
  .background(...)
  .frame(width: 160, height: 50)
  ```
- **Use Case**: Quick glance with time estimate

### Standard Widget
- **Size**: 180×100px (comfortable viewing)
- **Content**: Large percentage + Status + Time
- **Layout**: VStack, vertically centered
- **Implementation**:
  ```swift
  VStack { large% + status + time }
  .padding(12)
  .frame(width: 180, height: 100)
  .background(blur...)
  ```
- **Use Case**: Primary desktop widget

### Detailed Widget
- **Size**: 240×120px (information rich)
- **Content**: Percentage + Status + Cycles + Health + Time
- **Layout**: Header row + divider + stats grid
- **Implementation**:
  ```swift
  VStack { header + divider + HStack stats }
  .padding(12)
  .frame(width: 240, height: 120)
  .background(blur...)
  ```
- **Use Case**: Power users wanting all details

## Content Guidelines

### Text Truncation
- Never truncate primary information (percentage, time)
- Use fixed layouts that accommodate maximum expected content
- Test with edge cases: "100%", "Calculating...", "10:59 remaining"

### Dynamic Sizing
- Widgets should have fixed sizes that accommodate all content scenarios
- No dynamic resizing based on content
- Consistent window size for each widget style

### Visual Balance
- Center-align content in minimal and standard widgets
- Use consistent padding on all sides
- Ensure breathing room around all text elements

## Implementation Checklist
- [x] Update all widget sizes to new specifications
- [x] Ensure consistent padding across all widgets
- [x] Test with maximum content lengths
- [x] Verify no text truncation occurs
- [x] Check visual hierarchy is maintained
- [x] Validate color system implementation

## Common Pitfalls and Solutions

### Problem: Content gets clipped
**Solution**: Check that window size matches view frame exactly

### Problem: Widget appears cut off at edges
**Solution**: Ensure padding is inside frame, not outside

### Problem: Background doesn't fill window
**Solution**: Apply background before frame modifier

### Problem: Text overlaps or crowds
**Solution**: Use smaller font sizes and proper spacing

## Testing Protocol
1. Test with 100% battery (3 digits)
2. Test with "Calculating..." text
3. Test with "10:59 remaining" (longest time)
4. Test charging vs discharging states
5. Test all four widget styles
6. Verify no content is clipped in any state