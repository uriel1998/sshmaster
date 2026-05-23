# sshmaster

`sshm.sh` is a thin wrapper around `ssh`.

It accepts normal `ssh` arguments, checks the destination host against
`sshm.config`, and when there is a match it launches the session inside an
`xterm` with a configured icon and colors. When there is no match, it runs
plain `ssh`.

## Requirements

- `bash`
- `ssh`
- `xterm`
- `xseticon` for window icon decoration

## Usage

```bash
./sshm.sh [ssh arguments...]
./sshm.sh --help
```

Examples:

```bash
./sshm.sh dibbler
./sshm.sh user@dibbler
./sshm.sh -p 2222 user@example.com
./sshm.sh -J jumpbox internal-host
```

## Behavior

- `sshm.sh` accepts the same argument forms that `ssh` does.
- The first non-option destination is used to determine whether the host is in
  `sshm.config`.
- If the matched host appears in a config block, `sshm.sh` launches `xterm`
  and runs `ssh` inside it with the original argument list unchanged.
- If the host is not in `sshm.config`, `sshm.sh` executes plain `ssh`.
- Matching `xterm` sessions are launched with `TERM=xterm-256color`.

## Config Format

The default config file is [sshm.config](/home/steven/Documents/programming/sshmaster/sshm.config:1).
Blocks are separated by comment lines beginning with `#`.

Supported keys:

- `Host`: host alias or hostname to match. You can repeat this key within a block.
- `Icon`: icon filename stem, icon filename, or absolute path.
- `BGColor`: xterm color name, `#RRGGBB`, or a `0-255` xterm palette index.
- `FGColor`: xterm color name, `#RRGGBB`, or a `0-255` xterm palette index.

Example:

```text
########################################################################
Host dibbler
Host 192.168.1.101
Host stevesaus.me
Icon dibbler
BGColor 52
FGColor White
########################################################################
```

## Icons

By default, icons are loaded from [share/icons](/home/steven/Documents/programming/sshmaster/share/icons).

Icon resolution order:

1. exact path from `Icon`
2. `$SSHM_ICON_DIR/<Icon>`
3. `$SSHM_ICON_DIR/<Icon>.png`

If an `Icon` value is configured but no file is found, `sshm.sh` prints a
warning to stderr and still launches the `xterm`.

## Environment Overrides

- `SSHM_CONFIG`: override the config file path
- `SSHM_ICON_DIR`: override the icon directory

## Notes

- Numeric `BGColor` and `FGColor` values are interpreted as xterm 256-color
  palette indexes and converted to RGB before being passed to `xterm`.
- Named colors are passed through directly to `xterm`.
- Whether remote applications use 256 colors still depends on the remote host's
  terminfo and application behavior.
