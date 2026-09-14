//
//  ProtoData.swift
//  Fixierter Content-Payload — deterministisch, keine Uhr, kein Zufall, kein Netz.
//  Datums-Strings sind bewusst hartkodiert (locale-unabhängig reproduzierbar).
//
//  Reise: „Westliches Mittelmeer", 7 Tage, Mo 09.06.2025 – So 15.06.2025.
//

import SwiftUI

// MARK: - Stimmung (Rohwerte nach Journal-Editor-Contract J4)

enum ProtoMood: String, CaseIterable, Identifiable {
    case great, good, okay, bad, awful
    case unset = ""

    var id: String { rawValue }

    var label: String {
        switch self {
        case .great: return "Großartig"
        case .good:  return "Gut"
        case .okay:  return "Okay"
        case .bad:   return "Nicht so gut"
        case .awful: return "Schlecht"
        case .unset: return "Keine"
        }
    }

    /// Bewusst kein Emoji (Design-Entscheidung, Contract J4 lässt die Darstellung offen):
    /// ein Farbpunkt der Stimmungs-Rampe trägt die Skala, das Wort trägt die Bedeutung.
    var color: Color {
        switch self {
        case .great: return Proto.seaGreen
        case .good:  return Proto.oceanLight
        case .okay:  return Proto.moodNeutral
        case .bad:   return Proto.sunsetOrange
        case .awful: return Proto.moodAwful
        case .unset: return Proto.moodNeutral
        }
    }
}

// MARK: - Pin-Typ (Idiom aus ShipTrip/Components/PortPinView.swift)

enum ProtoPinType {
    case port, homePort, endPort, seaDay

    var icon: String {
        switch self {
        case .port, .homePort: return "mappin.circle.fill"
        case .endPort:         return "mappin.and.ellipse.circle.fill"
        case .seaDay:          return "water.waves"
        }
    }

    /// Die Hafen-Symbole tragen den gefüllten Kreis schon in sich, `water.waves`
    /// nicht — für den Seetag baut `ProtoDayBadge` ihn.
    var needsBadgeCircle: Bool { self == .seaDay }

    var color: Color {
        switch self {
        case .port:     return Proto.portPin
        case .homePort: return Proto.homePortPin
        case .endPort:  return Proto.endPortPin
        case .seaDay:   return Proto.seaDayPin
        }
    }
}

// MARK: - Payload-Typen

struct ProtoPhoto: Identifiable {
    let id: Int
    let asset: String
    let caption: String
}

struct ProtoEntry: Identifiable {
    let id: Int
    let mood: ProtoMood
    let text: String
    var photos: [ProtoPhoto] = []

    /// Zeichenbudget der eingeklappten Fassung. Acht Zeilen Fliesstext
    /// (callout, Flattersatz) fassen in der 282 pt breiten Inhaltsspalte rund
    /// 280 Zeichen — nachgemessen an der Runde-2-Aufnahme: dort standen bei
    /// 336 pt Spaltenbreite im Schnitt 42 Zeichen je Zeile, also knapp 8 pt je
    /// Zeichen. 250 liegt sicher darunter, damit die Kürzung *immer* an der
    /// Wortgrenze unten passiert und nie an SwiftUIs `.tail`, das mitten im
    /// Wort kappt (Runde 2: „außer zu schauen, w…").
    ///
    /// Der feste Payload hat keinen Eintrag zwischen 123 und 313 Zeichen — die
    /// Schwelle trennt hier also eindeutig.
    static let collapsedBudget = 250

    var isTruncated: Bool { text.count > Self.collapsedBudget }

    /// Die im Strang sichtbare Fassung: bis zur letzten Wortgrenze vor dem
    /// Budget, ohne hängendes Satzzeichen, mit echter Ellipse.
    var collapsedText: String {
        guard isTruncated else { return text }
        let head = text.prefix(Self.collapsedBudget)
        guard let lastSpace = head.lastIndex(of: " ") else { return text }
        var cut = head[head.startIndex..<lastSpace]
        while let last = cut.last, last.isPunctuation || last.isWhitespace {
            cut = cut.dropLast()
        }
        return String(cut) + " …"
    }
}

struct ProtoDay: Identifiable {
    let id: Int          // Reisetag-Nummer
    let dateLine: String // „MI, 11. JUNI"
    let title: String
    let subtitle: String?
    let pin: ProtoPinType
    var entries: [ProtoEntry] = []

    var isEmpty: Bool { entries.isEmpty }
}

// MARK: - Die Reise

enum ProtoTrip {
    static let title = "Westliches Mittelmeer"
    static let entryCount = 9

    static let days: [ProtoDay] = [
        // Tag 1 — Barcelona, Einschiffung
        ProtoDay(
            id: 1, dateLine: "MO, 9. JUNI", title: "Barcelona",
            subtitle: "Einschiffung", pin: .homePort,
            entries: [
                ProtoEntry(
                    id: 101, mood: .good,
                    text: "Koffer an Bord, die Kabine riecht nach neuem Teppich. Wir haben es tatsächlich geschafft.",
                    photos: [
                        ProtoPhoto(id: 1, asset: "foto_ablegen",
                                   caption: "Ablegen bei Sonnenuntergang")
                    ])
            ]),

        // Tag 2 — Palma
        ProtoDay(
            id: 2, dateLine: "DI, 10. JUNI", title: "Palma de Mallorca",
            subtitle: "Spanien", pin: .port,
            entries: [
                ProtoEntry(
                    id: 201, mood: .great,
                    text: "Früh raus, weil das Schiff schon um sieben festgemacht hat. Zu Fuß durch die Altstadt bis zur Kathedrale, danach Kaffee an der Promenade, wo Silke behauptet hat, sie könne von dort den Schornstein unseres Schiffs sehen. Konnte sie nicht. Am späten Nachmittag noch einmal zurück an den Hafen, nur wegen des Lichts.",
                    photos: [
                        ProtoPhoto(id: 2, asset: "foto_kathedrale",
                                   caption: "Kathedrale La Seu im Abendlicht"),
                        ProtoPhoto(id: 3, asset: "foto_marina", caption: "")
                    ])
            ]),

        // Tag 3 — Seetag, HÄRTEFALL: drei Einträge
        ProtoDay(
            id: 3, dateLine: "MI, 11. JUNI", title: "Seetag",
            subtitle: nil, pin: .seaDay,
            entries: [
                ProtoEntry(
                    id: 301, mood: .great,
                    text: "Der erste richtige Seetag, und ich verstehe endlich, warum Leute deswegen buchen. Um kurz nach sechs war ich als Einziger an der Reling, das Wasser noch grau und der Wind kalt genug für die Jacke. Zwei Stunden später lag dieselbe Fläche türkis da und war nicht wiederzuerkennen. Wir haben den halben Vormittag nichts getan außer zu schauen, was sich anfühlt wie eine Fähigkeit, die man erst wieder lernen muss. Mittags Paella am Pooldeck, danach eine Runde Schlaf im Liegestuhl, ohne schlechtes Gewissen. Gegen fünf zog eine Wolkenbank auf, die von Weitem aussah wie eine Küste, und wir haben ernsthaft zehn Minuten diskutiert, welche Insel das sein könnte. Es war keine.",
                    photos: [
                        // Captions kurz genug, dass sie unter einer 90-pt-Kachel
                        // in zwei Zeilen am Wortende umbrechen statt zu kappen.
                        ProtoPhoto(id: 4, asset: "foto_deck",
                                   caption: "Sechs Uhr, allein"),
                        ProtoPhoto(id: 5, asset: "foto_horizont",
                                   caption: "Ein anderes Schiff"),
                        ProtoPhoto(id: 6, asset: "foto_wasser",
                                   caption: "Türkis, sonst nichts")
                    ]),
                ProtoEntry(
                    id: 302, mood: .okay,
                    text: "Nachmittags frischte der Wind auf, die Liegestühle am Heck haben wir geräumt. Drinnen war es voll.",
                    photos: [
                        ProtoPhoto(id: 7, asset: "foto_bucht", caption: ""),
                        ProtoPhoto(id: 8, asset: "foto_morgenlicht", caption: "")
                    ]),
                ProtoEntry(
                    id: 303, mood: .bad,
                    text: "Nachts kaum geschlafen. Die Klimaanlage rattert, und den Techniker erreiche ich frühestens morgen früh.")
            ]),

        // Tag 4 — Neapel, nur Text
        ProtoDay(
            id: 4, dateLine: "DO, 12. JUNI", title: "Neapel",
            subtitle: "Italien", pin: .port,
            entries: [
                ProtoEntry(
                    id: 401, mood: .awful,
                    text: "Neapel im Regen, der Ausflug nach Pompeji fiel aus, und die Erstattung soll drei Wochen dauern. Wir sind an Bord geblieben.")
            ]),

        // Tag 5 — Civitavecchia, KEIN Eintrag
        ProtoDay(
            id: 5, dateLine: "FR, 13. JUNI", title: "Civitavecchia",
            subtitle: "Rom", pin: .port, entries: []),

        // Tag 6 — Cannes, zwei Einträge
        ProtoDay(
            id: 6, dateLine: "SA, 14. JUNI", title: "Cannes",
            subtitle: "Frankreich", pin: .port,
            entries: [
                ProtoEntry(
                    id: 601, mood: .good,
                    text: "Tenderboot um neun, Croissant an der Uferstraße, danach drei Stunden nur bummeln.",
                    photos: [
                        ProtoPhoto(id: 9, asset: "foto_promenade",
                                   caption: "Die Croisette am Abend")
                    ]),
                ProtoEntry(
                    id: 602, mood: .okay,
                    text: "Zurück an Bord war die Schlange am Tender länger als der Ausflug selbst.",
                    photos: [
                        ProtoPhoto(id: 10, asset: "foto_altstadt", caption: "")
                    ])
            ]),

        // Tag 7 — Barcelona, Ausschiffung
        ProtoDay(
            id: 7, dateLine: "SO, 15. JUNI", title: "Barcelona",
            subtitle: "Ausschiffung", pin: .endPort,
            entries: [
                ProtoEntry(
                    id: 701, mood: .good,
                    text: "Letzter Kaffee auf dem Balkon, während der Hafen langsam näher kommt. Nächstes Jahr wieder.")
            ])
    ]
}

// MARK: - Editor-Vorbelegung (Schritt 1 gefüllt, Schritt 2 auf Tag 3 / Seetag)

enum ProtoEditorState {
    static let text = """
    Erster richtiger Seetag. Um kurz nach sechs war ich als Einziger an der \
    Reling, das Wasser noch grau und der Wind kalt genug für die Jacke. Zwei \
    Stunden später lag dieselbe Fläche türkis da. Wir haben den halben \
    Vormittag nichts getan außer zu schauen.
    """

    /// Foto 2 ist gerade in der Caption-Eingabe (Cursor sichtbar).
    /// Gleiche Captions wie Eintrag 301 im Strang — einzeilig im 245-pt-Feld.
    static let photos: [ProtoPhoto] = [
        ProtoPhoto(id: 4, asset: "foto_deck", caption: "Sechs Uhr, allein"),
        ProtoPhoto(id: 5, asset: "foto_horizont", caption: "Ein anderes Schiff"),
        ProtoPhoto(id: 6, asset: "foto_wasser", caption: "")
    ]
    static let editingPhotoID = 5

    /// Ohne Jahr — die Zeile traegt sonst nicht in die verfuegbare Wertspalte.
    static let dayValue = "Tag 3 · Mi, 11. Juni"
    static let portValue = "Kein Hafen · Seetag"
    static let selectedMood: ProtoMood = .unset
}
