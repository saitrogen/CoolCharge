import CoolChargeCore
import AppKit
import SwiftUI

@main
struct CoolChargeApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            CoolChargeView(model: model)
        } label: {
            HStack(spacing: 4) {
                MenuBarBatteryIcon(
                    level: model.menuBarBatteryLevel,
                    badgeSymbol: model.menuBarBadgeSymbol
                )
                Text(model.menuBarTitle)
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
            }
            .accessibilityLabel(model.menuBarAccessibilityLabel)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct CoolChargeView: View {
    @ObservedObject var model: AppModel
    @AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false
    @State private var showingSetup = false
    @State private var copiedSetupCommand = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Color.clear.frame(height: 0).id("panelTop")
                        if showingSetup {
                            setupAssistant
                        } else {
                            if !model.chargeControlReady {
                                setupAttentionBanner
                            }
                            stateBanner
                            controls
                            statusCard
                            telemetryCard
                            settings
                        }
                    }
                    .padding(18)
                }
                .onAppear {
                    proxy.scrollTo("panelTop", anchor: .top)
                }
            }

            Divider()
            footer
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
        }
        .frame(width: 370, height: 650)
        .onAppear {
            if !hasCompletedWelcome {
                showingSetup = true
            }
            DispatchQueue.main.async {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
    }

    private var setupAssistant: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "snowflake.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.cyan)
                Text("Welcome to CoolCharge")
                    .font(.title2.weight(.semibold))
                Text("A quick safety check prevents macOS and CoolCharge from trying to manage charging at the same time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            setupStep(
                state: model.reading == nil ? .checking : .ready,
                title: "Battery telemetry",
                detail: model.reading == nil
                    ? "Waiting for the first battery reading."
                    : "Battery percentage and temperature are available."
            ) {
                EmptyView()
            }

            setupStep(
                state: backendStepState,
                title: "Charging backend",
                detail: backendStepDetail
            ) {
                if model.backendSetupState == .notInstalled || model.backendSetupState == .daemonUnavailable {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.backendSetupCommand)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 7))

                        HStack(spacing: 8) {
                            Button(copiedSetupCommand ? "Copied" : "Copy Commands") {
                                copySetupCommand()
                            }
                            Button("Open Terminal") {
                                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
                            }
                            Button("Guide") {
                                openURL("https://github.com/charlie0129/batt#installation")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            setupStep(
                state: appleSettingsStepState,
                title: "Apple charging controls",
                detail: appleSettingsStepDetail
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Turn off Optimized Battery Charging and Apple’s Charge Limit while CoolCharge is controlling the battery.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Button("Open Battery Settings") {
                            openBatterySettings()
                        }
                        if !model.appleSettingsConfirmed {
                            Button("I Turned Both Off") {
                                model.confirmAppleSettingsAreOff()
                            }
                            .disabled(model.appleChargingPolicyStatus.hasActivePolicy)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            HStack(spacing: 10) {
                Button("Recheck") {
                    copiedSetupCommand = false
                    model.refresh()
                }
                .buttonStyle(.bordered)

                Spacer()

                if model.setupIsReady {
                    Button("Start CoolCharge") {
                        finishSetup()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Continue Monitoring") {
                        finishSetup()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text(model.setupIsReady
                ? "Setup complete. CoolCharge can now manage charging."
                : "Monitoring is safe without setup; charging controls remain unavailable until every required check is complete.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var setupAttentionBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text("Finish charge-control setup")
                    .font(.subheadline.weight(.semibold))
                Text(model.setupAttentionSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Review") { showingSetup = true }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(12)
        .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.orange.opacity(0.25), lineWidth: 1)
        }
    }

    private var stateBanner: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: model.stateSymbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(stateColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.statusTitle)
                    .font(.headline)
                Text(model.statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if model.thermalResumeDate != nil {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        if let progress = model.thermalProgressText(at: timeline.date) {
                            Text(progress)
                                .font(.caption.weight(.medium).monospacedDigit())
                                .foregroundStyle(stateColor)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(stateColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(stateColor.opacity(0.22), lineWidth: 1)
        }
    }

    private var stateColor: Color {
        switch model.mode {
        case .thermalHold: .cyan
        case .manualHold: .orange
        case .override: .pink
        case .automatic: model.reading?.isCharging == true ? .green : .blue
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("CoolCharge")
                    .font(.title2.weight(.semibold))
                Text(model.modeTitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                if model.isCommandPending {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Applying…")
                } else {
                    Circle()
                        .fill(model.chargeControlReady ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(model.chargeControlReady ? "Live · 15s" : "Setup")
                }
            }
            .font(.caption.weight(.medium).monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        if let reading = model.reading {
            HStack(spacing: 0) {
                metric(value: "\(reading.percentage)%", label: batteryStateLabel(for: reading))
                Divider().frame(height: 44)
                metric(value: String(format: "%.1f°C", reading.temperatureCelsius), label: "Temperature")
                Divider().frame(height: 44)
                metric(value: "\(reading.cycleCount)", label: "Cycles")
            }
            .padding(.vertical, 12)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        } else {
            ProgressView("Reading battery…")
                .frame(maxWidth: .infinity, minHeight: 68)
        }
    }

    private func batteryStateLabel(for reading: BatteryReading) -> String {
        if reading.isCharging { return "Charging" }
        if model.isHolding { return "Held" }
        if reading.isConnected && reading.percentage >= model.targetPercentage { return "Target held" }
        if reading.isConnected { return "Not charging" }
        return "Battery"
    }

    @ViewBuilder
    private var telemetryCard: some View {
        if let reading = model.reading {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("POWER FLOW")
                detailRow(
                    "Adapter input",
                    reading.adapterRatedWatts > 0
                        ? String(format: "%.1f W / %d W", reading.adapterInputWatts, reading.adapterRatedWatts)
                        : String(format: "%.1f W", reading.adapterInputWatts)
                )
                detailRow("System load", String(format: "%.1f W", reading.systemLoadWatts))
                detailRow("Battery flow", batteryFlowText(reading))
                if let estimate = estimatedTimeToTarget(reading) {
                    detailRow("Estimated to \(activeTarget)%", estimate)
                }

                Divider()
                sectionLabel("BATTERY HEALTH")
                detailRow(
                    "Full / design capacity",
                    "\(reading.fullCapacityMilliampHours) / \(reading.designCapacityMilliampHours) mAh"
                )
                detailRow("Health", "\(reading.healthPercentage)%")
                detailRow("Voltage", String(format: "%.2f V", reading.batteryVoltageVolts))
                detailRow("Current", formattedCurrent(reading.batteryCurrentMilliamps))

                Text("Apple battery telemetry; SMC sensor apps can report different power domains and sampling times.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.caption)
    }

    private func batteryFlowText(_ reading: BatteryReading) -> String {
        let power = reading.batteryPowerWatts
        if abs(power) < 0.05 { return "0.0 W · \(reading.isConnected ? "held" : "idle")" }
        return String(format: "%@%.1f W · %@", power > 0 ? "+" : "", power, power > 0 ? "charging" : "discharging")
    }

    private func formattedCurrent(_ milliamps: Int) -> String {
        String(format: "%+.2f A", Double(milliamps) / 1_000)
    }

    private var activeTarget: Int {
        switch model.mode {
        case .override(let target): target
        case .automatic, .thermalHold, .manualHold: model.targetPercentage
        }
    }

    private func estimatedTimeToTarget(_ reading: BatteryReading) -> String? {
        guard
            reading.isCharging,
            reading.batteryCurrentMilliamps > 0,
            reading.fullCapacityMilliampHours > 0,
            reading.currentCapacityMilliampHours > 0
        else { return nil }

        let targetCapacity = Double(reading.fullCapacityMilliampHours) * Double(activeTarget) / 100
        let remaining = max(0, targetCapacity - Double(reading.currentCapacityMilliampHours))
        let minutes = Int(ceil(remaining / Double(reading.batteryCurrentMilliamps) * 60))
        if minutes < 1 { return "<1 min" }
        if minutes < 60 { return "~\(minutes) min" }
        return String(format: "~%d hr %d min", minutes / 60, minutes % 60)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("CHARGING MODE")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                modeButton(
                    title: automaticButtonTitle,
                    subtitle: automaticButtonSubtitle,
                    icon: model.mode.isThermalHold ? "snowflake" : "arrow.triangle.2.circlepath",
                    color: model.mode.isThermalHold ? .cyan : .blue,
                    isActive: model.mode.isAutomaticFamily
                ) {
                    model.resumeAutomatic()
                }

                modeButton(
                    title: "Hold Here",
                    subtitle: "Adapter only",
                    icon: "pause.fill",
                    color: .orange,
                    isActive: model.mode.isManualHold
                ) {
                    model.holdNow()
                }

                modeButton(
                    title: "Charge Now",
                    subtitle: "Ignore heat · \(model.targetPercentage)%",
                    icon: "bolt.fill",
                    color: .pink,
                    isActive: model.mode.isTargetOverride(model.targetPercentage)
                ) {
                    model.chargeNow(to: model.targetPercentage)
                }

                modeButton(
                    title: "Top Up",
                    subtitle: "Ignore heat · 100%",
                    icon: "battery.100percent",
                    color: .purple,
                    isActive: model.mode.isTargetOverride(100)
                ) {
                    model.chargeNow(to: 100)
                }
            }
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("AUTOMATIC CONTROL")

            settingRow(
                icon: "target",
                title: "Charge target",
                subtitle: "Automatic mode stops here"
            ) {
                HStack(spacing: 7) {
                    Text("\(model.targetPercentage)%")
                        .font(.headline.monospacedDigit())
                    Stepper("", value: $model.targetPercentage, in: 50...100, step: 5)
                        .labelsHidden()
                        .fixedSize()
                }
            }
            .onChange(of: model.targetPercentage) { _ in model.targetChanged() }

            settingRow(
                icon: "thermometer.medium",
                title: "Pause temperature",
                subtitle: String(format: "Pause ≥ %.0f°C · resume ≤ %.0f°C", model.temperatureLimit, model.resumeTemperature)
            ) {
                HStack(spacing: 7) {
                    Text(String(format: "%.0f°C", model.temperatureLimit))
                        .font(.headline.monospacedDigit())
                    Stepper("", value: $model.temperatureLimit, in: 30...45, step: 1)
                        .labelsHidden()
                        .fixedSize()
                }
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "shield.checkered")
                    .foregroundStyle(.blue)
                Text(String(
                    format: "At every battery level, cooling holds last at least five minutes and resume after two readings at or below %.0f°C. Overrides ignore only this custom rule; Apple’s hardware protection stays active.",
                    model.resumeTemperature
                ))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(10)
            .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(model.chargeControlReady ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(model.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button(showingSetup ? "Dashboard" : "Setup") {
                showingSetup.toggle()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
    }

    private var backendStepState: SetupStepState {
        switch model.backendSetupState {
        case .checking: .checking
        case .ready: .ready
        case .notInstalled, .daemonUnavailable: .actionRequired
        }
    }

    private var backendStepDetail: String {
        switch model.backendSetupState {
        case .checking:
            "Checking for batt and its daemon."
        case .notInstalled:
            "batt is not installed. CoolCharge can monitor the battery, but cannot control charging yet."
        case .daemonUnavailable:
            "batt is installed, but its privileged daemon is not responding."
        case .ready:
            "batt is installed and its daemon is responding."
        }
    }

    private var appleSettingsStepState: SetupStepState {
        if model.appleChargingPolicyStatus.hasActivePolicy { return .actionRequired }
        if model.appleSettingsConfirmed { return .ready }
        return model.appleChargingPolicyStatus == .unavailable ? .reviewRequired : .actionRequired
    }

    private var appleSettingsStepDetail: String {
        switch model.appleChargingPolicyStatus {
        case .clear:
            if model.appleSettingsConfirmed {
                return "No active Apple charging policy was detected, and you confirmed both controls are off."
            }
            return "No active Apple charging policy was detected. macOS does not reliably expose both switch positions, so please confirm them once."
        case .active(let policyCount):
            return "Detected \(policyCount) active Apple charging \(policyCount == 1 ? "policy" : "policies"). Turn off Apple’s controls, then recheck."
        case .unavailable:
            if model.appleSettingsConfirmed {
                return "macOS did not expose policy status; using your manual confirmation."
            }
            return "CoolCharge could not inspect Apple’s policy status. Open Battery Settings and confirm both controls are off."
        }
    }

    private func setupStep<Actions: View>(
        state: SetupStepState,
        title: String,
        detail: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: state.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(state.color)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                actions()
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(state.color.opacity(0.22), lineWidth: 1)
        }
    }

    private func copySetupCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.backendSetupCommand, forType: .string)
        copiedSetupCommand = true
    }

    private func openBatterySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Battery-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.battery"
        ]
        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) { return }
        }
    }

    private func openURL(_ value: String) {
        guard let url = URL(string: value) else { return }
        NSWorkspace.shared.open(url)
    }

    private func finishSetup() {
        hasCompletedWelcome = true
        showingSetup = false
    }

    private var automaticButtonTitle: String {
        model.mode.isThermalHold ? "Cooling" : "Automatic"
    }

    private var automaticButtonSubtitle: String {
        if model.mode.isThermalHold {
            return String(format: "Resume ≤ %.0f°C", model.resumeTemperature)
        }
        return "Heat-aware · \(model.targetPercentage)%"
    }

    private func modeButton(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.headline)
                    Spacer()
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                    }
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .padding(11)
            .foregroundStyle(isActive ? color : .primary)
            .background(
                isActive ? color.opacity(0.18) : Color.secondary.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 11)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .stroke(isActive ? color.opacity(0.8) : Color.secondary.opacity(0.12), lineWidth: isActive ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(!model.chargeControlReady || model.reading == nil || model.isCommandPending)
        .opacity((!model.chargeControlReady || model.reading == nil || model.isCommandPending) ? 0.5 : 1)
    }

    private func settingRow<Accessory: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            accessory()
        }
        .padding(11)
        .background(.quaternary.opacity(0.38), in: RoundedRectangle(cornerRadius: 11))
    }
}

private enum SetupStepState {
    case checking
    case ready
    case actionRequired
    case reviewRequired

    var symbol: String {
        switch self {
        case .checking: "clock"
        case .ready: "checkmark.circle.fill"
        case .actionRequired: "exclamationmark.circle.fill"
        case .reviewRequired: "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .checking: .secondary
        case .ready: .green
        case .actionRequired: .orange
        case .reviewRequired: .blue
        }
    }
}

private struct MenuBarBatteryIcon: View {
    let level: Double
    let badgeSymbol: String?

    private var fillWidth: CGFloat {
        let usableWidth: CGFloat = 17
        guard level > 0 else { return 0 }
        return max(1.5, usableWidth * level)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2.2)
                .strokeBorder(.primary.opacity(0.9), lineWidth: 1.2)
                .frame(width: 21, height: 10)

            RoundedRectangle(cornerRadius: 1.2)
                .fill(.primary.opacity(0.9))
                .frame(width: fillWidth, height: 6)
                .offset(x: 2)

            Capsule()
                .fill(.primary.opacity(0.75))
                .frame(width: 2, height: 5)
                .offset(x: 22)

            if let badgeSymbol {
                ZStack {
                    Circle()
                        .fill(.background)
                        .frame(width: 9, height: 9)
                    Image(systemName: badgeSymbol)
                        .font(.system(size: 5.5, weight: .bold))
                        .foregroundStyle(.primary)
                }
                .frame(width: 21, height: 10)
            }
        }
        .frame(width: 25, height: 12)
    }
}

private extension ControlMode {
    var isThermalHold: Bool {
        if case .thermalHold = self { return true }
        return false
    }

    var isAutomaticFamily: Bool {
        switch self {
        case .automatic, .thermalHold: true
        case .manualHold, .override: false
        }
    }

    var isManualHold: Bool {
        if case .manualHold = self { return true }
        return false
    }

    func isTargetOverride(_ target: Int) -> Bool {
        if case .override(let currentTarget) = self {
            return currentTarget == target
        }
        return false
    }
}
