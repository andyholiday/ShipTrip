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

    /// Nummer des zuletzt angenommenen Auftrags.
    private var lastAccepted: UInt64 = 0

    init(store: WidgetSnapshotStore) {
        self.store = store
    }

    /// Schreibt den Snapshot. Wirft weiter, damit der Aufrufer entscheidet,
    /// wie er den Fehler behandelt — die App protokolliert ihn nur.
    ///
    /// Auftraege mit kleinerer `generation` als der zuletzt angenommene sind
    /// von einem neueren ueberholt worden; sie werden verworfen, statt den
    /// frischeren Stand auf der Platte zu ueberschreiben. Der Aktor
    /// serialisiert, die Reihenfolge der Ankunft entscheidet also nicht.
    func save(_ snapshot: WidgetSnapshot, generation: UInt64) throws {
        guard generation >= lastAccepted else { return }
        lastAccepted = generation
        try store.save(snapshot)
    }
}
