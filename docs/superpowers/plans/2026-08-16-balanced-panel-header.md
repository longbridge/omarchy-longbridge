# Balanced Panel Header Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Balance the panel identity with a two-line title block and make the CLI installation guide accessible from the panel menu.

**Architecture:** Keep the header and guide-selection state local to `Panel.qml`. `PanelMenu.qml` emits an install-guide request, while `LongbridgeSetup.qml` exposes preview and dismissal properties without weakening mandatory first-run setup.

**Tech Stack:** QML, Bash source assertions, Omarchy plugin validation

## Global Constraints

- The title is `Longbridge` and the subtitle is `Markets & Portfolio`.
- The panel logo uses official brand colors; the bar icon remains monochrome.
- Mandatory first-run setup cannot be dismissed.
- Selecting `Install CLI` opens the installation guide even when setup is ready.

---

### Task 1: Balance the ready-state identity header

**Files:**
- Modify: `tests/test_panel_source.sh`
- Modify: `Panel.qml`
- Modify: `components/PanelMenu.qml`
- Modify: `components/LongbridgeSetup.qml`

**Interfaces:**
- Consumes: existing `panelHeader`, `headerLogo`, `panelMenu`, `root.foreground`, and `root.fontFamily` QML objects/properties
- Produces: a 24-unit `headerLogo`, centered `headerIdentityText` column, and `Install CLI` menu route to a dismissible manual guide

- [ ] **Step 1: Write the failing source assertions**

Add assertions for `width: Style.space(24)`, `id: headerIdentityText`, `text: "Markets & Portfolio"`, `text: "Install CLI"`, the install-guide signal, and the conditional Back action to `tests/test_panel_source.sh`.

- [ ] **Step 2: Run the focused source test and verify it fails**

Run: `bash tests/test_panel_source.sh`

Expected: FAIL because the 24-unit logo, subtitle, and install-guide route are absent.

- [ ] **Step 3: Implement the centered identity block**

In `Panel.qml`, set the logo width to `Style.space(24)`. Replace the title `Text` with a `Column` named `headerIdentityText`, anchored between the logo and menu and vertically centered. Give it two `Text` children: the existing bold title and a caption-sized `Markets & Portfolio` subtitle using 55% foreground opacity. Add `setupGuideOpen`; show only setup while it is true. In `PanelMenu.qml`, add `installCliRequested` and an `Install CLI` row. In `LongbridgeSetup.qml`, add `previewInstallGuide` and `dismissible`, render installation copy/actions for preview mode, and show a Back button only when dismissible.

- [ ] **Step 4: Run focused and complete verification**

Run: `bash tests/test_panel_source.sh && make validate`

Expected: both commands exit 0; shell-only QML import warnings may remain.

- [ ] **Step 5: Commit**

```bash
git add tests/test_panel_source.sh Panel.qml components/PanelMenu.qml components/LongbridgeSetup.qml docs/superpowers/specs/2026-08-16-balanced-panel-header-design.md docs/superpowers/plans/2026-08-16-balanced-panel-header.md
git commit -m "fix: balance panel identity header"
```
