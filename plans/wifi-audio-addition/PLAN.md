# Wi‑Fi + Audio — Research, UX, Implementation Plan

## Purpose

Microverse already monitors battery/CPU/memory/network/weather across multiple surfaces (popover, Smart Notch, Desktop Widget).
This plan captures:

- **Research**: what users expect from “Wi‑Fi strength” and “Audio devices” on macOS.
- **UX spec**: how these features should feel in a clean, Apple-like UI (clarity, deference, hierarchy).
- **Implementation notes**: APIs, edge cases, privacy, and performance considerations.

The goal is that a new contributor can understand *why* we built things a certain way and extend it without guesswork.

Also see:
- `docs/WIFI_AUDIO_FEATURES.md` (simple “why/where/how” overview + testing commands)

## How to use

1. Read `001-wifi-research.md` and `002-audio-research.md` for platform expectations and API constraints.
2. Read `003-ux-spec.md` for Microverse-specific UI/interaction decisions.
3. Use `004-implementation-notes.md` when changing code to avoid regressions.

## File index

- `001-wifi-research.md` — User expectations + APIs + privacy/perf notes for Wi‑Fi strength
- `002-audio-research.md` — User expectations + APIs + limitations for audio device routing & volume
- `003-ux-spec.md` — What ships where (popover/System/Widget/Notch) + design rules
- `004-implementation-notes.md` — Code map, test checklist, known limitations, future work
