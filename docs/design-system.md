# Wanderer web design system

Source: the "Wanderer Web Redesign" PDF (mobile-web artboards) and Android redesign canvases. The shared sand/trail palette and typography live in `lib/core/theme/wanderer_theme.dart`. Desktop web keeps its sidebar-based layouts; mobile web shares Android styling, with browser-specific entry, tracking, and app-handoff states.

## Color

| Token | Hex | Use |
|---|---|---|
| `sand` | `#F5F2EC` | page background |
| `paper` | `#FFFFFF` | cards, panels |
| `line` | `#E7E1D6` | 1px borders |
| `ink` | `#1B1A17` | text, dark (neutral) buttons |
| `stone` | `#57534E` | secondary text |
| `trail` | `#C2410C` | primary accent — the one main action per screen |
| `trailSoft` | `#FBEBDD` | active nav, promoted chips |
| `forest` | `#2F6B4F` | completed, success |

On web `primaryOrange` resolves to `trail`, `statusCompleted` to `forest` and in-progress to `sky` (`#2F5C8A`).

### Dark theme ("Dusk")

Same layout, fonts, shapes and spacing; only colours swap. Web follows the device setting until the user flips the sun/moon toggle (top bar, landing header) or the Settings switch.

| Token | Dark | Light counterpart | Use |
|---|---|---|---|
| `ground` | `#24201C` Ground | Sand | page background |
| `surface` | `#2E2924` | Paper | cards, sidebar |
| `raised` | `#39332D` | `#FAF8F4` | inputs, hover, stat tiles |
| `line` | `#4A423A` | `#E7E1D6` | borders, dividers |
| `text` | `#F6F1EA` Chalk | Ink | main text |
| `textMuted` | `#C4BBB1` Ash | Stone | secondary text |
| `accentText` | `#F6A56A` | `#9A3412` | orange text and links |

Pills use dark tinted fills with light text of the same hue: forest `#1E3329`/`#7BCBA3`, sky `#1D2A38`/`#93BEEB`, trail soft `#3A2418`/`#F8B283`, gold `#3A2E14`/`#F2C265`, neutral `#39332D`/`#CFC8BF`. Primary buttons keep `#C2410C` with white text. Maps use `MapStyleHelper.night`.

**In code:** read tokens with `final c = WandererTheme.of(context);` (`WandererColors` theme extension, light and dark sets). The static light constants (`WandererTheme.ink`, `.stone`, …) are only for building those sets — widgets that render on web must use `c.*` so they work in both themes.

Dark rules: never pure black or pure white text; depth comes from lighter surfaces (Night → Surface → Raised), not shadows.

## Type

- Headlines: **Bricolage Grotesque** 600/700 — use `WandererTheme.display(size)`. Display 68/32, section 24.
- Everything else: **Manrope** 400–700 (theme default on web). Card title 16/700, body 14–15, label 11 caps with 0.08em tracking.
- Fonts are bundled in `assets/fonts/` (OFL). Never add a third font.

## Components

- Buttons are 44px tall, radius 12. `ElevatedButton` = trail primary; `OutlinedButton` = white secondary; `FilledButton` with `ink` = neutral; `TextButton` = trail-deep link.
- Status is always a pill: `Pill` / `Pill.status(context, status)` in `widgets/common/pill.dart` (green completed, blue in progress, orange promoted, gold distance/achievements, grey private).
- Cards: `WandererTheme.cardDecoration(context)` — white, 1px `line` border, no heavy shadow.
- Radii: 10–12 controls, 14 small cards, 18 panels, 999 pills.
- Spacing: 4px grid — 8 inside groups, 12–16 between items, 24 between cards, 40 page gutter (16 on phones).

## Layout

- `AdaptiveLayout.usesDesktopLayout(context)` selects desktop web at **720 logical pixels and above**. `AdaptiveLayout.isMobileWeb(context)` identifies narrower browsers. They share Android's Home/Trips/Explore/You navigation, creation forms, profiles, and settings, but use the PDF's browser landing, inline login form, app-install cards, and read-only trip tracking. Native apps retain their existing presentation at every width. Resizing a browser reevaluates the layout.
- `WandererScaffold` replaces `Scaffold` wherever there is an `AppSidebar` drawer. Desktop web shows the sidebar beside the page (icon rail below 1200px, or always with `collapsedSidebar: true` for map-heavy pages). Mobile screens use bottom navigation or a back button, not a sidebar drawer.
- Trip details have a higher breakpoint: **1032 logical pixels** (960px of content plus the 72px navigation rail). Below it, including 1024px tablet views, use the full-screen Android-style map, draggable trip sheet, and compact share/settings/visibility menus, not the legacy floating panels. Wide desktop trip details and other screens keep their existing layouts. Browser settings offer the app handoff, planned-route toggle, and owner deletion without native tracking controls.
- Sidebar groups: Adventures (Home, My trips, Trip plans, Explore), Social (Friends, Achievements), Admin.
- Desktop web users land on `DashboardScreen` when logged in and `LandingScreen` when logged out. Mobile browsers use `AndroidShell` or the compact `LandingScreen`; native apps use `AndroidShell` or `AndroidWelcomeScreen`. `InitialScreen` decides; navigate to it for "go home".
- Layout is not a platform capability: keep `kIsWeb` and native guards for browser SSO redirects, URL parameters, map marker APIs, location permissions, and Android background services. Mobile web does not expose native push settings or automatic check-in controls.

## Mobile-web behavior

- Web landing: mobile and desktop use the same marketing page, including the highlighted hero headline, route/phone preview, feature cards, real featured trips, and footer. Narrow browsers stack the content and show Log in plus public exploration; the page remains scrollable.
- Android welcome: a single non-scrollable screen with the shared brand header, a decorative contour-map route illustration, and short, centered app-specific copy. No browser/phone mockup or marketing badge. Log in and Try without logging in remain visible above the safe-area inset. Artwork and secondary copy yield space on short screens or with enlarged text; no marketing feed or footer is included. Google sign-in and account creation remain available through Log in. The illustration is decorative, not user trip data. Web retains its existing headline and product preview.
- Home: app-install card, Trips/Badges/Friends statistics, latest trip, and bottom navigation. Creation is available from Trips, not a Home tracking button.
- Owner drafts: dedicated next-step/app-install view, trip settings readout, visibility editing, copy/share/delete actions, and Trips navigation. No map, QR code, or native Start button.
- Started trips: map and scrollable rounded sheet with timeline visible initially. Owners get an app handoff, not check-in/pause/rest/finish controls. Browsing does not request the viewer's location.
- Public trips: owner metadata and follow/share actions. Comments open a dedicated view with a fixed composer; the list scrolls independently above the keyboard.
- Plans: View plan and Start in app actions. Planning/editing stays available in the browser; handing off a plan does not create a trip in the browser.
- Browser chrome, keyboards, and status bars in the reference are context supplied by the device, not Flutter UI.

### App links and backend dependencies

`AndroidAppLinks` uses package-targeted Android intents with a Google Play fallback. MainActivity handles the separate `wanderer-app:///trip/:id` and `wanderer-app:///plan/:id` routes; `wanderer://` remains exclusively the SSO callback scheme. **Install an Android build containing the new intent filter before testing Open app.** Other platforms are sent to Google Play. Browser sessions/tokens are never embedded in app links; sign in separately in the app.

The PDF includes flows not fully supported by the existing backend:

- The frontend implements `/reset-password?token=...`, submitting `{token, newPassword}` to the existing password-reset PUT endpoint. Current backend emails still use its server-rendered reset form; changing those emails to the frontend URL requires a backend deployment. Existing reset-email links continue to work.
- Verification success stays visible with Open app/Continue in browser choices. There is no resend-verification endpoint, so the existing manual token recovery is retained instead of a non-functional resend form.
- Access-denied responses do not identify whether a trip is private or friends-only. Show a neutral restricted-trip page for 401/403, not inferred owner or privacy details; 404 has a separate not-found page.
- No analytics provider is configured. Do not present a fictitious analytics opt-in or add tracking to reproduce the cookie-consent artboard. Revisit consent when optional storage/analytics is introduced.

## Rules

1. One orange button per screen: the main action. Everything else is white or text.
2. Cards are white on sand with a 1px line border, no heavy shadows.
3. Status is always a pill: green completed, blue in progress, orange promoted.
4. Headlines in Bricolage Grotesque, everything else in Manrope. Never more than two fonts.
5. Desktop maps get rounded corners and floating white controls. Mobile maps follow Android: full-bleed with floating controls and draggable information sheets.
