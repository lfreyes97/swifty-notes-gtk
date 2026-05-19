# dmgbuild settings — produces a Finder-friendly drag-to-install DMG
# whose `.DS_Store` is written directly via the `ds_store` Python
# module instead of going through Finder + AppleScript. Tahoe's
# asynchronous `.DS_Store` writeback makes the AppleScript path
# (which `create-dmg` uses) silently lose the background image
# placement on a non-trivial fraction of runs; dmgbuild side-steps
# that entirely.

import os

# `defines` is the dict of `-D key=value` flags passed on the
# dmgbuild command line. Lets the caller plug in the actual .app
# path without editing this file.
application = defines.get("app")

# Rename the .app inside the DMG to the user-facing name. The Xcode
# project produces `swiftynotes.app` (matches PRODUCT_NAME =
# $(TARGET_NAME) at the target level, kept lowercase for parity with
# the SwiftPM executable name and Linux package naming), but Apple's
# convention is "Verbed Noun.app" with a space — so when the user
# drops onto /Applications they get the proper `/Applications/Swifty
# Notes.app`. dmgbuild's `(src, dst)` tuple syntax copies under the
# new filename; CFBundleDisplayName inside Info.plist still drives
# what shows up under the icon in Finder either way.
display_name = "Swifty Notes.app"

format = "UDZO"
filesystem = "HFS+"
size = None

files = [(application, display_name)]
symlinks = {"Applications": "/Applications"}

# Window geometry the user sees on first mount. Origin (200, 120) is
# arbitrary (Finder anchors to the screen the user has focus on);
# size is 600x400 to match the background PNG.
window_rect = ((200, 120), (600, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False

icon_size = 100
icon_locations = {
    display_name: (150, 200),
    "Applications": (450, 200),
}

# Background image. The path is resolved relative to the directory
# of the settings file (dmgbuild's own convention).
background = defines.get("background")
