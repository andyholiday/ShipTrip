# Render-Weg — Screenshot „Widgets" (1.9.0)

`template-widgets.html` rendert genau den neuen Shot, je Locale über `?lang=de|en`.
Raster, Tonwerte und Typo sind aus `../../release-1.7.0/app-store-v2/template.html`
übernommen. Die Widget-Kacheln in `assets/` sind echte Galerie-Renderings — DE aus
`docs/design/directions/shots/dynamic/`, EN aus einem Harness-Lauf; das Mittelformat
ist auf seine Inhaltskante `1092x510` beschnitten.

```bash
cd marketing/release-1.9.0/app-store-v2
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
for L in de en; do
  "$CHROME" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --default-background-color=FF0B1622 --window-size=1320,2868 \
    --screenshot="output/raw-$L.png" --virtual-time-budget=4000 \
    "file://$PWD/template-widgets.html?lang=$L"
  ffmpeg -y -i "output/raw-$L.png" -pix_fmt rgb24 "output/02-widgets-$L.png"
done
```

Der `ffmpeg`-Schritt entfernt den Alphakanal — App Store Connect weist PNGs mit Alpha
zurück. Prüfen mit `sips -g pixelWidth -g pixelHeight -g hasAlpha output/02-widgets-de.png`
(erwartet: 1320, 2868, no). Die fertigen Bilder liegen als `02-widgets.png` je Locale
unter `../app-store-connect/screenshots/`.
