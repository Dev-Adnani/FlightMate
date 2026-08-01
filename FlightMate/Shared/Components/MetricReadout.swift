//
//  MetricReadout.swift
//  FlightMate
//
//  Compact labeled instrument value used on dashboard telemetry cards.
//

import SwiftUI

/// A small instrument-style metric: caption label + monospaced value.
struct MetricReadout: View {
    let label: String
    let value: String
    var systemImage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.Colors.accent)
                        .symbolRenderingMode(.hierarchical)
                }
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(Theme.Typography.metric)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: Theme.Layout.controlCornerRadius, style: .continuous)
                .fill(Theme.Colors.iconWellFill)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack {
        MetricReadout(label: "Altitude", value: "32,000 ft", systemImage: "arrow.up.to.line")
        MetricReadout(label: "Speed", value: "450 kt", systemImage: "gauge.with.needle")
    }
    .padding()
}
