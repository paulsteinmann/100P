# 100P — CLAUDE.md

## Was das ist
Eine iPadOS-only, per Kabel sideload-fähige (kostenloser Apple-Developer-Account,
NICHT App Store) reine Privat-App: ein digitales Notizbuch. Die App *ist* das
Notizbuch — es gibt kein Organisations-Interface, keine Einstellungen, keine
Werkzeugauswahl. Gezeichnet wird ausschließlich mit dem Apple Pencil; Finger-Touches
sind ausschließlich für die Seiten-Navigation reserviert.

**100P ist die Weiterentwicklung von "Noboo"**, einer früheren privaten Notizbuch-App (die bleibt unverändert bestehen).
Gestaltung, Zeichnen, Blättern, PDF-Layout und Bildunterschrift sind identisch; geändert
sind nur: Name/Icon, genau EINE installierte App (keine Instanzen #1–#6 mehr), Seitenlimit
100 und der Reset-Ablauf (siehe unten). Die übrigen Invarianten stammen unverändert von Noboo.

## Nicht verhandelbare Invarianten — nicht ohne Rückfrage "verbessern"
- Finger-Touches dürfen NIE zeichnen (`drawingPolicy = .pencilOnly` auf dem Canvas).
- Es gibt genau EIN Werkzeug: einen festen schwarzen Fineliner (`PKInkingTool(.monoline, …)`,
  NICHT `.pen` — Monoline ist druckunabhängig, konstante Linienbreite). Kein `PKToolPicker`
  wird je gezeigt. Kein Radierer, kein Lasso, keine Farbauswahl, kein Verschieben.
- Kein Undo, kein Redo — nicht per Shake, nicht per 3-Finger-Wisch, nicht per Tastatur.
  Tinte ist absichtlich permanent ("einmal geschrieben, permanent"). Siehe `HundredPCanvasView.swift`.
  Dazu gehört auch: kein Markieren/Verschieben von Strichen. PencilKit bringt dafür eine
  eigene, von `drawingPolicy` unabhängige Finger-Interaktion mit (Lange-Halten → System-
  Editier-Menü "Select All" → Ziehen zum Verschieben) — auf dem echten Gerät gefunden,
  nicht offensichtlich aus der Doku. Abgestellt durch `canPerformAction` blanket-`false`
  (lässt das Menü gar nichts zum Anzeigen finden) plus `removeInteraction` auf alle
  `UIInteraction`s des Canvas in `commonInit()`.
- Einzelne Seiten können nie gelöscht werden, nur angehängt (Wisch-und-Halten-Geste auf der letzten Seite).
  Einzige Ausnahme: der Reset des ganzen Notizbuchs bei Seite 101 (siehe "100 Seiten und Reset").
- Orientierung ist fest auf Portrait gesperrt, immer — siehe `AppDelegate` in `HundredPApp.swift`
  und der Info.plist-Key `UISupportedInterfaceOrientations_iPad`. Der Canvas ignoriert die
  Safe Area und füllt den gesamten Bildschirm.

## App-Icon
`HundredP/HundredP.icon` — Icon-Composer-Format wie bei Noboo (`icon.json` + PNG-Layer).
Der Layer ist "100P" in **Menlo Regular** (dieselbe Schrift wie die Info-Zeile), schwarz auf
transparent, 1024×1024; erzeugt per Pillow aus `/System/Library/Fonts/Menlo.ttc` (Index 0).
Eingebunden als direkte Projektdatei, `ASSETCATALOG_COMPILER_APPICON_NAME = HundredP`.

## Seite kopieren
Langes Halten mit dem Finger (0,6s, `UILongPressGestureRecognizer`,
`allowedTouchTypes = [.direct]`) irgendwo auf der aktuellen Seite kopiert sie als PNG
**mit transparentem Hintergrund** in die Zwischenablage (`view.layer.render(in:)` der
ganzen `CanvasPageViewController`-View — Canvas *und* Bildunterschriftszeile, nicht nur
die rohe `PKDrawing`, die zwar auch transparent wäre, aber ohne Bildunterschrift; Canvas-
und View-Hintergrund werden dafür nur für den einen synchronen Render-Aufruf auf `.clear`
gestellt und sofort zurückgesetzt, kein sichtbares Flackern). Feedback bei Erfolg:
haptisch (`UIImpactFeedbackGenerator`) plus ein kurzer schwarzer Vollbild-Blitz
(`copyFlashView`, Alpha 0→1→0, ausgelöst *nach* dem Rendern, damit der Blitz selbst nie
mit aufs Bild kommt). Kollidiert nicht mit der Wisch-und-Halten-Geste für neue Seiten,
da die eine reale horizontale Bewegung braucht und die andere (Long-Press) gerade keine.

## Physikalischer Maßstab — DeviceScale.swift
Zielgerät: iPad Pro 12,9" (3. Gen.). Logische Portrait-Größe **1024×1366pt**
(NICHT die klassische iPad-Punktgröße 768×1024 — die 12,9"-Pro-Familie hat eine
eigene, größere Punktgröße; ein erster Entwurf dieser Datei hatte das
fälschlich mit 768×1024 verwechselt, aufgefallen erst beim Testen auf dem
exakten Simulator-Gerätetyp) entspricht einer physischen Displayfläche von
197,05mm × 262,8mm.
```
mmPerDevicePoint      ≈ 0.19241   (197.05/1024, gegengeprüft via 262.8/1366)
deviceToPDFPointScale ≈ 0.54554   (mmPerDevicePoint × 72/25.4)
Fineliner-Breite      ≈ 1.559 Device-Points   (0.3mm / mmPerDevicePoint)
```
Diese Werte leben AUSSCHLIESSLICH in `DeviceScale.swift`, mit Herleitung als Kommentar.
Bei Portierung auf ein anderes iPad-Modell müssen nur die physischen mm-Maße (Apple
Techspecs) neu eingesetzt werden, sonst nichts. Die Fineliner-Breite ist ein Startwert —
PencilKit-Rendering kann am echten Gerät eine empirische Nachjustierung brauchen
(am echten Gerät empirisch nachjustiert, siehe `liveToolWidthDevicePoints`).

## 100 Seiten und Reset
Ein Notizbuch = ein PDF = maximal `DeviceScale.maxPagesPerNotebook` (100) Seiten. Die App
zeigt immer nur das aktuelle Notizbuch. Auf Seite 100 bietet die Wisch-und-Halten-Geste
weiter an — statt einer 101. Seite erscheint aber der Reset-Dialog
(`PagerViewController.presentResetDialog` → `ResetDialogView`, Buttons "Abbrechen" / "Reset"):
- **Abbrechen:** nichts passiert, man bleibt auf Seite 100.
- **Reset** (`NotebookStore.startNewNotebook`): (1) das volle PDF `100P-000N.pdf` wird
  ein letztes Mal geschrieben und bleibt danach für immer unangetastet in iCloud; (2)
  `iCloudFolderService.startNewNotebook` legt den Seitenordner `.100p-pages-<N+1>/` an und
  löscht den alten; (3) neue leere erste Seite, sofort `100P-<N+1>.pdf` mit dieser einen Seite.
So sind beliebig viele 100-Seiten-PDFs möglich.

## PDF-Export
Ein PDF pro Notizbuch, `100P-0001.pdf`, `100P-0002.pdf`, … (4-stellig,
`iCloudFolderService.pdfFileName(number:)`), im vom Nutzer gewählten iCloud-Ordner, DIN A4,
eine PDF-Seite pro Seite. Wird komplett neu geschrieben (atomar: `.tmp` + `replaceItemAt`)
bei jedem Wechsel in den Hintergrund (`scenePhase`, per `beginBackgroundTask` abgesichert)
und sofort nach `addPage()` und Reset. Layout pro Seite unverändert zu Noboo:
- Haarlinie (0.5pt) = iPad-Bildschirm 1:1 (1024×1366 Device-Points × `deviceToPDFPointScale`), zentriert.
- Zeichnung VEKTORIELL aus `PKDrawing.strokes[].path` (300dpi-Raster ist der dokumentierte Fallback).
- Bildunterschrift 5pt unter der Haarlinie, Menlo, zweispaltig: links **`#<Notizbuchnummer>`**
  (`PDFExporter.captionLeftText(notebookNumber:)`, also `#1`, `#2`, …; bei Noboo stand hier
  "Noboo #N"), rechts Name + Zeitstempel + Seitenzahl mit Prozentzeichen, z.B. `"Max Mustermann  20260827 14:32  001/042%"`
  (Format `%03d/%03d%%`; das `%` ist Wunsch des Nutzers, bei Noboo gab es das nicht).
- Dieselbe Zeile live unten in der App (`PDFExporter.liveCaptionFontSize`), gleiche Formatfunktionen.

## Setup-Screen (`FolderPickerView.swift`)
Nur schwarz auf weiß, Menlo in `PDFExporter.liveCaptionFontSize` (wie die Info-Zeile),
Grau ausschließlich für Deaktiviertes (Platzhalter "Dein Name", Button solange kein Name
da ist). Zeilen sind von Hand umbrochen, maximal `FolderPickerView.maxLineLength` = 50 Zeichen. Statt eines Icons steht oben das Bild `Startup.png` (Finder-Fenster mit
`100P` und den PDFs; im Asset-Katalog als `Startup.imageset`, 3x). Namensfeld 432pt breit, eckig, 1pt schwarzer Rahmen.
**Alle Buttons sind Pillen** (`PillButtonStyle`, `Views/PillButtonStyle.swift`): schwarzer
Rahmen, schwarze Schrift auf weiß, `filled` = weiße Schrift auf schwarz, beim Drücken
invertiert, grau nur wenn deaktiviert. Der Reset-Dialog ist deshalb KEIN `UIAlertController`
(dessen Buttons lassen sich nicht so gestalten), sondern `ResetDialogView` (SwiftUI, per
`UIHostingController` `.overFullScreen` von `PagerViewController` präsentiert): "Abbrechen"
(Umriss) und "Reset" (gefüllt). Gemeinsame Schrift: `Font.hundredP`.

## Speichermodell
Single Source of Truth = der Ordner **`100P`**, den die App selbst innerhalb des einmalig
gewählten Speicherorts anlegt (`AppSettings.storageFolder(inside:)`; heißt der gewählte
Ordner schon "100P", wird er direkt benutzt). Gespeichert wird per Security-Scoped-Bookmark
nur der *gewählte Speicherort* (`storageLocationPath`/`storageLocationBookmark`), der
Unterordner wird zur Laufzeit abgeleitet. Setup-Dialog: "Wähle den Speicherort für deinen
100P-Ordner". Alles Folgende liegt IM Ordner `100P`:
```
100P-0001.pdf, 100P-0002.pdf, …          — abgeschlossene + aktuelles PDF
.100p-pages-0002/page-0001.drawing …     — rohe PKDrawing-Bytes NUR des aktuellen Notizbuchs
.100p-pages-0002/index.json              — [{index, createdAt}, ...]
```
**Notizbuchnummer** (`iCloudFolderService.notebookNumber`): Nummer des neuesten
`.100p-pages-<n>/`-Ordners. Gibt es keinen (Erststart, oder Neuinstallation in einen Ordner
mit alten PDFs), dann höchste vorhandene `100P-<n>.pdf` + 1 (erkennt auch die
`.100P-<n>.pdf.icloud`-Platzhalter) — ein fertiges PDF wird so nie überschrieben.
Absturzsicher: beim Reset wird erst der neue Ordner angelegt, dann der alte gelöscht; ein
übrig gebliebener älterer Ordner wird beim nächsten Start entfernt (`init`).
Debounced Save (~1,5s) + erzwungenes Save bei Hintergrund/Inaktiv. Kein `NSFileCoordinator`.
Die versteckten `.100p-pages-<n>/` (rohe Zeichnungen, brauchen wir zum Wiederherstellen) liegen
so im `100P`-Ordner statt lose im iCloud-Hauptordner.

## Signierung
Für die Installation per Kabel mit einem (kostenlosen) Apple-ID-Personal-Team: in Xcode unter
Signing & Capabilities das eigene Team wählen und die Bundle-ID `com.example.hundredp` durch eine
eigene ersetzen. Bundle-ID (Platzhalter):  `com.example.hundredp`, Anzeigename "Hundred Pages" (unter dem Icon; Ordner/PDFs heißen weiter 100P), **eine** App (nur Debug/Release,
keine Instanz-Configurations). Target/Modul heißen `HundredP` (Swift-Modulnamen dürfen nicht
mit einer Ziffer beginnen). Reinstall:
```
xcrun devicectl list devices
xcodebuild -project HundredP.xcodeproj -scheme HundredP -destination 'id=<UDID>' \
  -allowProvisioningUpdates -derivedDataPath build build
xcrun devicectl device install app --device <UDID> build/Build/Products/Debug-iphoneos/HundredP.app
xcrun devicectl device process launch --device <UDID> com.example.hundredp
```

## Build
```
xcodebuild -project HundredP.xcodeproj -scheme HundredP \
  -destination 'platform=iOS Simulator,name=<verfügbares iPad>' build
```
Dieses öffentliche Repo enthält bewusst keine Unit-Tests. Pencil-Zeichnen, echtes Druckgefühl,
iCloud-Sync und der Reset-Dialog per Geste sind ohnehin nur am echten Gerät verifizierbar.
