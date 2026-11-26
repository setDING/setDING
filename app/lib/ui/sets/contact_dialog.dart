import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../l10n/generated/app_localizations.dart';

/// The fields of a person without an account (ADR-0064).
typedef ContactFields = ({
  String firstName,
  String lastName,
  String nickname,
  String? email,
});

/// Asks for the name and the optional mail address of a person without an
/// account (ADR-0064): only the first name is required. [initial] fills the
/// fields to edit a contact. Returns null when cancelled.
Future<ContactFields?> showContactDialog(
  BuildContext context, {
  required String title,
  ContactEntry? initial,
}) => showDialog<ContactFields>(
  context: context,
  builder: (_) => _ContactDialog(title: title, initial: initial),
);

/// Whether [value] looks like a mail address; the server checks it too.
bool looksLikeEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

class _ContactDialog extends StatefulWidget {
  const _ContactDialog({required this.title, this.initial});

  final String title;
  final ContactEntry? initial;

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final _form = GlobalKey<FormState>();
  late final _first = TextEditingController(text: widget.initial?.firstName);
  late final _last = TextEditingController(text: widget.initial?.lastName);
  late final _nickname = TextEditingController(text: widget.initial?.nickname);
  late final _email = TextEditingController(text: widget.initial?.email);

  @override
  void dispose() {
    for (final c in [_first, _last, _nickname, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final email = _email.text.trim();
    Navigator.pop<ContactFields>(context, (
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      nickname: _nickname.text.trim(),
      email: email.isEmpty ? null : email,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('contact-first-name'),
                  controller: _first,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.accountFirstName,
                    helperText: l10n.contactNameHint,
                  ),
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 100,
                  buildCounter: _noCounter,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? l10n.accountFieldRequired
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('contact-last-name'),
                  controller: _last,
                  decoration: InputDecoration(labelText: l10n.accountLastName),
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 100,
                  buildCounter: _noCounter,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('contact-nickname'),
                  controller: _nickname,
                  decoration: InputDecoration(labelText: l10n.accountNickname),
                  textInputAction: TextInputAction.next,
                  maxLength: 100,
                  buildCounter: _noCounter,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('contact-email'),
                  controller: _email,
                  decoration: InputDecoration(
                    labelText: l10n.contactEmail,
                    helperText: l10n.contactEmailHint,
                    helperMaxLines: 3,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    return value.isEmpty || looksLikeEmail(value)
                        ? null
                        : l10n.accountErrorInvalidEmail;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('contact-save'),
          onPressed: _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }

  static Widget? _noCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => null;
}
