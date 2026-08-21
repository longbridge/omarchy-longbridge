# Repository working agreements

## Colors

- Use colors from the active Omarchy system theme. Do not hard-code UI colors.
- Pass semantic colors down from `Panel.qml` as required component properties so theme changes propagate through every view.
- Use `ThemePalette.green` for price rises and live-market state, and `ThemePalette.red` for price falls. Keep the text label as the source of meaning; color must not be the only state indicator.
- Use `Color.foreground`, `Color.background`, `Color.accent`, `Color.urgent`, or colors derived from them for text, surfaces, controls, borders, risk, and allocation visuals.
- Derive muted, hover, selected, and translucent variants from an inherited color with alpha. Do not introduce literal fallback grays or opacity-specific hex values.
- Fixed hex colors are allowed only for an explicitly enabled official brand asset, such as `LongbridgeLogo.qml` with `brandColors: true`, and for test fixture values that verify that behavior.
- Keep the source regression checks in `tests/test_panel_source.sh` updated so non-brand QML components cannot silently reintroduce hard-coded colors.
