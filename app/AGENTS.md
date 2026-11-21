# AGENTS.md – app

Rules for working on the Flutter client in `app/`. The repository-wide rules in the
root [`AGENTS.md`](../AGENTS.md) apply as well.

## Settings screen

A new or changed setting follows the layout of
[ADR-0050](../docs/architecture/adr/0050-settings-screen-layout.md): it sits in a
titled `SettingsSection` and has a leading icon (`SettingsSwitch`,
`SettingsChoice` or a `ListTile` with `leading`, from
`lib/ui/settings/settings_layout.dart`). `test/settings_layout_test.dart` fails
otherwise.
