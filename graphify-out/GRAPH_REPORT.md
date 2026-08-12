# Graph Report - .  (2026-08-12)

## Corpus Check
- Corpus is ~45,686 words - fits in a single context window. You may not need a graph.

## Summary
- 1055 nodes · 1327 edges · 47 communities (41 shown, 6 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 33 edges (avg confidence: 0.8)
- Token cost: 45,804 input · 1,200 output

## Community Hubs (Navigation)
- Localization Strings
- Windows Runner & Plugins
- Home Timeline & Effects
- Android Background Service
- Settings Screen
- App Settings Store
- App Theme & Scope
- Saved-Items Store
- Data Models
- Phone-to-PC Keyboard
- Video Player Screen
- GitHub Auth Service
- Audio Player Service
- Account Cloud Sync
- Linux Runner & Plugins
- Weather Effects Painter
- App State Hub
- Message Bubble & Gallery
- Account Device Discovery
- Onboarding Screen
- HTTP Receive Server
- App Entrypoint (main)
- Windows Runner (C++)
- Home Widgets & Animations
- Format Helpers
- Image Gallery
- CI & Build Config
- Send Client
- Auth Config
- Admin Settings Page
- Now-Playing Screen
- App Widgets (misc)
- Home Bubble Actions
- Music Screen Imports
- Core Services (ChangeNotifiers)
- Networking & Cloud Concepts
- Widget Test
- Android MainActivity
- Voice & Share Packages
- App Version
- Linux Install Script
- Foreground Task Package
- Nullable String
- Launcher Icons Config

## God Nodes (most connected - your core abstractions)
1. `_` - 205 edges
2. `Win32Window` - 19 edges
3. `MessageHandler` - 12 edges
4. `FlutterWindow` - 10 edges
5. `Create` - 10 edges
6. `WndProc` - 10 edges
7. `MessageHandler` - 8 edges
8. `AppState` - 7 edges
9. `_MyApplication` - 7 edges
10. `WindowClassRegistrar` - 7 edges

## Surprising Connections (you probably didn't know these)
- `build-apk CI job` --references--> `texfi_files (Flutter app)`  [INFERRED]
  .github/workflows/build-apk.yml → pubspec.yaml
- `Linux runner build (GTK)` --references--> `texfi_files (Flutter app)`  [INFERRED]
  linux/CMakeLists.txt → pubspec.yaml
- `texfi_files (Flutter app)` --references--> `flutter_lints analysis config`  [INFERRED]
  pubspec.yaml → analysis_options.yaml
- `Windows runner build` --references--> `texfi_files (Flutter app)`  [INFERRED]
  windows/CMakeLists.txt → pubspec.yaml
- `Built-in audio/video player + music library` --implements--> `media_kit dependency`  [INFERRED]
  README.md → pubspec.yaml

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **APK/Windows build and release pipeline** — github_workflows_build_apk_build_apk, github_workflows_build_apk_build_windows, github_workflows_build_apk_release [EXTRACTED 0.90]
- **Cross-device Saved Messages transfer** — readme_account_cloud, readme_local_transfer, readme_github_oauth_device_flow, readme_dartio_transfer_server [INFERRED 0.75]

## Communities (47 total, 6 thin omitted)

### Community 0 - "Localization Strings"
Cohesion: 0.01
Nodes (202): _, accentColor, addToGroup, all, allowTyping, animations, animationsSub, animRise (+194 more)

### Community 1 - "Windows Runner & Plugins"
Cohesion: 0.06
Nodes (54): FlutterViewController, PluginRegistry, Point, RECT, Size, unique_ptr, RegisterPlugins(), DartProject (+46 more)

### Community 2 - "Home Timeline & Effects"
Cohesion: 0.04
Nodes (52): Animation, dart:ui, effects.dart, item_bubble.dart, _app, _applyFilter, _attachMenu, _bgLayer (+44 more)

### Community 3 - "Android Background Service"
Cohesion: 0.04
Nodes (45): @pragma, dart:io, double?, Background, init, _inited, _KeepAliveHandler, onDestroy (+37 more)

### Community 4 - "Settings Screen"
Cohesion: 0.05
Nodes (44): admin_page.dart, bool?, _accountCard, _accountTile, build, _card, _cloudStatus, _colorDot (+36 more)

### Community 5 - "App Settings Store"
Cohesion: 0.04
Nodes (44): double get, adminUnlocked, animations, animDurationMs, animSpeed, animStyle, autoAcceptFiles, autoDiscovery (+36 more)

### Community 6 - "App Theme & Scope"
Cohesion: 0.05
Nodes (42): ../app_state.dart, AppStrings get, FontWeight, InheritedNotifier, all, apple, AppScope, build (+34 more)

### Community 7 - "Saved-Items Store"
Cohesion: 0.06
Nodes (35): bool get, dart:async, Directory, Directory get, File, SavedItem, add, addRemote (+27 more)

### Community 8 - "Data Models"
Cohesion: 0.05
Nodes (36): DateTime, accountId, address, aud, baseUrl, cloud, createdAt, ext (+28 more)

### Community 9 - "Phone-to-PC Keyboard"
Cohesion: 0.06
Nodes (31): Peer, _app, build, _controller, count, createState, _debounce, didChangeDependencies (+23 more)

### Community 10 - "Video Player Screen"
Cohesion: 0.07
Nodes (30): ColorScheme, dart:typed_data, _art, build, color, _controls, createState, didChangeDependencies (+22 more)

### Community 11 - "GitHub Auth Service"
Cohesion: 0.06
Nodes (30): GithubAccount? get, _account, accountId, AuthStatus, avatarUrl, begin, cancel, dispose (+22 more)

### Community 12 - "Audio Player Service"
Cohesion: 0.07
Nodes (29): Duration, art, artist, current, dispose, dur, _loadArt, next (+21 more)

### Community 13 - "Account Cloud Sync"
Cohesion: 0.07
Nodes (27): auth_config.dart, auth_service.dart, _api, _appendIndex, auth, available, _busy, _ensureRepo (+19 more)

### Community 14 - "Linux Runner & Plugins"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 15 - "Weather Effects Painter"
Cohesion: 0.09
Nodes (21): AnimationController, CustomPainter, dart:math, _build, _c, createState, density, didUpdateWidget (+13 more)

### Community 16 - "App State Hub"
Cohesion: 0.09
Nodes (21): core/cloud_sync.dart, auth, client, cloud, discovery, dispose, isTrusted, lastReceived (+13 more)

### Community 17 - "Message Bubble & Gallery"
Cohesion: 0.09
Nodes (21): image_gallery.dart, build, child, _content, _copy, _fileContent, _footer, _groupDialog (+13 more)

### Community 18 - "Account Device Discovery"
Cohesion: 0.09
Nodes (21): addManual, auth, _busy, dispose, _ensureGist, _fetchPeers, _gistDescription, _gistId (+13 more)

### Community 19 - "Onboarding Screen"
Cohesion: 0.11
Nodes (19): IconData, active, build, _buildSlides, _controller, _count, createState, dispose (+11 more)

### Community 20 - "HTTP Receive Server"
Cohesion: 0.11
Nodes (18): HttpServer?, int get, _decodeFrom, _handle, _handleFile, _handleKey, _handleMessage, _json (+10 more)

### Community 21 - "App Entrypoint (main)"
Cohesion: 0.15
Nodes (12): ../core/auth_service.dart, ../core/background.dart, ../core/settings.dart, auth, init, main, settings, startNetwork (+4 more)

### Community 22 - "Windows Runner (C++)"
Cohesion: 0.22
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 23 - "Home Widgets & Animations"
Cohesion: 0.23
Nodes (13): WeatherOverlay, _WeatherOverlayState, _Entrance, _EntranceState, HomePage, _HomePageState, _PulsingMic, _PulsingMicState (+5 more)

### Community 24 - "Format Helpers"
Cohesion: 0.15
Nodes (12): clockTime, daySeparator, diff, humanSize, i, now, s, that (+4 more)

### Community 25 - "Image Gallery"
Cohesion: 0.17
Nodes (11): build, _controller, createState, dispose, images, _index, initialIndex, path (+3 more)

### Community 26 - "CI & Build Config"
Cohesion: 0.20
Nodes (11): flutter_lints analysis config, build-apk CI job, build-windows CI job, release CI job, Linux runner build (GTK), get_thumbnail_video (video preview), media_kit dependency, media_kit_video dependency (+3 more)

### Community 27 - "Send Client"
Cohesion: 0.18
Nodes (10): dart:convert, close, deviceName, _http, SendClient, sendFile, sendText, sendTyping (+2 more)

### Community 28 - "Auth Config"
Cohesion: 0.18
Nodes (10): AuthConfig, cloudMaxBytes, deviceCodeUrl, githubClientId, scope, storageRepo, tokenUrl, verificationUrl (+2 more)

### Community 29 - "Admin Settings Page"
Cohesion: 0.22
Nodes (8): ../app.dart, ../core/version.dart, AdminPage, build, _kv, _section, _toast, package:flutter/services.dart

### Community 30 - "Now-Playing Screen"
Cohesion: 0.22
Nodes (8): ../core/player_service.dart, _art, _controls, _fmt, h, m, s, _thumb

### Community 31 - "App Widgets (misc)"
Cohesion: 0.22
Nodes (9): TexfiApp, AudioPlayerScreen, MiniPlayer, _ZoomableImage, ConstraintsBox, ItemBubble, _SlideView, _AudioArt (+1 more)

### Community 32 - "Home Bubble Actions"
Cohesion: 0.22
Nodes (9): build, _appBar, _openImage, _openMedia, _voiceContent, _onVersionTap, _open, _sectionAbout (+1 more)

### Community 33 - "Music Screen Imports"
Cohesion: 0.29
Nodes (6): audio_player_screen.dart, ../core/models.dart, format.dart, ../l10n/app_strings.dart, build, MusicScreen

### Community 34 - "Core Services (ChangeNotifiers)"
Cohesion: 0.29
Nodes (7): ChangeNotifier, AuthService, CloudSync, PlayerService, Settings, Discovery, Store

### Community 35 - "Networking & Cloud Concepts"
Cohesion: 0.33
Nodes (7): http dependency, network_info_plus (local transfer), Account cloud (hybrid GitHub storage), dart:io local HTTP transfer server, GitHub OAuth device flow identity, Any-size local transfer, Type from phone to PC

### Community 36 - "Widget Test"
Cohesion: 0.40
Nodes (4): package:flutter/material.dart, package:flutter_test/flutter_test.dart, package:texfi_files/main.dart, main

### Community 38 - "Voice & Share Packages"
Cohesion: 0.67
Nodes (3): record (voice messages), share_plus (forward/share), Voice messages (m4a)

## Knowledge Gaps
- **733 isolated node(s):** `DesignPreset`, `state`, `name`, `cardRadius`, `buttonRadius` (+728 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_` connect `Localization Strings` to `Account Cloud Sync`, `Admin Settings Page`?**
  _High betweenness centrality (0.319) - this node is a cross-community bridge._
- **Why does `SavedItem` connect `Saved-Items Store` to `Data Models`, `Video Player Screen`, `Audio Player Service`, `App State Hub`, `Message Bubble & Gallery`?**
  _High betweenness centrality (0.024) - this node is a cross-community bridge._
- **Why does `Peer` connect `Phone-to-PC Keyboard` to `Data Models`, `Home Timeline & Effects`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **What connects `DesignPreset`, `state`, `name` to the rest of the system?**
  _733 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Localization Strings` be split into smaller, more focused modules?**
  _Cohesion score 0.009950248756218905 - nodes in this community are weakly interconnected._
- **Should `Windows Runner & Plugins` be split into smaller, more focused modules?**
  _Cohesion score 0.05711263881544157 - nodes in this community are weakly interconnected._
- **Should `Home Timeline & Effects` be split into smaller, more focused modules?**
  _Cohesion score 0.03773584905660377 - nodes in this community are weakly interconnected._