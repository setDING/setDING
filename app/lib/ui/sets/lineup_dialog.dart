import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers.dart';
import '../widgets/section_header.dart';

/// Chooses the people who play a set (ADR-0061): the band's members,
/// checked by default, and people of the organization added as
/// substitutes. Saving the whole band without substitutes goes back to the
/// whole band, so the lineup follows the band again.
Future<void> showLineupDialog(
  BuildContext context,
  WidgetRef ref,
  SetlistEntry set,
) async {
  final band = ref.read(currentBandProvider);
  final orgId = band.organizationId;
  if (orgId == null) return;
  final members = await ref.read(bandMembersProvider(set.bandId).future);
  final org = await ref.read(orgMembersProvider(orgId).future);
  if (!context.mounted) return;
  final people = await showDialog<List<String>?>(
    context: context,
    builder: (_) => _LineupDialog(set: set, members: members, org: org),
  );
  if (people == null) return; // cancelled
  final whole =
      people.length == members.length &&
      members.every((m) => people.contains(m.userId));
  await ref
      .read(setRepositoryProvider)
      .setLineup(set.id, whole ? null : people);
}

class _LineupDialog extends StatefulWidget {
  const _LineupDialog({
    required this.set,
    required this.members,
    required this.org,
  });

  final SetlistEntry set;
  final List<MembershipEntry> members;
  final List<OrgMembershipEntry> org;

  @override
  State<_LineupDialog> createState() => _LineupDialogState();
}

class _LineupDialogState extends State<_LineupDialog> {
  late final Set<String> _band = {for (final m in widget.members) m.userId};
  late final Map<String, String> _names = {
    for (final m in widget.org) m.userId: m.userName,
    for (final m in widget.members) m.userId: m.userName,
  };

  /// Checked people: the band by default, or the set's own lineup.
  late final Set<String> _checked = widget.set.lineupCustom
      ? {
          for (final id in widget.set.lineup)
            if (_names.containsKey(id)) id,
        }
      : {..._band};

  /// Substitutes shown: those of the lineup and those added here.
  late final List<String> _substitutes = [
    for (final id in _checked)
      if (!_band.contains(id)) id,
  ];

  int _byName(String a, String b) =>
      _names[a]!.toLowerCase().compareTo(_names[b]!.toLowerCase());

  Future<void> _addPeople() async {
    final candidates = [
      for (final m in widget.org)
        if (!_band.contains(m.userId) && !_substitutes.contains(m.userId))
          m.userId,
    ]..sort(_byName);
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _PeoplePicker(ids: candidates, names: _names),
    );
    if (picked == null) return;
    setState(() {
      _substitutes.add(picked);
      _checked.add(picked);
    });
  }

  Widget _tile(String id, {required bool substitute}) {
    final l10n = AppLocalizations.of(context);
    return CheckboxListTile(
      key: ValueKey('lineup-$id'),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      value: _checked.contains(id),
      title: Text(_names[id]!),
      subtitle: substitute ? Text(l10n.lineupSubstitute) : null,
      onChanged: (on) =>
          setState(() => on == true ? _checked.add(id) : _checked.remove(id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final band = [..._band.where(_names.containsKey)]..sort(_byName);
    final substitutes = [..._substitutes]..sort(_byName);
    return AlertDialog(
      title: Text(l10n.lineup),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                l10n.lineupBandMembers,
                padding: SectionHeader.insetPadding,
              ),
              for (final id in band) _tile(id, substitute: false),
              if (substitutes.isNotEmpty)
                SectionHeader(
                  l10n.lineupSubstitutes,
                  padding: SectionHeader.insetPadding,
                ),
              for (final id in substitutes) _tile(id, substitute: true),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('lineup-add-people'),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: Text(l10n.lineupAddPeople),
                onPressed: _addPeople,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.set.lineupCustom)
          TextButton(
            key: const Key('lineup-whole-band'),
            onPressed: () => Navigator.pop(context, [
              for (final m in widget.members) m.userId,
            ]),
            child: Text(l10n.lineupWholeBand),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('lineup-save'),
          onPressed: () => Navigator.pop(context, [
            for (final id in [...band, ...substitutes])
              if (_checked.contains(id)) id,
          ]),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// Picks one person of the organization by name.
class _PeoplePicker extends StatefulWidget {
  const _PeoplePicker({required this.ids, required this.names});

  final List<String> ids;
  final Map<String, String> names;

  @override
  State<_PeoplePicker> createState() => _PeoplePickerState();
}

class _PeoplePickerState extends State<_PeoplePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = _query.trim().toLowerCase();
    final shown = [
      for (final id in widget.ids)
        if (widget.names[id]!.toLowerCase().contains(query)) id,
    ];
    return AlertDialog(
      title: Text(l10n.lineupAddPeople),
      content: SizedBox(
        width: 420,
        height: 360,
        child: Column(
          children: [
            TextField(
              key: const Key('lineup-search'),
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.lineupSearchPeople,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: widget.ids.isEmpty
                  ? Center(
                      child: Text(
                        l10n.lineupNoMorePeople,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView(
                      children: [
                        for (final id in shown)
                          ListTile(
                            key: ValueKey('lineup-pick-$id'),
                            leading: const Icon(Icons.person_outline),
                            title: Text(widget.names[id]!),
                            onTap: () => Navigator.pop(context, id),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
