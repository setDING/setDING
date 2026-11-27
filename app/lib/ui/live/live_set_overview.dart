import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import 'live_item.dart';

/// The overview of the set in live mode: the item chosen to turn to, or
/// null. [context] is below the stage theme, which the sheet follows.
Future<int?> showLiveSetOverview(
  BuildContext context, {
  required List<LiveItem> items,
  required int current,
}) async {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (context, controller) => ListView(
        controller: controller,
        children: [
          ListTile(
            title: Text(
              l10n.liveSetOverview,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (var i = 0; i < items.length; i++)
            ListTile(
              selected: i == current,
              leading: Text('${i + 1}'),
              title: Text(items[i].title(l10n)),
              subtitle: items[i].song?.songKey == null
                  ? null
                  : Text(items[i].song!.songKey!),
              onTap: () => Navigator.pop(context, i),
            ),
        ],
      ),
    ),
  );
}
