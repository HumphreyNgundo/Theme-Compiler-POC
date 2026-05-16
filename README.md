# Theme Compiler POC

A proof-of-concept Flutter app that **builds its entire UI from a JSON document fetched at runtime**. There are no hardcoded screens. Theme colours, fonts, navigation, screen layouts, and even button actions are all described in a single JSON file. At launch, an "engine" reads that JSON and compiles it into live widgets.

The example payload bundled with the project (`mock_api/app_definition.json`) describes a fictional Kenyan banking app called **Kijani Finance** — splash → login → 4-tab shell (Home, Payments, History, Profile).

---

## What the app does today

When you run `flutter run`:

1. **Splash screen** — a terminal-style "compile console" plays a 7-step pipeline (init → fetch JSON → parse screens → build nav → build component registry → compile theme → render). The steps are real work, but each one has a small artificial delay so the animation is visible.
2. **Login screen** — rendered from JSON. The "Sign In" button is wired to an `authenticate` action; it accepts anything (no real validation).
3. **Main app shell** — a bottom tab bar with Home, Payments, History, Profile. Sub-screens (Send Money, Paybill, Confirm Payment, etc.) push onto a nested navigator so the tab bar stays visible.
4. **All actions are JSON-driven** — buttons declare `{"type": "navigate", "screen": "send_money"}` and the engine dispatches.

The whole point: to add a new screen, you edit the JSON. To add a new *kind* of widget, you add a case to one file (`component_registry.dart`).

---

## Project structure

```
lib/
├── main.dart                  # Entry point — boots the provider tree
├── app.dart                   # Root widget — routes splash / auth / main shell
├── engine/
│   ├── app_engine.dart        # The compiler: fetch JSON, parse, compile ThemeData
│   ├── component_registry.dart# The renderer: JSON node → Flutter widget
│   └── icon_resolver.dart     # Maps icon-name strings to Flutter IconData
├── models/
│   └── app_definition.dart    # Typed Dart models for the JSON document
├── providers/
│   └── engine_provider.dart   # Central state — engine progress, auth, tab, actions
└── screens/
    ├── splash_screen.dart     # The "compile console" UI
    └── engine_screen.dart     # The main runtime — tab bar + nested navigator

mock_api/
└── app_definition.json        # The whole app, as JSON (currently: Kijani Finance)
```

---

## What each module does

### `lib/main.dart`
Tiny — just calls `runApp` with `ChangeNotifierProvider<EngineProvider>` wrapping `ThemeCompilerApp`. Nothing app-specific lives here.

### `lib/app.dart` — `ThemeCompilerApp`
The root widget. Watches `EngineProvider` and decides what to show:
- `loading` → `SplashScreen`
- `ready` + not authenticated → an **auth shell** (renders the login screen from JSON in its own `Navigator`, so flows like "forgot password" work without a tab bar)
- `ready` + authenticated → `EngineScreen` (the main shell)

### `lib/engine/app_engine.dart` — `AppEngine`
The compiler. Runs a `Stream` of `EngineProgress` updates so the splash console can show live progress. Responsibilities:
1. **Fetch** the app definition (`_fetchDefinition()` — currently loads `mock_api/app_definition.json` from bundled assets; the file contains a clearly marked block showing how to swap in an HTTP call).
2. **Parse** the JSON into typed models (`AppDefinition.fromJson`).
3. **Compile a `ThemeData`** from the `theme` block — colours, fonts (via `google_fonts`), button shapes, input decoration, card style. Every value comes from JSON.
4. **Emit a final `EngineProgress`** containing the parsed `AppDefinition` and `ThemeData`.

The 7 pipeline steps and their labels are defined in `_pipeline`.

### `lib/engine/component_registry.dart` — `ComponentRegistry`
The renderer, and the largest file in the project (~1100 lines). One static `build()` method dispatches on `ComponentDef.type` and returns a Flutter widget. Currently understands ~35 types in three rough buckets:

- **Layout**: `scroll_view`, `list_view`, `column`, `row`, `center`, `card`, `spacer`, `divider`
- **Primitives**: `text`, `field_label`, `section_label`, `detail_row`, `text_field`, `form`, `button`, `outlined_button`, `biometric_button`
- **App-specific composites**: `icon_box`, `dashboard_header`, `account_carousel`, `quick_action_grid`, `transaction_list`, `service_tile`, `section`, `avatar`, `settings_tile`, `warning_box`, `success_view`, `engine_info_card`

Unknown types render an error tile rather than crashing. Resolves `$variable` references against the theme (e.g. `"color": "$primary"` looks up the theme colour).

> **Note**: the composites are bespoke to the Kijani Finance demo. They're handy for showing what the engine can do, but a "real" generic engine would probably push these out of the registry and into composition.

### `lib/engine/icon_resolver.dart` — `IconResolver`
A static map from icon-name strings (used in JSON, e.g. `"icon": "wallet"`) to Flutter `IconData`. Unknown names fall back to a hollow circle. Extend the map when JSON references a new icon.

### `lib/models/app_definition.dart`
Plain-Dart models for the JSON document. The hierarchy:

| Model | Represents |
|---|---|
| `AppDefinition` | The root — `version`, `appName`, `tagline`, `theme`, `navigation`, `screens` |
| `ThemeDef` | Colour palette (named tokens), `fontFamily`, `darkMode` flag, plus helpers to resolve `$tokenName` references and hex strings |
| `NavigationDef` | `authScreen` (which screen to show when logged out), `initialScreen` (default tab), `tabs` |
| `TabDef` | One bottom-nav entry: `screenId`, `label`, `icon` |
| `ScreenDef` | One screen: `id`, `title`, `showAppBar`, list of root `components` |
| `ComponentDef` | One UI node: `type`, `props` (free-form map), optional `children` |
| `ActionDef` | An action handler: `type` (e.g. `navigate`, `authenticate`) plus typed params |

### `lib/providers/engine_provider.dart` — `EngineProvider`
The single source of truth at runtime. A `ChangeNotifier` that holds:

- **Compile-phase state**: `state` (loading/ready), live `steps`, `progress` (0–1)
- **Runtime state**: parsed `appDef`, compiled `themeData`, `isAuthenticated`, `currentTab`
- **Navigator key** for push/pop on the nested navigator

Also dispatches actions via `handleAction(ActionDef, BuildContext)`:

| Action type | Effect |
|---|---|
| `authenticate` | Flips auth flag → app shell appears |
| `logout` | Clears auth + resets tab |
| `navigate` | Pushes a screen onto the nested navigator (or switches tab if the target is a tab screen) |
| `navigate_tab` | Switches to a tab by index |
| `go_back` | Pops the nested navigator |
| `share` | Stub — shows a SnackBar (would use `share_plus` in production) |

### `lib/screens/splash_screen.dart` — `SplashScreen`
Pure presentation. Listens to `EngineProvider` and renders:

- a brand block (the hardcoded "Kijani Finance" logo + "Engine v1.0" tag — currently the only thing in the app that isn't JSON-driven)
- a terminal-style step list with a check / spinner / hollow-circle per step
- a linear progress bar at the bottom

Kicks off `EngineProvider.initialize()` in `initState` after the first frame.

### `lib/screens/engine_screen.dart` — `EngineScreen`
The post-login runtime. Hosts a `NavigationBar` whose entries come from `appDef.navigation.tabs`, and a nested `Navigator` whose routes are resolved by looking up `ScreenDef` by id and rendering it through `ComponentRegistry`. Has a 404 fallback for unknown screen ids.

### `mock_api/app_definition.json`
The whole app. ~500 lines. To see the engine react to changes, edit this file and hot-restart.

---

## How a frame gets to the screen

```
splash_screen
   │  (calls engine.initialize())
   ▼
engine_provider ───► app_engine
                       │
                       ├─ fetch JSON  ─► mock_api/app_definition.json
                       ├─ parse       ─► AppDefinition (models)
                       └─ compile     ─► ThemeData
                       │
                       ▼ (stream of EngineProgress)
engine_provider (state = ready)
   │
   ▼
app.dart  ──► EngineScreen
                 │
                 ▼
              ComponentRegistry.build(screenDef.components)
                 │  (recursive)
                 ▼
              Flutter widget tree
```

Button taps in the tree call `onAction(ActionDef)` → `engine_provider.handleAction()` → navigation or auth state change → rebuild.

---

## Running it

```bash
flutter pub get
flutter run            # pick a device: Android, iOS, Chrome
```

To swap the mock for a real backend, replace the body of `AppEngine._fetchDefinition()` with an `http.get` (the call site already imports `http`). The rest of the engine doesn't care where the JSON came from.

---

## What's notably missing / could go next

These aren't bugs — they're places the POC stops short. Listed here so direction-finding is easier:

- **No real auth.** `authenticate` is a flag flip; there's no token, no API, no persistence.
- **No real network layer.** The `http` package is in `pubspec.yaml` but unused; `_fetchDefinition` reads a bundled asset.
- **No caching of the JSON.** Every cold start re-fetches.
- **No schema validation.** Malformed JSON will surface as runtime exceptions inside `ComponentRegistry`, which it catches and renders as red error tiles.
- **Composites are app-specific.** Components like `dashboard_header`, `account_carousel`, `transaction_list` are bespoke to Kijani Finance. A more reusable engine would express these as compositions of primitives in JSON instead of as registry entries.
- **Splash has one hardcoded string.** The "Kijani Finance" logo name is in `splash_screen.dart`. Could be read from JSON, except… the JSON hasn't loaded yet.
- **`test/widget_test.dart` is broken.** It imports a `theme_provider.dart` that no longer exists (was renamed to `engine_provider.dart`).
- **One open `withOpacity` deprecation** in `app_engine.dart:222` — Flutter wants `.withValues(alpha: …)` now.
