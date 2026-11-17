# FocusAnchor

> A neurodiversity-friendly focus companion — a heart-rate-aware study & focus helper built on HarmonyOS.

**FocusAnchor** is a dual-module HarmonyOS (ArkTS / ArkUI) application:

- **Phone / Tablet (`entry` module)**: the full experience — focus mode, study-task management, voice input, floating ball, settings and local encrypted storage.
- **Watch (`wear` module)**: a lightweight round-face experience — view / edit / complete tasks, synced with the phone via distributed data.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     HarmonyOS project                        │
├──────────────────────────┬──────────────────────────────────┤
│  entry module (branch1)   │  wear module (branch2)            │
│  deviceTypes: phone/tablet│  deviceTypes: wearable            │
│  EntryAbility            │  WearAbility                       │
├──────────────────────────┴──────────────────────────────────┤
│  Phone layering                                              │
│  pages/       Index · AppTabs · FocusPage · SettingsPage      │
│  components/  FloatBall                                       │
│  services/    AppState · Storage · WatchSync · XiaoyiBridge    │
│               Reminder · Domain(HR/advice) · TaskFile         │
│  models/      AppTypes (data models & rules)                  │
│  common/      LocaleHelper (EN / ZH)                          │
├──────────────────────────────────────────────────────────────┤
│  Cross-device: distributed KV (phone↔watch task/language sync)│
│  Local security: AES-256-CBC · Voice: CoreSpeechKit ASR        │
└──────────────────────────────────────────────────────────────┘
```

- **Bundle name**: `com.focusanchor.focuxanchor`
- **Version**: `1.0.0` (versionCode `1000000`)
- **SDK**: HarmonyOS API `26.0.0`

---

## Features

### Phone / Tablet (entry)

| Area | Feature |
| --- | --- |
| Overview | Heart rate (BPM), focus status, system clock, one-tap into Focus, manual "Remind" |
| Focus mode | Focus-level colored ring (green→yellow→orange→red), white-disc entrance + wave animation |
| Study tasks | Add / edit / clear; priority (high/med/low); deadline parsing with auto-escalation; study method; voice input |
| Xiaoyi voice | Microphone permission, ASR speech-to-text (EN/ZH fallback), command parsing, voice quick-add |
| Floating ball | Draggable with edge snap; single-tap quick menu; double-tap voice panel |
| Personalised advice | Advice based on focus state & tasks; efficiency score (0–100) |
| Reminders | System notification for unfinished tasks; 15-min periodic check + manual |
| Settings | EN / ZH; profile (name, age, preset/album avatar); privacy toggles; HR range; PIN lock |
| Local security | Tasks & HR history stored AES-256-CBC encrypted (random IV + SHA256-derived key) |

### Watch (wear)

| Area | Feature |
| --- | --- |
| Round-face layout | Safe-area insets for circular screens (Swiper + page dots) |
| Tasks | List, create / edit / complete / delete; priority cycling; due-day (1/3/7) |
| Focus mode | HR ring + wave animation + white-disc entrance (circular clip) |
| Settings | Language switch (EN / ZH) |
| Sync | Distributed KV task & language sync with phone (last-write-wins) |

---

## Project layout

```
pig-master/
├── AppScope/                    # app-level config (bundle, version, icon)
├── entry/                       # branch1: phone / tablet
│   └── src/main/ets/
│       ├── common/LocaleHelper.ets
│       ├── components/FloatBall.ets
│       ├── entryability/EntryAbility.ets
│       ├── models/AppTypes.ets
│       ├── pages/
│       └── services/
├── wear/                        # branch2: watch
│   └── src/main/ets/
│       ├── entryability/WearAbility.ets
│       └── pages/
├── build-profile.json5
├── oh-package.json5
└── README.md
```

---

## Build & run

1. Install **DevEco Studio** 26.0.0 (HarmonyOS API 26.0.0).
2. Open the project and let dependencies sync.
3. Configure signing under `File → Project Structure → Signing Configs`.
4. Select a target device: run `entry` for phone/tablet, `wear` for watch.
5. Click **Run**.

> Phone and watch must use the same Huawei account with distributed capabilities enabled for task/language sync.

---

## Permissions

| Permission | Purpose |
| --- | --- |
| `ohos.permission.MICROPHONE` | Xiaoyi voice-to-text input |
| `ohos.permission.READ_IMAGEVIDEO` | Album avatar picker |
| `ohos.permission.DISTRIBUTED_DATASYNC` | Phone ↔ watch task/language sync |
| `ohos.permission.INTERNET` | Online ASR / network |
| `ohos.permission.VIBRATE` | Heart-rate alert vibration |

---

## Implementation status (honest notes)

| Capability | Status |
| --- | --- |
| Heart-rate data | ⚠️ Currently **simulated random drift** (60–120 BPM); no real sensor yet |
| Xiaoyi advice | ⚠️ Uses **local hardcoded text**; no real AI/LLM integration yet |
| PIN lock | ⚠️ Switch & storage exist, but **no launch-time enforcement** yet |
| Phone ↔ watch sync | ✅ Distributed KV works (tasks + language) |
| Local encryption | ✅ AES-256-CBC implemented |

---

## Contributing

1. Fork the repository
2. Create a `Feat_xxx` branch
3. Commit your code
4. Create a Pull Request

---

## License

See [LICENSE](./LICENSE).
