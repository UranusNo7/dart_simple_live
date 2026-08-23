# Project structure

## Top-level packages

- `simple_live_app/`: Primary Flutter application for mobile and desktop. Owns UI, navigation, settings, persistence services, synchronization flows, and live-room presentation.
- `simple_live_core/`: Shared Dart live-platform clients, models, request logic, and danmaku implementations.
- `simple_live_tv_app/`: Flutter TV application built on the shared core package.
- `simple_live_console/`: Console-oriented Dart client and utilities.
- `assets/`: Repository-level media used outside package-local Flutter asset declarations.
- `docs/`: Maintainer documentation for behavior, release boundaries, architecture, and focused audits.

## Primary app layout

Within `simple_live_app/lib/`:

- `main.dart`: Process initialization, services, themes, routing host, global keyboard/mouse behavior.
- `app/`: Shared settings, styles, constants, events, logging, and utilities.
- `app/player_config/`: Fixed media player configurations for Windows and Android phones.
- `modules/`: Feature pages and GetX controllers, including home, search, follow, live room, settings, and synchronization.
- `modules/live_room/player/`: Player lifecycle, gestures, fullscreen behavior, danmaku surface, and player controls.
- `services/`: Long-lived persistence, accounts, follows, synchronization, and connection services.
- `widgets/`: Reusable presentation components, pagination views, images, status states, and SuperChat cards.
- `routes/`: Named routes and navigation helpers.
- `models/`: App-specific persisted and transport models.
- `requests/`: App-level HTTP and synchronization request wrappers.

## Test layout

- `simple_live_app/test/`: Flutter widget and pagination regression tests.
- `simple_live_core/test/`: Shared core behavior and protocol regression tests.

Generated output under package `build/` directories is not source and should not be used as an audit input.
