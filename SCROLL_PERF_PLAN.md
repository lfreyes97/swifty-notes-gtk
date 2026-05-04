# Scroll-perf refactor plan (Linux profiling + MarkdownPreview rework)

This is a working document. Picks up on a Linux dev box from where the
macOS scroll-perf investigation left off. Delete (or fold into a CHANGELOG
entry) once the refactor lands and the underlying issue
[#1](https://github.com/makoni/swift-adwaita/issues/1) is resolved.

## Background

Scroll jitter is reported by Linux Flathub users (issue #1 in the
upstream `swift-adwaita` repo) and was reproduced on macOS during the
1.3.0 port. On macOS the symptoms were:

- subtle lag when scrolling note content in **Split mode** on a
  trackpad
- sidebar list felt OK after disabling overlay+kinetic scrolling
  (commit `a59a78e`)

The cheap macOS-specific fixes (kinetic scrolling off, overlay
scrollbars off) are landed and gated to `#if os(macOS)`. The remaining
jitter is **architectural and cross-platform** — same reason Linux
users report it.

## What we know (from macOS Time Profiler)

Two profiles were captured: default `opengl` renderer and forced
`cairo` renderer. Normalized per second of capture they are nearly
identical:

| | OpenGL renderer | Cairo renderer |
|---|---:|---:|
| `gtk_widget_render` | 435 ms/s | 449 ms/s |
| Main-thread % | ~50% | ~58% |
| Where the time goes | GPU shader ops via Apple GL→Metal shim | Recursive `gsk_render_node_draw_full` chain |

**Key conclusion:** the GL→Metal compatibility layer on macOS is **not**
the bottleneck. If it were, Cairo (which bypasses GL entirely) would
be visibly faster. It isn't. So:

- **Vulkan via MoltenVK is not worth pursuing** — would be the same
  ~10% the renderer choice already costs us.
- **The cost is the scenegraph itself**: deep recursive widget tree
  rebuilt every frame.

Specific signals from the Cairo profile (`prof4.txt`):

- `gsk_render_node_draw_full` recurses 30+ levels deep on a long
  markdown note → each Box, Label, Image, SourceView is its own GTK
  widget node, and the renderer walks all of them per frame.
- `gsk_texture_node_draw` 178 ms / `gdk_memory_convert` 135 ms — every
  image block converts pixel format (`r8g8b8a8 → b8g8r8a8 premultiplied`)
  on every frame, even though the image data hasn't changed.
- `pango_cairo_renderer_show_text_glyphs_range` adds up to ~150 ms of
  text rasterization across the call sites visible in the trace.

**Profile sizes for reference:** the macOS Time Profiler dumps lived in
`~/Downloads/prof{1,2,3,4}.txt` during the investigation. They're not
checked in.

## Hypothesis to validate on Linux

> The scroll-frame budget is dominated by walking and re-rendering the
> deep `MarkdownPreview` widget tree. Per-frame texture decoding for
> image blocks is a secondary contributor.

If true, on Linux we should see:

1. `sysprof` marks attribute most of the render frame to per-widget
   layout/render in `MarkdownPreview` subtree
2. FPS during scroll on a long demo note (the seeded Markdown
   Showcase) sits visibly below 60 — somewhere in the 30–50 range
3. Widget-count for the rendered preview of a long note runs into
   hundreds of nodes

Linux is the better platform to confirm this because:

- `sysprof` has GTK4 integration: per-widget layout/render timings are
  emitted as marks. macOS Time Profiler shows only function names.
- The Linux GL/Vulkan path isn't behind a compat shim, so the trace
  is clean — what you see is the real cost.
- Issue #1 reporters are on Linux; perf wins should be measured on
  the platform where users feel them.

## Linux profiling toolkit — concrete commands

Pre-reqs (Ubuntu 24.04 / Fedora 40):

```bash
# Ubuntu/Debian
sudo apt install sysprof linux-tools-common linux-tools-generic
# Fedora
sudo dnf install sysprof perf
```

Build the app for profiling (Release-equivalent, with debug symbols):

```bash
swift build -c release -Xswiftc -g
# binary lands at .build/release/swiftynotes
```

### 1. FPS baseline measurement (do this first)

```bash
GSK_DEBUG=fps .build/release/swiftynotes
```

Open a long seeded note (`Markdown Showcase`), enter Split view,
scroll the editor for 10 s on each input device (trackpad if laptop,
mouse wheel, scrollbar drag). Note the on-screen FPS overlay.

**Baseline target:** record the FPS for each scenario in this file
under "Measured baseline" below. This is the regression metric for
later comparison.

### 2. sysprof — find the dominant widgets

```bash
sysprof
# In the GUI: New Recording → Command line: .build/release/swiftynotes
# Click Record, scroll the same long note for 10 s, click Stop.
```

What to look for in the timeline:

- **Marks track**: GTK4 emits marks named like `gtk_widget_snapshot`,
  `gsk_renderer_render`, `layout pass`. Filter for the `Markdown` /
  `Preview` widget classes — they should dominate during scroll
  frames.
- **CPU usage callgraph**: drill into hottest stacks, expect
  `gsk_render_node_draw_full` recursion + `gdk_memory_convert` for
  textures.

If the callgraph instead shows time concentrated in scroll input
handlers, signal emission, or main-loop overhead — the hypothesis is
wrong and we need to re-think before refactoring.

### 3. GtkInspector — see the widget tree

```bash
GTK_DEBUG=interactive .build/release/swiftynotes
```

In the inspector window:

- **Objects** tab: navigate to the open note's `MarkdownPreview`,
  expand the `Box → Box → ScrolledWindow → Viewport → Box` chain.
  Count nodes. For a long note expect 100s of widgets.
- **Recordings** tab (Linux only): click record, scroll for a few
  seconds, stop. Inspect the captured render-tree per frame — shows
  the actual `GskRenderNode` graph.

### 4. GSK cache pressure (for the texture-decode hypothesis)

```bash
GSK_DEBUG=cache-pressure .build/release/swiftynotes
```

Logs hit/miss rate on GSK's internal texture cache. If the texture
cache is thrashing during scroll on a note with images, option (a)
below (texture caching) becomes high-value.

## Optimization options, ranked by leverage

### Option A — Cache decoded textures (low risk, low-mid reward)

Profile signal: `gdk_memory_convert` 135 ms, called per frame per
image block. The conversion R8G8B8A8 → B8G8R8A8 premultiplied is
deterministic and reusable.

**Where:** `Sources/SwiftyNotes/UI/MarkdownPreview.swift`,
`makeBlockImageWidget(alt:source:title:)` and `loadBlockImage(at:into:clamp:)`.
Currently each block image creates a fresh `Picture` widget and the
underlying `GdkTexture` chain decodes/converts on each draw.

**Approach:** keep a `[URL: GdkTexture]` cache (NSCache or simple
dictionary keyed on resolved file URL + mtime) of pre-converted
textures, hand the cached texture to `Picture.paintable = ...`
instead of re-loading. Invalidate on note edit / image file mtime
change.

**Expected win:** 3–8% on notes with images, none on text-only notes.

**Risk:** low. Localized change, easy to test (image rendering
correctness + cache invalidation on file change).

### Option B — Collapse markdown blocks into fewer widgets (high reward, big rewrite)

Profile signal: `gsk_render_node_draw_full` recurses 30+ levels deep.
Each markdown block (heading, paragraph, image, code, list item)
becomes a separate `Box → Label/Picture/SourceView` subtree in
`MarkdownPreview.makeWidget(for:)`. For a long note that's hundreds
of widgets.

**Three sub-options, ranked by ambition:**

1. **Coalesce text-only blocks into one PangoLayout per
   contiguous run.** Adjacent paragraphs / headings / lists — anything
   that's pure text — render into a single `Label` with mixed Pango
   markup instead of one `Label` per block. Image / code-block / table
   nodes still render separately and break the run. Cuts widget
   count substantially (often 5–10×) without losing per-block selection
   behavior.

2. **Render the entire preview into a single `TextView`** with
   `GtkTextTag`s for styling. Loses per-block widget identity (no
   per-image clickability, no `SourceView` syntax highlighting in
   code blocks unless we render those into `Picture`s). Probably the
   wrong tradeoff for this app.

3. **Custom `Gtk.Widget` subclass** that owns its own `GskRenderNode`
   tree directly, bypassing the `Box`-of-children model. Most
   flexible, hardest to maintain, requires GObject subclassing in
   Swift via `swift-adwaita`'s C bridging.

**Recommended path:** start with B.1. It preserves the current API
surface (still a sequence of "blocks" exposed to layout code) but
cuts the actual GTK widget count where it matters most — in long
text-heavy notes which are exactly the case users scroll.

**Where:** `Sources/SwiftyNotes/UI/MarkdownPreview.swift`,
`render(blocks:baseDirectory:)` and `makeWidget(for:)`.

**Risk:** mid. Touches the rendered preview, the test suite
(`Tests/SwiftyNotesTests/MarkdownPreviewWidgetXCTests.swift` — and
its macOS XCTest mirrors) needs to be updated to match new widget
structure.

### Option C — Virtualize the preview pane (out of scope here)

GTK4 has `GtkListView` with `GtkListItemFactory` for virtualized
scrolling — only visible rows are realized. Could in principle apply
to `MarkdownPreview` if we model it as a list of blocks rather than
a `Box`-of-children. Big rewrite, parallel work to B.3. Don't pursue
unless A + B don't move the needle.

## Acceptance criteria

A scroll-perf change ships when:

1. **FPS regression-free**: GSK fps overlay during a 10-s scroll on
   the seeded `Markdown Showcase` note in Split view shows ≥ the
   pre-change FPS on Linux (X11 + Wayland) and macOS.
2. **FPS uplift on the scroll path**: same scenario shows a measurable
   win — at minimum +10 FPS, ideally pinned to vsync (60 / 120
   depending on display).
3. **No visual regression**: existing `MarkdownPreviewWidgetXCTests`
   (Linux native + macOS XCTest mirrors) all pass without weakening
   assertions.
4. **No new GLib criticals/warnings** in stderr during the test note
   render.
5. **Manual smoke**: scroll feels qualitatively smoother on each input
   device tested for the baseline.

Record before/after numbers for each platform under "Measured before /
after" sections below as you go.

## File map

Cross-platform code (always edit here, both OSes pick it up):

- `Sources/SwiftyNotes/UI/MarkdownPreview.swift` — the widget builder
- `Sources/SwiftyNotes/UI/MainWindow.swift` — owns editor↔preview
  scroll sync wiring
- `Sources/SwiftyNotes/UI/PreviewScrollSync.swift` — the sync helper
  itself (already shown to be cheap, 2 ms total in the macOS
  profile — leave alone)
- `Sources/SwiftyNotes/UI/NotesSidebar.swift` — already platform-tuned
- `Tests/SwiftyNotesTests/MarkdownPreviewWidgetXCTests.swift` — block
  rendering assertions, will need updating for B.1

macOS-only (don't touch from Linux):

- `Tests/SwiftyNotesTests/macOS/MarkdownPreviewWidgetXCTests.swift` —
  XCTest mirror, regenerate via `scripts/regenerate-macos-mirrors.sh`
  if assertions in the cross-platform test change
- `packaging/macos/**` — Xcode project, scheme, xcconfig

## Working notes (fill in as you go)

### Measured baseline

> Fill in once Linux profiling is done. Format:
> `<scenario>: <FPS> @ <renderer> on <platform>`
>
> Example:
> ```
> Split-view editor scroll, long Markdown Showcase note:
>   Linux/Wayland/ngl: 38–42 FPS (140Hz display, target 140)
>   Linux/X11/ngl:     45–52 FPS
>   macOS/Quartz/gl:   ~50–55 FPS (subjective, no fps overlay)
> ```

### Measured after option A

> Fill in.

### Measured after option B.1

> Fill in.

## Open questions / rabbit holes

- Does `GskCacheTexture` automatically dedupe `GdkTexture` instances
  loaded from the same `GFile`? If yes, option A is a no-op. Check via
  `GSK_DEBUG=cache-pressure` on a note with the same image used twice.
- Does Pango's text rendering reuse glyph rasterization across frames
  for unchanged Labels? `pango_cairo_renderer_show_text_glyphs_range`
  cost in the macOS profile suggests partial reuse only.
- Does GTK4 4.18+ on Linux distros expose the `gpu` renderer (Vulkan
  path)? If yes, worth one comparative profile — but only after the
  architectural fix; otherwise we're optimizing a slow path.
