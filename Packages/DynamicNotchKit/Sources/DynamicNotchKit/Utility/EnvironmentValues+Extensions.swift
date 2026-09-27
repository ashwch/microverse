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

extension EnvironmentValues {
    var notchStyle: DynamicNotchStyle {
        get { self[NotchStyleKey.self] }
        set { self[NotchStyleKey.self] = newValue }
    }

    var notchSection: DynamicNotchSection {
        get { self[NotchSectionKey.self] }
        set { self[NotchSectionKey.self] = newValue }
    }
}

enum DynamicNotchSection {
    case expanded
    case compactLeading
    case compactTrailing
}
