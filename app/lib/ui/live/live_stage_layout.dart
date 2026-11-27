import 'package:material_ui/material_ui.dart';

import '../../settings/settings.dart';
import 'live_beat.dart';
import 'live_item.dart';

/// The pages of live mode with the drum panel (ADR-0026): beside it on wide
/// stages ([wide]), in it on small ones ([compact], with the song map when
/// [compactMap]), or alone. Empty areas of the panel are tap zones
/// ([onStageTap]).
class LiveStageLayout extends StatelessWidget {
  const LiveStageLayout({
    super.key,
    required this.page,
    required this.items,
    required this.current,
    required this.onSelect,
    required this.onStageTap,
    required this.compact,
    required this.compactMap,
    required this.wide,
    required this.landscape,
    required this.panelWidth,
    required this.drumView,
    required this.onView,
  });

  /// The pages of the set.
  final Widget page;
  final List<LiveItem> items;
  final int current;
  final ValueChanged<int> onSelect;

  /// A tap at this horizontal position of the stage.
  final ValueChanged<double> onStageTap;
  final bool compact;
  final bool compactMap;
  final bool wide;

  /// The small stage is in landscape: beat and set side by side.
  final bool landscape;
  final double panelWidth;
  final DrumPanelView drumView;
  final ValueChanged<DrumPanelView> onView;

  @override
  Widget build(BuildContext context) {
    return compact
        ? Stack(
            fit: StackFit.expand,
            children: [
              // The pages stay built for the page
              // controller and the preparation, unseen
              // unless they show the song map.
              if (!compactMap) Offstage(child: page),
              // Empty areas of the panel are the tap
              // zones; the set list and the buttons keep
              // their taps.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => onStageTap(d.localPosition.dx),
                child: DrumPanel(
                  items: items,
                  current: current,
                  onSelect: onSelect,
                  direction: landscape ? Axis.horizontal : Axis.vertical,
                  view: drumView,
                  onView: onView,
                  songMap: compactMap ? page : null,
                ),
              ),
            ],
          )
        : !wide
        ? page
        : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: panelWidth,
                // Empty areas of the panel are part of the tap zones;
                // the set list and the buttons keep their taps.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => onStageTap(d.localPosition.dx),
                  child: DrumPanel(
                    items: items,
                    current: current,
                    onSelect: onSelect,
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: page),
            ],
          );
  }
}
