#!/usr/bin/env bash
set -euo pipefail

# Adds the Swift packages (swift-perception) to a CMake-generated ARMSX2iOS Xcode
# project. Called by generate-ios-xcode.sh and generate-ios-sim-xcode.sh.
#
# Usage: add-swift-packages.sh <path/to/ARMSX2iOS.xcodeproj>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="${1:?usage: add-swift-packages.sh <path/to/ARMSX2iOS.xcodeproj>}"

if ! command -v ruby >/dev/null 2>&1; then
	echo "error: ruby is required to add the Swift packages (it ships with macOS)." >&2
	exit 1
fi

if ! ruby -e 'require "xcodeproj"' >/dev/null 2>&1; then
	echo "Installing the xcodeproj gem..."
	gem install xcodeproj --no-document --user-install
	GEM_USER_DIR="$(ruby -e 'print Gem.user_dir')"
	export GEM_PATH="$GEM_USER_DIR${GEM_PATH:+:$GEM_PATH}"
fi

ruby "$SCRIPT_DIR/add-swift-packages.rb" "$PROJECT"
