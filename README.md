# Fast4

An iOS scoreboard for Fast4 tennis, drawn as a 16-bit sports game. Two big
buttons, an undo button, and the format handled for you.

Open `Fast4.xcodeproj` in Xcode and run. iOS 17+, iPhone and iPad.

| Home | Scoreboard |
| :--: | :--: |
| <img src="docs/screenshots/home.png" width="340" alt="Setup screen: player name fields, a best-of-3 or best-of-5 picker, a match tie-break checkbox, a first-serve picker, a start button, and a summary of the Fast4 rules."> | <img src="docs/screenshots/scoreboard.png" width="340" alt="Scoreboard in set 2, game 3. Alice leads, having won set 1 by 4 games to 2; games are level at 1-1 and the current game stands at 30-0."> |
| Choose players, format and first serve | Sets, games and points, with a ball marking the server |
| **Sudden death** | **Deciding point** |
| <img src="docs/screenshots/sudden-death.png" width="340" alt="Scoreboard at 40-40 with a red SUDDEN DEATH banner beneath the set and game indicator."> | <img src="docs/screenshots/deciding-point.png" width="340" alt="Scoreboard during a set tie-break at 4 points all, with a red DECIDING POINT banner."> |
| At 40-40 the next point takes the game | At 4-4 in a tie-break, the next point takes the set |

Every point is one tap; the undo button rewinds any mistake, including one that
closed out a game or a set. The deciding-point banner is the only red in the
app — it appears at 40-40, at 4-4 in a set tie-break, and at 9-9 in a match
tie-break.

## The format it implements

| Rule | Behaviour |
| --- | --- |
| Sudden-death deuce | At 40-40 the next point takes the game — no advantage |
| Short sets | First to 4 games wins the set |
| Set tie-break | At 3-3, a tie-break to 5; deciding point at 4-4; the set is recorded 4-3 |
| Match tie-break | Optionally, a deciding set (1-1 or 2-2) is a tie-break to 10; deciding point at 9-9 |
| No-let serves | Nothing to implement — a let is simply played as a normal point |

Serving alternates each game, and follows the one-point-then-two pattern inside
a tie-break; after a tie-break, whoever served it first receives first in the
next set.

## Running it on your own iPhone

You don't need the App Store, and you don't need the paid Apple Developer
Program either — a **free Apple ID is enough** to put this on your own phone.
The device must be running iOS 17 or later.

### One-time setup

1. Add your Apple ID to Xcode under **Settings → Accounts**.
2. Set your own signing team: select the **Fast4** target → **Signing &
   Capabilities** → **Team**. The `DEVELOPMENT_TEAM` committed here belongs to
   this repo's author, so anyone else has to change it. If signing complains,
   change `PRODUCT_BUNDLE_IDENTIFIER` too — bundle IDs are globally unique, and
   `com.jlzhou.Fast4` is taken.
3. Connect the iPhone by cable, unlock it, and tap **Trust This Computer**.
4. On the phone, turn on **Settings → Privacy & Security → Developer Mode**,
   then restart when prompted. This is required on iOS 16 and later, and the
   row only appears once a Mac running Xcode has been connected.

### Install

Pick your iPhone in Xcode's destination menu and press **⌘R**.

Or from the command line, with the phone connected:

```sh
xcodebuild -project Fast4.xcodeproj -scheme Fast4 \
  -destination 'generic/platform=iOS' -derivedDataPath build \
  -allowProvisioningUpdates build

xcrun devicectl list devices        # copy your device's identifier
xcrun devicectl device install app --device <identifier> \
  build/Build/Products/Debug-iphoneos/Fast4.app
```

`-allowProvisioningUpdates` is what lets Xcode create the provisioning profile
for you; without it the build fails with "No profiles for 'com.jlzhou.Fast4'
were found".

On first launch the phone will refuse to open an app from an unknown developer.
Trust it once under **Settings → General → VPN & Device Management** → your
Apple ID → **Trust**.

### The seven-day catch

On a free Apple ID the provisioning profile is valid for **exactly seven days**.
After that the app stops launching until you connect the phone and run it again,
which re-signs it silently. Free accounts are also limited to roughly three
sideloaded apps on a device at once.

Paid membership ($99/yr) extends profiles to a year and covers up to 100
registered devices — that, rather than App Store access as such, is what the fee
buys you if you only ever intend to run this yourself.

## How it's put together

- `Fast4/Model/MatchState.swift` — the scoring engine. Only `config` and
  `pointLog` are authoritative; every other value is derived by replaying the
  log. Undo is therefore just "drop the last point and replay", which cannot
  leave the state inconsistent.
- `Fast4/Model/MatchStore.swift` — owns the live match and mirrors it into
  `UserDefaults` after every point, so quitting mid-match loses nothing.
- `Fast4/Views/PixelKit.swift` — the pixel-art design system: palette, font,
  the grass court, the net, chunky panels, beveled buttons that drop onto their
  own shadow, hand-plotted icons, and an in-idiom modal (a system action sheet
  in the middle of a pixel game looks like a bug).
- `Fast4/Views/` — setup screen, scoreboard, point-by-point history.

### Look

White and shades of green, everything on a 4pt grid with square corners — a
grass court is already white-on-green, so the palette and the subject agree.

The backdrop is a mown grass court seen from above, with the singles markings
and the net laid over the stripes. On the scoreboard the two players are
separated by a net drawn in elevation, tape and mesh, because they are in fact
on opposite sides of one. The title carries a racket with a strung lattice —
filling the head solid reads as a lollipop, not a racket.

The font is **Silkscreen** (SIL Open Font License, `Fast4/Resources/`),
registered at launch with Core Text so no hand-written `Info.plist` is needed.
It was chosen the hard way: softer pixel faces that suited the theme better
render `5` almost identically to `S` and `B` almost identically to `G`, which is
fatal on a scoreboard. Only the regular weight ships — Silkscreen Bold closes
the counter of `4` so it reads as a solid blob, and this app is full of fours.
Emphasis comes from size and colour instead.

The app icon is generated, not drawn by hand:

```sh
swiftc -O Tools/MakeIcon/main.swift -o /tmp/makeicon
/tmp/makeicon Fast4/Assets.xcassets/AppIcon.appiconset/icon-1024.png
```

It plots a 32×32 sprite with antialiasing off, then upscales with
nearest-neighbour interpolation, so the result is true pixel art rather than a
smooth vector shrunk down.

## Tests

The engine has no UIKit dependency, so it is tested by a standalone harness
rather than an Xcode test target:

```sh
swiftc -O Fast4/Model/Player.swift Fast4/Model/MatchConfig.swift \
          Fast4/Model/MatchState.swift EngineTests/main.swift -o /tmp/enginetests
/tmp/enginetests
```

It covers each rule above plus serving rotation, undo across game/set/match
boundaries, encode-decode round trips, and ~200k assertions swept over 400
randomised matches (no set ever reaches 4-4, every set is won 4-x, a 4-3 set
always came from a tie-break, and every match terminates).

## Licence

The code is MIT licensed — see [LICENSE](LICENSE).

The bundled font is not covered by that licence. Silkscreen is licensed
separately under the SIL Open Font License, and its terms are included at
`Fast4/Resources/Silkscreen-OFL.txt`; that file must travel with the `.ttf` in
any redistribution.
