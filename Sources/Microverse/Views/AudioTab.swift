import AppKit
import SwiftUI

/// System → Audio popover section.
///
/// First principle: let users do the 90% actions (see/switch devices, adjust volume) without opening System Settings,
/// while still respecting routes that don’t support volume/mute controls.
struct AudioTab: View {
    @EnvironmentObject private var audio: AudioDevicesStore

    var body: some View {
        VStack(spacing: 8) {
            outputCard
            inputCard
        }
        .padding(8)
        .onAppear {
            audio.start()
        }
        .onDisappear {
            audio.stop()
        }
    }

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("OUTPUT", systemIcon: "speaker.wave.2")

            if audio.outputDevices.isEmpty {
                Text("No output devices.")
                    .font(MicroverseDesign.Typography.caption)
                    .foregroundColor(.white.opacity(0.6))
            } else {
                VStack(spacing: 0) {
                    ForEach(audio.outputDevices) { device in
                        deviceRow(
                            device,
                            isSelected: device.id == audio.defaultOutputDeviceID,
                            icon: outputDeviceIcon(for: device)
                        ) {
                            audio.setDefaultOutputDevice(device.id)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
            }

            if let volume = audio.outputVolume {
                HStack(spacing: 10) {
                    Text("Volume")
                        .font(MicroverseDesign.Typography.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Slider(
                        value: Binding(
                            get: { Double(audio.outputVolume ?? volume) },
                            set: { audio.setOutputVolume(Float($0)) }
                        ),
                        in: 0...1
                    )
                    .disabled(!audio.canSetOutputVolume)

                    Text(audio.formattedPercent(volume))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }
            } else {
                Text("Volume control unavailable for the current device.")
                    .font(MicroverseDesign.Typography.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            if audio.outputMuted != nil {
                HStack {
                    Text("Mute")
                        .font(MicroverseDesign.Typography.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()

                    Toggle(
                        "",
                        isOn: Binding(
                            get: { audio.outputMuted ?? false },
                            set: { audio.setOutputMuted($0) }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(ElegantToggleStyle())
                    .disabled(!audio.canSetOutputMute || audio.outputMuted == nil)
                }
            }

            Button("Open Sound Settings") {
                openSoundSettings(anchor: "output")
            }
            .buttonStyle(FlatButtonStyle())
        }
        .padding(12)
        .background(MicroverseDesign.cardBackground())
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("INPUT", systemIcon: "mic")

            if audio.inputDevices.isEmpty {
                Text("No input devices.")
                    .font(MicroverseDesign.Typography.caption)
                    .foregroundColor(.white.opacity(0.6))
            } else {
                VStack(spacing: 0) {
                    ForEach(audio.inputDevices) { device in
                        deviceRow(
                            device,
                            isSelected: device.id == audio.defaultInputDeviceID,
                            icon: inputDeviceIcon(for: device)
                        ) {
                            audio.setDefaultInputDevice(device.id)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
            }

            Button("Open Sound Settings") {
                openSoundSettings(anchor: "input")
            }
            .buttonStyle(FlatButtonStyle())
        }
        .padding(12)
        .background(MicroverseDesign.cardBackground())
    }

    private func deviceRow(_ device: AudioDevicesStore.Device, isSelected: Bool, icon: String, onSelect: @escaping () -> Void) -> some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 16)

                Text(device.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(isSelected ? 1.0 : 0.85))
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(MicroverseDesign.Colors.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(isSelected ? 0.08 : 0.0))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func outputDeviceIcon(for device: AudioDevicesStore.Device) -> String {
        if let model = audio.airPodsModel(for: device) { return model.symbolName }
        if audio.isSonyWH1000XM(device) { return "headphones" }
        if device.isBluetooth { return "headphones" }
        if device.isAirPlay { return "airplayaudio" }
        if device.isUSB { return "cable.connector" }
        if device.isBuiltIn { return "laptopcomputer" }
        return "speaker.wave.2"
    }

    private func inputDeviceIcon(for device: AudioDevicesStore.Device) -> String {
        if let model = audio.airPodsModel(for: device) { return model.symbolName }
        if device.isBluetooth { return "mic" }
        if device.isUSB { return "cable.connector" }
        if device.isBuiltIn { return "laptopcomputer" }
        return "mic"
    }

    private func openSoundSettings(anchor: String) {
        let urls: [URL?] = [
            URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension?\(anchor)"),
            URL(string: "x-apple.systempreferences:com.apple.preference.sound"),
        ]

        for url in urls.compactMap({ $0 }) {
            if NSWorkspace.shared.open(url) {
                return
            }
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}
