# 100P

Wie die frühere Privat-App "Noboo", nur mit 100-Seiten-PDFs: Digitales Papier-Notizbuch fürs eigene iPad,
nur mit Apple Pencil. Ist Seite 100 voll und du willst Seite 101 anlegen, fragt ein Dialog nach
einem **Reset**: Das volle PDF bleibt in iCloud, die App beginnt mit einem neuen PDF und einer
leeren Seite. Die Info-Zeile zeigt `#1`, `#2`, … für das jeweilige PDF.
Details: `CLAUDE.md`. Reine Privat-App, nicht für den App Store.

## Installation auf dem iPad
1. `HundredP.xcodeproj` in Xcode öffnen. Unter Signing & Capabilities das eigene Team wählen und
   die Platzhalter-Bundle-ID `com.example.hundredp` durch eine eigene ersetzen. iPad per Kabel
   anschließen, als Ziel wählen.
2. Run (▶). Beim ersten Mal ggf. am iPad unter **Einstellungen > Allgemein > VPN &
   Geräteverwaltung** dem Entwickler vertrauen.
3. Beim ersten Start Namen eingeben und einen Speicherort wählen (am besten iCloud Drive).
   Die App legt dort selbst den Ordner "100P" an; darin landen `100P-0001.pdf`, `100P-0002.pdf`, … .

Terminal-Variante siehe `CLAUDE.md` ("Signierung"). Tests: `xcodebuild … test` (Simulator).
