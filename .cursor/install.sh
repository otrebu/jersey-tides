#!/usr/bin/env bash
# Cloud Agent install for jersey-tides.
#
# Node/pnpm is the primary dev environment (demo site + published packages + the
# Scriptable iOS widget, all cross-platform). The native ios/ SwiftUI app and
# WidgetKit extension require full Xcode and can only be built on macOS, so they
# are out of scope on a Linux Cloud Agent. The ios/TidesCore engine package is
# pure Foundation, so its `swift test` fixture-parity gate runs here once a Swift
# toolchain is installed (best-effort below).
set -eo pipefail

# --- Node / pnpm workspace (required) ---------------------------------------
# The repo requires Node >=22.18; select it via nvm because the default on-PATH
# node can be older and breaks tsdown.
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
. "$NVM_DIR/nvm.sh"
nvm use 22
corepack enable 2>/dev/null || true

pnpm install --frozen-lockfile
# Build the workspace: apps/demo consumes @u-b/tides-react through its dist
# exports, so the libs must be built for `pnpm dev` to resolve them. Also builds
# the Scriptable iOS widget (targets/scriptable -> dist/Tides.js).
pnpm -r build

# --- Swift toolchain for ios/TidesCore (best-effort) ------------------------
# Non-fatal: a Swift download hiccup must not take down the primary JS/TS env.
if command -v swift >/dev/null 2>&1 || [ -x "$HOME/.local/share/swiftly/bin/swift" ]; then
  echo "[install] Swift toolchain already present; skipping ios/TidesCore toolchain setup."
else
  echo "[install] Installing Swift toolchain via swiftly (enables 'swift test' in ios/TidesCore)..."
  # Run `swiftly init` from $HOME so it does not drop a stray .swift-version in
  # the checked-out repo; the global default toolchain still applies in /workspace.
  if {
    sudo apt-get update -qq &&
    sudo apt-get install -y -qq gnupg2 libcurl4-openssl-dev libpython3-dev \
      libxml2-dev libncurses-dev libz3-dev &&
    curl -fsSL -o /tmp/swiftly.tar.gz \
      "https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz" &&
    tar -xzf /tmp/swiftly.tar.gz -C /tmp &&
    ( cd "$HOME" && /tmp/swiftly init --assume-yes --quiet-shell-followup )
  }; then
    echo "[install] Swift toolchain installed."
  else
    echo "[install] WARNING: Swift toolchain setup failed; ios/TidesCore 'swift test' will be unavailable." >&2
  fi
fi
