import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/band_providers.dart';
import '../../data/contact_repository.dart';
import '../../data/database.dart';
import '../../data/person_name.dart';
import '../../data/set_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../settings/settings.dart' show nameFormatProvider;
import '../widgets/section_header.dart';
import 'contact_dialog.dart';

/// Chooses the people who play a set (ADR-0061): the band's members,
/// checked by default, people of the organization added as substitutes,
/// and people without an account (ADR-0064), picked from the
/// organization's contacts or created here. Saving the whole band without
/// anybody else goes back to the whole band, so the lineup follows the band
/// again.
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
  final contacts = await ref.read(allOrgContactsProvider(orgId).future);
  if (!context.mounted) return;
  final repository = ref.read(contactRepositoryProvider);
  final result =
      await showDialog<
        ({List<String> people, List<String> contacts, bool wholeBand})
      >(
        context: context,
        builder: (_) => _LineupDialog(
          set: set,
          members: members,
          org: org,
          contacts: contacts,
          format: ref.read(nameFormatProvider),
          createContact: (fields) => repository.createContact(
            orgId,
            firstName: fields.firstName,
            lastName: fields.lastName,
            nickname: fields.nickname,
            email: fields.email,
          ),
        ),
      );
  if (result == null) return; // cancelled
  final people = result.people;
  final whole =
      result.wholeBand ||
      result.contacts.isEmpty &&
          people.length == members.length &&
          members.every((m) => people.contains(m.userId));
  await ref
      .read(setRepositoryProvider)
      .setLineup(set.id, whole ? null : people, contacts: result.contacts);
}

class _LineupDialog extends StatefulWidget {
  const _LineupDialog({
    required this.set,
    required this.members,
    required this.org,
    required this.contacts,
    required this.format,
    required this.createContact,
  });

  final SetlistEntry set;
  final List<MembershipEntry> members;
  final List<OrgMembershipEntry> org;

  /// Every contact of the organization, deleted ones too (ADR-0064): those
  /// in the lineup keep their name, only the others are offered.
  final List<ContactEntry> contacts;

  /// Creates a contact with the fields and returns its ID.
  final Future<String> Function(ContactFields fields) createContact;

  /// How names are shown (ADR-0062).
  final NameFormat format;

  @override
  State<_LineupDialog> createState() => _LineupDialogState();
}

class _LineupDialogState extends State<_LineupDialog> {
  late final Set<String> _band = {for (final m in widget.members) m.userId};
  late final Map<String, PersonName> _people = {
    for (final m in widget.org) m.userId: m.person,
    for (final m in widget.members) m.userId: m.person,
  };
  late final Map<String, String> _names = {
    for (final MapEntry(:key, :value) in _people.entries)
      key: personLabel(value, widget.format),
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

  /// People without an account by contact ID, with their shown names.
  late final Map<String, PersonName> _contactPeople = {
    for (final c in widget.contacts) c.id: c.person,
  };
  late final Map<String, String> _contactNames = {
    for (final MapEntry(:key, :value) in _contactPeople.entries)
      key: personLabel(value, widget.format),
  };

  /// Checked contacts: those of the set's own lineup this device knows.
  late final Set<String> _checkedContacts = widget.set.lineupCustom
      ? {
          for (final id in widget.set.lineupContacts)
            if (_contactNames.containsKey(id)) id,
        }
      : {};

  /// Contacts of the lineup this device does not know (yet): not shown,
  /// but kept when saving.
  late final List<String> _unknownContacts = widget.set.lineupCustom
      ? [
          for (final id in widget.set.lineupContacts)
            if (!_contactNames.containsKey(id)) id,
        ]
      : [];

  /// Contacts shown: those of the lineup and those added here.
  late final List<String> _shownContacts = [..._checkedContacts];

  int _contactsByName(String a, String b) => _contactPeople[a]!
      .sortKey(widget.format)
      .compareTo(_contactPeople[b]!.sortKey(widget.format));

  int _byName(String a, String b) => _people[a]!
      .sortKey(widget.format)
      .compareTo(_people[b]!.sortKey(widget.format));

  Future<void> _addPeople() async {
    final l10n = AppLocalizations.of(context);
    final people = [
      for (final m in widget.org)
        if (!_band.contains(m.userId) && !_substitutes.contains(m.userId))
          m.userId,
    ]..sort(_byName);
    final contacts = [
      for (final c in widget.contacts)
        if (!c.deleted && !_shownContacts.contains(c.id)) c.id,
    ]..sort(_contactsByName);
    final picked = await showDialog<_Pick>(
      context: context,
      builder: (_) => _PeoplePicker(
        candidates: [
          for (final id in people)
            _Candidate(
              key: 'lineup-pick-$id',
              pick: _Pick.person(id),
              name: _names[id]!,
              person: _people[id]!,
            ),
          for (final id in contacts)
            _Candidate(
              key: 'lineup-pick-contact-$id',
              pick: _Pick.contact(id),
              name: _contactNames[id]!,
              person: _contactPeople[id]!,
              subtitle: l10n.lineupNoAccount,
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    if (picked.isNew) return _newContact();
    final id = picked.id!;
    setState(() {
      if (picked.isContact) {
        _shownContacts.add(id);
        _checkedContacts.add(id);
      } else {
        _substitutes.add(id);
        _checked.add(id);
      }
    });
  }

  /// Creates a person without an account and puts them in the lineup.
  Future<void> _newContact() async {
    final l10n = AppLocalizations.of(context);
    final fields = await showContactDialog(
      context,
      title: l10n.lineupNewContact,
    );
    if (fields == null || !mounted) return;
    final id = await widget.createContact(fields);
    if (!mounted) return;
    final person = PersonName(
      firstName: fields.firstName,
      lastName: fields.lastName,
      nickname: fields.nickname,
    );
    setState(() {
      _contactPeople[id] = person;
      _contactNames[id] = personLabel(person, widget.format);
      _shownContacts.add(id);
      _checkedContacts.add(id);
    });
  }

  Widget _contactTile(String id) {
    final l10n = AppLocalizations.of(context);
    return CheckboxListTile(
      key: ValueKey('lineup-contact-$id'),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      value: _checkedContacts.contains(id),
      title: Text(_contactNames[id]!),
      subtitle: Text(l10n.lineupNoAccount),
      onChanged: (on) => setState(
        () =>
            on == true ? _checkedContacts.add(id) : _checkedContacts.remove(id),
      ),
    );
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
    final contacts = [..._shownContacts]..sort(_contactsByName);
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
              if (contacts.isNotEmpty)
                SectionHeader(
                  l10n.lineupPeopleWithoutAccount,
                  padding: SectionHeader.insetPadding,
                ),
              for (final id in contacts) _contactTile(id),
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
            onPressed: () => Navigator.pop(context, (
              people: [for (final m in widget.members) m.userId],
              contacts: const <String>[],
              wholeBand: true,
            )),
            child: Text(l10n.lineupWholeBand),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('lineup-save'),
          onPressed: () => Navigator.pop(context, (
            people: [
              for (final id in [...band, ...substitutes])
                if (_checked.contains(id)) id,
            ],
            contacts: [
              for (final id in contacts)
                if (_checkedContacts.contains(id)) id,
              ..._unknownContacts,
            ],
            wholeBand: false,
          )),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// What the picker returns: a person of the organization, a contact, or
/// *New person without account*.
class _Pick {
  const _Pick.person(String this.id) : isContact = false, isNew = false;
  const _Pick.contact(String this.id) : isContact = true, isNew = false;
  const _Pick.newContact() : id = null, isContact = true, isNew = true;

  final String? id;
  final bool isContact;
  final bool isNew;
}

/// One entry of the picker.
class _Candidate {
  const _Candidate({
    required this.key,
    required this.pick,
    required this.name,
    required this.person,
    this.subtitle,
  });

  final String key;
  final _Pick pick;
  final String name;

  /// The name parts that are searched.
  final PersonName person;
  final String? subtitle;
}

/// Picks one person of the organization or a person without an account by
/// first name, last name or nickname (ADR-0062, ADR-0064), or creates a new
/// person without an account.
class _PeoplePicker extends StatefulWidget {
  const _PeoplePicker({required this.candidates});

  final List<_Candidate> candidates;

  @override
  State<_PeoplePicker> createState() => _PeoplePickerState();
}

class _PeoplePickerState extends State<_PeoplePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shown = [
      for (final c in widget.candidates)
        if (c.person.matches(_query)) c,
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
              child: widget.candidates.isEmpty
                  ? Center(
                      child: Text(
                        l10n.lineupNoMorePeople,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView(
                      children: [
                        for (final c in shown)
                          ListTile(
                            key: ValueKey(c.key),
                            leading: Icon(
                              c.pick.isContact
                                  ? Icons.person_off_outlined
                                  : Icons.person_outline,
                            ),
                            title: Text(c.name),
                            subtitle: c.subtitle == null
                                ? null
                                : Text(c.subtitle!),
                            onTap: () => Navigator.pop(context, c.pick),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('lineup-new-contact'),
                icon: const Icon(Icons.person_add_alt_outlined),
                label: Text(l10n.lineupNewContact),
                onPressed: () =>
                    Navigator.pop(context, const _Pick.newContact()),
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
