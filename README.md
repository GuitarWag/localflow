# localflow

Local push-to-talk dictation for macOS. Hold Right Control, speak, release, and the text is pasted at the cursor in whatever app has focus. Transcription runs on your machine with [mlx-whisper](https://github.com/ml-explore/mlx-examples/tree/main/whisper) (`whisper-large-v3-turbo`). No audio leaves the machine.

Built for dictating into Claude Code in the terminal. It works in any app that accepts Cmd+V.

## Requirements

- Apple Silicon Mac
- [uv](https://docs.astral.sh/uv/)
- About 1.6 GB of disk for the model, downloaded on first run

## Run

```sh
./localflow.py
```

Wait for `ready. hold ctrl_r to dictate`, then switch to the app you want to type into. Hold Right Control and talk. You hear a Tink when you press and another when you release. The text is pasted about a second later, without pressing Enter. Every transcript is printed in the terminal with its timing. Ctrl+C quits.

## Permissions

The terminal app you run it from needs these, in System Settings > Privacy & Security:

- Microphone
- Accessibility, to send Cmd+V
- Input Monitoring, to read the hotkey

## Configuration

| Variable | Default | Notes |
|---|---|---|
| `LOCALFLOW_KEY` | `ctrl_r` | Any [pynput key name](https://pynput.readthedocs.io/en/latest/keyboard.html#pynput.keyboard.Key): `alt_r`, `cmd_r`, `f13`. Built-in MacBook keyboards have no Right Control. |
| `LOCALFLOW_LANG` | auto-detect | e.g. `en`. Setting it stops wrong-language guesses on short phrases. |
| `LOCALFLOW_MODEL` | `mlx-community/whisper-large-v3-turbo` | Any mlx-community Whisper repo. |

```sh
LOCALFLOW_KEY=alt_r LOCALFLOW_LANG=en ./localflow.py
```

## How it works

The script records 16 kHz mono audio while the hotkey is held and transcribes it with mlx-whisper on a worker thread. It saves your clipboard, copies the transcript, sends Cmd+V, and restores the clipboard 0.3s later.

## Mac app

`mac/` has a menu bar version of the same tool, built with [WhisperKit](https://github.com/argmaxinc/WhisperKit). Settings pick the microphone, the hold-to-talk key (Right Control, Right Option, Right Command, Fn), the language and the model. The Python script above is unchanged.

```sh
mac/build.sh            # ad-hoc signed mac/LocalFlow.app
open mac/LocalFlow.app
```

On first launch it asks for Microphone and Accessibility, then downloads the model (about 630 MB) to `~/Library/Application Support/LocalFlow`. The menu bar icon shows the state: download arrow while loading, filled mic while recording.

An ad-hoc signed build only runs cleanly on the machine that built it. Each rebuild changes the signature, so macOS may ask for Accessibility again. To share it, sign with a Developer ID and notarize:

```sh
mac/build.sh "Developer ID Application: Your Name (TEAMID)"
ditto -c -k --keepParent mac/LocalFlow.app LocalFlow.zip
xcrun notarytool submit LocalFlow.zip --keychain-profile <profile> --wait
xcrun stapler staple mac/LocalFlow.app
```

Without that, recipients have to run `xattr -dr com.apple.quarantine LocalFlow.app` before opening it.
