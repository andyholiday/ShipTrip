//
//  ShipTripWidgetEntryView.swift
//  ShipTripWidget
//
//  Verteilt einen Eintrag auf die vier unterstuetzten Familien und setzt den
//  Container-Hintergrund. Die Familien-Ansichten selbst kennen weder
//  `WidgetFamily` noch den Hintergrund.
//

import SwiftUI
import WidgetKit

struct ShipTripWidgetEntryView: View {

    @Environment(\.widgetFamily) private var family

    let entry: ShipTripWidgetEntry

    var body: some View {
        content
            .containerBackground(background, for: .widget)
    }

    // MARK: - Familien

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(state: entry.state)
        case .accessoryRectangular:
            RectangularWidgetView(state: entry.state)
        case .accessoryCircular:
            CircularWidgetView(state: entry.state)
        default:
            SmallWidgetView(state: entry.state)
        }
    }

    /// Auf dem Sperrbildschirm liefert das System den Hintergrund; dort bleibt
    /// der Container durchsichtig.
    private var background: AnyShapeStyle {
        switch family {
        case .accessoryRectangular, .accessoryCircular:
            return AnyShapeStyle(Color.clear)
        default:
            return AnyShapeStyle(WidgetStyle.surface)
        }
    }
}
