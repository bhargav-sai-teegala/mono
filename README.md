# Mono

A minimal macOS menubar app for staying focused on one task at a time.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **One task at a time** — the active task stays front and center in your menubar
- **Subtasks** — break any task into smaller steps with progress tracking
- **Built-in timer** — track time spent on each task, pause and resume freely
- **Skip** — push the current task to the back of the queue without losing its time
- **History** — completed tasks are saved with total time spent
- **Launch at login** — optionally start Mono automatically on boot

## Install

1. Download `Mono-1.0.0-macOS.zip` from the [latest release](https://github.com/bhargav-sai-teegala/mono/releases/latest)
2. Unzip and drag `Mono.app` to your `/Applications` folder
3. On first launch, right-click → **Open** to bypass the Gatekeeper warning (unsigned app)

**Requirements:** macOS 13 Ventura or later, Apple Silicon or Intel

## Build from Source

```bash
git clone https://github.com/bhargav-sai-teegala/mono.git
cd mono
bash install.sh
```

This builds a release binary, generates the app icon, and installs `Mono.app` to `~/Applications`.

## Usage

Click the **◆** icon in your menubar to open Mono.

| Action | How |
|---|---|
| Add a task | Type in the input field and press Return |
| Start timer | Click the play button on the active task |
| Add subtasks | Expand a task and type in the subtask field |
| Mark done | Click the checkmark — task moves to history |
| Skip task | Push current task to the back of the queue |
| Launch at login | Right-click the menubar icon |

## License

MIT
