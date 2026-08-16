# butrelinux Extras — Current Status

## Overview

The butrelinux extras project is currently in the **beta/prototyping stage**. The basic architecture has been validated: applications can live in a separate Distrobox container, while their desktop integration and host interaction are exposed through Distrobox rather than modifying the immutable host OS.

The current prototype uses a preassembled container image purely to make rapid iteration practical. The eventual implementation will build a smaller, user-specific container locally based on the applications selected through a terminal UI.

The overall goal is to provide an application environment that is **isolated from the host OS while remaining integrated enough to behave like locally installed software**.

## Current Prototype

The original prototype uses a BlueBuild recipe based on Fedora Minimal:

```text
Fedora Minimal
    ↓
dnf5 + repositories
    ↓
large predefined application set
    ↓
GHCR image
    ↓
Distrobox
```

The image contains applications such as Steam, MangoHud, GameMode, VSCodium, Neovim, Vesktop, Signal, OBS Studio, VLC, Firefox, and others.

This image intentionally contains far more software than a final installation should. Its purpose is to avoid repeatedly waiting for package installation while developing and testing the Distrobox integration.

The resulting image is about **5.39 GB**.

That size is considered acceptable for the development fixture but is not appropriate as the polished user experience.

## Dynamic Local Images

The first implementation of the eventual architecture has now been tested successfully.

Instead of starting from the large preassembled image, the script can:

1. Present a package-selection UI.
2. Generate a temporary Containerfile.
3. Start from Fedora Minimal.
4. Install `dnf5` and the necessary repository configuration.
5. Install only the selected applications.
6. Use:

```text
--setopt=install_weak_deps=False
```

7. Build the resulting image locally.
8. Create the Distrobox from that image.

The resulting images are substantially smaller. Current testing produced images around:

```text
1.36 GB
1.40 GB
```

compared with the 5.39 GB preassembled development image.

The Fedora Minimal base itself is approximately 140 MB.

This validates the basic premise that the final implementation can produce an application environment whose size is roughly proportional to what the user actually chooses to install.

## Distrobox Integration

The existing Distrobox integration is already fairly mature and is intended to remain largely unchanged.

The container is created as:

```text
extras
```

and receives the following integration:

* Desktop applications are exported with `distrobox-export`.
* `xdg-open` delegates to the host through `distrobox-host-exec`.
* `flatpak` delegates to the host.
* Bash's `command_not_found_handle` delegates unknown commands to the host.
* Zsh's `command_not_found_handler` is mapped to the same mechanism.
* NVIDIA hosts are detected using the existing `/usr/share/ublue-os/image-info.json` logic and receive Distrobox's `--nvidia` option.

The container is therefore intended to feel like an extension of the host rather than an isolated workstation.

## Container State

The current direction intentionally **does not treat the Distrobox container as immutable state**.

The container is expected to become stateful.

That is desirable because application configuration, caches, Steam data, editor configuration, OBS configuration, and similar state can live inside the Distrobox environment rather than being added to the immutable host OS.

The container is therefore effectively a disposable application environment:

```text
butrelinux host
    │
    └── extras Distrobox
          ├── applications
          ├── configuration
          ├── caches
          └── application state
```

If the container becomes unusable, it can be removed and recreated without compromising the host operating system.

Consequently, rebuilding an image every time the user wants another application is not necessarily desirable. Once an `extras` container exists, installing another application directly into it is perfectly acceptable.

## Existing-Container Decision Tree

The next iteration will distinguish between a fresh installation, an existing but unmanaged container, and an existing managed installation.

A marker file will establish that the `extras` container is managed by butrelinux extras.

The intended decision tree is:

| `extras` container | Marker  | Action                                                 |
| ------------------ | ------- | ------------------------------------------------------ |
| Missing            | Missing | Fresh installation                                     |
| Exists             | Missing | Ask permission to adopt/mutate it                      |
| Missing            | Exists  | Stale managed state; proceed with recreation           |
| Exists             | Exists  | Existing managed installation; inject packages into it |

The important distinction is that **the marker represents management/ownership, not container state**.

If an unrelated Distrobox happens to be named `extras`, the program should not automatically modify it.

Instead, it should ask the user whether they want butrelinux extras to adopt and modify that container.

Once adopted, the marker can be created and future invocations can safely treat the container as managed.

## Package Selection

The initial UI will use `whiptail` and select individual packages.

The package catalog currently includes applications such as:

* Steam
* MangoHud
* GameMode
* vkBasalt
* Vulkan tools
* VSCodium
* Neovim
* Vesktop
* Fluxer
* Signal Desktop
* Nheko
* OBS Studio
* VLC
* Firefox

The initial implementation deliberately keeps this simple:

```text
whiptail
    ↓
package names
    ↓
container builder
```

There is no need to build a complicated package metadata system yet.

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

If Distrobox's requirements make `microdnf` or Fedora Minimal awkward, a small maintained Fedora-derived base image may eventually be used.

That would still be fundamentally different from the current 5.39 GB image:

```text
maintained base image
    +
selected applications
    =
local extras environment
```

The maintained image would contain only the substrate required to reliably build and run the Distrobox environment.

## Current Development Status

At this point, the important architectural experiment has succeeded.

The prototype has demonstrated that:

* A Fedora Minimal base works for the intended container model.
* Applications can be installed dynamically rather than being baked into one giant image.
* `install_weak_deps=False` produces substantially more appropriately sized environments.
* Locally generated images in the 1–1.5 GB range are achievable for useful application selections.
* The existing Distrobox integration can be reused.
* The container can reasonably be treated as persistent application state.
* A large prebuilt GHCR image is unnecessary for the final user experience.

The next significant implementation step is therefore **not container optimization**. It is turning the prototype into a state-aware frontend that can distinguish between:

```text
new installation
existing unmanaged "extras"
existing managed "extras"
stale managed state
```

and then choose between building a new container and installing additional packages into the existing one.

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

The core philosophy is that **the host remains boring and immutable, while the extras container is the place where mutable application state belongs**.

The current 5.39 GB BlueBuild image has served its purpose as a rapid-iteration fixture. The emerging local-build approach is the path toward the actual polished implementation.



for the current implementation see files/system/usr/bin/enable-extras  
NOTE: there are some packages duplicated from the host.  these will eventually be removed from the host environment and live in extras.  most notable example is firefox.  I figure some people might want a different web browser.

