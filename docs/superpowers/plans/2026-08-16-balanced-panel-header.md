# Balanced Panel Header Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Balance the panel identity with a 24-unit color logo and a vertically centered two-line title block.

**Architecture:** Keep the header local to `Panel.qml`. Replace the single title text with a centered column while preserving the independent right-side menu anchors.

**Tech Stack:** QML, Bash source assertions, Omarchy plugin validation

## Global Constraints

- The title is `Longbridge` and the subtitle is `Markets & Portfolio`.
- The panel logo uses official brand colors; the bar icon remains monochrome.
- Setup, tabs, menus, and data loading do not change.

---

### Task 1: Balance the ready-state identity header

**Files:**
- Modify: `tests/test_panel_source.sh`
- Modify: `Panel.qml`

**Interfaces:**
- Consumes: existing `panelHeader`, `headerLogo`, `panelMenu`, `root.foreground`, and `root.fontFamily` QML objects/properties
- Produces: a 24-unit `headerLogo` and centered `headerIdentityText` column containing the title and subtitle

- [ ] **Step 1: Write the failing source assertions**

Add assertions for `width: Style.space(24)`, `id: headerIdentityText`, and `text: "Markets & Portfolio"` to `tests/test_panel_source.sh`.

- [ ] **Step 2: Run the focused source test and verify it fails**

Run: `bash tests/test_panel_source.sh`

Expected: FAIL because the 24-unit logo or subtitle is absent.

- [ ] **Step 3: Implement the centered identity block**

In `Panel.qml`, set the logo width to `Style.space(24)`. Replace the title `Text` with a `Column` named `headerIdentityText`, anchored between the logo and menu and vertically centered. Give it two `Text` children: the existing bold title and a caption-sized `Markets & Portfolio` subtitle using 55% foreground opacity.

- [ ] **Step 4: Run focused and complete verification**

Run: `bash tests/test_panel_source.sh && make validate`

Expected: both commands exit 0; shell-only QML import warnings may remain.

- [ ] **Step 5: Commit**

```bash
git add tests/test_panel_source.sh Panel.qml docs/superpowers/plans/2026-08-16-balanced-panel-header.md
git commit -m "fix: balance panel identity header"
```
