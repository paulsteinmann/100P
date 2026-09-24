# 100P

A digital paper notebook for the iPad. You draw with the Apple Pencil, and every page ends up
in a PDF in your iCloud folder.

## What you can do

- **Add pages:** on the last page, swipe left and hold to add a new one, up to 100. On page 100
  the same gesture offers a reset: your PDF stays untouched in the folder, and a fresh one
  (`100P-0002.pdf`, `100P-0003.pdf`, …) starts with a blank page.
- **Copy a page:** tap and hold with a finger to copy a screenshot of the current page to the
  clipboard.
- **Get your PDF:** a complete, always up-to-date PDF of your notebook is synced to the folder
  you selected.
- **Turn pages:** swipe with a finger.

## What you can't do

Delete anything, rearrange anything, adjust anything, place anything. There is one pen, ink is
permanent, and fingers never draw.

## Install (free, via cable)

You need: a Mac, an iPad (iPadOS 17 or newer), a USB cable, an Apple Pencil and a regular
Apple ID. A paid developer account is **not** needed.

1. Install **Xcode** from the Mac App Store (free, large) and open it once.
2. In Xcode: *Settings → Accounts → +* and sign in with your Apple ID.
3. Download this repo (*Code → Download ZIP*, unzip) and double-click `HundredP.xcodeproj`.
4. Click the **HundredP** project in the left sidebar → target **HundredP** →
   *Signing & Capabilities*: choose your name ("Personal Team") as *Team* and change the
   *Bundle Identifier* to something of your own, e.g. `com.yourname.hundredp`.
5. On the iPad: *Settings → Privacy & Security → Developer Mode* → switch on (the iPad restarts).
6. Connect the iPad with the cable, tap "Trust This Computer", pick the iPad as the run
   destination at the top of Xcode and press **▶**.
7. On first launch the iPad may say the developer is not trusted: *Settings → General →
   VPN & Device Management* → your Apple ID → *Trust*. Then open the app ("Hundred Pages").

On first launch, enter your name and choose a location (iCloud Drive works best); the app
creates a folder called "100P" there.

**Good to know:** with a free account Apple may stop the app from launching after about
7 days. Just connect the iPad and press **▶** again; your pages are kept. The PDF's physical
scale is tuned for the iPad Pro 12.9″ (3rd generation); on other iPads the app works, but sizes
in the PDF are not 1:1.
