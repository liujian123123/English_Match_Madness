# Match Madness

A Duolingo-style vocabulary matching game for Android, built with Flutter.

Match English words with their Chinese translations against the clock. Import your own word lists, track wrong answers, and review vocabulary with an Ebbinghaus forgetting-curve priority system.

## Features

- **Timed matching game** — Choose from 4 difficulty levels (1:00 / 1:30 / 2:00 / 3:00). Match English words to Chinese translations under time pressure.
- **Smart word selection** — Words you often get wrong appear more frequently, guided by an Ebbinghaus forgetting-curve algorithm.
- **Sound effects** — Procedurally generated success/failure audio. TTS reads matched words aloud in English.
- **Score & results** — Points based on correct matches, time remaining, and a difficulty multiplier. Full session results after each game.
- **Paste import** — Paste a list of English words; the app looks up translations via Youdao Dictionary API, lets you edit them, then imports.
- **JSON import** — Import word pairs from a JSON file.
- **Word manager** — Browse, edit, add, or delete imported words. Add detailed notes (example sentences, usage) to each word.
- **Backup & restore** — Export your word bank to any location via the system save dialog, and restore it after reinstalling the app.
- **Wrong-word review** — Review words you missed in previous games; remove them individually or clear all.
- **Offline-friendly** — Built-in word bank of 30+ common word pairs works without internet. API lookup is used as a supplement.

## Screenshots

(Add screenshots here)

## Requirements

- Android 5.0 (API 21) or later
- Internet connection (only required for dictionary API lookups)

## Download

Get the latest APK from the [Releases](https://github.com/yourusername/match_madness/releases) page.

## Build from Source

### Prerequisites

- Flutter SDK 3.0+
- Android SDK
- Java 17

### Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/match_madness.git
cd match_madness

# Install dependencies
flutter pub get

# Build release APK
flutter build apk --release
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

### Environment Variables (Windows)

```powershell
$env:ANDROID_HOME = "path\to\android-sdk"
$env:JAVA_HOME = "path\to\jdk-17"
```

## Project Structure

```
lib/
├── main.dart                          # Entry point
├── models/
│   ├── word_pair.dart                 # Word pair data model (with optional note)
│   ├── game_config.dart               # Game difficulty configuration
│   ├── dictionary_result.dart         # API query result wrapper
│   ├── session_result.dart            # Game session result
│   └── word_stats.dart                # Per-word statistics for forgetting curve
├── game/
│   ├── word_pool.dart                 # Word pool: load, deduplicate, priority-sort
│   ├── game_phase.dart                # Game state machine enum
│   └── scoring.dart                   # Scoring formula
├── screens/
│   ├── home_screen.dart               # Main menu: difficulty selector, navigation
│   ├── game_screen.dart               # Core matching game
│   ├── result_screen.dart             # Post-game statistics
│   ├── import_screen.dart             # JSON file import
│   ├── paste_import_screen.dart       # Paste + API lookup import
│   ├── review_screen.dart             # Wrong-word review
│   └── word_manager_screen.dart       # Word bank management
├── widgets/
│   ├── match_card.dart                # Card component for matching
│   ├── timer_widget.dart              # Countdown timer
│   └── score_display.dart             # Score display
└── services/
    ├── storage_service.dart           # Persistence: file + SharedPreferences + backup
    ├── dictionary_service.dart        # Youdao Dictionary API integration
    └── sound_service.dart             # TTS + procedural WAV sound effects
```

## Data Persistence

Words survive app restarts via a three-layer strategy:

1. **App documents directory** — Primary storage
2. **SharedPreferences** — Fast cache
3. **Manual backup** — `Export` saves to a user-chosen location via system dialog; `Restore` reads from a user-selected file

On Chinese Android ROMs, automatic MediaStore persistence is unreliable. Manual backup/restore is recommended before uninstalling.

## Tech Stack

- **Framework**: Flutter / Dart
- **TTS**: flutter_tts
- **Sound effects**: audioplayers (procedurally generated WAV bytes)
- **Dictionary API**: Youdao Dictionary (`dict.youdao.com/jsonapi_s`)
- **File I/O**: file_picker, path_provider
- **Persistence**: shared_preferences

## License

MIT