//
//  UTType+ShipTrip.swift
//  ShipTrip
//
//  Eigener Dokumenttyp der App: die `.shiptrip`-Datei einer geteilten Kreuzfahrt.
//  Die zugehoerige Deklaration (UTExportedTypeDeclarations, CFBundleDocumentTypes)
//  steht in `ShipTrip-Info.plist` — siehe ADR-007 / Contract C2.
//

import UniformTypeIdentifiers

extension UTType {
    /// Geteilte Kreuzfahrt (`.shiptrip`). Konformiert bewusst nur zu `public.data`
    /// und nicht zu `com.pkware.zip-archive`, damit ZIP-Handler den Doppeltipp nicht
    /// beanspruchen (Contract C2).
    static let shipTripCruise = UTType(exportedAs: "com.andre.shiptrip.cruise")
}
