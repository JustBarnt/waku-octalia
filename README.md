# Octalia on waku

The Octalia shell, ported to run on waku. This folder is the config home: `shell.qml`, its modules
and `keys.conf` are here. It started as the `octalia` folder of
[waku-ports](https://github.com/JanDeDobbeleer/waku-ports), whose history it keeps.

## Run it

Needs `waku.exe`, `wakuc.exe` and `wakukeys.exe` on your PATH (or pass `-Waku` to `start.ps1`).

    .\start.ps1              # stops any running waku, then starts Octalia
    .\start.ps1 -Watch       # reload the shell when a file changes (else: wakuc --config-home <here> reload)
    .\start.ps1 -Log         # also write waku's diagnostics log to logs\waku.log
    .\start.ps1 -DryRun      # print what would run
    .\stop.ps1               # stop every running waku and its key handler

Start at sign-in, with waku's own per-user Scheduled Task (no admin rights):

    .\install-startup.ps1            # register (again: replaces it)
    .\install-startup.ps1 -Log       # and write logs\waku.log on every start
    .\install-startup.ps1 -Status    # show the tasks and the stored environment
    .\install-startup.ps1 -Remove    # remove the tasks and the stored environment

The task runs `waku.exe` directly, not `start.ps1`, so `install-startup.ps1` stores Octalia's two
variables (`OCTALIA_CONFIG_DIR`, `OCTALIA_CACHE_DIR`) in your user environment. Both scripts take
them, and the waku flags, from `tools\env.ps1`. Settings and cache live in `state\`, which git
ignores.

## Keys and tiling

This port uses waku's own tiler and key handler. No komorebi, whkd or AutoHotkey is needed. The shell
turns the tiler on (`Tiling.enabled`, in `shell.qml`) and ships its bindings in `keys.conf` next to
`shell.qml`; `wakukeys` reads that file by itself when it runs with this folder as `--config-home`
(`start.ps1` and `wakuc startup enable` both do). All three ports ship the same file, so they behave the
same. Edit `keys.conf` and save: the daemon reloads it. `wakukeys status` shows what is bound.

Windows reserves `Alt+Space` and `Win+L`; they cannot be bound.

| Keys | Does |
|---|---|
| `Alt+T` | new Windows Terminal window |
| `Alt+Q` | close the focused window |
| `Alt+M` | minimize the focused window |
| `Alt+Shift+O` | reload the shell |
| **Focus** | |
| `Alt+Left/Down/Up/Right` | focus the window in that direction |
| `Alt+Shift+[` / `Alt+Shift+]` | focus the previous / next window |
| **Move** | |
| `Alt+Shift+Left/Down/Up/Right` | swap the window with its neighbour |
| `Alt+Shift+Enter` | promote the window to the main slot |
| **Stacks** (windows that share one slot; the top one shows) | |
| `Ctrl+Alt+Shift+Left/Down/Up/Right` | stack the window onto its neighbour |
| `Alt+;` | take the window out of its stack |
| `Alt+[` / `Alt+]` | cycle the stack backward / forward |
| **Resize** | |
| `Alt+=` / `Alt+-` | wider / narrower |
| `Alt+Shift+=` / `Alt+Shift+-` | taller / shorter |
| **Layout** | |
| `Alt+L` | next layout: mainStack, mainStackTop, columns, rows, bsp, grid, centerMain |
| `Alt+X` / `Alt+Y` | mirror the layout horizontally / vertically |
| `Alt+F` | float the window, or tile it again |
| `Alt+Shift+M` | monocle: the focused window fills the area |
| `Alt+Shift+R` | retile every window of the desktop |
| `Alt+P` | pause or resume the tiler |
| **Desktops** | |
| `Alt+1` ... `Alt+9` | go to desktop 1 to 9 |
| `Alt+Shift+1` ... `Alt+Shift+9` | move the window to desktop 1 to 9 (you stay); past the last desktop it makes one new desktop |
| `Ctrl+Alt+Left` / `Ctrl+Alt+Right` | previous / next desktop |

The same actions run from a terminal: `wakuc tile layout next`, `wakuc tile focus left`,
`wakuc desktop goto 2`, `wakuc tile status`.
