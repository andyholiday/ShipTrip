# App Store Connect release configuration

- Version: 1.7.0
- Build: 23
- Platform: iOS, iPhone only
- Primary category: Travel
- Secondary category: Lifestyle
- Distribution method: Public
- Availability: All App Store countries and regions
- Base country or region: Germany
- Base price: EUR 0.99
- Other storefronts: Apple automatically generated equivalent prices
- Pre-order: No
- Release option: Automatically release after App Review approval
- Localizations: German (Germany), English (U.S.)
- Required screenshot display: iPhone 6.9-inch, 1320 x 2868 portrait
- App preview: 886 x 1920 portrait, H.264, 30 fps, 15-30 seconds, maximum 500 MB

## Verified release checks

- Localized privacy policies are live and the `de-DE`/`en-US` App Store privacy URLs are verified.
- Build 23 is present in App Store Connect with `processingState=VALID` and selected for version 1.7.0.
- The CloudKit schema was promoted to Production on 2026-08-08. The Production export contains all eight ShipTrip record types and semantically matches the Development schema.
- Functional suite passed serially on 2026-08-06: 319 passed, 0 failed, 1 skipped. The nine audit-only screenshot exporters remain excluded because they contain an obsolete absolute `/Users/andreja/...` output path and would overwrite local audit evidence.
- Release simulator build passed on 2026-08-06 with two existing warnings; the selected App Store Connect build is `VALID`.
- Age rating stays at 4+ (decision by Andre, 2026-08-23). The AI trip capture stays inactive until the user enters their own Gemini API key from Google AI Studio in Settings, so the 18+ requirement of the Gemini API terms binds the key holder and not the App Store audience. No age rating question is answered differently because of it.

## Remaining blocking checks before submission

- Confirm the latest Paid Apps Agreement is active.
- Complete and publish the current App Privacy questionnaire so it matches private iCloud/CloudKit sync, optional Calendar access, Photos, and optional Gemini transmission.
- Resolve the Gemini API EEA Paid Services requirement before submission. The age requirement is settled; see the age rating entry above.
