# Review — T4/D2: CruiseFormView aufspalten, Hafen-Momente-Duplikat zusammenführen

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (frischer Spawn, BUILD-TOKEN)
- **Datum**: 2026-08-27
- **Diff**: `release/1.8.5..7f6e1c1` (Worktree `ShipTrip-worktrees/t4-formview-split`)
- **Verdikt**: approve (GO)
- **Stats**: critical: 0, major: 1, minor: 1 — Blocker: 0, ins Backlog: 2

## Summary

Der Diff ist tatsächlich reines Verschieben/Deduplizieren. Beide Kernbehauptungen
des Developers wurden mechanisch nachgeprüft und halten: (a) die "Hafen-Momente"-Section
lag byte-identisch zweimal im Code (alt `CruiseFormView.swift:1212-1411` vs.
`PortFormView.swift:325-524` — `diff` liefert 0 Unterschiede), (b) der verschobene
Code ist bis auf die drei angekündigten Abweichungen wortgleich (normalisierter
Diff alter Entfernungsbereich vs. neue Dateien zeigt ausschließlich die deklarierten
Struktur-Änderungen). Sheet-Aufrufstellen in `CruiseFormView` sind unverändert.
Build und change-scoped Testrunde grün: 416/416, Unit- und UI-Bundle.

Ein nicht-blockierender Befund bleibt: die Platzierung des `onChange` auf der
`Section` statt am Host (F01).

## Testumfang (Refactor-Klasse der Leiter)

Refactor = berührte Suite vorher/nachher. Gefahren wurde die volle Unit-Suite
`ShipTripTests` **plus** die zwei UI-Klassen, die genau den verschobenen State
anfassen (`AusflugLoeschenUITests`, `PortMemoryCardUITests`). Begründung für die
Ausweitung über Unit hinaus: das einzige echte Verhaltensrisiko dieses Diffs ist
die View-Identität/State-Lebensdauer der ausgelagerten Section — für Unit-Tests
unsichtbar, für diese UI-Tests direkt beobachtbar. Keine neuen Tests verlangt.

- Projekt-Kanon eingehalten: `build-for-testing` + `test-without-building`
  (kein `xcodebuild test -scheme`).
- Wegwerf-Simulator per `simctl create` + `bootstatus -b` + trap-Cleanup;
  Kalender-Privacy vorab granted.
- **Ergebnis**: build exit 0, tests exit 0 — 416 Tests, 416 passed, 0 failed,
  0 skipped. `ShipTripTests` [Passed], `ShipTripUITests` [Passed].
- **evidence_path**:
  `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/t4-formview-split/.winston-evidence/20260827T071509Z/gate-run.json`
  (`status: verified`, `status_claim: runtime-verifiziert`, Xcode 26.6)

## Prüfung der drei angekündigten Abweichungen

1. **`FeedbackStatus` in `AIImportSheet` verschachtelt** — trägt. `SettingsView.swift:572`
   hat einen eigenen `private enum FeedbackStatus`; die Verschachtelung vermeidet die
   Modulebenen-Mehrdeutigkeit sauber. Aufrufstelle `CruiseFormView.swift:174` zieht
   korrekt auf `AIImportSheet.FeedbackStatus?` nach, Sheet-Konstruktion unverändert.
   `@Binding fileprivate` → `@Binding` (internal) ist die zwingende Folge der
   Datei-Trennung, kein zusätzlicher Sichtbarkeits-Overreach.
2. **`ReminderPermissionSheet` von `private` auf internal** — trägt. Ohne Alternative
   bei Datei-Trennung; keine Namenskollision im Modul (nur Doku-Erwähnungen).
3. **`HafenMomenteSection` hält `selectedPhotoItem` + `onChange` selbst** —
   State-Lebensdauer ist unkritisch: die Section steht in beiden Hosts unbedingt und
   an fester Position im `Form`-Body, hat damit stabile strukturelle Identität; der
   `@State` überlebt Re-Renders des Hosts genau wie vorher. Empirisch gestützt durch
   die vier grünen UI-Tests, die Löschen, Reorder-Affordance und Zero-State über
   mehrere Interaktionen hinweg durchspielen. Die *Platzierung* des `onChange` ist
   dagegen ein Befund → F01.

## Findings

| ID  | Severity | Blocker | File:Line                                        | Kategorie   | Titel                                            |
|-----|----------|---------|--------------------------------------------------|-------------|--------------------------------------------------|
| F01 | major    | nein    | `ShipTrip/Views/Cruises/HafenMomenteSection.swift:44-46` | performance | `onChange` auf der `Section` statt auf einer Zeile |
| F02 | minor    | nein    | `ShipTrip/Views/Onboarding/OnboardingCards.swift:147`    | docs        | Stale Referenz `CruiseFormView.ReminderPermissionSheet` |

### F01 — `onChange` auf der `Section` statt auf einer Zeile

- **File**: `ShipTrip/Views/Cruises/HafenMomenteSection.swift:44-46`
- **Severity**: major · **Blocker**: nein
- **Problem**: Vorher hing `.onChange(of: selectedPhotoItem)` am `NavigationStack`
  des Hosts — genau eine Instanz. Jetzt hängt es an der `Section` innerhalb des
  `Form`. SwiftUI reicht View-Modifier auf Zeilen-Containern an *jede* enthaltene
  Zeile durch (für `Group`/`GridRow` explizit dokumentiert: „applying a view modifier
  to a GridRow causes the modifier to be applied to all individual cells"). Damit
  startet eine Foto-Auswahl voraussichtlich einen `loadTransferable`-Task **pro
  Zeile** (4 feste Zeilen + eine je Ausflug) statt einen — bei einem Vollformat-Foto
  N-facher Decode und N-facher Speicherpeak. Korrektheit bleibt unberührt (alle Tasks
  schreiben dieselben `Data`), deshalb kein Blocker.
- **Verifikationsstand — ehrlich**: nicht zur Laufzeit belegt. Der Picker-Pfad hat
  keine UI-Test-Abdeckung (Photos-Permission + System-Picker), und Apple dokumentiert
  die Durchreichung für `Section` nicht wörtlich. Der Befund ist eine begründete
  Hypothese, kein Messwert.
- **Fix**: `.onChange` von der `Section` auf `coverPhotoTile` ziehen — das ist
  unbedingt genau eine Zeile (if/else liefert beide Male einen Row), damit garantiert
  genau eine Instanz:
  ```swift
  Section(String(localized: "Hafen-Momente")) {
      coverPhotoTile
          .onChange(of: selectedPhotoItem) { _, newItem in loadImage(from: newItem) }
      excursionChipScroller
      ...
  }
  ```

### F02 — Stale Doku-Referenz

- **File**: `ShipTrip/Views/Onboarding/OnboardingCards.swift:147`
- **Severity**: minor · **Blocker**: nein
- **Problem**: Doc-Kommentar verweist auf `CruiseFormView.ReminderPermissionSheet`;
  der Typ liegt nach D2 als Top-Level-Typ in `ReminderPermissionSheet.swift`.
- **Fix**: Referenz auf `ReminderPermissionSheet` kürzen.

## Statischer Pass (`guard.py sizes`)

`ShipTrip/Views/Cruises/CruiseFormView.swift`: 950 Zeilen (> 500 hart), exit 1.
**Kein neuer Befund**: vorbestehend, durch D2 von 1538 auf 950 verbessert; der
Taskplan-Eintrag T4 nennt kein Zeilenziel. Der Developer hat den Rest bereits
selbst unter `.planning/BACKLOG.md:166` eingetragen — dort allerdings als `[minor]`.
Nach der Severity-Tabelle ist ein Hard-Limit-Überschreiter `major`; die Zeile sollte
entsprechend korrigiert werden. Weiterhin kein Blocker.

## Nicht geprüft (Trigger nicht ausgelöst)

- **GDPR**: keine berührte Datenverarbeitung — der Diff verschiebt Views, ändert
  keinen Datenfluss. Der bestehende Gemini-Übertragungshinweis in `AIImportSheet`
  ist wortgleich mitgewandert.
- **Security**: keine berührte Angriffsfläche.

## Verdikt

**GO.** Keine offenen Blocker. F01 und F02 gehen ins Backlog.
