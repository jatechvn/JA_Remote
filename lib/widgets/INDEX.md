# lib/widgets/ Directory Guide

Shared Apple Liquid Glass widget library, keyboard routing helpers, and terminal/editor components.

## Barrel & Part Architecture

- `lib/widgets/glass_widgets.dart` is the main barrel:
  - **`part` files**: `glass_background.dart` (`MeshOrb`, `MeshBackground`), `glass_surfaces.dart` (`GlassCard`, `BentoCard`), `glass_indicators.dart` (`WaveIndicator`, `DynamicIslandCapsule`, `SlidingPillTabBar`, badges/docks), `glass_marquee.dart` (`AsymmetricMarqueeText` / `BounceMarqueeText`), `glass_actions.dart` (`GlassButton`, `GlowingActionButton`), `glass_effects.dart` (`BorderBeam`, `SpotlightGlow`), `glass_scaffold.dart` (`GlassScaffold`).
  - **Re-`export`ed components**: `glass_dropdown.dart`, `glass_terminal.dart`, `glass_script_editor.dart`, `glass_remote_widgets.dart`.
- **Standalone shared widgets**: `app_toast.dart`, `command_palette.dart`, `filter_search_dock.dart`, `glass_deploy_dest_field.dart`, `glass_dialog.dart`, `glass_search_history_field.dart`, `glass_update_dialog.dart`, `mobile_dock_nav.dart`, `route_shortcuts.dart`.

## Non-Obvious Invariants

- **Power Gating (`AppPowerManager`)**: `MeshOrb` listens to `backgroundAnimationNotifier`; `WaveIndicator` and `BorderBeam` listen to `indicatorsAnimationNotifier` with animation direction preserved (`AnimationStatus.reverse` vs `forward`); `AsymmetricMarqueeText` listens to `marqueeAnimationNotifier`, freezes scroll offset when paused, and increments `_sessionEpoch` to cancel stale delayed timer callbacks.
- **`RouteShortcuts` (`lib/widgets/route_shortcuts.dart`)**: Hooks early key-down dispatch scoped to the active `ModalRoute` and enabled `TickerMode`, bypassing header/autofocus traps while allowing modal dialogs and text editors to intercept keys normally.
- **`GlassTerminalController` (`lib/widgets/glass_terminal.dart`)**: `TerminalLine.fromExternal` strips duplicate leading `[HH:mm:ss]` timestamps and classifies `output` lines (`[✓]`, `[✗]`, `[!]`, `[BẮT ĐẦU]`, `[HOOK]`) into semantic colors. External `FocusNode` retains Tab autocomplete & Up/Down history via a non-focusable ancestor `Focus`.

## Verification

- `flutter test test/glass_scaffold_test.dart test/glass_terminal_test.dart test/terminal_external_focus_test.dart test/glass_script_editor_test.dart test/glass_search_history_field_test.dart test/dropdown_marquee_test.dart test/command_palette_test.dart test/route_shortcuts_test.dart`
