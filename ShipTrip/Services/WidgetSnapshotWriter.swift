//
//  WidgetSnapshotWriter.swift
//  ShipTrip
//
//  Serialisiert alle Schreibzugriffe auf die Snapshot-Datei im
//  App-Group-Container (Taskplan 1.9.0, Leitentscheidung 3/6).
//
//  `WidgetSnapshotStore.save(_:)` schreibt atomar, aber zwei gleichzeitige
//  Writes wuerden sich trotzdem ueberholen koennen. Der Aktor macht daraus
//  eine Warteschlange: der letzte Schreiber gewinnt, nie eine Mischung.
//

import Foundation

/// Einziger Schreibweg der App auf `widget-snapshot.json`.
actor WidgetSnapshotWriter {

    private let store: WidgetSnapshotStore

    init(store: WidgetSnapshotStore) {
        self.store = store
    }

    /// Schreibt den Snapshot. Wirft weiter, damit der Aufrufer entscheidet,
    /// wie er den Fehler behandelt — die App protokolliert ihn nur.
    ///
    /// `generation` ist die Naht fuer Fix 3: veraltete Auftraege verwirft
    /// diese Fassung noch nicht.
    func save(_ snapshot: WidgetSnapshot, generation: UInt64) throws {
        try store.save(snapshot)
    }
}
