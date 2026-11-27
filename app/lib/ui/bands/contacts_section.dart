import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/band_providers.dart';
import '../../data/band_view.dart';
import '../../data/contact_repository.dart';
import '../../data/database.dart';
import '../../data/person_name.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../settings/settings.dart' show nameFormatProvider;
import '../../sync/auth_providers.dart';
import '../../sync/sync_backend.dart';
import '../sets/contact_dialog.dart';
import '../sets/notify_lineup.dart' show lineupMailUri;
import '../widgets/dialogs.dart';
import '../widgets/menu_action.dart';
import '../widgets/section_header.dart';
import 'bands_screen.dart';

/// Who may create and edit the contacts of [org] and see their mail
/// addresses (ADR-0064): its admins and whoever may edit sets in one of its
/// [bands]. The server enforces the same rule.
bool canEditContacts(OrganizationView org, List<BandView> bands) =>
    org.isAdmin ||
    bands.any(
      (b) => b.organizationId == org.id && !b.substitute && b.canManageSets,
    );

/// The bands of [org] that [bands] lets the user invite into as a band
/// leader (ADR-0023); organization admins invite into the organization.
List<BandView> leaderBands(OrganizationView org, List<BandView> bands) => [
  for (final b in bands)
    if (b.organizationId == org.id && !b.substitute && b.isBandAdmin) b,
];

/// *People without an account* of an organization (ADR-0064), for those who
/// may edit sets in one of its bands: create and edit them, invite them to
/// setDING with a personal link (organization admins, band leaders into
/// their band) and delete them (organization admins).
class ContactsSection extends ConsumerWidget {
  const ContactsSection({super.key, required this.org, required this.bands});

  final OrganizationView org;
  final List<BandView> bands;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final contacts =
        ref.watch(orgContactsProvider(org.id)).value ?? const <ContactEntry>[];
    final format = ref.watch(nameFormatProvider);
    final sorted = [...contacts]
      ..sort(
        (a, b) => a.person.sortKey(format).compareTo(b.person.sortKey(format)),
      );
    final invite = org.isAdmin || leaderBands(org, bands).isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(l10n.lineupPeopleWithoutAccount),
        for (final c in sorted)
          ListTile(
            key: ValueKey('contact-${c.id}'),
            leading: const Icon(Icons.person_off_outlined),
            title: Text(personLabel(c.person, format)),
            subtitle: c.email == null ? null : Text(c.email!),
            onTap: () => _edit(context, ref, c),
            trailing: PopupMenuButton<String>(
              key: ValueKey('contact-menu-${c.id}'),
              onSelected: (value) => switch (value) {
                'edit' => _edit(context, ref, c),
                'invite' => _invite(context, ref, c),
                'delete' => _delete(context, ref, c, format),
                _ => null,
              },
              itemBuilder: (_) => [
                MenuAction(
                  value: 'edit',
                  icon: Icons.edit_outlined,
                  label: l10n.edit,
                ),
                if (invite)
                  MenuAction(
                    value: 'invite',
                    icon: Icons.forward_to_inbox_outlined,
                    label: l10n.contactInvite,
                  ),
                if (org.isAdmin) ...[
                  const PopupMenuDivider(),
                  MenuAction(
                    value: 'delete',
                    icon: Icons.delete_outline,
                    label: l10n.delete,
                    destructive: true,
                  ),
                ],
              ],
            ),
          ),
        ListTile(
          key: const Key('contact-new'),
          leading: const Icon(Icons.person_add_alt_outlined),
          title: Text(l10n.lineupNewContact),
          subtitle: Text(l10n.contactsHint),
          onTap: () => _create(context, ref),
        ),
      ],
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final fields = await showContactDialog(
      context,
      title: l10n.lineupNewContact,
    );
    if (fields == null) return;
    await ref
        .read(contactRepositoryProvider)
        .createContact(
          org.id,
          firstName: fields.firstName,
          lastName: fields.lastName,
          nickname: fields.nickname,
          email: fields.email,
        );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ContactEntry contact,
  ) async {
    final l10n = AppLocalizations.of(context);
    final fields = await showContactDialog(
      context,
      title: l10n.contactEditTitle,
      initial: contact,
    );
    if (fields == null) return;
    await ref
        .read(contactRepositoryProvider)
        .updateContact(
          contact.id,
          firstName: fields.firstName,
          lastName: fields.lastName,
          nickname: fields.nickname,
          email: fields.email,
        );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ContactEntry contact,
    NameFormat format,
  ) async {
    final l10n = AppLocalizations.of(context);
    final name = personLabel(contact.person, format);
    final ok = await confirm(
      context,
      title: l10n.contactDeleteTitle(name),
      message: l10n.contactDeleteMessage(name),
      action: l10n.delete,
    );
    if (!ok) return;
    await ref.read(contactRepositoryProvider).deleteContact(contact.id);
  }

  /// Creates a personal invitation (ADR-0064): into the organization for its
  /// admins, into one of their bands for band leaders. Needs a connection,
  /// and the contact on the server.
  Future<void> _invite(
    BuildContext context,
    WidgetRef ref,
    ContactEntry contact,
  ) async {
    final l10n = AppLocalizations.of(context);
    String? bandId;
    if (!org.isAdmin) {
      final own = leaderBands(org, bands);
      if (own.isEmpty) return;
      bandId = own.length == 1
          ? own.single.id
          : await showDialog<String>(
              context: context,
              builder: (context) => SimpleDialog(
                title: Text(l10n.contactInviteChooseBand),
                children: [
                  for (final b in own)
                    SimpleDialogOption(
                      key: ValueKey('contact-invite-band-${b.id}'),
                      onPressed: () => Navigator.pop(context, b.id),
                      child: Text(b.name),
                    ),
                ],
              ),
            );
      if (bandId == null) return;
    }
    if (!context.mounted) return;
    CreatedInvite? invite;
    final ok = await runBandAction(
      context,
      () async => invite = await ref
          .read(syncBackendProvider)
          .createInvite(org.id, bandId: bandId, contactId: contact.id),
    );
    if (!ok || !context.mounted) return;
    final format = ref.read(nameFormatProvider);
    await showDialog<void>(
      context: context,
      builder: (_) => PersonalInviteDialog(
        invite: invite!,
        name: personLabel(contact.person, format),
        organization: org.name,
        email: contact.email,
      ),
    );
  }
}

/// A personal invitation (ADR-0064): as a QR code to scan in person, to
/// copy or share, and by mail to the contact's address from the device's
/// mail program (the server sends no mail, ADR-0024).
class PersonalInviteDialog extends StatelessWidget {
  const PersonalInviteDialog({
    super.key,
    required this.invite,
    required this.name,
    required this.organization,
    this.email,
  });

  final CreatedInvite invite;
  final String name;
  final String organization;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(invite.expires.toLocal());
    final subject = l10n.contactInviteSubject;
    final body = l10n.contactInviteBody(name, organization, invite.url);
    return AlertDialog(
      title: Text(l10n.contactInviteTitle(name)),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                // The QR code needs a light background to be scanned.
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  key: const Key('invite-qr'),
                  data: invite.url,
                  size: 220,
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(invite.url, key: const Key('invite-url')),
              const SizedBox(height: 12),
              Text(l10n.contactInviteHint(date, name)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('invite-copy'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: invite.url));
            if (context.mounted) showMessage(context, l10n.inviteCopied);
          },
          child: Text(l10n.inviteCopy),
        ),
        if (email case final email?)
          TextButton(
            key: const Key('invite-mail'),
            onPressed: () => launchUrl(lineupMailUri([email], subject, body)),
            child: Text(l10n.lineupMail),
          ),
        TextButton(
          key: const Key('invite-share'),
          onPressed: () => SharePlus.instance.share(
            ShareParams(text: body, subject: subject),
          ),
          child: Text(l10n.lineupShare),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
