# Wanderer web design system

Source: the "Wanderer Web Redesign" canvas (Style guide board). **Web only** for now; Android/iOS keep the old palette until they are redesigned. Every token below lives in `lib/core/theme/wanderer_theme.dart` and is gated on `kIsWeb` (a compile-time constant, so tokens stay `const`).

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

- `WandererScaffold` replaces `Scaffold` wherever there is an `AppSidebar` drawer. On web ≥720px it shows the sidebar beside the page (icon rail below 1200px, or always with `collapsedSidebar: true` for map-heavy pages); narrower, it is a drawer.
- Sidebar groups: Adventures (Home, My trips, Trip plans, Explore), Social (Friends, Achievements), Admin.
- Logged-in web users land on `DashboardScreen`; logged-out ones on `LandingScreen`. `InitialScreen` decides — navigate to it for "go home".

## Rules

1. One orange button per screen: the main action. Everything else is white or text.
2. Cards are white on sand with a 1px line border, no heavy shadows.
3. Status is always a pill: green completed, blue in progress, orange promoted.
4. Headlines in Bricolage Grotesque, everything else in Manrope. Never more than two fonts.
5. Maps get rounded corners and floating white controls; never full-bleed behind text panels.
