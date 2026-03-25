# Gaudi Theme

## Overview

Gaudi is a modular, asynchronous Bash prompt theme built for the gaudi-bash framework. It organizes prompt information into independent **segments** -- small, self-contained scripts that each display a single piece of context (working directory, Git status, language runtime version, cloud profile, and so on).

Key characteristics:

- **Nerd Font support** -- Segments use Nerd Font glyphs by default for icons (e.g., Git branch, Node.js, Docker). A patched Nerd Font must be installed and active in your terminal for symbols to render correctly. Symbol display can be disabled globally with `GAUDI_ENABLE_SYMBOLS=false`, in which case the segment name is shown as a plain-text fallback.
- **Modular segment architecture** -- Every segment lives in its own file under `segments/`. Segments are loaded on demand and sourced once per shell session; only those listed in the three prompt arrays are executed when the prompt renders.
- **Async rendering** -- Expensive segments (SCM status, language versions, cloud profiles) run in independent background jobs backed by per-segment cache files, so the prompt appears instantly and updates in place as fresh results arrive.

## Prompt Layout

The prompt is divided into three configurable zones, each backed by a Bash array:

| Array                 | Position    | Default segments                                              |
|-----------------------|-------------|---------------------------------------------------------------|
| `GAUDI_PROMPT_RIGHT`  | Right-aligned on the first line | `battery`, `time`, `user`, `host`          |
| `GAUDI_PROMPT_LEFT`   | Left-aligned on the first line  | `multiplexer`, `duration`, `cwd`           |
| `GAUDI_PROMPT_ASYNC`  | Appended after LEFT (rendered asynchronously) | `scm`, `aws`, `docker`, `node`, `ruby`, `elixir`, `golang`, `angular`, `react`, `php`, `rust`, `haskell`, `julia`, `pyenv`, `elm`, `java`, `package` |

When `GAUDI_SPLIT_PROMPT=true` (the default), the right-aligned and left-aligned zones occupy the same line with the right portion pushed to the terminal edge:

```
                        [battery] [time] [user] [host]   <-- RIGHT (right-aligned)
[multiplexer] [duration] [cwd]  [scm] [node] [docker] ...  <-- LEFT + ASYNC

>> _
```

When `GAUDI_SPLIT_PROMPT=false`, all zones are concatenated on a single line without right-alignment:

```
[battery] [time] [user] [host] [cwd] [scm] [node] [docker] ...

>> _
```

The prompt character (`>>`) appears on the line below. It is green on success and can be customized via the `char` segment.

## Configuration

### Global Variables

All global variables use Bash default-value assignment (`${VAR=default}`), so any value you export **before** the theme loads takes precedence.

| Variable | Default | Description |
|----------|---------|-------------|
| `GAUDI_SPLIT_PROMPT` | `true` | When `true`, right-prompt segments are right-aligned on the first line. When `false`, all segments render inline from left to right. |
| `GAUDI_SPLIT_PROMPT_TWO_LINES` | `false` | When `true` (and split prompt is enabled), a newline separates the right and left sections instead of a carriage return on the same line. |
| `GAUDI_ENABLE_SYMBOLS` | `true` | When `true`, Nerd Font glyphs are used for segment icons. When `false`, the segment name is displayed as a plain-text fallback. |
| `GAUDI_ENABLE_HUSHLOGIN` | `true` | Controls whether the login banner is suppressed. |
| `GAUDI_PROMPT_DEFAULT_PREFIX` | `" "` (space) | Default string prepended to every segment's content. Individual segments can override this. |
| `GAUDI_PROMPT_DEFAULT_SUFFIX` | `" "` (space) | Default string appended to every segment's content. Individual segments can override this. |

## Async Rendering

Many segments -- particularly SCM, language runtimes, and cloud profiles -- involve shelling out to external commands (`git`, `node`, `docker`, `aws`, etc.) which can introduce noticeable latency. Gaudi solves this with a file-backed background rendering pipeline:

1. **Initial draw** -- When the prompt hook fires, `GAUDI_PROMPT_LEFT` and `GAUDI_PROMPT_RIGHT` are rendered synchronously. For the async zone, Gaudi reads the last known output for each segment from `${XDG_CACHE_HOME:-$HOME/.cache}/gaudi-bash/theme/gaudi`.
2. **Global segment priming** -- Uncached global segments such as `aws` and `kubecontext` are rendered synchronously once so a fresh shell does not show a blank prompt and then pop in later.
3. **Per-segment refresh** -- Every segment in `GAUDI_PROMPT_ASYNC` is refreshed in its own background job. Slow segments no longer block unrelated async segments from appearing.
4. **Generation guard** -- Each prompt render increments a generation id. Background jobs compare against the current generation before updating cache or repainting, which prevents stale jobs from redrawing over newer prompts.
5. **In-place overwrite** -- When a segment changes, Gaudi reconstructs the async zone from cache files and redraws only the current prompt.

This design ensures that:
- The prompt appears without delay.
- Global segments can appear immediately on a cold start.
- Results persist between renders and shell starts.
- Slow external commands never block interactive typing or unrelated async segments.

## Available Segments

### Shell Context

| Segment | Description |
|---------|-------------|
| `char` | Prompt character (`>>`). Changes color based on last command exit status (green on success, red on failure). |
| `continuation` | PS2 continuation prompt character displayed during multi-line input. |
| `cwd` | Current working directory with intelligent path shortening. Shows a lock indicator when the directory is not writable. Optionally displays file count and total size. |
| `duration` | Execution time of the last command. Only appears when the command exceeded a configurable threshold (default: 1 second). |
| `host` | Hostname. Highlights differently when connected via SSH. |
| `jobs` | Number of background jobs. Only appears when the count meets a configurable threshold. |
| `multiplexer` | Detached tmux and GNU Screen session counts. |
| `separator` | Inserts a newline to split the prompt across multiple lines. |
| `shlvl` | Current shell nesting level (`SHLVL`). Useful for detecting nested shells spawned from editors or nix-shell. Only shown when depth exceeds a threshold (default: 2). |
| `system` | System statistics: CPU load, memory usage, and disk usage. |
| `time` | Current time in a configurable format (default: `HH:MM`). |
| `user` | Username. Visibility can be set to `always`, `true` (show if needed or on SSH), `needed`, or `false`. Root users are highlighted in red. |
| `battery` | Battery level and charging status with threshold-based visibility. |
| `vpn` | Indicates when the connection is routed through a VPN. |

### Version Control

| Segment | Description |
|---------|-------------|
| `scm` | Source control management. Shows the current ref plus ahead/behind, stash, merge/rebase state, and Git counters such as `+:N` (staged), `!:N` (changed), `?:N` (untracked), and `x:N` (conflicted). The background changes with repo state: green (clean), orange (staged only), yellow (working tree changes), red (conflicts). Supports Git, Mercurial, and others. |

### Languages and Runtimes

| Segment | Description |
|---------|-------------|
| `node` | Node.js version via nvm, nodenv, or the system binary. Shown in directories containing `package.json`, `node_modules`, or `.js` files. |
| `ruby` | Ruby version via chruby, rbenv, rvm, or the system binary. Shown in directories with Ruby project markers. |
| `elixir` | Elixir version. Shown in directories containing `mix.exs`. |
| `golang` | Go version. Shown in directories containing `.go` files or `go.mod`. |
| `php` | PHP version. Shown in directories containing PHP project files. |
| `rust` | Rust version and optional toolchain. Shown in directories containing `Cargo.toml`. |
| `haskell` | Haskell Stack version. Shown in directories containing `stack.yaml`. |
| `julia` | Julia version. Shown in directories containing `Project.toml` or `.jl` files. |
| `pyenv` | Python version via pyenv. Shown in directories containing Python project markers. |
| `java` | Java version. Shown in directories containing Java project files. |
| `elm` | Elm version. Shown in directories containing `elm.json` or `elm-package.json`. |
| `swift` | Swift version. Shown in directories containing `Package.swift`. Supports local-only or global display. |
| `dotnet` | .NET SDK version. Shown in directories containing .NET project files. |
| `conda` | Active Conda environment name. |

### Infrastructure

| Segment | Description |
|---------|-------------|
| `aws` | Active AWS CLI profile (`AWS_DEFAULT_PROFILE` / `CURRENT_AWS_PROFILE`). Hidden when set to `default`. |
| `docker` | Docker daemon version. Shown in directories containing `Dockerfile` or `docker-compose.yml`. |
| `dockercompose` | Docker Compose service status with up/down indicators. |
| `gcloud` | Active Google Cloud SDK configuration/project. |
| `kubecontext` | Current Kubernetes context and namespace from `kubectl`. |
| `terraform` | Terraform workspace. Shown in directories containing `.tf` files. |
| `vagrant` | Vagrant machine status. Shown in directories containing a `Vagrantfile`. |
| `nix` | Indicates when running inside a Nix shell environment. |

### Build Tools

| Segment | Description |
|---------|-------------|
| `gradle` | Gradle version. Shown in directories containing Gradle project files. |
| `maven` | Maven version. Shown in directories containing `pom.xml`. |
| `package` | Current package version from `package.json` (NPM). |
| `xcode` | Xcode version on macOS. Supports local-only or global display. |

### Frontend Frameworks

| Segment | Description |
|---------|-------------|
| `angular` | Angular version. Shown in directories with Angular project markers. |
| `react` | React version. Shown in directories with React dependencies. |
| `ember` | Ember.js version. Shown in directories with Ember project markers. |

## Per-Segment Configuration

Every segment follows a consistent configuration pattern using environment variables prefixed with `GAUDI_<SEGMENT>_`. The common variables are:

| Variable Pattern | Purpose | Example |
|------------------|---------|---------|
| `GAUDI_<SEGMENT>_SHOW` | Enable or disable the segment (`true` / `false`). | `GAUDI_NODE_SHOW=false` |
| `GAUDI_<SEGMENT>_COLOR` | ANSI color code (foreground and/or background). | `GAUDI_NODE_COLOR="$GAUDI_YELLOW"` |
| `GAUDI_<SEGMENT>_SYMBOL` | Nerd Font glyph or text displayed before the content. | `GAUDI_NODE_SYMBOL="\ue74e"` |
| `GAUDI_<SEGMENT>_PREFIX` | String prepended to the segment output. | `GAUDI_NODE_PREFIX=" "` |
| `GAUDI_<SEGMENT>_SUFFIX` | String appended to the segment output. | `GAUDI_NODE_SUFFIX=" "` |

Some segments expose additional variables. For example:

- `GAUDI_NODE_DEFAULT_VERSION` -- Hide the segment when the active version matches this value.
- `GAUDI_BATTERY_THRESHOLD` -- Only show battery when the charge is below this percentage.
- `GAUDI_DURATION_MIN_SECONDS` -- Minimum command duration (in seconds) before the segment appears.
- `GAUDI_SCM_FETCH` -- Whether to run `git fetch` automatically.
- `GAUDI_RUST_SHOW_TOOLCHAIN` -- Display the active Rust toolchain alongside the version.
- `GAUDI_CWD_SHORTEN` -- Intelligently shorten long directory paths.
- `GAUDI_CWD_SUMMARY` -- Append file count and directory size to the path.
- `GAUDI_SHLVL_THRESHOLD` -- Minimum shell depth before the segment appears.

Refer to the header of each segment file in `segments/` for the full list of supported variables.

## Customizing the Prompt

Override the prompt arrays in your `~/.bash_profile` (or `~/.bashrc`) **before** the theme is sourced. For example, to show only the working directory and Git status on the left, move time to the right, and limit async segments:

```bash
# ~/.bash_profile

GAUDI_PROMPT_LEFT=(
  cwd
)

GAUDI_PROMPT_RIGHT=(
  time
)

GAUDI_PROMPT_ASYNC=(
  scm
  node
)
```

You can also add segments that are not in the defaults. Any `.bash` file in the `segments/` directory can be referenced by name (without the extension):

```bash
GAUDI_PROMPT_ASYNC=(
  scm
  node
  kubecontext
  terraform
  conda
)
```

To disable a single segment without modifying the arrays, set its `_SHOW` variable:

```bash
GAUDI_DOCKER_SHOW=false
GAUDI_AWS_SHOW=false
```

## Creating Custom Segments

To add a new segment, create a file in the `segments/` directory following this template:

```bash
#!/usr/bin/env bash
#
# My Segment
#
# Brief description of what this segment displays.

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

GAUDI_MYSEGMENT_SHOW="${GAUDI_MYSEGMENT_SHOW=true}"
GAUDI_MYSEGMENT_PREFIX="${GAUDI_MYSEGMENT_PREFIX="$GAUDI_PROMPT_DEFAULT_PREFIX"}"
GAUDI_MYSEGMENT_SUFFIX="${GAUDI_MYSEGMENT_SUFFIX="$GAUDI_PROMPT_DEFAULT_SUFFIX"}"
GAUDI_MYSEGMENT_SYMBOL="${GAUDI_MYSEGMENT_SYMBOL="\\uf111"}"
GAUDI_MYSEGMENT_COLOR="${GAUDI_MYSEGMENT_COLOR="$GAUDI_GREEN"}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

gaudi_mysegment () {
  # Early return if disabled
  [[ $GAUDI_MYSEGMENT_SHOW == false ]] && return

  # Check that the relevant tool exists
  gaudi::exists mytool || return

  # Gather information
  local content
  content="$(mytool --version 2>/dev/null)"
  [[ -z "$content" ]] && return

  # Render the section
  gaudi::section \
    "$GAUDI_MYSEGMENT_COLOR" \
    "$GAUDI_MYSEGMENT_PREFIX" \
    "$GAUDI_MYSEGMENT_SYMBOL" \
    "$content" \
    "$GAUDI_MYSEGMENT_SUFFIX"
}
```

Key rules:

1. The filename must match the segment name: `segments/mysegment.bash`.
2. The entry-point function must be named `gaudi_<segment>` (matching the filename).
3. Use `gaudi::exists` to check for external commands and return early if they are not available.
4. Use `gaudi::section` to produce correctly formatted and colored output.
5. Add context detection (check for project files, environment variables, etc.) so the segment only appears when relevant.

Then add the segment name to one of the prompt arrays:

```bash
GAUDI_PROMPT_ASYNC+=( mysegment )
```
