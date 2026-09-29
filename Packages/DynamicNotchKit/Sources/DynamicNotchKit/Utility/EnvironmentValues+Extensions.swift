//
//  EnvironmentValues+Extensions.swift
//  DynamicNotchKit
//
//  Created by Kai Azim on 2025-03-26.
//

import SwiftUI

// Explicit EnvironmentKey types instead of `@Entry`: identical semantics, but buildable with the
// Command Line Tools toolchain, which does not ship the SwiftUIMacros plugin.
private struct NotchStyleKey: EnvironmentKey {
    static let defaultValue: DynamicNotchStyle = .auto
}

private struct NotchSectionKey: EnvironmentKey {
    static let defaultValue: DynamicNotchSection = .expanded
}

private struct HasPhysicalNotchKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var notchStyle: DynamicNotchStyle {
        get { self[NotchStyleKey.self] }
        set { self[NotchStyleKey.self] = newValue }
    }

    var notchSection: DynamicNotchSection {
        get { self[NotchSectionKey.self] }
        set { self[NotchSectionKey.self] = newValue }
    }

    /// Whether the screen the notch is on has a physical notch. Lets compact content decide what to
    /// show beside the pill versus in the center slot, which only exists on notchless screens.
    public var dynamicNotchHasPhysicalNotch: Bool {
        get { self[HasPhysicalNotchKey.self] }
        set { self[HasPhysicalNotchKey.self] = newValue }
    }
}

enum DynamicNotchSection {
    case expanded
    case compactLeading
    /// The reserved notch width in the middle, only rendered on screens without a physical notch.
    case compactCenter
    case compactTrailing
}
