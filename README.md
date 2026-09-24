# 100P

Ein digitales Notizbuch fürs iPad: gezeichnet wird nur mit dem Apple Pencil. Jede Seite landet
maßstabsgetreu in einem PDF (`100P-0001.pdf`) in deinem iCloud-Ordner. Nach 100 Seiten fragt
die App beim Anlegen der nächsten, ob sie ein neues PDF beginnen soll – so entstehen beliebig
viele 100-Seiten-PDFs.

- **Neue Seite:** auf der letzten Seite nach links wischen und halten
- **Blättern:** mit dem Finger wischen

## Installation (kostenlos, per Kabel)

Du brauchst: einen Mac, ein iPad (iPadOS 17 oder neuer), ein USB-Kabel, einen Apple Pencil und
eine normale Apple-ID. Ein bezahlter Entwickler-Account ist **nicht** nötig.

1. **Xcode** aus dem Mac App Store installieren (kostenlos, groß) und einmal öffnen.
2. In Xcode: *Settings → Accounts → +* → mit deiner Apple-ID anmelden.
3. Dieses Repo laden (*Code → Download ZIP*, entpacken) und `HundredP.xcodeproj` doppelklicken.
4. Links das Projekt **HundredP** anklicken → Target **HundredP** → *Signing & Capabilities*:
   bei *Team* deinen Namen ("Personal Team") wählen und die *Bundle Identifier* ändern,
   z. B. in `com.deinname.hundredp`.
5. Am iPad: *Einstellungen → Datenschutz & Sicherheit → Entwicklermodus* einschalten
   (das iPad startet neu).
6. iPad per Kabel anschließen, „Diesem Computer vertrauen“ bestätigen, oben in Xcode das iPad
   als Ziel wählen und auf **▶** drücken.
7. Beim ersten Start meldet das iPad einen nicht vertrauten Entwickler: *Einstellungen →
   Allgemein → VPN & Geräteverwaltung* → deine Apple-ID → *Vertrauen*. Dann die App öffnen.

Beim ersten Öffnen gibst du deinen Namen ein und wählst einen Speicherort (am besten iCloud
Drive); die App legt dort selbst den Ordner „100P“ an.

**Gut zu wissen:** Mit einem kostenlosen Account kann Apple die App nach etwa 7 Tagen sperren.
Dann einfach das iPad anschließen und nochmal **▶** drücken, deine Seiten bleiben erhalten.
Die Maße im PDF sind auf das iPad Pro 12,9″ (3. Generation) abgestimmt; auf anderen iPads
läuft die App, die Größen im PDF stimmen dort aber nicht 1:1.

Technische Details: [`CLAUDE.md`](CLAUDE.md)
