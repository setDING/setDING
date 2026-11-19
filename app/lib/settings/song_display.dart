import 'dart:convert';

import 'package:chordpro/chordpro.dart' show SectionRole;
import 'package:flutter/foundation.dart';

export 'package:chordpro/chordpro.dart' show SectionRole;

/// Colours of the song display palette (ADR-0033). Each colour has a light
/// and a dark tone (`ui/render/song_display_colors.dart`); [auto] keeps the
/// colour the element has without a style.
enum SongColor {
  auto,
  blue,
  amber,
  red,
  green,
  teal,
  purple,
  pink,
  grey,
  blackWhite,
}

/// Size of chords relative to their normal size.
enum ChordSize {
  small(0.85),
  medium(1),
  large(1.2);

  const ChordSize(this.factor);
  final double factor;
}

/// Size of a section heading relative to its normal size.
enum LabelSize {
  small(0.85),
  medium(1),
  large(1.25),
  extraLarge(1.6);

  const LabelSize(this.factor);
  final double factor;
}

/// Width of the indent bar, in units of the font size.
enum BarWidth {
  thin(0.15),
  medium(0.25),
  wide(0.4);

  const BarWidth(this.units);
  final double units;
}

/// Indent of a section next to its bar, in units of the font size.
enum SectionIndent {
  none(0),
  normal(0.6),
  large(1);

  const SectionIndent(this.units);
  final double units;
}

/// How the sections of one type look (ADR-0033). The default value is the
/// look of a section without a style.
@immutable
class SectionStyle {
  const SectionStyle({
    this.chordBold = true,
    this.chordItalic = false,
    this.chordSize = ChordSize.medium,
    this.chordColor = SongColor.auto,
    this.textBold = false,
    this.textItalic = false,
    this.textColor = SongColor.auto,
    this.showLabel = true,
    this.labelBold = true,
    this.labelItalic = false,
    this.labelSize = LabelSize.medium,
    this.labelColor = SongColor.auto,
    this.bar = false,
    this.barWidth = BarWidth.thin,
    this.barColor = SongColor.auto,
    this.indent = SectionIndent.none,
    this.tint = false,
    this.extra = const {},
  });

  final bool chordBold;
  final bool chordItalic;
  final ChordSize chordSize;
  final SongColor chordColor;
  final bool textBold;
  final bool textItalic;
  final SongColor textColor;
  final bool showLabel;
  final bool labelBold;
  final bool labelItalic;
  final LabelSize labelSize;
  final SongColor labelColor;
  final bool bar;
  final BarWidth barWidth;
  final SongColor barColor;
  final SectionIndent indent;

  /// A light background in the bar colour.
  final bool tint;

  /// Unknown keys from a newer app version, written back unchanged.
  final Map<String, Object?> extra;

  /// Space left of the content (bar and indent), in units of the font size.
  double get leftUnits => (bar ? barWidth.units : 0) + indent.units;

  SectionStyle copyWith({
    bool? chordBold,
    bool? chordItalic,
    ChordSize? chordSize,
    SongColor? chordColor,
    bool? textBold,
    bool? textItalic,
    SongColor? textColor,
    bool? showLabel,
    bool? labelBold,
    bool? labelItalic,
    LabelSize? labelSize,
    SongColor? labelColor,
    bool? bar,
    BarWidth? barWidth,
    SongColor? barColor,
    SectionIndent? indent,
    bool? tint,
  }) => SectionStyle(
    chordBold: chordBold ?? this.chordBold,
    chordItalic: chordItalic ?? this.chordItalic,
    chordSize: chordSize ?? this.chordSize,
    chordColor: chordColor ?? this.chordColor,
    textBold: textBold ?? this.textBold,
    textItalic: textItalic ?? this.textItalic,
    textColor: textColor ?? this.textColor,
    showLabel: showLabel ?? this.showLabel,
    labelBold: labelBold ?? this.labelBold,
    labelItalic: labelItalic ?? this.labelItalic,
    labelSize: labelSize ?? this.labelSize,
    labelColor: labelColor ?? this.labelColor,
    bar: bar ?? this.bar,
    barWidth: barWidth ?? this.barWidth,
    barColor: barColor ?? this.barColor,
    indent: indent ?? this.indent,
    tint: tint ?? this.tint,
    extra: extra,
  );

  Map<String, Object?> toJson() => {
    ...extra,
    'chordBold': chordBold,
    'chordItalic': chordItalic,
    'chordSize': chordSize.name,
    'chordColor': chordColor.name,
    'textBold': textBold,
    'textItalic': textItalic,
    'textColor': textColor.name,
    'showLabel': showLabel,
    'labelBold': labelBold,
    'labelItalic': labelItalic,
    'labelSize': labelSize.name,
    'labelColor': labelColor.name,
    'bar': bar,
    'barWidth': barWidth.name,
    'barColor': barColor.name,
    'indent': indent.name,
    'tint': tint,
  };

  static const _keys = {
    'chordBold',
    'chordItalic',
    'chordSize',
    'chordColor',
    'textBold',
    'textItalic',
    'textColor',
    'showLabel',
    'labelBold',
    'labelItalic',
    'labelSize',
    'labelColor',
    'bar',
    'barWidth',
    'barColor',
    'indent',
    'tint',
  };

  /// A style from JSON; missing or unknown values give the default.
  static SectionStyle fromJson(Map<String, Object?> json) {
    const d = SectionStyle();
    bool flag(String key, bool fallback) => switch (json[key]) {
      final bool b => b,
      _ => fallback,
    };
    T pick<T extends Enum>(List<T> values, String key, T fallback) =>
        values.firstWhere((v) => v.name == json[key], orElse: () => fallback);
    return SectionStyle(
      chordBold: flag('chordBold', d.chordBold),
      chordItalic: flag('chordItalic', d.chordItalic),
      chordSize: pick(ChordSize.values, 'chordSize', d.chordSize),
      chordColor: pick(SongColor.values, 'chordColor', d.chordColor),
      textBold: flag('textBold', d.textBold),
      textItalic: flag('textItalic', d.textItalic),
      textColor: pick(SongColor.values, 'textColor', d.textColor),
      showLabel: flag('showLabel', d.showLabel),
      labelBold: flag('labelBold', d.labelBold),
      labelItalic: flag('labelItalic', d.labelItalic),
      labelSize: pick(LabelSize.values, 'labelSize', d.labelSize),
      labelColor: pick(SongColor.values, 'labelColor', d.labelColor),
      bar: flag('bar', d.bar),
      barWidth: pick(BarWidth.values, 'barWidth', d.barWidth),
      barColor: pick(SongColor.values, 'barColor', d.barColor),
      indent: pick(SectionIndent.values, 'indent', d.indent),
      tint: flag('tint', d.tint),
      extra: {
        for (final MapEntry(:key, :value) in json.entries)
          if (!_keys.contains(key) && key != 'from') key: value,
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SectionStyle &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// The style of one section type: its own [style], or inherited [from]
/// another type (ADR-0033). [style] is kept while inheriting, so switching
/// back restores it.
@immutable
class TypeStyle {
  const TypeStyle({this.from, this.style = const SectionStyle()});

  final SectionRole? from;
  final SectionStyle style;

  TypeStyle copyWith({SectionStyle? style}) =>
      TypeStyle(from: from, style: style ?? this.style);

  @override
  bool operator ==(Object other) =>
      other is TypeStyle && other.from == from && other.style == style;

  @override
  int get hashCode => Object.hash(from, style);
}

/// The presets of the song display (ADR-0033); [custom] is any other
/// combination.
enum SongDisplayPreset {
  classic,
  colorCoded,
  chorusFocus,
  singer,
  guitar,
  minimal,
  custom,
}

/// Where a type inherits from when nothing else is set: intro and outro
/// from the interlude, the pre-chorus from the verse, all others from
/// [SectionRole.standard].
SectionRole? defaultParent(SectionRole role) => switch (role) {
  SectionRole.standard => null,
  SectionRole.intro || SectionRole.outro => SectionRole.interlude,
  SectionRole.preChorus => SectionRole.verse,
  _ => SectionRole.standard,
};

/// The personal song display setting (ADR-0033): a preset, or custom
/// styles per section type.
@immutable
class SongDisplay {
  const SongDisplay._(this.preset, this.types, this.extra);

  /// A [preset] (not [SongDisplayPreset.custom]).
  const SongDisplay.preset(SongDisplayPreset preset)
    : this._(preset, null, const {});

  /// Custom styles; types that are missing inherit from their
  /// [defaultParent].
  SongDisplay.custom(
    Map<SectionRole, TypeStyle> types, {
    Map<String, Object?> extra = const {},
  }) : this._(SongDisplayPreset.custom, Map.unmodifiable(types), extra);

  static const classic = SongDisplay.preset(SongDisplayPreset.classic);

  final SongDisplayPreset preset;

  /// Custom styles, null for a preset.
  final Map<SectionRole, TypeStyle>? types;

  /// Unknown keys from a newer app version, written back unchanged.
  final Map<String, Object?> extra;

  /// The styles of all types, of the preset or the custom ones.
  Map<SectionRole, TypeStyle> get allTypes {
    final own = types ?? presetTypes(preset);
    return {
      for (final role in SectionRole.values)
        role: own[role] ?? TypeStyle(from: defaultParent(role)),
    };
  }

  /// The style in effect for [role], following the inheritance. The
  /// standard type never inherits; a cycle (not offered in the editor)
  /// ends at the standard type.
  SectionStyle styleOf(SectionRole role) {
    final all = allTypes;
    var current = role;
    for (var i = 0; i < SectionRole.values.length; i++) {
      final type = all[current]!;
      final from = type.from;
      if (current == SectionRole.standard || from == null) return type.style;
      current = from;
    }
    return all[SectionRole.standard]!.style;
  }

  /// The styles in effect for all types.
  Map<SectionRole, SectionStyle> resolve() => {
    for (final role in SectionRole.values) role: styleOf(role),
  };

  /// Whether [role] would inherit from itself when inheriting from
  /// [target].
  bool makesCycle(SectionRole role, SectionRole target) {
    final all = allTypes;
    SectionRole? current = target;
    for (var i = 0; current != null && i <= SectionRole.values.length; i++) {
      if (current == role) return true;
      current = current == SectionRole.standard ? null : all[current]!.from;
    }
    return false;
  }

  /// A custom display with [role] changed to [type]; starts from the
  /// styles of the current preset.
  SongDisplay withType(SectionRole role, TypeStyle type) => SongDisplay.custom({
    ...allTypes,
    role: role == SectionRole.standard ? TypeStyle(style: type.style) : type,
  }, extra: extra);

  String toJsonString() => jsonEncode({
    ...extra,
    'preset': preset.name,
    if (types case final types?)
      'types': {
        for (final MapEntry(:key, :value) in types.entries)
          key.name: {...value.style.toJson(), 'from': value.from?.name},
      },
  });

  /// The display stored as [json]; anything unreadable gives [classic].
  static SongDisplay fromJsonString(String? json) {
    if (json == null || json.isEmpty) return classic;
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return classic;
    }
    if (decoded is! Map<String, Object?>) return classic;
    final extra = {
      for (final MapEntry(:key, :value) in decoded.entries)
        if (key != 'preset' && key != 'types') key: value,
    };
    final name = decoded['preset'];
    final preset = SongDisplayPreset.values
        .where((p) => p.name == name)
        .firstOrNull;
    if (preset == null) return classic;
    if (preset != SongDisplayPreset.custom) {
      return SongDisplay._(preset, null, extra);
    }
    final rawTypes = decoded['types'];
    final types = <SectionRole, TypeStyle>{};
    if (rawTypes is Map<String, Object?>) {
      for (final role in SectionRole.values) {
        final raw = rawTypes[role.name];
        if (raw is! Map<String, Object?>) continue;
        final from = SectionRole.values
            .where((r) => r.name == raw['from'])
            .firstOrNull;
        types[role] = TypeStyle(
          from: role == SectionRole.standard ? null : from,
          style: SectionStyle.fromJson(raw),
        );
      }
    }
    return SongDisplay.custom(types, extra: extra);
  }

  @override
  bool operator ==(Object other) =>
      other is SongDisplay && other.toJsonString() == toJsonString();

  @override
  int get hashCode => toJsonString().hashCode;
}

/// The types of a preset; missing types inherit from their
/// [defaultParent].
Map<SectionRole, TypeStyle> presetTypes(SongDisplayPreset preset) {
  const s = SectionStyle();
  TypeStyle own(SectionStyle style) => TypeStyle(style: style);
  SectionStyle coded(SongColor c) => s.copyWith(
    bar: true,
    barColor: c,
    labelColor: c,
    chordColor: c,
    indent: SectionIndent.normal,
  );
  const barred = SectionStyle(bar: true, indent: SectionIndent.normal);
  return switch (preset) {
    SongDisplayPreset.classic ||
    SongDisplayPreset.custom => {SectionRole.chorus: own(barred)},
    SongDisplayPreset.colorCoded => {
      SectionRole.standard: own(coded(SongColor.grey)),
      SectionRole.verse: own(coded(SongColor.blue)),
      SectionRole.preChorus: own(coded(SongColor.pink)),
      SectionRole.chorus: own(coded(SongColor.amber).copyWith(tint: true)),
      SectionRole.bridge: own(coded(SongColor.purple)),
      SectionRole.intro: own(coded(SongColor.green)),
      SectionRole.outro: own(coded(SongColor.green)),
    },
    SongDisplayPreset.chorusFocus => {
      SectionRole.chorus: own(
        s.copyWith(
          textBold: true,
          bar: true,
          barWidth: BarWidth.wide,
          barColor: SongColor.teal,
          labelColor: SongColor.teal,
          labelSize: LabelSize.large,
          tint: true,
          indent: SectionIndent.large,
        ),
      ),
      SectionRole.bridge: own(
        s.copyWith(
          textItalic: true,
          labelItalic: true,
          bar: true,
          barColor: SongColor.grey,
          indent: SectionIndent.normal,
        ),
      ),
    },
    SongDisplayPreset.singer => {
      SectionRole.standard: own(
        s.copyWith(
          chordColor: SongColor.grey,
          chordBold: false,
          chordSize: ChordSize.small,
        ),
      ),
      SectionRole.chorus: own(
        s.copyWith(
          chordColor: SongColor.grey,
          chordBold: false,
          chordSize: ChordSize.small,
          textBold: true,
          bar: true,
          barColor: SongColor.grey,
          indent: SectionIndent.normal,
        ),
      ),
      SectionRole.bridge: own(
        s.copyWith(
          chordColor: SongColor.grey,
          chordBold: false,
          chordSize: ChordSize.small,
          textItalic: true,
        ),
      ),
    },
    SongDisplayPreset.guitar => {
      SectionRole.standard: own(
        s.copyWith(chordSize: ChordSize.large, textColor: SongColor.grey),
      ),
      SectionRole.chorus: own(
        s.copyWith(
          chordSize: ChordSize.large,
          textColor: SongColor.grey,
          bar: true,
          barWidth: BarWidth.medium,
          indent: SectionIndent.normal,
        ),
      ),
      SectionRole.bridge: own(
        s.copyWith(
          chordSize: ChordSize.large,
          textColor: SongColor.grey,
          chordColor: SongColor.red,
          labelColor: SongColor.red,
          bar: true,
          barColor: SongColor.red,
          indent: SectionIndent.normal,
        ),
      ),
      SectionRole.interlude: own(
        s.copyWith(
          chordSize: ChordSize.large,
          textColor: SongColor.grey,
          chordColor: SongColor.amber,
          labelColor: SongColor.amber,
          labelSize: LabelSize.large,
          bar: true,
          barColor: SongColor.amber,
          barWidth: BarWidth.wide,
          indent: SectionIndent.normal,
          tint: true,
        ),
      ),
    },
    SongDisplayPreset.minimal => {
      SectionRole.standard: own(s.copyWith(showLabel: false, chordBold: false)),
      SectionRole.chorus: own(s.copyWith(chordBold: false, textItalic: true)),
    },
  };
}
