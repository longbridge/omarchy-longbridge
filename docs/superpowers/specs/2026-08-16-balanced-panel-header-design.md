# Balanced Panel Header Design

## Goal

Make the Longbridge panel identity read as one visually balanced unit despite the official logo's bottom-heavy geometry.

## Layout

The ready-state header is a fixed-height horizontal composition:

- A 24-unit official color Longbridge logo at the left.
- A two-line text column separated from the logo by 8 units.
- `Longbridge` as the bold title.
- `Markets & Portfolio` as the subdued subtitle.
- The existing popup menu at the far right.

The logo and complete two-line text column share a common vertical center. The menu is independently centered against the header. The text column fills the space between the logo and menu and elides if necessary.

## Visual Rules

The subtitle uses the panel foreground with reduced opacity and the caption font size. It is informational and has no status indicator, dot, underline, or rise/fall color. The logo remains colored inside the panel while the bar icon remains monochrome.

## Scope and Verification

Only the ready-state identity header changes. Setup, tabs, menus, data loading, and portfolio/watchlist content remain unchanged. Source checks will assert the subtitle, 24-unit logo, and shared centered text column; the existing validation suite must continue to pass.
