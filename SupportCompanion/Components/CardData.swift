//
//  CardData.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-15.
//

import Foundation
import SwiftUI

struct CardData: View {
    @Environment(\.colorScheme) var colorScheme
    let info: [(key: String, display: String, value: InfoValue)]
    let customContent: (String, InfoValue) -> AnyView

    init(
        info: [(key: String, display: String, value: InfoValue)],
        customContent: @escaping (String, InfoValue) -> AnyView = { _, _ in AnyView(EmptyView()) }
    ) {
        self.info = info
        self.customContent = customContent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(info, id: \.key) { key, display, value in
                VStack(alignment: .leading, spacing: 5) {
                    // Display the key-value pair with formatting based on the key
                    defaultContent(for: key, display: display, value: value)
                    
                    // Insert custom content for specific labels
                    customContent(key, value)
                }
            }
        }
    }

    /// Provides the default content for a key-value pair
    private func defaultContent(for key: String, display: String, value: InfoValue) -> some View {
        HStack(alignment: .top) {
            Text(display)
                .fontWeight(.bold)
                .font(.system(size: 14))

            switch key {
            case Constants.Battery.Keys.health:
                healthContent(value: value)
            case Constants.DeviceInfo.Keys.lastRestart:
                daysContent(value: value, suffix: " \(Constants.General.days)")
            case "FileVault":
                fileVaultContent(value: value)
            case Constants.KerberosSSO.Keys.expiryDays:
                daysContent(value: value, suffix: " \(Constants.General.days)", color: colorForValue(key: key, value: value))
            case Constants.KerberosSSO.Keys.lastSSOPasswordChangeDays,
                 Constants.KerberosSSO.Keys.lastLocalPasswordChangeDays:
                daysContent(value: value, suffix: " \(Constants.General.daysAgo)")
            case Constants.Battery.Keys.temperature:
                temperatureContent(value: value)
            case Constants.PlatformSSO.Keys.registrationCompleted:
                pssoRegistrationContent(value: value)
            default:
                defaultText(value: value, key: key)
            }
        }
    }

    /// Displays health-specific content with color coding
    private func healthContent(value: InfoValue) -> some View {
        let color = colorForValue(key: Constants.Battery.Keys.health, value: value)
        let isGreen = color == .green
        
        return Group {
            Text(value.displayValue)
                .foregroundColor(color)
                .font(.system(size: 14))
                .shadow(color: isGreen ? .black.opacity(0.4) : .clear, radius: 1, x: 0, y: 1)
            Text("%")
                .font(.system(size: 14))
        }
    }
    
    private func temperatureContent(value: InfoValue) -> some View {
        let color = colorForValue(key: Constants.Battery.Keys.temperature, value: value)
        let isGreen = color == .green
        
        return Group {
            Text(value.displayValue)
                .foregroundColor(color)
                .font(.system(size: 14))
                .shadow(color: isGreen ? .black.opacity(0.4) : .clear, radius: 1, x: 0, y: 1)
            Text("°C")
                .font(.system(size: 14))
        }
    }

    /// Displays generic content with a suffix (e.g., "days")
    private func daysContent(value: InfoValue, suffix: String, color: Color = .primary) -> some View {
        Text(value.displayValue)
            .foregroundColor(color)
            .font(.system(size: 14))
        + Text(suffix)
            .font(.system(size: 14))
    }
    
    private func pssoRegistrationContent(value: InfoValue) -> some View {
        let color = colorForValue(key: Constants.PlatformSSO.Keys.registrationCompleted, value: value)
        let isGreen = color == .green
        
        return Text(value.displayValue)
            .foregroundColor(colorForValue(key: Constants.PlatformSSO.Keys.registrationCompleted, value: value))
            .font(.system(size: 14))
            .shadow(color: isGreen ? .black.opacity(0.4) : .clear, radius: 1, x: 0, y: 1)
    }

    /// Displays FileVault-specific content with icons
    private func fileVaultContent(value: InfoValue) -> some View {
        HStack {
            if value.displayValue == "Enabled" {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor((colorScheme == .light ? .redLight : .red))
            }
            Text(value.displayValue)
                .font(.system(size: 14))
        }
    }

    /// Displays default text with optional coloring
    private func defaultText(value: InfoValue, key: String) -> some View {
        Text(value.displayValue)
            .font(.system(size: 14))
            .foregroundColor(colorForValue(key: key, value: value))
    }

    /// Determines the color for specific values.
    private func colorForValue(key: String, value: InfoValue) -> Color {
        switch key {
        case "Health":
            if let intValue = value.rawValue as? Int {
                return intValue <= 30
                    ? (colorScheme == .light ? .redLight : .red)
                    : (intValue < 80
                        ? (colorScheme == .light ? .orangeLight : .orange)
                       : .green)
            }
        case "LastRestart":
            if let intValue = value.rawValue as? Int {
                return intValue > 7 ? (colorScheme == .light ? .redLight : .red) : .green
            }
        case "FileVault":
            if let boolValue = value.rawValue as? Bool {
                return !boolValue ? (colorScheme == .light ? .redLight : .red) : .green
            }
        case Constants.PlatformSSO.Keys.registrationCompleted:
            if let boolValue = value.rawValue as? Bool {
                return !boolValue ? (colorScheme == .light ? .redLight : .red) : .green
            }
        case Constants.KerberosSSO.Keys.expiryDays:
            if let intValue = value.rawValue as? Int {
                return intValue <= 30 ? (colorScheme == .light ? .orangeLight : .orange) : (intValue < 2 ? (colorScheme == .light ? .redLight : .red) : .green)
            }
        case Constants.Battery.Keys.temperature:
            if let doubleValue = value.rawValue as? Double {
                return doubleValue > 80 ? (colorScheme == .light ? .redLight : .red) : (doubleValue >= 60 ? (colorScheme == .light ? .orange : .orange) : .green)
            } else if let intValue = value.rawValue as? Int {
                let temperature = Double(intValue)
                return temperature > 80 ? (colorScheme == .light ? .redLight : .red) : (temperature >= 60 ? (colorScheme == .light ? .orangeLight : .orange) : .green)
            } else {
                return .primary
            }
        default:
            return .primary
        }
        return .primary
    }
    
    struct ConditionalShadowModifier: ViewModifier {
        let isGreen: Bool

        func body(content: Content) -> some View {
            content
                .shadow(color: isGreen ? .black.opacity(0.4) : .clear, radius: 2, x: 0, y: 1)
        }
    }
}
