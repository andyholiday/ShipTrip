//
//  ShipTripWidgetBundle.swift
//  ShipTripWidget
//
//  Einstiegspunkt der WidgetKit-Extension (Taskplan 1.9.0, LE 1). Haelt
//  bewusst nur die Bundle-Deklaration — die Widgets selbst liegen daneben.
//

import SwiftUI
import WidgetKit

@main
struct ShipTripWidgetBundle: WidgetBundle {

    var body: some Widget {
        ShipTripWidget()
    }
}
