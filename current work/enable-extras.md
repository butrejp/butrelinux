# butrelinux Extras — Current Status

## Overview

The butrelinux extras project is currently in the **beta/prototyping stage**. The basic architecture has been validated: applications can live in a separate Distrobox container, while their desktop integration and host interaction are exposed through Distrobox rather than modifying the immutable host OS.

The current implementation uses a **state-aware, locally-built container model**. Instead of a monolithic prebuilt image, the script presents a package-selection UI, generates a temporary Containerfile, builds a user-specific image locally, and manages the lifecycle of the `extras` Distrobox container through a marker-file state machine.

The overall goal is to provide an application environment that is **isolated from the host OS while remaining integrated enough to behave like locally installed software**.

## Architecture

```text
butrelinux host
    │
    ├── whiptail package-selection UI
    │
    ├── state machine (marker file + container presence)
    │       │
    │       ├── fresh install → build image → create Distrobox → mark
    │       ├── adopt unmanaged → mark → inject packages
    │       ├── stale state → rebuild → recreate → mark
    │       └── managed → inject packages idempotently
    │
    └── extras Distrobox
            ├── applications
            ├── configuration
            ├── caches
            └── application state
```

The core philosophy is that **the host remains boring and immutable, while the extras container is the place where mutable application state belongs**.

## Dynamic Local Images

The script implements the eventual architecture:

1. Present a package-selection UI via `whiptail`.
2. Generate a temporary Containerfile.
3. Start from Fedora Minimal (`quay.io/fedora/fedora-minimal:44`).
4. Install `dnf5` and the Terra repository configuration.
5. Install only the selected applications with `--setopt=install_weak_deps=False`.
6. Build the resulting image locally.
7. Create the Distrobox from that image.

Resulting images are substantially smaller than the original prototype. Current testing produced images around **1.36–1.40 GB** compared with the 5.39 GB preassembled development image. The Fedora Minimal base itself is approximately 140 MB.

This validates the premise that the final implementation can produce an application environment whose size is roughly proportional to what the user actually chooses to install.

## State Machine

The script distinguishes between four states using a marker file (`~/.local/share/butrelinux-extras/managed`) and the presence of a Distrobox container named `extras`:

| `extras` container | Marker  | Action                                                 |
| ------------------ | ------- | ------------------------------------------------------ |
| Missing            | Missing | Fresh installation: build image, create box, mark    |
| Exists             | Missing | Ask permission to adopt/mutate it; if yes, mark + inject |
| Missing            | Exists  | Stale managed state; proceed with recreation           |
| Exists             | Exists  | Existing managed installation; inject packages into it |

The marker represents **management/ownership, not container state**. If an unrelated Distrobox happens to be named `extras`, the program does not automatically modify it. Instead, it asks the user whether to adopt it. Once adopted, the marker is created and future invocations treat the container as managed.

## Idempotent Package Injection

For managed containers, the script does **not** rebuild the image or recreate the Distrobox. Instead, it:

1. Queries the existing container with `rpm -q` to determine which selected packages are already installed.
2. Lists already-installed packages as skipped.
3. Installs only the missing packages via `distrobox enter … dnf5 install`.
4. If all packages are already present, exits cleanly with a message.

This makes the container effectively **stateful and incrementally expandable**. Rebuilding an image every time the user wants another application is unnecessary. Once an `extras` container exists, installing additional applications directly into it is the normal path.

For adopted containers that may lack the Terra repository, the script attempts an idempotent Terra setup before installing.

## Distrobox Integration

The container is created as `extras` and receives the following integration:

* Desktop applications are exported with `distrobox-export`.
* `xdg-open` delegates to the host through `distrobox-host-exec`.
* `flatpak` delegates to the host.
* Bash's `command_not_found_handle` delegates unknown commands to the host.
* Zsh's `command_not_found_handler` is mapped to the same mechanism.
* NVIDIA hosts are detected using `/usr/share/ublue-os/image-info.json` and receive Distrobox's `--nvidia` option.

The container therefore feels like an extension of the host rather than an isolated workstation.

## Container State

The current direction **does not treat the Distrobox container as immutable state**.

The container is expected to become stateful. Application configuration, caches, Steam data, editor configuration, OBS configuration, and similar state live inside the Distrobox environment rather than being added to the immutable host OS.

If the container becomes unusable, it can be removed and recreated without compromising the host operating system. The marker file can be removed manually to force a fresh installation path.

## Package Selection

The UI uses `whiptail` and selects individual packages. The current package catalog includes:

* **Gaming**: Steam, MangoHud, GameMode, vkBasalt, Vulkan tools
* **Development**: VSCodium, Neovim, Github Desktop Plus
* **Communication**: Vesktop, Fluxer, Signal Desktop, Nheko
* **Media/Creative**: OBS Studio, VLC, Krita, GIMP, Inkscape, Blender, Kdenlive
* **Web/Network**: Firefox, Firefox language packs, Thunderbird, Chromium, qBitTorrent, FileZilla

The initial implementation deliberately keeps this simple: `whiptail` → package names → container builder. There is no complicated package metadata system yet.

## Future Package Organization

Package groups are likely to be added later, but they should primarily function as **organization/navigation**, rather than automatically installing arbitrary collections of applications.

For example:

```text
Gaming
    Steam
    MangoHud
    GameMode
    vkBasalt

Development
    VSCodium
    Neovim

Communication
    Vesktop
    Fluxer
    Signal
    Nheko

Media
    OBS Studio
    VLC
```

Selecting the "Media" category would not mean installing both OBS and VLC. It would simply provide a logical place to find those applications.

Actual package bundles could potentially be added later where there is a genuinely useful relationship between the applications, but individual package selection remains the fundamental primitive.

The desired model is:

> **Categories organize; bundles suggest; packages are what actually get installed.**

## Base Image

Fedora Minimal is currently the preferred base.

Alpine has been considered because of its small footprint, but it would introduce additional compatibility questions around musl, desktop applications, RPM-based repositories, Steam, Vulkan, NVIDIA integration, and general application expectations.

Fedora Minimal already provides a conventional environment for the RPM ecosystem being used, so there is currently little reason to introduce Alpine complexity merely to reduce the base image.

If Distrobox's requirements make `microdnf` or Fedora Minimal awkward, a small maintained Fedora-derived base image may eventually be used. That would still be fundamentally different from the original 5.39 GB image.

## Current Development Status

The important architectural experiments have succeeded:

* A Fedora Minimal base works for the intended container model.
* Applications can be installed dynamically rather than being baked into one giant image.
* `install_weak_deps=False` produces substantially more appropriately sized environments.
* Locally generated images in the 1–1.5 GB range are achievable for useful application selections.
* The existing Distrobox integration can be reused.
* The container can reasonably be treated as persistent application state.
* A large prebuilt GHCR image is unnecessary for the final user experience.
* A marker-file state machine correctly handles fresh installs, adoptions, stale state, and managed incremental updates.
* Idempotent package injection avoids unnecessary rebuilds and provides clear feedback on already-installed packages.

The next significant implementation steps may include:

* Category-based organization in the `whiptail` UI.
* A `--remove` or `--uninstall` mode for removing packages from the managed container.
* A `--re-export` flag for re-running desktop application export and host integration.
* Storing additional metadata in the marker file (installed package list, image hash, last-run timestamp).

## Intended End State

The current architectural direction can be summarized as:

```text
                 butrelinux host
                       │
                       │
                 whiptail UI
                       │
              package selection
                       │
             ┌─────────┴─────────┐
             │                   │
       no managed extras    managed extras
             │                   │
       build local image    inject packages
             │                   │
             └─────────┬─────────┘
                       │
                  Distrobox
                    "extras"
                       │
          ┌────────────┼────────────┐
          │            │            │
       GUI apps     host exec    app state
          │            │            │
          └────────────┴────────────┘
                       │
                immutable host
```

The original 5.39 GB BlueBuild image has served its purpose as a rapid-iteration fixture. The emerging local-build approach with state-aware lifecycle management is the path toward the actual polished implementation.

## Host Package Duplicates

There are some packages duplicated from the host. These will eventually be removed from the host environment and live in extras. The most notable example is Firefox. Some users may prefer a different web browser, so keeping the host minimal and offering browser choice through extras is the intended direction.
