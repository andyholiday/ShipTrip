//
//  WidgetSnapshotPublishing.swift
//  ShipTrip
//
//  Naht zwischen App-Mutationen und dem Widget-Snapshot
//  (Taskplan 1.9.0, Leitentscheidung 6). Nur das Protokoll — die
//  Implementierung `WidgetSnapshotPublisher` liegt auf der App-Seite unter
//  `ShipTrip/Services/`, Tests setzen einen Spy ein.
//

import Foundation

/// Loest das Neuschreiben des Widget-Snapshots aus.
///
/// Aufrufer muessen nichts ueber Koaleszierung, Dateipfade oder
/// `WidgetCenter` wissen: `publish()` ist ein Hinweis, kein Auftrag. Die
/// Implementierung entprellt die Aufrufe, veroeffentlicht ausschliesslich den
/// bereits persistierten Ist-Stand und schluckt Fehler (protokolliert sie),
/// statt sie zu werfen — ein misslungener Snapshot darf keinen Speichervorgang
/// der App scheitern lassen.
protocol WidgetSnapshotPublishing: Sendable {
    func publish()
}
