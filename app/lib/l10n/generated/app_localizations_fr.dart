// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'setDING';

  @override
  String get navSets => 'Sets';

  @override
  String get navSongs => 'Morceaux';

  @override
  String get navSettings => 'Réglages';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get edit => 'Modifier';

  @override
  String get add => 'Ajouter';

  @override
  String get ok => 'OK';

  @override
  String get close => 'Fermer';

  @override
  String get rename => 'Renommer';

  @override
  String get discard => 'Abandonner';

  @override
  String get untitled => 'Sans titre';

  @override
  String errorGeneric(String error) {
    return 'Une erreur s\'est produite : $error';
  }

  @override
  String get songsEmpty =>
      'Pas encore de morceaux. Crée un nouveau morceau ou importe des fichiers ChordPro.';

  @override
  String get searchSongs => 'Rechercher des morceaux';

  @override
  String get searchClear => 'Effacer la recherche';

  @override
  String get newSong => 'Nouveau morceau';

  @override
  String get newPdfSong => 'Nouveau morceau PDF';

  @override
  String get importFiles => 'Importer des fichiers';

  @override
  String get importTitle => 'Importer des fichiers ChordPro';

  @override
  String get importDescription =>
      'Pris en charge : .cho, .chordpro, .chopro, .crd, .pro, .txt, archives ZIP contenant de tels fichiers et sauvegardes setDING.';

  @override
  String get importGermanNotation =>
      'Les fichiers utilisent la notation allemande (H/B)';

  @override
  String get importGermanNotationHint =>
      'Les accords sont convertis en notation internationale lors de l\'importation.';

  @override
  String get chooseFiles => 'Choisir des fichiers';

  @override
  String importResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux importés',
      one: '1 morceau importé',
      zero: 'Aucun morceau importé',
    );
    return '$_temp0';
  }

  @override
  String importSkipped(String files) {
    return 'Ignorés : $files';
  }

  @override
  String get deleteSongTitle => 'Supprimer le morceau ?';

  @override
  String deleteSongMessage(String title) {
    return '« $title » sera supprimé et retiré de tous les sets.';
  }

  @override
  String get attachmentsTooltip => 'Contient des pièces jointes PDF';

  @override
  String get keyOriginal => 'Originale';

  @override
  String get capo => 'Capodastre';

  @override
  String capoValue(int fret) {
    return 'Capodastre $fret';
  }

  @override
  String capoLabel(int fret) {
    return 'Capodastre : $fret';
  }

  @override
  String capoLabelWithKey(int fret, String key) {
    return 'Capodastre : $fret ($key)';
  }

  @override
  String capoAsInSongLabel(String capo) {
    return '$capo, comme dans le morceau';
  }

  @override
  String get noCapo => 'Sans capodastre';

  @override
  String capoAsInSong(int fret) {
    return 'Capodastre $fret (comme dans le morceau)';
  }

  @override
  String get allTags => 'Tous';

  @override
  String get tagsFilter => 'Tags';

  @override
  String get filterByTags => 'Filtrer par tags';

  @override
  String tagsFilterMore(String tag, int count) {
    return '$tag +$count';
  }

  @override
  String get notes => 'Mes notes';

  @override
  String get notesHint => 'Toi seul vois cette note.';

  @override
  String get editSource => 'Modifier le ChordPro';

  @override
  String get attachments => 'Pièces jointes';

  @override
  String get addAttachment => 'Joindre un fichier';

  @override
  String get noAttachments => 'Pas encore de pièces jointes.';

  @override
  String get attachmentTooLarge =>
      'Le fichier dépasse 20 Mo et ne peut pas être joint.';

  @override
  String get songLinks => 'Sources';

  @override
  String get noSongLinks =>
      'Pas encore de sources. Ajoute des enregistrements sur YouTube, Spotify, etc.';

  @override
  String get addSongLink => 'Ajouter un lien';

  @override
  String get editSongLink => 'Modifier le lien';

  @override
  String get deleteSongLink => 'Retirer la source';

  @override
  String get deleteSongLinkMessage => 'Retirer cette source du morceau ?';

  @override
  String get songLinkUrl => 'Lien (URL)';

  @override
  String get songLinkLabel => 'Libellé (facultatif)';

  @override
  String get songLinkLabelHint => 'Live 2009';

  @override
  String get songLinkInvalid =>
      'Saisis un lien web commençant par https:// (sans |).';

  @override
  String get songLinkFailed => 'Le lien n\'a pas pu être ouvert.';

  @override
  String get attachmentName => 'Nom de la pièce jointe';

  @override
  String pagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String get liveView => 'Afficher en mode live';

  @override
  String get liveViewChordPro => 'Texte ChordPro';

  @override
  String get exportSong => 'Exporter';

  @override
  String get exported => 'Exporté';

  @override
  String get exportedOpen => 'Ouvrir';

  @override
  String get openFileFailed => 'Aucune app n\'a pu ouvrir le fichier.';

  @override
  String get playLive => 'Jouer en live';

  @override
  String get live => 'Live';

  @override
  String get chordView => 'Affichage des accords';

  @override
  String get useDeviceSetting => 'Comme dans les réglages';

  @override
  String get on => 'Activé';

  @override
  String get off => 'Désactivé';

  @override
  String get fontLarger => 'Texte plus grand';

  @override
  String get fontSmaller => 'Texte plus petit';

  @override
  String get fitToPage => 'Ajuster à la page';

  @override
  String get resetAdjustments => 'Réinitialiser les ajustements personnels';

  @override
  String get personalAdjustments => 'Ajustements personnels';

  @override
  String get scopePersonal =>
      'Juste pour toi – le morceau reste inchangé pour tous les autres.';

  @override
  String get scopeSet => 'Pour ce set – s\'applique à tout le groupe.';

  @override
  String get scopeBand =>
      'Pour tout le groupe – s\'applique dans tous ses sets.';

  @override
  String get scopeSong =>
      'Pour le morceau – le modifie pour tous dans l\'organisation.';

  @override
  String get keyPickerPersonal => 'Ma tonalité – juste pour moi';

  @override
  String get keyPickerSet => 'Tonalité dans ce set – pour tout le groupe';

  @override
  String get keyPickerBand => 'Tonalité du groupe – pour tous ses sets';

  @override
  String get editTitle => 'Modifier le titre';

  @override
  String get title => 'Titre';

  @override
  String get artist => 'Artiste';

  @override
  String get noContent => 'Ce morceau n\'a pas encore de texte ChordPro.';

  @override
  String get addChordPro => 'Ajouter un texte ChordPro';

  @override
  String keyLabel(String key) {
    return 'Tonalité : $key';
  }

  @override
  String bpm(int tempo) {
    return '$tempo BPM';
  }

  @override
  String get noKeyForDegrees =>
      'Les chiffres Nashville et les chiffres romains nécessitent une tonalité dans le morceau.';

  @override
  String get firstVerseChordsOnly => 'Accords uniquement au couplet 1';

  @override
  String get noVersesForFirstVerseChords =>
      'Le morceau n\'a pas d\'autres couplets avec des accords.';

  @override
  String get verseChords => 'Accords dans les couplets';

  @override
  String get verseChordsAll => 'Accords dans tous les couplets';

  @override
  String get verseChordsStacked => 'Couplets superposés';

  @override
  String get chorusesStacked => 'Refrains superposés';

  @override
  String get editorTitleNew => 'Nouveau morceau';

  @override
  String get editorTitleEdit => 'Modifier le morceau';

  @override
  String get editorTab => 'Texte';

  @override
  String get previewTab => 'Aperçu';

  @override
  String get insertVerse => 'Insérer un verse';

  @override
  String get insertChorus => 'Insérer un chorus';

  @override
  String get insertBridge => 'Insérer un bridge';

  @override
  String get insertComment => 'Insérer un commentaire';

  @override
  String get insertChord => 'Insérer un accord';

  @override
  String get discardChangesTitle => 'Abandonner les modifications ?';

  @override
  String get discardChangesMessage =>
      'Tes modifications n\'ont pas encore été enregistrées.';

  @override
  String get sectionVerse => 'Verse';

  @override
  String get sectionChorus => 'Chorus';

  @override
  String get sectionBridge => 'Bridge';

  @override
  String get sectionTab => 'Tab';

  @override
  String get sectionGrid => 'Grid';

  @override
  String get setsEmpty =>
      'Pas encore de sets. Crée un set pour ton prochain concert.';

  @override
  String get newSet => 'Nouveau set';

  @override
  String get editSet => 'Modifier le set';

  @override
  String get setName => 'Nom';

  @override
  String get gigDate => 'Date';

  @override
  String get venue => 'Lieu';

  @override
  String get noDate => 'Pas de date';

  @override
  String get pickDate => 'Choisir une date';

  @override
  String get clearDate => 'Retirer la date';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '1 élément',
      zero: 'Vide',
    );
    return '$_temp0';
  }

  @override
  String offlineMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux pas hors ligne',
      one: '1 morceau pas hors ligne',
    );
    return '$_temp0';
  }

  @override
  String get offlineMissingTooltip =>
      'Tous les morceaux et PDF de ce set ne sont pas sur l\'appareil. Connecte-le au réseau et attends la synchronisation.';

  @override
  String syncStale(String time) {
    return 'Dernière synchronisation avec le serveur : $time. Les sets sur cet appareil ne sont peut-être pas à jour.';
  }

  @override
  String get syncStaleNever =>
      'Cet appareil ne s\'est pas encore synchronisé avec le serveur. Les sets ne sont peut-être pas à jour.';

  @override
  String syncUnsent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifications de cet appareil n\'ont',
      one: '1 modification de cet appareil n\'a',
    );
    return '$_temp0 pas encore atteint le serveur.';
  }

  @override
  String get addSongs => 'Ajouter des morceaux';

  @override
  String get pause => 'Pause';

  @override
  String get textItem => 'Texte';

  @override
  String get markerIconBreak => 'Pause';

  @override
  String get markerIconDrinks => 'Boissons';

  @override
  String get markerIconAnnouncement => 'Annonce';

  @override
  String get markerIconMicrophone => 'Discours';

  @override
  String get markerIconGuest => 'Invité';

  @override
  String get markerIconEncore => 'Rappel';

  @override
  String get markerIconTransition => 'Transition';

  @override
  String get markerIconSolo => 'Solo';

  @override
  String get markerIconApplause => 'Applaudissements';

  @override
  String get markerIconInstrument => 'Changement d\'instrument';

  @override
  String get markerIconTuning => 'Accordage';

  @override
  String get markerIconClick => 'Clic';

  @override
  String get markerIconLight => 'Lumière';

  @override
  String get markerIconEffects => 'Effets';

  @override
  String get markerIconCelebration => 'Fête';

  @override
  String get markerIconInfo => 'Note';

  @override
  String get markerIconWarning => 'Attention';

  @override
  String get marker => 'Repère';

  @override
  String get addMarker => 'Ajouter un repère';

  @override
  String get editMarker => 'Modifier le repère';

  @override
  String get markerText => 'Texte';

  @override
  String get markerPreview => 'Aperçu';

  @override
  String get markerGroupBreak => 'Pause';

  @override
  String get markerGroupAnnouncement => 'Annonce';

  @override
  String get markerGroupFlow => 'Déroulement';

  @override
  String get markerGroupStage => 'Scène';

  @override
  String get markerGroupShow => 'Show';

  @override
  String get markerGroupGeneral => 'Général';

  @override
  String get setEmpty => 'Ce set est vide. Ajoute quelques morceaux.';

  @override
  String get deleteSetTitle => 'Supprimer le set ?';

  @override
  String deleteSetMessage(String name) {
    return '« $name » sera supprimé. Les morceaux sont conservés.';
  }

  @override
  String get removeFromSet => 'Retirer du set';

  @override
  String get selectSongs => 'Sélectionner des morceaux';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnés',
      one: '1 sélectionné',
      zero: 'Aucun sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get songMissing => 'Le morceau n\'existe plus';

  @override
  String liveNext(String title) {
    return 'Suivant : $title';
  }

  @override
  String get liveWebNotice =>
      'Pas fiable hors ligne dans le navigateur – sur scène, utilise l\'app';

  @override
  String liveMidiConnected(String name) {
    return 'Clavier connecté : $name';
  }

  @override
  String get liveMidiNotConnected => 'Clavier non connecté';

  @override
  String get liveMidiSendAgain => 'Renvoyer le programme';

  @override
  String get liveMidiButton => 'Programme du clavier (appui long : renvoyer)';

  @override
  String get liveMidiChange => 'Changer de programme';

  @override
  String get liveMidiSameAsPrevious => 'Comme le morceau précédent';

  @override
  String liveMidiPreviousProgram(String program, String title) {
    return '$program – de « $title »';
  }

  @override
  String get liveMidiNoPrevious => 'Aucun morceau précédent avec un programme';

  @override
  String get liveMidiSaved => 'Programme du clavier enregistré';

  @override
  String get liveMidiRemoved => 'Programme du clavier retiré';

  @override
  String get liveMidiTakeOverWaiting => 'Choisis un son sur le clavier';

  @override
  String liveMidiTakeOver(String program) {
    return 'Reprendre : $program';
  }

  @override
  String get liveMidiTakeOverHint =>
      'setDING reprend le programme envoyé par le clavier.';

  @override
  String get liveMidiTakeOverNordHint =>
      'Rien n\'arrive ? Sur le Nord, règle « Program Change » sur « Send » ou « Send & Receive » dans le menu MIDI.';

  @override
  String get liveMidiTakeOverSame => 'C\'est déjà le programme du morceau';

  @override
  String get liveWakeLockNotice =>
      'L\'écran peut s\'éteindre – vérifie les réglages d\'énergie de l\'appareil';

  @override
  String get liveEnd => 'Fin du set';

  @override
  String get liveSetOverview => 'Vue d\'ensemble du set';

  @override
  String get liveExit => 'Quitter le mode live';

  @override
  String liveSongPage(int page, int count) {
    return 'Page $page/$count';
  }

  @override
  String livePosition(int current, int total) {
    return '$current / $total';
  }

  @override
  String get settingsSectionGeneral => 'Général';

  @override
  String get settingsSectionDisplay => 'Affichage';

  @override
  String get settingsSectionLive => 'Écran et mode live';

  @override
  String get settingsSectionStorage => 'Stockage et infos';

  @override
  String get settingsSectionMusician => 'Musicien';

  @override
  String get settingsCategoryAccountHint =>
      'Connexion, serveur et synchronisation';

  @override
  String get settingsCategoryGeneralHint => 'Langue et thème';

  @override
  String get settingsCategoryMusicianHint =>
      'Instrument, voix, diagrammes d\'accords, pulsation';

  @override
  String get settingsCategoryDisplayHint =>
      'Notation des accords, Nashville et chiffres romains, contenu, refrain, progression';

  @override
  String get settingsCategoryLiveHint =>
      'Taille du texte, ajustement à l\'écran, colonnes, tourne-page';

  @override
  String get settingsCategoryAboutHint =>
      'Stockage, journal de diagnostic et version';

  @override
  String get settingsInstrument => 'Mon instrument';

  @override
  String get settingsInstrumentHint =>
      'Utilisé pour les parties conditionnelles (p. ex. guitare seulement) et pour les diagrammes d\'accords.';

  @override
  String get instrumentGuitar => 'Guitare';

  @override
  String get instrumentUkulele => 'Ukulélé';

  @override
  String get instrumentBass => 'Basse';

  @override
  String get instrumentKeyboard => 'Clavier';

  @override
  String get instrumentVocals => 'Chant';

  @override
  String get instrumentDrums => 'Batterie';

  @override
  String get instrumentOther => 'Autre …';

  @override
  String get settingsUserName => 'Voix ou rôle (facultatif)';

  @override
  String get settingsUserNameHint =>
      'Ton instrument compte déjà. Nécessaire seulement si un morceau a des parties pour des voix ou des personnes, p. ex. « alto » ou « ténor ».';

  @override
  String settingsUserNameIsInstrument(String name) {
    return '« $name » est un instrument. Le réglage d\'instrument le couvre, tu peux donc laisser ce champ vide.';
  }

  @override
  String get settingsDiagrams => 'Diagrammes d\'accords';

  @override
  String get settingsDiagramsHint =>
      'Affiche les doigtés de tous les accords du morceau pour ton instrument. Un morceau peut le définir lui-même avec la directive diagrams.';

  @override
  String get settingsBassStrings => 'Cordes de basse';

  @override
  String get settingsBassStringsHint =>
      'Les diagrammes d\'accords montrent une basse 4 cordes (E-A-D-G) ou une basse 5 cordes avec une corde de si grave.';

  @override
  String bassStringCount(int count) {
    return '$count cordes';
  }

  @override
  String get diagramsOff => 'Désactivés';

  @override
  String get diagramsTop => 'En haut';

  @override
  String get diagramsBottom => 'En bas';

  @override
  String get notSet => 'Non défini';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get languageSystem => 'Langue du système';

  @override
  String get languageDe => 'Deutsch';

  @override
  String get languageEn => 'English';

  @override
  String get languageIt => 'Italiano';

  @override
  String get languageFr => 'Français';

  @override
  String get languageEs => 'Español';

  @override
  String get languagePt => 'Português';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get themeSystem => 'Comme le système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get settingsAccent => 'Couleur d\'accent';

  @override
  String get accentBrand => 'Bleu setDING';

  @override
  String get accentRed => 'Rouge';

  @override
  String get accentAmber => 'Ambre';

  @override
  String get accentGreen => 'Vert';

  @override
  String get accentTeal => 'Sarcelle';

  @override
  String get accentPurple => 'Violet';

  @override
  String get accentPink => 'Rose';

  @override
  String get settingsNotation => 'Notation des accords';

  @override
  String get notationInternational => 'Internationale (B, Bb)';

  @override
  String get notationGerman => 'Allemande (H, B)';

  @override
  String get settingsChordView => 'Afficher les accords comme';

  @override
  String get settingsChordViewHint =>
      'Accords (Am7), chiffres Nashville (6m7) ou chiffres romains (vi7). Les chiffres nécessitent une tonalité dans le morceau.';

  @override
  String get settingsNumeralSpelling => 'Écriture des chiffres romains';

  @override
  String get settingsNumeralSpellingHint =>
      'Comment les chiffres romains montrent l\'accord : par la casse, ii7 – V7 – IΔ7, ou en majuscules avec le symbole d\'accord, IIm7 – V7 – Imaj7. Le symbole d\'accord suit le style d\'accords.';

  @override
  String get numeralSpellingCasing => 'Casse';

  @override
  String get numeralSpellingChordSymbol => 'Symbole d\'accord';

  @override
  String get settingsChordStyle => 'Style d\'accords';

  @override
  String get settingsChordStyleHint =>
      'Comment les accords sont écrits, p. ex. Am7, Cmaj7, Em7b5 (standard) ou A−7, CΔ7, Eø7 (jazz). Le morceau lui-même n\'est pas modifié.';

  @override
  String get chordStyleAsWritten => 'Tel qu\'écrit';

  @override
  String get chordStyleStandard => 'Standard';

  @override
  String get chordStyleJazz => 'Jazz';

  @override
  String get settingsChordSuperscript => 'Extensions en exposant';

  @override
  String get settingsChordSuperscriptHint =>
      'Affiche les extensions et altérations plus petites et en exposant, p. ex. C⁷. Nécessite le style standard ou jazz.';

  @override
  String get settingsDisplayMode => 'Contenu';

  @override
  String get displayLyricsAndChords => 'Paroles et accords';

  @override
  String get displayLyricsOnly => 'Paroles seulement';

  @override
  String get settingsFontSize => 'Taille du texte';

  @override
  String get settingsColumns => 'Colonnes';

  @override
  String get columnsAuto => 'Automatique';

  @override
  String get columnsOne => 'Une';

  @override
  String get columnsTwo => 'Deux';

  @override
  String get settingsPageTurn => 'Tourne-page';

  @override
  String get pageTurnFull => 'Page entière';

  @override
  String get pageTurnHalf => 'Demi-page';

  @override
  String get settingsAutoFit => 'Ajuster le morceau à l\'écran';

  @override
  String get settingsAutoFitHint =>
      'Le morceau entier tient à l\'écran sans défilement. Les sections sont disposées automatiquement en colonnes et le texte est aussi grand que possible.';

  @override
  String get settingsColumnsHint =>
      'Lors de l\'ajustement à l\'écran, le nombre maximal de colonnes autorisé.';

  @override
  String get columnsThree => 'Trois';

  @override
  String get settingsChorusRepeat => 'Refrain répété';

  @override
  String get settingsChorusRepeatHint =>
      'Automatique : un refrain répété n\'est affiché que comme court libellé si le morceau ne tiendrait sinon pas bien à l\'écran.';

  @override
  String get chorusRepeatAuto => 'Automatique';

  @override
  String get chorusRepeatFull => 'Afficher en entier';

  @override
  String get chorusRepeatLabel => 'Libellé seulement';

  @override
  String get settingsPageTurnHint =>
      'Touche le côté gauche ou droit de l\'écran pour reculer ou avancer. Tourne-page (pédale) et clavier : flèche droite, flèche bas, Page suivante et Espace pour avancer, flèche gauche, flèche haut et Page précédente pour reculer. Avec une pulsation (tempo et pulsation ou clic activés), maintenir avancer ou appuyer sur Entrée la démarre et l\'arrête.';

  @override
  String get settingsSetProgress => 'Barre de progression du set';

  @override
  String get settingsSetProgressHint =>
      'Une fine barre au-dessus de la barre du bas montre les morceaux du set et les pages du morceau actuel : la page actuelle dans la couleur d\'accent, les pages à venir dans un ton plus clair. Les repères comme les pauses sont en pointillés.';

  @override
  String get settingsBeatSection => 'Pulsation et clic';

  @override
  String get settingsBeatSectionHint =>
      'Tempo et mesure du morceau, ou tempo de l\'arrangement du groupe. Activé par défaut si ton instrument est la batterie.';

  @override
  String get settingsBeatDisplay => 'Indicateur de pulsation';

  @override
  String get settingsBeatDisplayHint =>
      'Des points à côté du tempo et de la mesure s\'allument à chaque temps ; le décompte affiche de grands chiffres.';

  @override
  String get settingsEdgeFlash => 'Faire clignoter le bord de l\'écran';

  @override
  String get settingsEdgeFlashHint =>
      'Le bord clignote à chaque temps, le 1 dans une autre couleur – visible du coin de l\'œil.';

  @override
  String get settingsClick => 'Clic';

  @override
  String get settingsClickHint =>
      'Joue un clic sur la sortie audio de l\'appareil, p. ex. dans le mix in-ear.';

  @override
  String get settingsClickStart => 'Démarrage';

  @override
  String get settingsClickStartHint =>
      'Manuellement : touche le tempo, maintiens la pédale avancer ou appuie sur Entrée. Passer à un autre morceau du set arrête la pulsation.';

  @override
  String get clickStartAutomatic => 'À chaque morceau';

  @override
  String get clickStartManual => 'Manuellement';

  @override
  String get settingsClickDuration => 'Durée';

  @override
  String get clickDurationSong => 'Tout le morceau';

  @override
  String get clickDurationCountIn => 'Décompte seulement';

  @override
  String get settingsClickInBackground => 'En arrière-plan';

  @override
  String get settingsClickInBackgroundHint =>
      'Quand l\'app est réduite, qu\'une autre app est ouverte ou que l\'écran est verrouillé.';

  @override
  String get clickInBackgroundStop => 'Arrêter';

  @override
  String get clickInBackgroundKeepPlaying => 'Continuer à jouer';

  @override
  String get settingsCountIn => 'Décompte';

  @override
  String get countInOff => 'Désactivé';

  @override
  String get countInOneBar => '1 mesure';

  @override
  String get countInTwoBars => '2 mesures';

  @override
  String get settingsClickVolume => 'Volume';

  @override
  String get settingsClickAccent => 'Accent sur le 1';

  @override
  String get settingsClickSound => 'Son';

  @override
  String get clickSoundClick => 'Clic';

  @override
  String get clickSoundWoodblock => 'Woodblock';

  @override
  String get clickSoundBeep => 'Bip';

  @override
  String get settingsClickSubdivision => 'Subdivisions';

  @override
  String get settingsClickSubdivisionHint =>
      'Clics plus discrets entre les temps. Chaque morceau peut avoir les siennes dans ses ajustements personnels.';

  @override
  String get subdivisionOff => 'Désactivées';

  @override
  String get subdivisionEighths => 'Croches';

  @override
  String get subdivisionSixteenths => 'Doubles croches';

  @override
  String get subdivisionTriplets => 'Triolets';

  @override
  String clickSubdivisionAsInSettings(String value) {
    return 'Comme dans les réglages ($value)';
  }

  @override
  String get clickGrouping => 'Regroupement';

  @override
  String get clickGroupingNone => 'Pas de groupes';

  @override
  String clickGroupingAsInSong(String grouping) {
    return 'Comme dans le morceau ($grouping)';
  }

  @override
  String get clickGroupingHint =>
      'Temps accentués d\'une mesure asymétrique, juste pour toi.';

  @override
  String get settingsAudioLatency => 'Latence audio';

  @override
  String get settingsAudioLatencyHint =>
      'Décale l\'affichage pour qu\'il corresponde à ce que tu entends. Les écouteurs filaires demandent peu, les écouteurs Bluetooth 100–300 ms.';

  @override
  String audioLatencyValue(int ms) {
    return '$ms ms';
  }

  @override
  String get audioLatencyCalibrate => 'Mesurer la latence audio';

  @override
  String get audioLatencyCalibrateTitle => 'Mesurer la latence audio';

  @override
  String get audioLatencyCalibrateHint =>
      'Mets les écouteurs que tu utilises sur scène et tape en rythme sur chaque temps du clic.';

  @override
  String get audioLatencyTap => 'Taper';

  @override
  String audioLatencyTaps(int count) {
    return '$count frappes';
  }

  @override
  String audioLatencyResult(int ms) {
    return 'Mesuré : $ms ms';
  }

  @override
  String get audioLatencyApply => 'Appliquer';

  @override
  String get clickNoAudio =>
      'Il n\'y a pas de sortie audio pour le clic sur cet appareil.';

  @override
  String get beatStart => 'Démarrer la pulsation';

  @override
  String get beatStop => 'Arrêter la pulsation';

  @override
  String get beatDisplayLabel => 'Pulsation';

  @override
  String countInBar(int bar, int count) {
    return 'Mesure $bar sur $count';
  }

  @override
  String get tempoSlower => 'Plus lent';

  @override
  String get tempoFaster => 'Plus rapide';

  @override
  String get tapTempo => 'Tap tempo';

  @override
  String get tempoReset => 'Revenir au tempo du morceau';

  @override
  String get clickNoAudioLive => 'Pas d\'audio pour le clic';

  @override
  String get settingsSongMap => 'Plan du morceau au lieu des accords';

  @override
  String get settingsSongMapHint =>
      'Le mode live montre les parties du morceau avec un repère des paroles et les notes de batterie.';

  @override
  String get songMapEmpty =>
      'Ce morceau n\'a pas de parties (verse, chorus, …) à afficher comme plan du morceau.';

  @override
  String get songMapNoTempo => 'Pas de tempo pour ce morceau';

  @override
  String get drumPanelSet => 'Set';

  @override
  String get drumPanelSongMap => 'Plan du morceau';

  @override
  String get settingsLiveAppearance => 'Apparence sur scène';

  @override
  String get settingsLiveAppearanceHint =>
      'Le mode live indépendamment du thème de l\'app. Le noir économise l\'énergie sur les écrans OLED.';

  @override
  String get liveAppearanceApp => 'Comme l\'app';

  @override
  String get liveAppearanceDark => 'Sombre';

  @override
  String get liveAppearanceBlack => 'Noir';

  @override
  String settingsStorageUsed(String size) {
    return 'Les pièces jointes PDF occupent $size';
  }

  @override
  String get appMenuEntryAdd => 'Ajouter au menu des applications';

  @override
  String get appMenuEntryAddHint =>
      'setDING avec son icône dans le menu de démarrage de ton bureau';

  @override
  String get appMenuEntryInstalled => 'Dans le menu des applications';

  @override
  String get appMenuEntryInstalledHint =>
      'Le menu de démarrage lance ce fichier AppImage';

  @override
  String get appMenuEntryRemove => 'Retirer';

  @override
  String get appMenuEntryAdded =>
      'setDING est maintenant dans le menu des applications';

  @override
  String get appMenuEntryRemoved => 'setDING retiré du menu des applications';

  @override
  String appMenuEntryFailed(String error) {
    return 'Menu des applications non modifié : $error';
  }

  @override
  String get settingsLogCopy => 'Copier le journal de diagnostic';

  @override
  String get settingsLogCopyHint =>
      'Les messages récents de l\'app, p. ex. pourquoi une synchronisation a échoué – à coller dans un message au support.';

  @override
  String get settingsLogCopied => 'Journal de diagnostic copié';

  @override
  String get settingsAbout =>
      'setDING fonctionne localement sur cet appareil. Toutes les données sont disponibles hors ligne.';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get lilypondNotice =>
      'Cette notation Lilypond utilise des fonctions que setDING ne sait pas dessiner. Source :';

  @override
  String get sequenceLabel => 'Ordre du morceau';

  @override
  String get sectionIntro => 'Intro';

  @override
  String get sectionPreChorus => 'Pre-chorus';

  @override
  String get sectionPostChorus => 'Post-chorus';

  @override
  String get sectionInterlude => 'Interlude';

  @override
  String get sectionInstrumental => 'Instrumental';

  @override
  String get sectionSolo => 'Solo';

  @override
  String get sectionTag => 'Tag';

  @override
  String get sectionOutro => 'Outro';

  @override
  String get sectionEnding => 'Ending';

  @override
  String get sectionTurnaround => 'Turnaround';

  @override
  String get sectionVamp => 'Vamp';

  @override
  String get sectionRefrain => 'Refrain';

  @override
  String get sectionBreakdown => 'Breakdown';

  @override
  String get editorGroupChords => 'Accords';

  @override
  String get editorGroupSections => 'Sections';

  @override
  String get editorGroupInfo => 'Infos du morceau';

  @override
  String get editorGroupText => 'Texte';

  @override
  String get editorGroupMore => 'Plus';

  @override
  String get searchMatchCase => 'Respecter la casse';

  @override
  String get replaceToggle => 'Remplacer';

  @override
  String get replaceWith => 'Remplacer par';

  @override
  String get replace => 'Remplacer';

  @override
  String get replaceAll => 'Tout remplacer';

  @override
  String replacedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count remplacés',
      one: '1 remplacé',
    );
    return '$_temp0';
  }

  @override
  String get convertChordsOverLyrics =>
      'Convertir les accords au-dessus des paroles';

  @override
  String get pastedChordsOverLyrics =>
      'Le texte collé a les accords au-dessus des paroles.';

  @override
  String get convert => 'Convertir';

  @override
  String get convertCcliGrids =>
      'Convertir les barres de mesure en grilles d\'accords';

  @override
  String ccliGridsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocs de barres de mesure peuvent',
      one: 'Un bloc de barres de mesure peut',
    );
    return '$_temp0 être affichés comme grille d\'accords.';
  }

  @override
  String get convertCommentHeadings =>
      'Convertir les titres en commentaire en sections';

  @override
  String commentHeadingsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sections sont marquées',
      one: 'Une section est marquée',
    );
    return '$_temp0 par un commentaire comme \"Verse 1\". La conversion en fait des sections ChordPro ; le morceau garde le même aspect.';
  }

  @override
  String get remove => 'Retirer';

  @override
  String get ccliFooterHint =>
      'Le morceau se termine par le pied de page CCLI de SongSelect. En le retirant, le numéro du morceau et le copyright restent dans les détails du morceau.';

  @override
  String legacyLabelsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count libellés de section sont',
      one: 'Un libellé de section est',
    );
    return '$_temp0 sous la forme courte. La spécification ChordPro recommande label=\"…\".';
  }

  @override
  String songSelectDirectivesHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count directives CCLI ne suivent pas',
      one: 'Une directive CCLI ne suit pas',
    );
    return '$_temp0 la spécification ChordPro : ccli devient x_ccli, ccli_license est retirée.';
  }

  @override
  String importLegacyLabelsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux importés écrivent',
      one: '1 morceau importé écrit',
    );
    return '$_temp0 les libellés de section sous la forme courte. La conversion les écrit comme label=\"…\", comme le recommande la spécification ChordPro ; les morceaux gardent le même aspect.';
  }

  @override
  String get convertLabels => 'Convertir les libellés';

  @override
  String songsLabelsConverted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Libellés convertis dans $count morceaux',
      one: 'Libellés convertis dans 1 morceau',
      zero: 'Aucun libellé converti',
    );
    return '$_temp0';
  }

  @override
  String get hideHint => 'Masquer l\'astuce';

  @override
  String get searchInSong => 'Rechercher';

  @override
  String get searchNoMatches => 'Aucun résultat';

  @override
  String get searchPrevious => 'Résultat précédent';

  @override
  String get searchNext => 'Résultat suivant';

  @override
  String get searchClose => 'Fermer la recherche';

  @override
  String searchMatchCount(int current, int total) {
    return '$current sur $total';
  }

  @override
  String get editorGroupLines => 'Lignes';

  @override
  String get redo => 'Rétablir';

  @override
  String get moveLinesUp => 'Monter la ligne';

  @override
  String get moveLinesDown => 'Descendre la ligne';

  @override
  String get moveChordLeft => 'Déplacer l\'accord à gauche';

  @override
  String get moveChordRight => 'Déplacer l\'accord à droite';

  @override
  String get duplicateLines => 'Dupliquer la ligne';

  @override
  String get deleteLines => 'Supprimer la ligne';

  @override
  String get toggleComment => 'Commenter la ligne (#)';

  @override
  String get insertOptionalChord => 'Accord facultatif';

  @override
  String get insertAnnotation => 'Annotation';

  @override
  String get insertNoChord => 'Pas d\'accord (N.C.)';

  @override
  String get insertDefine => 'Définition d\'accord';

  @override
  String get insertChordDiagram => 'Diagramme d\'accord';

  @override
  String get insertTranspose => 'Transposer';

  @override
  String get insertTab => 'Tab';

  @override
  String get insertGrid => 'Grille d\'accords';

  @override
  String get insertChorusRecall => 'Répéter le chorus';

  @override
  String get metaSubtitle => 'Sous-titre';

  @override
  String get metaComposer => 'Compositeur';

  @override
  String get metaLyricist => 'Parolier';

  @override
  String get metaCopyright => 'Copyright';

  @override
  String get metaCcli => 'Numéro CCLI';

  @override
  String get metaTag => 'Tag';

  @override
  String get metaYear => 'Année';

  @override
  String get metaAlbum => 'Album';

  @override
  String get metaDuration => 'Durée';

  @override
  String get metaTempo => 'Tempo (BPM)';

  @override
  String get metaTime => 'Mesure';

  @override
  String get metaKey => 'Tonalité';

  @override
  String get insertCommentItalic => 'Commentaire (italique)';

  @override
  String get insertCommentBox => 'Commentaire (encadré)';

  @override
  String get insertHighlight => 'Surlignage';

  @override
  String get insertBold => 'Gras';

  @override
  String get insertItalic => 'Italique';

  @override
  String get insertUnderline => 'Souligné';

  @override
  String get insertColour => 'Couleur';

  @override
  String get insertColumnBreak => 'Saut de colonne';

  @override
  String get insertNewPage => 'Saut de page';

  @override
  String get insertColumns => 'Colonnes';

  @override
  String get insertImage => 'Image';

  @override
  String get insertAbc => 'Notation ABC';

  @override
  String get insertTextblock => 'Bloc de texte';

  @override
  String get insertNewSong => 'Morceau suivant dans le même fichier';

  @override
  String get sequenceEdit => 'Ordre du morceau pour ce set';

  @override
  String get sequenceFromSet => 'Ordre modifié pour ce set';

  @override
  String get sequenceFromBand => 'Ordre du groupe';

  @override
  String get bandArrangement => 'Arrangement du groupe';

  @override
  String arrangementOf(String band) {
    return 'Arrangement de $band';
  }

  @override
  String get arrangementBand => 'Groupe';

  @override
  String get arrangementAsWritten => 'Comme dans le morceau';

  @override
  String arrangementKey(String key) {
    return 'Tonalité $key';
  }

  @override
  String get arrangementSequence => 'Ordre';

  @override
  String get arrangementTempo => 'Tempo';

  @override
  String get arrangementTempoLabel =>
      'Tempo en BPM (vide = comme dans le morceau)';

  @override
  String get arrangementReset =>
      'Réinitialiser l\'arrangement du groupe au morceau';

  @override
  String sequenceOriginal(Object sequence) {
    return 'Dans le morceau : $sequence';
  }

  @override
  String get sequenceNoneInSong => 'Le morceau n\'a pas d\'ordre.';

  @override
  String get sequenceRestore => 'Utiliser l\'ordre du morceau';

  @override
  String get sequenceHint => 'p. ex. I, V1, C, V2, PC, C x2, B, O';

  @override
  String get sequenceAbbreviations =>
      'I Intro · V Verse · PC Pre-chorus · C Chorus · B Bridge · Int Interlude · Solo · T Tag · O Outro · C x2 = deux fois';

  @override
  String get sequenceEmpty =>
      'Touche les parties ci-dessous pour construire l\'ordre, ou fais-les glisser ici.';

  @override
  String get sequenceReorderHint =>
      'Appuie longuement sur une partie pour la déplacer à une autre position.';

  @override
  String get sequenceSongParts => 'Parties du morceau';

  @override
  String get sequenceCommonParts =>
      'Parties courantes (le morceau n\'a pas encore de sections)';

  @override
  String get sequenceClear => 'Vider';

  @override
  String get sequenceAsText => 'Modifier en texte';

  @override
  String get settingsSectionAccount => 'Compte et synchronisation';

  @override
  String get accountSignedOut => 'Non connecté';

  @override
  String get accountSignedOutHint =>
      'Connecte-toi pour partager morceaux et sets avec ton groupe. Sans compte, setDING continue de fonctionner localement sur cet appareil.';

  @override
  String get accountSignIn => 'Se connecter';

  @override
  String get accountSignUp => 'Créer un compte';

  @override
  String get accountJoin => 'Rejoindre avec une invitation';

  @override
  String get accountSignOut => 'Se déconnecter';

  @override
  String get accountSignOutTitle => 'Se déconnecter ?';

  @override
  String get accountSignOutMessage =>
      'Les morceaux et sets sur cet appareil sont conservés.';

  @override
  String get accountSignOutMessageWeb =>
      'Les données de ce navigateur sont supprimées. Les morceaux et sets restent sur le serveur.';

  @override
  String get accountEmail => 'E-mail';

  @override
  String get accountPassword => 'Mot de passe';

  @override
  String get accountPasswordConfirm => 'Confirmer le mot de passe';

  @override
  String get accountPasswordShow => 'Afficher le mot de passe';

  @override
  String get accountPasswordHide => 'Masquer le mot de passe';

  @override
  String get accountKeepSignedIn => 'Rester connecté';

  @override
  String get accountKeepSignedInHint =>
      'Seulement sur ton propre appareil. Sinon tu es déconnecté à la fermeture du navigateur.';

  @override
  String get accountName => 'Nom';

  @override
  String get accountNameHint => 'Comment les membres de ton groupe te voient.';

  @override
  String get accountToSignUp => 'Pas encore de compte ? Crée-en un';

  @override
  String get accountToSignIn => 'Déjà un compte ? Connecte-toi';

  @override
  String get accountForgotPassword => 'Mot de passe oublié ?';

  @override
  String get accountResetTitle => 'Réinitialiser le mot de passe';

  @override
  String get accountResetSent =>
      'Si un compte existe avec cette adresse, un e-mail de réinitialisation a été envoyé.';

  @override
  String get accountFieldRequired => 'Obligatoire.';

  @override
  String accountPasswordTooShort(int min) {
    return 'Au moins $min caractères.';
  }

  @override
  String get accountPasswordMismatch =>
      'Les mots de passe ne correspondent pas.';

  @override
  String get accountChangeName => 'Changer le nom';

  @override
  String get accountNameChanged => 'Nom changé.';

  @override
  String get accountChangePassword => 'Changer le mot de passe';

  @override
  String get accountChangePasswordHint =>
      'Tu restes connecté sur cet appareil. Tes autres appareils sont déconnectés.';

  @override
  String get accountCurrentPassword => 'Mot de passe actuel';

  @override
  String get accountNewPassword => 'Nouveau mot de passe';

  @override
  String get accountPasswordWrongCurrent =>
      'Le mot de passe actuel est incorrect.';

  @override
  String get accountPasswordChanged =>
      'Mot de passe changé. Reconnecte-toi sur tes autres appareils.';

  @override
  String get accountDelete => 'Supprimer le compte';

  @override
  String get accountDeleteHint =>
      'Supprime définitivement ton compte et tes données personnelles.';

  @override
  String get accountDeleteTitle => 'Supprimer le compte ?';

  @override
  String get accountDeleteMessage =>
      'Ton compte, tes ajustements personnels, annotations et réglages sont supprimés définitivement, et tu es déconnecté sur tous les appareils. Les morceaux et sets restent dans tes organisations. Les sauvegardes du serveur en gardent une copie jusqu\'à 14 jours. Saisis ton mot de passe pour confirmer.';

  @override
  String get accountDeleteSoleAdmin =>
      'Tu es le seul admin de ces organisations. Nomme d\'abord quelqu\'un d\'autre admin ou ferme l\'organisation :';

  @override
  String get accountDeleted => 'Ton compte a été supprimé.';

  @override
  String get dangerZone => 'Zone de danger';

  @override
  String get accountErrorNetwork =>
      'Pas de connexion au serveur. Vérifie ta connexion Internet.';

  @override
  String get accountErrorInvalidCredentials =>
      'E-mail ou mot de passe incorrect.';

  @override
  String get accountErrorEmailTaken =>
      'Un compte avec cette adresse e-mail existe déjà.';

  @override
  String get accountErrorInvalidEmail => 'L\'adresse e-mail n\'est pas valide.';

  @override
  String get accountErrorWeakPassword =>
      'Le mot de passe ne remplit pas les exigences du serveur.';

  @override
  String get accountErrorServer =>
      'Le serveur a signalé une erreur. Réessaie plus tard.';

  @override
  String get accountErrorUpdateRequired =>
      'Cette version de setDING est trop ancienne pour le serveur. Mets l\'app à jour.';

  @override
  String get updateRequiredTitle => 'Mets setDING à jour';

  @override
  String get updateRequiredBody =>
      'Le serveur n\'accepte plus cette version, rien n\'est donc synchronisé. Tes modifications restent sur cet appareil et sont envoyées après la mise à jour.';

  @override
  String updateRequiredVersions(String current, String minimum) {
    return 'Installée : $current, requise : $minimum ou plus récente.';
  }

  @override
  String get updateRequiredHowTo =>
      'Sur Android, mets-la à jour dans Obtainium ; sinon télécharge la nouvelle version depuis les releases setDING sur GitHub.';

  @override
  String get updateRequiredReload => 'Recharger';

  @override
  String get updateRequiredCopyLink => 'Copier le lien de téléchargement';

  @override
  String get updateRequiredCopied => 'Lien copié.';

  @override
  String updateAvailableTitle(String version) {
    return 'setDING $version est disponible';
  }

  @override
  String get updateAvailableDetails => 'Détails';

  @override
  String updateAvailableInstalled(String current) {
    return 'Installée : $current.';
  }

  @override
  String get settingsServer => 'Serveur';

  @override
  String get settingsServerHint => 'Le changer te déconnecte.';

  @override
  String get settingsServerInvalid =>
      'L\'adresse doit commencer par http:// ou https://.';

  @override
  String get bandLocal => 'Sur cet appareil';

  @override
  String get bandLocalHint => 'Seulement sur cet appareil, non synchronisé.';

  @override
  String get bandSwitch => 'Changer de groupe';

  @override
  String get bandManage => 'Gérer les groupes';

  @override
  String get bandNone => 'Aucun groupe';

  @override
  String noBandInLibrary(String organization) {
    return 'Tu ne fais partie d\'aucun groupe de $organization. Les sets appartiennent à un groupe : crées-en un ou demande à être ajouté.';
  }

  @override
  String get librarySwitch => 'Changer de bibliothèque de morceaux';

  @override
  String get bandsTitle => 'Groupes';

  @override
  String get bandsEmpty =>
      'Tu ne fais pas encore partie d\'un groupe. Crée un groupe pour tes morceaux et sets.';

  @override
  String get bandsSignInHint => 'Connecte-toi pour créer des groupes.';

  @override
  String get bandNew => 'Nouveau groupe';

  @override
  String get bandName => 'Nom du groupe';

  @override
  String get bandRoleAdmin => 'Admin';

  @override
  String get bandRoleMember => 'Membre';

  @override
  String get bandMembers => 'Membres';

  @override
  String bandYou(String name) {
    return '$name (toi)';
  }

  @override
  String get bandMakeAdmin => 'Nommer admin';

  @override
  String get bandMakeMember => 'Nommer membre';

  @override
  String get bandRoleLeader => 'Leader';

  @override
  String get bandRolePlanner => 'Planificateur de sets';

  @override
  String get orgRoleLibrarian => 'Bibliothécaire';

  @override
  String get bandMakeLeader => 'Nommer leader';

  @override
  String get bandMakePlanner => 'Nommer planificateur de sets';

  @override
  String get orgMakeLibrarian => 'Nommer bibliothécaire';

  @override
  String get orgLibrarianHint =>
      'Les bibliothécaires créent, modifient et suppriment les morceaux de l\'organisation.';

  @override
  String get bandPlannerHint =>
      'Les planificateurs de sets composent les sets du groupe.';

  @override
  String get inviteBandHint =>
      'Crée un lien valable 7 jours. Quiconque l\'ouvre rejoint l\'organisation et ce groupe en tant que membre. Sous Membres, tu peux ensuite changer son rôle dans le groupe.';

  @override
  String joinQuestionBand(String band, String org) {
    return 'Rejoindre $band ($org) ?';
  }

  @override
  String get joinExplanationBand =>
      'Tu deviens membre de l\'organisation et du groupe et tu vois ses morceaux et ses sets.';

  @override
  String get bandRemoveMember => 'Retirer du groupe';

  @override
  String bandRemoveTitle(String name) {
    return 'Retirer $name ?';
  }

  @override
  String bandRemoveMessage(String name) {
    return '$name ne verra plus les morceaux et les sets du groupe.';
  }

  @override
  String get bandLeave => 'Quitter le groupe';

  @override
  String bandLeaveTitle(String band) {
    return 'Quitter $band ?';
  }

  @override
  String get bandLeaveMessage =>
      'Tu ne verras plus les morceaux et les sets du groupe. Un admin peut t\'inviter à nouveau.';

  @override
  String get bandRefresh => 'Actualiser';

  @override
  String get bandErrorLastAdmin => 'Un groupe a besoin d\'au moins un admin.';

  @override
  String get bandErrorNotAllowed =>
      'Non autorisé, ou le groupe n\'existe plus.';

  @override
  String get accountErrorSignedOut => 'Connecte-toi.';

  @override
  String get copyToBand => 'Copier dans un groupe';

  @override
  String get copyToBandTitle => 'Copier dans quel groupe ?';

  @override
  String get copyToBandNoTarget =>
      'Il n\'y a aucun autre groupe dans lequel tu peux copier.';

  @override
  String copiedSongs(int count, String band) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux copiés dans $band',
      one: '1 morceau copié dans $band',
    );
    return '$_temp0';
  }

  @override
  String copiedSet(String band) {
    return 'Set copié dans $band';
  }

  @override
  String songsSelected(int count) {
    return '$count sélectionnés';
  }

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String get selectMode => 'Sélectionner';

  @override
  String get deleteSelected => 'Supprimer la sélection';

  @override
  String deleteSongsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Supprimer $count morceaux ?',
      one: 'Supprimer 1 morceau ?',
    );
    return '$_temp0';
  }

  @override
  String deleteSongsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Les $count morceaux sélectionnés seront supprimés et retirés de tous les sets.',
      one: 'Le morceau sélectionné sera supprimé et retiré de tous les sets.',
    );
    return '$_temp0 Tu peux les restaurer depuis la corbeille.';
  }

  @override
  String songsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux supprimés',
      one: '1 morceau supprimé',
    );
    return '$_temp0';
  }

  @override
  String get bandRoleOrgAdmin => 'Admin de l\'organisation';

  @override
  String get bandOrganization => 'Organisation';

  @override
  String get bandNewOrganization => 'Nouvelle organisation';

  @override
  String get bandNewHint =>
      'Les groupes d\'une organisation partagent leurs morceaux.';

  @override
  String get bandAddMember => 'Ajouter un membre';

  @override
  String get bandAddMemberTitle => 'Ajouter qui ?';

  @override
  String get bandAddMemberNone =>
      'Tout le monde dans l\'organisation fait déjà partie de ce groupe.';

  @override
  String get bandOrgAdminHint =>
      'Tu gères ce groupe en tant qu\'admin de l\'organisation.';

  @override
  String get bandErrorNotOrgMember =>
      'Cette personne n\'est pas membre de l\'organisation.';

  @override
  String get orgName => 'Nom de l\'organisation';

  @override
  String get orgPeople => 'Personnes';

  @override
  String get orgBands => 'Groupes';

  @override
  String get orgRemove => 'Retirer de l\'organisation';

  @override
  String orgRemoveTitle(String name) {
    return 'Retirer $name ?';
  }

  @override
  String orgRemoveMessage(String name) {
    return '$name quittera aussi tous les groupes de l\'organisation et ne verra plus ses morceaux.';
  }

  @override
  String get orgLeave => 'Quitter l\'organisation';

  @override
  String orgLeaveTitle(String org) {
    return 'Quitter $org ?';
  }

  @override
  String get orgLeaveMessage =>
      'Tu quitteras aussi tous ses groupes et ne verras plus ses morceaux.';

  @override
  String get orgSongsShared =>
      'Tous les groupes de l\'organisation partagent les mêmes morceaux.';

  @override
  String get copyToLibraryTitle =>
      'Copier dans quelle bibliothèque de morceaux ?';

  @override
  String get inviteCreate => 'Inviter des personnes';

  @override
  String get inviteCreateHint =>
      'Crée un lien valable 7 jours. Quiconque l\'ouvre rejoint l\'organisation en tant que membre, mais pas encore de groupe. Ajoute-le ensuite à un groupe ; sous Personnes, tu peux changer son rôle.';

  @override
  String get inviteLinkTitle => 'Lien d\'invitation';

  @override
  String inviteLinkHint(String date) {
    return 'Partage le lien, p. ex. dans une discussion de groupe, ou fais scanner le code QR. Valable jusqu\'au $date. Tu peux l\'afficher à nouveau depuis la liste des liens.';
  }

  @override
  String get inviteCopy => 'Copier le lien';

  @override
  String get inviteCopied => 'Lien copié';

  @override
  String get invitesTitle => 'Liens d\'invitation';

  @override
  String inviteDates(String created, String expires) {
    return 'Créé le $created, valable jusqu\'au $expires';
  }

  @override
  String get inviteOrganizationOnly => 'Organisation seulement';

  @override
  String get inviteShow => 'Afficher le lien';

  @override
  String inviteJoined(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ont rejoint : $names',
      one: 'A rejoint : $names',
      zero: 'Personne n\'a encore rejoint',
    );
    return '$_temp0';
  }

  @override
  String get inviteRevoke => 'Révoquer';

  @override
  String get inviteRevokeTitle => 'Révoquer le lien ?';

  @override
  String get inviteRevokeMessage =>
      'Le lien ne fonctionnera plus. Les personnes déjà inscrites restent membres.';

  @override
  String get inviteAskAdmin =>
      'Demande une invitation à un admin de l\'organisation ou à un leader de groupe.';

  @override
  String get inviteErrorUnknown =>
      'Cette invitation n\'existe pas. Vérifie le lien.';

  @override
  String get inviteErrorExpired =>
      'Cette invitation a expiré. Demande un nouveau lien.';

  @override
  String get inviteErrorRevoked =>
      'Cette invitation a été révoquée. Demande un nouveau lien.';

  @override
  String get joinTitle => 'Rejoindre';

  @override
  String get joinHint => 'Colle le lien d\'invitation que tu as reçu.';

  @override
  String get joinLink => 'Lien d\'invitation';

  @override
  String get joinContinue => 'Continuer';

  @override
  String get joinInvalidLink => 'Ce n\'est pas un lien d\'invitation valide.';

  @override
  String joinQuestion(String org) {
    return 'Rejoindre $org ?';
  }

  @override
  String get joinExplanation =>
      'Tu deviens membre de l\'organisation et tu vois ses morceaux. Un admin peut ensuite t\'ajouter à un groupe.';

  @override
  String joinAlreadyMember(String org) {
    return 'Tu es déjà membre de $org.';
  }

  @override
  String get joinButton => 'Rejoindre';

  @override
  String joinDone(String org) {
    return 'Tu as rejoint $org.';
  }

  @override
  String get joinSignInFirst =>
      'Connecte-toi ou crée un compte pour rejoindre.';

  @override
  String get joinHaveAccount => 'J\'ai déjà un compte';

  @override
  String get inviteErrorUsed =>
      'Cette invitation a déjà été utilisée. Demande un nouveau lien.';

  @override
  String get inviteErrorNotStored =>
      'Ce lien ne peut plus être affiché. Crées-en un nouveau.';

  @override
  String get accountErrorInvitationRequired =>
      'Ce serveur n\'accepte de nouveaux comptes qu\'avec un lien d\'invitation.';

  @override
  String get accountErrorEmailNotVerified =>
      'Confirme d\'abord ton adresse e-mail. Nous t\'avons envoyé un nouvel e-mail.';

  @override
  String get bandErrorFounderInvitationRequired =>
      'Les nouvelles organisations nécessitent une invitation de fondateur de l\'exploitant du serveur.';

  @override
  String get accountInviteOnlyHint =>
      'Sur ce serveur, les nouveaux comptes nécessitent un lien d\'invitation.';

  @override
  String accountVerifyEmail(String email) {
    return 'Presque fini : nous avons envoyé un e-mail à $email. Confirme ton adresse avec le lien qu\'il contient, puis connecte-toi.';
  }

  @override
  String get accountVerifyResend => 'Renvoyer l\'e-mail';

  @override
  String get accountVerifySent => 'E-mail envoyé.';

  @override
  String joinFoundQuestion(String org) {
    return 'Fonder $org ?';
  }

  @override
  String get joinFoundExplanation =>
      'Tu crées l\'organisation et en deviens admin. Tu peux ensuite créer des groupes et inviter des personnes.';

  @override
  String get joinFoundButton => 'Fonder l\'organisation';

  @override
  String joinFoundDone(String org) {
    return 'Tu as fondé $org.';
  }

  @override
  String get syncTitle => 'Synchronisation';

  @override
  String get syncNow => 'Synchroniser maintenant';

  @override
  String get settingsSyncMode => 'Synchronisation';

  @override
  String get syncModeAutomatic => 'Automatique';

  @override
  String get syncModeOnStart => 'Au démarrage';

  @override
  String get syncModeManual => 'Manuelle';

  @override
  String get syncModeAutomaticHint =>
      'Synchronise au démarrage, quelques secondes après les modifications, quand quelque chose change sur le serveur et toutes les 5 minutes.';

  @override
  String get syncModeOnStartHint =>
      'Synchronise une fois au démarrage de l\'app et après la connexion. Sinon avec « Synchroniser maintenant ».';

  @override
  String get syncModeManualHint =>
      'Synchronise seulement quand tu touches « Synchroniser maintenant ».';

  @override
  String get syncRunning => 'Synchronisation …';

  @override
  String syncLast(String time) {
    return 'Dernière synchronisation : $time';
  }

  @override
  String get syncNever => 'Pas encore synchronisé';

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifications ne sont pas encore sur le serveur.',
      one: '1 modification n\'est pas encore sur le serveur.',
      zero: 'Toutes les modifications sont sur le serveur.',
    );
    return '$_temp0';
  }

  @override
  String get syncOffline =>
      'Pas de connexion – les modifications seront envoyées plus tard.';

  @override
  String syncConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux en conflit – ouvre-les pour décider.',
      one: '1 morceau en conflit – ouvre-le pour décider.',
    );
    return '$_temp0';
  }

  @override
  String get conflictBanner =>
      'Ce morceau a été modifié sur le serveur et sur cet appareil.';

  @override
  String get conflictBannerDeleted =>
      'Ce morceau a été supprimé sur le serveur et modifié sur cet appareil.';

  @override
  String get conflictKeepMine => 'Garder la mienne';

  @override
  String get conflictTakeServer => 'Utiliser la version du serveur';

  @override
  String get conflictKeepBoth => 'Garder les deux';

  @override
  String get conflictCompare => 'Afficher la version du serveur';

  @override
  String get conflictServerVersion => 'Version du serveur';

  @override
  String get conflictKeptBoth =>
      'Ta version a été enregistrée comme morceau séparé.';

  @override
  String get accountErrorConflict =>
      'Le morceau a été modifié entre-temps sur le serveur.';

  @override
  String get pdfMissing =>
      'Le PDF n\'est pas encore sur cet appareil. Il sera téléchargé à la prochaine synchronisation.';

  @override
  String get pdfLoadFailed =>
      'Le PDF n\'a pas pu être chargé depuis le serveur. Vérifie la connexion et rouvre le morceau.';

  @override
  String get openAttachment => 'Ouvrir';

  @override
  String get imageMissing => 'L\'image n\'est pas sur cet appareil.';

  @override
  String syncMissingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count PDF sont encore en cours de téléchargement.',
      one: '1 PDF est encore en cours de téléchargement.',
    );
    return '$_temp0';
  }

  @override
  String get invalidChordProTitle => 'Vérifier le ChordPro ?';

  @override
  String get invalidChordProMessage =>
      'Le morceau contient des endroits qui ne seront probablement pas affichés comme prévu :';

  @override
  String problemUnclosedDirective(int line) {
    return 'Ligne $line : une accolade (directive) n\'est pas fermée.';
  }

  @override
  String problemUnclosedChord(int line) {
    return 'Ligne $line : un crochet (accord) n\'est pas fermé.';
  }

  @override
  String problemUnclosedEnvironment(int line) {
    return 'Ligne $line : le bloc n\'est jamais terminé et contient tout le reste du morceau.';
  }

  @override
  String problemTextAfterDirective(int line) {
    return 'Ligne $line : texte après une directive ; toute la ligne est affichée comme paroles.';
  }

  @override
  String problemInvalidKey(int line) {
    return 'Ligne $line : la directive key ne donne aucune tonalité ; le morceau n\'a pas de tonalité pour la transposition et les vues d\'accords.';
  }

  @override
  String chordProProblemsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count endroits du ChordPro ne seront probablement pas affichés comme prévu',
      one: '1 endroit du ChordPro ne sera probablement pas affiché comme prévu',
    );
    return '$_temp0';
  }

  @override
  String chordProProblemsShow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Afficher les $count problèmes ChordPro',
      one: 'Afficher le problème ChordPro',
    );
    return '$_temp0';
  }

  @override
  String setChordProProblemsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux avec des problèmes ChordPro',
      one: '1 morceau avec des problèmes ChordPro',
    );
    return '$_temp0';
  }

  @override
  String get importProblemsTitle => 'Vérifier l\'importation';

  @override
  String importProblemsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux importés contiennent des endroits',
      one: '1 morceau importé contient des endroits',
    );
    return '$_temp0 qui ne seront probablement pas affichés comme prévu :';
  }

  @override
  String importProblemItem(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count endroits',
      one: '1 endroit',
    );
    return '$title ($_temp0)';
  }

  @override
  String get importProblemsHint =>
      'Les morceaux sont marqués dans la liste des morceaux. La correction automatique ne modifie que les endroits avec une réparation claire ; corrige le reste dans l\'éditeur.';

  @override
  String songsFixed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux corrigés',
      one: '1 morceau corrigé',
      zero: 'Aucun morceau corrigé',
    );
    return '$_temp0';
  }

  @override
  String moreProblems(int count) {
    return '… et $count de plus.';
  }

  @override
  String get saveAnyway => 'Enregistrer quand même';

  @override
  String get fixProblems => 'Corriger automatiquement';

  @override
  String get keepEditing => 'Continuer à modifier';

  @override
  String get webSignInHint =>
      'Connecte-toi pour gérer organisations, groupes, morceaux et sets dans le navigateur.';

  @override
  String get webNoBandTitle => 'Pas encore de groupe';

  @override
  String get webNoBandMessage =>
      'Tu ne fais pas encore partie d\'un groupe. Crée une organisation avec un groupe, ou rejoins-en une avec un lien d\'invitation.';

  @override
  String get songDetails => 'Détails du morceau';

  @override
  String get songDetailsTooltip =>
      'Modifier titre, tonalité, tempo et plus du morceau – pour tous';

  @override
  String get noKey => 'Pas de tonalité';

  @override
  String get timeHint => 'p. ex. 4/4';

  @override
  String get noSequence => 'Pas d\'ordre';

  @override
  String get sequenceChange => 'Changer l\'ordre du morceau';

  @override
  String get sortSongs => 'Trier';

  @override
  String get sortByTitle => 'Titre';

  @override
  String get sortByArtist => 'Artiste';

  @override
  String get sortByKey => 'Tonalité';

  @override
  String get sortByRecent => 'Modifiés récemment';

  @override
  String get noArtist => 'Pas d\'artiste';

  @override
  String get songConflictTooltip =>
      'Modifié ici et sur le serveur – ouvre le morceau pour décider';

  @override
  String get pdfOnlyTooltip => 'Partition (PDF) seulement, sans accords';

  @override
  String upcomingGigTooltip(String set, String date) {
    return 'Dans « $set » le $date';
  }

  @override
  String get foundInLyrics => 'Trouvé dans les paroles';

  @override
  String hiddenParts(String parts) {
    return 'Masquées (pas dans l\'ordre) : $parts';
  }

  @override
  String get setsUpcoming => 'À venir';

  @override
  String get setsUndated => 'Sans date';

  @override
  String setsPast(int count) {
    return 'Passés ($count)';
  }

  @override
  String get showPastSets => 'Afficher les sets passés';

  @override
  String get hidePastSets => 'Masquer les sets passés';

  @override
  String get nextGig => 'Prochain concert';

  @override
  String gigInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Dans $days jours',
      one: 'Demain',
      zero: 'Aujourd\'hui',
    );
    return '$_temp0';
  }

  @override
  String get undo => 'Annuler';

  @override
  String songDeleted(String title) {
    return '« $title » supprimé';
  }

  @override
  String setDeleted(String name) {
    return 'Set « $name » supprimé';
  }

  @override
  String attachmentDeleted(String name) {
    return 'Pièce jointe « $name » supprimée';
  }

  @override
  String setItemRemoved(String title) {
    return '« $title » retiré du set';
  }

  @override
  String get settingsGroupPersonal => 'Personnel – sur tous tes appareils';

  @override
  String get settingsGroupDevice => 'Cet appareil';

  @override
  String get settingsGroupAccount => 'Compte et organisation';

  @override
  String get settingsScopePersonalHint =>
      'Ces réglages appartiennent à ton compte et s\'appliquent sur tous les appareils où tu es connecté.';

  @override
  String get settingsScopePersonalSignedOutHint =>
      'Tant que tu n\'es pas connecté, ces réglages s\'appliquent seulement sur cet appareil. Après la connexion, ils sont synchronisés avec ton compte.';

  @override
  String get settingsScopeDeviceHint =>
      'Ces réglages s\'appliquent seulement sur cet appareil et ne sont pas synchronisés.';

  @override
  String get settingsTakenOver =>
      'Les réglages de ton compte ont été appliqués.';

  @override
  String get annotationsDraw => 'Dessiner des annotations';

  @override
  String get annotationsShow => 'Afficher les annotations';

  @override
  String get annotationsHide => 'Masquer les annotations';

  @override
  String get annotationPen => 'Stylo';

  @override
  String get annotationHighlighter => 'Surligneur';

  @override
  String get annotationText => 'Texte';

  @override
  String get annotationTextHint => 'Saisir un texte';

  @override
  String get annotationEraser => 'Gomme (trait entier)';

  @override
  String get annotationPartialEraser => 'Gomme (partie d\'un trait)';

  @override
  String get annotationLasso => 'Sélectionner (lasso)';

  @override
  String get annotationStamps => 'Tampons';

  @override
  String get annotationStampsMusic => 'Signes musicaux';

  @override
  String get annotationStampsRepeats => 'Reprises';

  @override
  String get annotationStampsCues => 'Signaux';

  @override
  String annotationColor(Object number) {
    return 'Couleur $number';
  }

  @override
  String get annotationSize => 'Épaisseur du trait';

  @override
  String get annotationSmaller => 'Plus petit';

  @override
  String get annotationLarger => 'Plus grand';

  @override
  String get annotationDeleteSelection => 'Supprimer la sélection';

  @override
  String get annotationUndo => 'Annuler';

  @override
  String get annotationRedo => 'Rétablir';

  @override
  String get annotationMore => 'Plus';

  @override
  String get annotationDrawWithFinger => 'Dessiner au doigt';

  @override
  String get annotationDone => 'Terminé';

  @override
  String get annotationsDeleteAll =>
      'Supprimer toutes les annotations de ce morceau';

  @override
  String get annotationsDeleted => 'Annotations supprimées';

  @override
  String get annotationsOtherLayout => 'Dessinées pour une autre vue';

  @override
  String get annotationsOtherLayoutLandscape => 'Dessinées en paysage';

  @override
  String get annotationsOtherLayoutPortrait => 'Dessinées en portrait';

  @override
  String annotationsOrphaned(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count annotations sans leur ligne',
      one: '1 annotation sans sa ligne',
    );
    return '$_temp0';
  }

  @override
  String get annotationsFull =>
      'Annotations pleines : efface-en pour en dessiner d\'autres';

  @override
  String annotationsNearlyFull(int percent) {
    return 'Annotations pleines à $percent %';
  }

  @override
  String get annotationsPanelTitle => 'Annotations à main levée';

  @override
  String get annotationsPanelShow => 'Afficher mes annotations';

  @override
  String annotationsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count annotations',
      one: '1 annotation',
      zero: 'Aucune pour l\'instant : dessine-les en mode live',
    );
    return '$_temp0';
  }

  @override
  String get settingsShowAnnotations => 'Afficher les annotations à main levée';

  @override
  String get settingsShowAnnotationsHint =>
      'Tes propres dessins sur les morceaux et partitions';

  @override
  String get settingsRepeatedChorusOnce =>
      'Afficher un refrain écrit en entier une seule fois';

  @override
  String get settingsRepeatedChorusOnceHint =>
      'Un refrain réécrit plus loin mot pour mot est omis';

  @override
  String get settingsShowOutsideSequence =>
      'Afficher les parties hors de l\'ordre';

  @override
  String get settingsShowOutsideSequenceHint =>
      'Atténuées en mode live au lieu d\'être masquées';

  @override
  String get settingsAnnotationFinger => 'Dessiner les annotations au doigt';

  @override
  String get settingsAnnotationFingerHint =>
      'Pour les appareils sans stylet ; sinon les doigts continuent de tourner les pages';

  @override
  String get settingsSpaceStartsBeat => 'Espace démarre la pulsation';

  @override
  String get settingsSpaceStartsBeatHint =>
      'Espace démarre et arrête la pulsation et le clic comme Entrée, au lieu d\'avancer';

  @override
  String get stampFermata => 'Point d\'orgue';

  @override
  String get stampBreath => 'Respiration';

  @override
  String get stampCrescendo => 'Crescendo';

  @override
  String get stampDecrescendo => 'Decrescendo';

  @override
  String get stampRitardando => 'Ritardando';

  @override
  String get stampAccent => 'Accent';

  @override
  String stampRepeat(Object times) {
    return 'Jouer $times×';
  }

  @override
  String get stampRepeatStart => 'Début de reprise';

  @override
  String get stampRepeatEnd => 'Fin de reprise';

  @override
  String get stampCoda => 'Coda';

  @override
  String get stampSegno => 'Segno';

  @override
  String get stampGlasses => 'Attention';

  @override
  String get stampStop => 'Stop';

  @override
  String get stampEye => 'Regarder';

  @override
  String get stampExclamation => 'Important';

  @override
  String get stampStar => 'Étoile';

  @override
  String get settingsSectionBands => 'Organisation et groupes';

  @override
  String get settingsCategoryBandsHint =>
      'Organisations, groupes, membres et invitations';

  @override
  String get settingsBandsJoinHint =>
      'Rejoins une organisation ou un groupe avec un lien d\'invitation.';

  @override
  String get settingsSectionSongDisplay => 'Affichage des morceaux';

  @override
  String get settingsCategorySongDisplayHint =>
      'Styles par section : accords, paroles, titres, barres';

  @override
  String get songDisplayPreview => 'Aperçu';

  @override
  String get songDisplayPreset => 'Préréglage';

  @override
  String get songDisplayPresetClassic => 'Classique';

  @override
  String get songDisplayPresetColorCoded => 'Codé par couleur';

  @override
  String get songDisplayPresetChorusFocus => 'Accent sur le refrain';

  @override
  String get songDisplayPresetSinger => 'Chant';

  @override
  String get songDisplayPresetGuitar => 'Guitare';

  @override
  String get songDisplayPresetMinimal => 'Minimal';

  @override
  String get songDisplayPresetBlackWhite => 'Noir/blanc';

  @override
  String get songDisplayPresetCustom => 'Personnalisé';

  @override
  String get songDisplayDiscardTitle => 'Abandonner les styles personnalisés ?';

  @override
  String songDisplayDiscardMessage(String name) {
    return 'Le préréglage « $name » remplace tes styles personnalisés.';
  }

  @override
  String get songDisplayDiscard => 'Abandonner';

  @override
  String get songDisplayFont => 'Police';

  @override
  String get songDisplayFontStandard => 'Standard';

  @override
  String get songDisplayFontMonospace => 'Chasse fixe';

  @override
  String get songDisplaySection => 'Section';

  @override
  String get songDisplayTypeStandard => 'Standard';

  @override
  String get songDisplayTypeIntro => 'Intro';

  @override
  String get songDisplayTypeVerse => 'Verse';

  @override
  String get songDisplayTypePreChorus => 'Pre-chorus';

  @override
  String get songDisplayTypeChorus => 'Chorus';

  @override
  String get songDisplayTypeBridge => 'Bridge';

  @override
  String get songDisplayTypeInterlude => 'Interlude';

  @override
  String get songDisplayTypeOutro => 'Outro';

  @override
  String get songDisplayStandardHint =>
      'Style de base pour chaque section sans style propre et pour les sections non reconnues (p. ex. tabs, grilles, noms personnalisés).';

  @override
  String get songDisplayStyle => 'Style';

  @override
  String get songDisplayOwnStyle => 'Style propre';

  @override
  String songDisplayLike(String name) {
    return 'Comme $name';
  }

  @override
  String songDisplayInheritsHint(String chain) {
    return 'Reprend tout de : $chain. Les modifications là-bas s\'appliquent aussi ici.';
  }

  @override
  String get songDisplayChords => 'Accords';

  @override
  String get songDisplayLyrics => 'Paroles';

  @override
  String get songDisplayHeading => 'Titre';

  @override
  String get songDisplayBar => 'Barre de retrait';

  @override
  String get songDisplayBold => 'Gras';

  @override
  String get songDisplayItalic => 'Italique';

  @override
  String get songDisplaySize => 'Taille';

  @override
  String get songDisplayColor => 'Couleur';

  @override
  String get songDisplayShowHeading => 'Afficher le titre';

  @override
  String get songDisplayShowBar => 'Afficher la barre';

  @override
  String get songDisplayBarWidth => 'Largeur';

  @override
  String get songDisplayIndent => 'Retrait';

  @override
  String get songDisplayTint => 'Teinter l\'arrière-plan';

  @override
  String get songDisplaySizeSmall => 'S';

  @override
  String get songDisplaySizeMedium => 'M';

  @override
  String get songDisplaySizeLarge => 'L';

  @override
  String get songDisplaySizeExtraLarge => 'XL';

  @override
  String get songDisplayBarThin => 'Fine';

  @override
  String get songDisplayBarMedium => 'Moyenne';

  @override
  String get songDisplayBarWide => 'Large';

  @override
  String get songDisplayIndentNone => 'Aucun';

  @override
  String get songDisplayIndentNormal => 'Normal';

  @override
  String get songDisplayIndentLarge => 'Grand';

  @override
  String get songColorAuto => 'Automatique';

  @override
  String get songColorBlue => 'Bleu';

  @override
  String get songColorAmber => 'Ambre';

  @override
  String get songColorRed => 'Rouge';

  @override
  String get songColorGreen => 'Vert';

  @override
  String get songColorTeal => 'Sarcelle';

  @override
  String get songColorPurple => 'Violet';

  @override
  String get songColorPink => 'Rose';

  @override
  String get songColorGrey => 'Gris';

  @override
  String get songColorBlackWhite => 'Noir/blanc';

  @override
  String get songDisplayCustomise => 'Personnaliser l\'affichage';

  @override
  String get songDisplayCustomiseHint =>
      'Accords, paroles, titres, barres et couleurs';

  @override
  String get songDisplayEditorTitle =>
      'Personnaliser l\'affichage des morceaux';

  @override
  String get songDisplayDemoSong => 'Morceau de démo';

  @override
  String get songDisplayLibrarySong => 'Morceau de la bibliothèque …';

  @override
  String get songDisplayPickSong => 'Morceau pour l\'aperçu';

  @override
  String get songDisplayResizePreview =>
      'Faire glisser pour redimensionner l\'aperçu';

  @override
  String get appUpdateInstall => 'Installer';

  @override
  String appUpdateInstallTitle(String version) {
    return 'Installer setDING $version ?';
  }

  @override
  String get appUpdateInstallBody =>
      'setDING se ferme, installe la nouvelle version et redémarre. Tes données restent sur cet appareil.';

  @override
  String get appUpdateDownloading => 'Téléchargement de la mise à jour …';

  @override
  String get appUpdateFailed =>
      'La mise à jour n\'a pas pu être installée. Réessaie plus tard.';

  @override
  String get whatsNewTitle => 'Nouveautés';

  @override
  String whatsNewAvailable(String version) {
    return 'Nouveau dans setDING $version';
  }

  @override
  String get whatsNewShow => 'Afficher';

  @override
  String whatsNewVersion(String version) {
    return 'Version $version';
  }

  @override
  String get whatsNewAllChanges => 'Toutes les modifications';

  @override
  String get midiTestTitle => 'Test MIDI (prototype)';

  @override
  String get midiTestTileHint =>
      'Envoyer un program change à un clavier connecté en USB, p. ex. un Nord Stage 3';

  @override
  String get midiTestHint =>
      'Envoie un program change à un clavier connecté en USB, pour tester le MIDI sur cet appareil. Ce que le clavier envoie, p. ex. quand tu y choisis un programme ou un song, apparaît dans le journal.';

  @override
  String get midiTestDevices => 'Appareils';

  @override
  String get midiTestRefresh => 'Rechercher à nouveau';

  @override
  String get midiTestNoDevices =>
      'Aucun appareil MIDI trouvé. Connecte le clavier en USB et recherche à nouveau.';

  @override
  String get midiTestConnect => 'Connecter';

  @override
  String get midiTestDisconnect => 'Déconnecter';

  @override
  String get midiTestConnected => 'Connecté';

  @override
  String get midiTestChannel => 'Canal MIDI';

  @override
  String get midiTestModeNordProgram => 'Programme Nord';

  @override
  String get midiTestModeNordSong => 'Song Nord';

  @override
  String get midiTestModeNordLive => 'Live Nord';

  @override
  String get midiTestModeRaw => 'Valeurs brutes';

  @override
  String get midiTestBank => 'Banque';

  @override
  String get midiTestLive => 'Mémoire live';

  @override
  String get midiTestMsb => 'Bank select MSB (CC 0, 0–127)';

  @override
  String get midiTestLsb => 'Bank select LSB (CC 32, 0–127)';

  @override
  String get midiTestProgram => 'Programme (1–128)';

  @override
  String get midiTestEmptyNotSent => 'Un bank select vide n\'est pas envoyé.';

  @override
  String get midiTestInvalid => 'Vérifie les valeurs';

  @override
  String get midiTestSend => 'Envoyer';

  @override
  String get midiTestLog => 'Journal';

  @override
  String get midiTestCopy => 'Copier le journal';

  @override
  String get midiTestCopied => 'Journal copié';

  @override
  String get midiTestClear => 'Vider le journal';

  @override
  String midiTestSent(String bytes) {
    return 'Envoyé : $bytes';
  }

  @override
  String midiTestReceivedCc(
    int controller,
    int value,
    int channel,
    String bytes,
  ) {
    return 'Reçu : CC $controller = $value (canal $channel) – $bytes';
  }

  @override
  String midiTestReceivedPc(
    int number,
    int program,
    int channel,
    String bytes,
  ) {
    return 'Reçu : program change $number (valeur $program, canal $channel) – $bytes';
  }

  @override
  String midiTestReceivedOther(String bytes) {
    return 'Reçu : $bytes';
  }

  @override
  String midiTestError(String message) {
    return 'Erreur : $message';
  }

  @override
  String get midiTestModeCc => 'Control change';

  @override
  String get midiTestController => 'Contrôleur (CC 0–127)';

  @override
  String get midiTestValue => 'Valeur (0–127)';

  @override
  String get midiTestCcHint =>
      'Nord Stage 3 selon midi.guide : CC 2 mode live, CC 3 mode song, CC 5 partie de song. Quelles valeurs font quoi fait partie du test.';

  @override
  String get midiGuideTitle => 'Test guidé';

  @override
  String get midiGuideHint =>
      'Touche « Envoyer », regarde l\'écran du Nord et touche ce qui s\'est passé. Rien n\'est à régler sur le Nord. Les réponses sont conservées dans le journal.';

  @override
  String get midiGuideNordSend => 'Nord Stage 3 – envoi';

  @override
  String get midiGuideNordReceive => 'Nord Stage 3 – réception';

  @override
  String get midiGuideMotifSend => 'Motif XF – envoi';

  @override
  String get midiGuideMotifReceive => 'Motif XF – réception';

  @override
  String get midiGuideNordReceiveHint =>
      'Sur le Nord, règle « Program Change » sur « Send » ou « Send & Receive » dans le menu MIDI, et règle ici le canal sur le canal global du Nord. Choisis ensuite un programme, une live memory ou une partie de song quelconque sur le Nord, p. ex. avec la molette ou les boutons de mode. setDING montre ce qui est arrivé ; touche si cela correspond à l\'écran. Les résultats sont conservés dans le journal.';

  @override
  String get midiGuideMotifSendHint =>
      'Sur le Motif XF, sous Utility → Control (F5) → MIDI (SF2) : règle MIDI IN/OUT sur USB, active la réception de bank select et program change, règle le Basic Receive Channel sur le canal indiqué ici et le Device Number sur « all » ou 1, puis enregistre avec Store. Touche « Envoyer », regarde l\'écran du Motif et touche ce qui s\'est passé. Les réponses sont conservées dans le journal.';

  @override
  String get midiGuideMotifReceiveHint =>
      'Sur le Motif XF, sous Utility → Control (F5) → MIDI (SF2) : règle MIDI IN/OUT sur USB, active l\'envoi de bank select et program change et règle le Transmit Channel sur le canal indiqué ici, puis enregistre avec Store. Choisis ensuite une voice ou une performance quelconque sur le Motif, aussi dans différentes banques et deux fois dans la même banque. setDING montre ce qui est arrivé ; touche si cela correspond à l\'écran. Les résultats sont conservés dans le journal.';

  @override
  String midiGuideMotifExpected(String name) {
    return 'Le Motif affiche $name.';
  }

  @override
  String get midiGuideWaiting => 'Choisis un son sur le clavier …';

  @override
  String midiGuideFreeReceived(String name) {
    return 'Reçu : $name';
  }

  @override
  String get midiGuideMatches => 'Correspond à l\'écran';

  @override
  String get midiGuideNoMatch => 'Ne correspond pas';

  @override
  String midiGuideFreeResult(String name, String values, String answer) {
    return 'Reçu $name ($values) : $answer';
  }

  @override
  String midiGuideChecked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sons vérifiés',
      one: '1 son vérifié',
      zero: 'Rien de vérifié pour l\'instant',
    );
    return '$_temp0';
  }

  @override
  String midiGuideStep(int current, int total, String title) {
    return 'Étape $current sur $total : $title';
  }

  @override
  String midiGuideExpected(String expected) {
    return 'Attendu : $expected';
  }

  @override
  String get midiGuideDone =>
      'Test terminé. Les réponses sont dans le journal.';

  @override
  String get midiGuideRestart => 'Recommencer';

  @override
  String get midiGuideBack => 'Retour';

  @override
  String get midiGuideSkip => 'Passer';

  @override
  String midiGuideResult(int current, String title, String answer) {
    return 'Étape $current ($title) : $answer';
  }

  @override
  String midiGuideProgram(String name) {
    return 'Programme $name';
  }

  @override
  String midiGuideProgramExpected(String name) {
    return 'Le Nord affiche $name.';
  }

  @override
  String midiGuideLive(int number) {
    return 'Live memory $number';
  }

  @override
  String midiGuideLiveExpected(int number) {
    return 'Le Nord affiche Live $number.';
  }

  @override
  String get midiGuideSongModeOn => 'Mode song activé (CC 3 = 127)';

  @override
  String get midiGuideSongModeOnExpected => 'Le Nord passe en mode song.';

  @override
  String get midiGuideSongModeOff => 'Mode song désactivé (CC 3 = 0)';

  @override
  String get midiGuideSongModeOffExpected => 'Le Nord quitte le mode song.';

  @override
  String get midiGuideAnswerAsExpected => 'Comme prévu';

  @override
  String get midiGuideAnswerDifferent => 'Autre chose';

  @override
  String get midiGuideAnswerNothing => 'Rien ne s\'est passé';

  @override
  String get midiTestFree => 'Envoi libre';

  @override
  String get midiTestPage => 'Page';

  @override
  String get midiTestButton => 'Bouton';

  @override
  String midiGuideSong(int song, int part) {
    return 'Song $song, partie $part';
  }

  @override
  String midiGuideSongExpected(int song, int part) {
    return 'Le Nord affiche le song $song, partie $part.';
  }

  @override
  String get midiTestSong => 'Song';

  @override
  String get midiTestPart => 'Partie';

  @override
  String get settingsEditorTypingAids =>
      'Fermer automatiquement crochets et sections';

  @override
  String get settingsEditorTypingAidsHint =>
      'Dans l\'éditeur ChordPro : [ ajoute ], Entrée après le début d\'une section ajoute sa fin, et renommer le début d\'une section renomme aussi sa fin.';

  @override
  String get settingsDeveloperMode => 'Mode développeur';

  @override
  String get settingsDeveloperModeHint =>
      'Affiche la catégorie « Développement » avec des fonctions expérimentales à tester. Pas nécessaire pour une utilisation normale.';

  @override
  String get settingsGroupDevelopment => 'Développement';

  @override
  String get settingsSectionDevelopment => 'Fonctions de test';

  @override
  String get settingsCategoryDevelopmentHint =>
      'Expérimental, pour les tests uniquement';

  @override
  String get settingsDevelopmentNoteTitle => 'Fonctions expérimentales';

  @override
  String get settingsDevelopmentNote =>
      'Ces fonctions servent aux tests. Elles peuvent changer, avoir des bugs ou disparaître à nouveau. Pas prévues pour les concerts. Masque-les avec « Mode développeur » sous Général.';

  @override
  String get settingsSectionMidi => 'Clavier (MIDI)';

  @override
  String get settingsCategoryMidiHint =>
      'Program changes vers un clavier connecté en USB';

  @override
  String get settingsMidiEnabled => 'Program changes MIDI';

  @override
  String get settingsMidiEnabledHint =>
      'En mode live, le clavier passe au programme enregistré pour chaque morceau.';

  @override
  String settingsMidiConnected(String name) {
    return 'Connecté à $name';
  }

  @override
  String get settingsMidiNotConnected => 'Non connecté';

  @override
  String get settingsMidiOutput => 'Sortie';

  @override
  String get settingsMidiOutputHint =>
      'Le clavier connecté en USB. setDING s\'y reconnecte tout seul quand il est branché.';

  @override
  String get settingsMidiNoDevices =>
      'Aucun appareil MIDI trouvé. Connecte le clavier en USB et recherche à nouveau.';

  @override
  String get settingsMidiSearch => 'Rechercher à nouveau';

  @override
  String settingsMidiOutputMissing(String name) {
    return '$name (non branché)';
  }

  @override
  String get settingsMidiProfile => 'Profil de l\'appareil';

  @override
  String get settingsMidiProfileHint =>
      'Comment les programmes du clavier sont saisis et affichés. « Générique » utilise bank select et numéro de programme et fonctionne avec n\'importe quel clavier.';

  @override
  String get midiProfileNordStage3 => 'Nord Stage 3';

  @override
  String get midiProfileGeneric => 'Générique';

  @override
  String get settingsMidiChannel => 'Canal MIDI';

  @override
  String get settingsMidiChannelHint =>
      'Le canal sur lequel le clavier reçoit.';

  @override
  String get settingsMidiTakeOver => 'Reprendre les programmes du clavier';

  @override
  String get settingsMidiTakeOverHint =>
      'Pendant que le programme du clavier est ouvert en mode live, setDING affiche le son que tu choisis sur le clavier et le reprend dans le morceau si tu le veux. Le clavier doit envoyer bank select et program change.';

  @override
  String get settingsMidiTakeOverNordHint =>
      'Pendant que le programme du clavier est ouvert en mode live, setDING affiche le son que tu choisis sur le Nord et le reprend dans le morceau si tu le veux. Sur le Nord, règle « Program Change » sur « Send » ou « Send & Receive » dans le menu MIDI.';

  @override
  String get settingsMidiNordHint =>
      'Sur le Nord Stage 3, active la réception « Program Change » dans son menu MIDI, et règle ici le canal sur le canal global du Nord. La numérotation des songs Nord dépend de la version OS du Nord (vérifiée avec l\'OS 2.54) ; si un song ne correspond pas, utilise le profil « Générique ».';

  @override
  String get midiProgramTitle => 'Programme du clavier';

  @override
  String get midiProgramHint =>
      'Envoyé au clavier en mode live quand ce morceau arrive.';

  @override
  String get midiProgramNone => 'Aucun : le clavier garde son son';

  @override
  String get midiProgramChoose => 'Choisir un programme';

  @override
  String get midiProgramPreviewSwitch => 'Envoyer pendant la sélection';

  @override
  String get midiProgramPreviewHint =>
      'Chaque choix part immédiatement au clavier ; Annuler rétablit le programme précédent.';

  @override
  String get midiProgramRemove => 'Retirer le programme';

  @override
  String get midiProgramTest => 'Tester';

  @override
  String get midiProgramTestHint => 'Envoie une fois le programme au clavier';

  @override
  String get midiProgramNotConnected => 'Clavier non connecté';

  @override
  String get midiProgramOff =>
      'Les program changes MIDI sont désactivés sur cet appareil (réglages : Clavier (MIDI)).';

  @override
  String midiProgramSent(String device) {
    return 'Envoyé à $device';
  }

  @override
  String get midiProgramSendFailed => 'Le programme n\'a pas pu être envoyé';

  @override
  String get midiProgramKindProgram => 'Programme';

  @override
  String get midiProgramKindLive => 'Live memory';

  @override
  String get midiProgramKindSong => 'Song';

  @override
  String get midiProgramKindGeneric => 'Autres valeurs';

  @override
  String get midiProgramBank => 'Banque';

  @override
  String get midiProgramPageButton => 'Page (rangée) et bouton';

  @override
  String get midiProgramSongNumber => 'Song';

  @override
  String get midiProgramPreviousSong => 'Song précédent';

  @override
  String get midiProgramNextSong => 'Song suivant';

  @override
  String get midiProgramPart => 'Partie';

  @override
  String get midiProgramSongHint =>
      'La numérotation des songs Nord dépend de la version OS du Nord (vérifiée avec l\'OS 2.54). Si un song ne correspond pas, utilise le profil « Générique » dans les réglages.';

  @override
  String get midiProgramsTitle => 'Programmes du clavier';

  @override
  String midiProgramDevice(String profile) {
    return 'Cet appareil : $profile';
  }

  @override
  String get midiProgramForOtherKeyboard => 'Programme pour un autre clavier';

  @override
  String midiProgramUnknownKeyboard(String id) {
    return 'Clavier inconnu ($id)';
  }

  @override
  String get midiProgramMsb => 'Bank select MSB (facultatif)';

  @override
  String get midiProgramLsb => 'Bank select LSB (facultatif)';

  @override
  String get midiProgramNumber => 'Programme';

  @override
  String midiProgramRange(int min, int max) {
    return '$min–$max';
  }

  @override
  String midiProgramOutOfRange(int min, int max) {
    return 'Saisis un nombre de $min à $max';
  }

  @override
  String midiProgramValueNord(String name) {
    return 'Programme $name';
  }

  @override
  String get midiProfileMotifXf => 'Yamaha Motif XF';

  @override
  String get settingsMidiMotifHint =>
      'Sur le Motif XF, sous Utility → Control (F5) → MIDI (SF2) : règle MIDI IN/OUT sur USB, active la réception de Bank Select et Program Change, règle le Basic Receive Channel sur le canal indiqué ici et le Device Number sur « all » ou 1, puis enregistre avec Store. setDING fait passer lui-même le Motif en mode voice ou performance avant chaque programme.';

  @override
  String get midiProgramKindPerformance => 'Performance';

  @override
  String get midiProgramKindVoice => 'Voice';

  @override
  String get midiProgramGroup => 'Groupe';

  @override
  String get midiProgramMotifNumber => 'Numéro';

  @override
  String get midiProgramMotifHint =>
      'Comme sur l\'écran du Motif XF, p. ex. USR1 A01. setDING fait passer le Motif en mode voice ou performance avant l\'envoi.';

  @override
  String midiProgramValueMotifVoice(String name) {
    return 'Voice $name';
  }

  @override
  String midiProgramValueMotifPerformance(String name) {
    return 'Performance $name';
  }

  @override
  String get midiTestModeMotif => 'Motif XF';

  @override
  String midiProgramShortLive(int number) {
    return 'Live $number';
  }

  @override
  String midiProgramShortSong(int song, int part) {
    return 'S$song:$part';
  }

  @override
  String midiProgramShortPerformance(String name) {
    return 'P $name';
  }

  @override
  String midiProgramShortGeneric(int program, String msb, String lsb) {
    return '$program ($msb/$lsb)';
  }

  @override
  String midiProgramValueLive(int number) {
    return 'Live memory $number';
  }

  @override
  String midiProgramValueSong(int song, int part) {
    return 'Song $song, partie $part';
  }

  @override
  String midiProgramValueGeneric(int program) {
    return 'Programme $program';
  }

  @override
  String midiProgramValueMsb(int value) {
    return 'MSB $value';
  }

  @override
  String midiProgramValueLsb(int value) {
    return 'LSB $value';
  }

  @override
  String get trash => 'Corbeille';

  @override
  String trashWithCount(int count) {
    return 'Corbeille ($count)';
  }

  @override
  String get trashSongsTitle => 'Morceaux supprimés';

  @override
  String get trashSetsTitle => 'Sets supprimés';

  @override
  String trashEmpty(int days) {
    return 'La corbeille est vide. Les morceaux et sets supprimés peuvent être restaurés ici pendant $days jours.';
  }

  @override
  String trashHint(int days) {
    return 'Les morceaux et sets supprimés peuvent être restaurés pendant $days jours. Ensuite, ils sont supprimés définitivement.';
  }

  @override
  String trashDeletedOn(String date) {
    return 'supprimé le $date';
  }

  @override
  String trashDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'encore $days jours',
      one: 'encore 1 jour',
      zero: 'dernier jour',
    );
    return '$_temp0';
  }

  @override
  String get trashRestore => 'Restaurer';

  @override
  String trashRestored(String title) {
    return '« $title » restauré';
  }

  @override
  String get trashGroupToday => 'Aujourd\'hui';

  @override
  String get trashGroupWeek => 'Cette semaine';

  @override
  String get trashGroupOlder => 'Plus ancien';

  @override
  String trashMenu(String title) {
    return 'Actions pour « $title »';
  }

  @override
  String get trashPurge => 'Supprimer définitivement';

  @override
  String get trashPurgeTitle => 'Supprimer définitivement ?';

  @override
  String trashPurgeOne(String title) {
    return '« $title » sera supprimé définitivement. Cette action est irréversible.';
  }

  @override
  String trashPurgeMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments seront supprimés',
      one: '1 élément sera supprimé',
    );
    return '$_temp0 définitivement. Cette action est irréversible.';
  }

  @override
  String get trashEmptyAction => 'Vider la corbeille';

  @override
  String get trashEmptyTitle => 'Vider la corbeille ?';

  @override
  String trashPurged(String title) {
    return '« $title » supprimé définitivement';
  }

  @override
  String trashPurgedMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments supprimés',
      one: '1 élément supprimé',
    );
    return '$_temp0 définitivement';
  }

  @override
  String trashRestoredMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments restaurés',
      one: '1 élément restauré',
    );
    return '$_temp0';
  }

  @override
  String get backupExport => 'Sauvegarder la bibliothèque';

  @override
  String get backupSyncing => 'Synchronisation avec le serveur …';

  @override
  String get backupCollecting => 'Création de la sauvegarde …';

  @override
  String get backupSaved => 'Sauvegarde enregistrée.';

  @override
  String get backupFailedTitle => 'Sauvegarde impossible';

  @override
  String get backupSyncDeferred =>
      'Le mode live est ouvert. Ferme-le et réessaie.';

  @override
  String get backupSyncFailed =>
      'La synchronisation avec le serveur a échoué. La sauvegarde d\'une organisation nécessite une connexion qui fonctionne, afin qu\'elle contienne tout. Réessaie quand tu es en ligne.';

  @override
  String get backupPendingChanges =>
      'Des modifications de cet appareil n\'ont pas encore atteint le serveur. Attends la synchronisation et réessaie.';

  @override
  String get backupConflicts =>
      'Certains morceaux ont un conflit de synchronisation. Résous d\'abord les conflits.';

  @override
  String get backupMissingFiles =>
      'Toutes les pièces jointes ne sont pas encore téléchargées. Attends le téléchargement et réessaie.';

  @override
  String backupFileMissing(String name, String song) {
    return 'La pièce jointe « $name » de « $song » n\'a pas pu être chargée.';
  }

  @override
  String get backupInvalid => 'Ce fichier n\'est pas une sauvegarde setDING.';

  @override
  String get backupNewer =>
      'Cette sauvegarde a été créée avec une version plus récente de setDING. Mets l\'app à jour pour l\'importer.';

  @override
  String get backupImportTitle => 'Importer une sauvegarde';

  @override
  String backupImportSummary(String library, int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs morceaux',
      one: '1 morceau',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'Sauvegarde de « $library » : $_temp0, $_temp1.';
  }

  @override
  String get backupImportCopyHint =>
      'Tout est importé comme copie dans la bibliothèque actuelle. Rien d\'existant n\'est modifié.';

  @override
  String backupImportIdentical(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux sont',
      one: '1 morceau est',
    );
    return '$_temp0 déjà ici avec le même texte et seront utilisés tels quels.';
  }

  @override
  String backupImportDiffering(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux existent',
      one: '1 morceau existe',
    );
    return '$_temp0 ici avec un texte différent :';
  }

  @override
  String get backupKeepExisting => 'Garder les morceaux existants';

  @override
  String get backupAddAll => 'Importer comme morceaux supplémentaires';

  @override
  String get backupImportSetsTo => 'Les sets vont dans :';

  @override
  String backupBandSets(String band, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
    );
    return '$band ($_temp0)';
  }

  @override
  String get backupSkipSets => 'Ne pas importer';

  @override
  String get backupImportStart => 'Importer';

  @override
  String get backupImportDone => 'Sauvegarde importée';

  @override
  String backupResultSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux importés',
      one: '1 morceau importé',
    );
    return '$_temp0';
  }

  @override
  String backupResultIdentical(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux étaient déjà ici',
      one: '1 morceau était déjà ici',
    );
    return '$_temp0';
  }

  @override
  String backupResultKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux existants conservés',
      one: '1 morceau existant conservé',
    );
    return '$_temp0';
  }

  @override
  String backupResultSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets importés',
      one: '1 set importé',
      zero: 'Aucun set importé',
    );
    return '$_temp0';
  }

  @override
  String backupResultFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pièces jointes',
      one: '1 pièce jointe',
    );
    return '$_temp0';
  }

  @override
  String backupResultAdditional(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ces morceaux existent maintenant deux fois. Compare-les avec les existants et supprime ceux dont tu n\'as pas besoin :',
      one: 'Ce morceau existe maintenant deux fois. Compare-le avec l\'existant et supprime celui dont tu n\'as pas besoin :',
    );
    return '$_temp0';
  }

  @override
  String get bandDelete => 'Supprimer le groupe';

  @override
  String bandDeleteTitle(String band) {
    return 'Supprimer $band ?';
  }

  @override
  String bandDeleteMessage(int days) {
    return 'Ses sets, arrangements de groupe et adhésions sont supprimés avec lui, et ses invitations ouvertes sont révoquées. Les morceaux restent dans la bibliothèque de l\'organisation. Les admins de l\'organisation peuvent restaurer le groupe depuis la corbeille pendant $days jours. Pour garder une copie hors de setDING, sauvegarde d\'abord la bibliothèque.';
  }

  @override
  String bandDeleteSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
      zero: 'aucun set',
    );
    return '$_temp0';
  }

  @override
  String bandDeleteMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '1 membre',
      zero: 'aucun membre',
    );
    return '$_temp0';
  }

  @override
  String bandDeleteInvites(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations ouvertes',
      one: '1 invitation ouverte',
      zero: 'aucune invitation ouverte',
    );
    return '$_temp0';
  }

  @override
  String get bandDeleteLastBand =>
      'C\'est le dernier groupe de l\'organisation. L\'organisation et sa bibliothèque de morceaux restent.';

  @override
  String bandDeleteConfirmName(String band) {
    return 'Tape « $band » pour confirmer';
  }

  @override
  String bandDeleted(String band) {
    return '$band supprimé';
  }

  @override
  String get trashBandsTitle => 'Groupes supprimés';

  @override
  String trashBandsEmpty(int days) {
    return 'Aucun groupe supprimé. Les groupes supprimés peuvent être restaurés ici pendant $days jours.';
  }

  @override
  String trashBandsHint(int days) {
    return 'Les groupes supprimés peuvent être restaurés avec leurs sets, arrangements et membres pendant $days jours. Ensuite, ils sont supprimés définitivement.';
  }

  @override
  String bandsGone(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$names ne sont plus disponibles pour toi : les groupes ont été supprimés ou tu n\'en es plus membre.',
      one:
          '$names n\'est plus disponible pour toi : le groupe a été supprimé ou tu n\'en es plus membre.',
    );
    return '$_temp0';
  }

  @override
  String get backupAll => 'Tout sauvegarder';

  @override
  String get backupAllName => 'tout';

  @override
  String get backupAllHint =>
      'Tes bibliothèques avec morceaux, sets et pièces jointes, tes ajustements personnels et notes, et tes réglages, dans un seul fichier.';

  @override
  String get backupNever => 'Pas encore de sauvegarde sur cet appareil.';

  @override
  String backupLast(String date) {
    return 'Dernière sauvegarde : $date';
  }

  @override
  String get backupRestore => 'Restaurer une sauvegarde';

  @override
  String get backupRestoreHint =>
      'Importe un fichier de sauvegarde comme copie, ou remplace la bibliothèque « Sur cet appareil » par sa sauvegarde.';

  @override
  String get backupRestoreTitle => 'Restaurer une sauvegarde';

  @override
  String backupLibraryTo(String library, int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs morceaux',
      one: '1 morceau',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return '« $library » ($_temp0, $_temp1) dans';
  }

  @override
  String get backupImportDifferingAll =>
      'Morceaux qui existent ici avec un texte différent :';

  @override
  String get backupRestorePersonal =>
      'Restaurer mes ajustements personnels et notes';

  @override
  String backupPersonalOf(String library, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '1 morceau',
    );
    return '$library : $_temp0';
  }

  @override
  String get backupRestoreSettings => 'Restaurer mes réglages';

  @override
  String get backupRestoreSettingsHint =>
      'Remplace tes réglages actuels par ceux de la sauvegarde.';

  @override
  String get backupRestoreStart => 'Restaurer';

  @override
  String get backupRestoreDone => 'Sauvegarde restaurée';

  @override
  String backupResultPersonal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '1 morceau',
    );
    return 'Ajustements personnels et notes de $_temp0 restaurés';
  }

  @override
  String get backupResultSettings => 'Réglages restaurés';

  @override
  String backupReminder(int days) {
    return 'Ta bibliothèque sur cet appareil n\'a pas été sauvegardée depuis $days jours.';
  }

  @override
  String get backupReminderAction => 'Sauvegarder';

  @override
  String get orgClose => 'Fermer l\'organisation';

  @override
  String orgCloseTitle(String org) {
    return 'Fermer $org ?';
  }

  @override
  String orgCloseMessage(int days) {
    return 'Ses groupes, sets, morceaux et pièces jointes ainsi que les ajustements personnels de chacun pour ses morceaux sont retirés, et ses invitations sont révoquées. Les membres en sont informés à leur prochaine synchronisation. Ses admins peuvent la restaurer depuis la corbeille pendant $days jours ; ensuite tout est supprimé définitivement.';
  }

  @override
  String orgCloseBands(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groupes',
      one: '1 groupe',
      zero: 'aucun groupe',
    );
    return '$_temp0';
  }

  @override
  String orgCloseSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '1 morceau',
      zero: 'aucun morceau',
    );
    return '$_temp0';
  }

  @override
  String orgClosePeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes',
      one: '1 personne',
    );
    return '$_temp0';
  }

  @override
  String get orgCloseBackup => 'Sauvegarder d\'abord';

  @override
  String orgClosed(String org) {
    return '$org fermée';
  }

  @override
  String get orgsClosedTitle => 'Organisations fermées';

  @override
  String orgsClosedEmpty(int days) {
    return 'Aucune organisation fermée. Leurs admins peuvent restaurer ici les organisations fermées pendant $days jours.';
  }

  @override
  String orgsClosedHint(int days) {
    return 'Les organisations fermées peuvent être restaurées avec tout leur contenu pendant $days jours. Ensuite, elles sont supprimées définitivement.';
  }

  @override
  String orgClosedOn(String date) {
    return 'fermée le $date';
  }

  @override
  String orgClosedBy(String name) {
    return 'par $name';
  }

  @override
  String orgClosedNotice(String org, String name, int days) {
    return '$org a été fermée par $name. Ses admins peuvent la restaurer pendant $days jours.';
  }

  @override
  String orgClosedNoticeAnonymous(String org, int days) {
    return '$org a été fermée. Ses admins peuvent la restaurer pendant $days jours.';
  }

  @override
  String get navOverview => 'Vue d\'ensemble';

  @override
  String get overviewNextSet => 'Prochain set';

  @override
  String get overviewLastEditedSet => 'Dernier set modifié';

  @override
  String overviewSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '1 morceau',
      zero: 'Aucun morceau',
    );
    return '$_temp0';
  }

  @override
  String get overviewStartLive => 'Lancer le live';

  @override
  String get overviewOpenSet => 'Ouvrir le set';

  @override
  String get overviewTodo => 'À faire';

  @override
  String overviewTodoProblems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux avec des problèmes ChordPro',
      one: '1 morceau avec des problèmes ChordPro',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux avec des conflits de synchronisation',
      one: '1 morceau avec un conflit de synchronisation',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoSheetMusicOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux avec partition (PDF) seulement',
      one: '1 morceau avec partition (PDF) seulement',
    );
    return '$_temp0';
  }

  @override
  String get attentionProblems => 'Problèmes ChordPro';

  @override
  String get attentionConflicts => 'Conflits de synchronisation';

  @override
  String get attentionSheetMusicOnly => 'Partition seulement';

  @override
  String chordProConversionsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Convertir $count endroits du ChordPro',
      one: 'Convertir 1 endroit du ChordPro',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoConversions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux avec des conversions possibles',
      one: '1 morceau avec des conversions possibles',
    );
    return '$_temp0';
  }

  @override
  String get attentionConversions => 'Convertibles';

  @override
  String get convertAllSongs => 'Tout convertir';

  @override
  String get convertAllSongsTitle => 'Convertir tous les morceaux ?';

  @override
  String convertAllSongsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Les $count morceaux sont convertis',
      one: 'Le morceau est converti',
    );
    return '$_temp0 pour tous : directives CCLI et libellés de section comme le recommande la spécification ChordPro, barres de mesure CCLI en grilles, pied de page CCLI retiré.';
  }

  @override
  String songsConverted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux convertis',
      one: '1 morceau converti',
    );
    return '$_temp0';
  }

  @override
  String songConverted(String title) {
    return '« $title » converti';
  }

  @override
  String get songsFilterEmpty => 'Plus aucun morceau dans ce filtre.';

  @override
  String get playHistory => 'Joué';

  @override
  String playHistoryOf(String band) {
    return 'Joué par $band';
  }

  @override
  String playHistoryNone(String band) {
    return '$band n\'a pas encore joué ce morceau dans un set passé.';
  }

  @override
  String get playHistoryTotal => 'au total';

  @override
  String get playHistoryLastYear => '12 derniers mois';

  @override
  String get playHistoryLast => 'dernière fois';

  @override
  String playHistoryFirst(String date) {
    return 'Première fois le $date';
  }

  @override
  String playHistoryShowAll(int count) {
    return 'Afficher les $count';
  }

  @override
  String playHistoryDiffers(String key) {
    return 'En surbrillance : une tonalité autre que celle d\'aujourd\'hui ($key)';
  }

  @override
  String get playHistoryApproximate =>
      '≈ déduit de l\'arrangement d\'aujourd\'hui : le set n\'a pas de valeurs enregistrées';

  @override
  String keyHistoryLast(String key, String date) {
    return 'Dernière fois en $key le $date';
  }

  @override
  String keyHistoryMostly(String key, int count, int total) {
    return 'surtout en $key ($count sur $total)';
  }

  @override
  String songLastPlayed(String date) {
    return 'Joué pour la dernière fois le $date';
  }

  @override
  String get songNeverPlayed => 'Jamais joué';

  @override
  String get overviewRecentChanges => 'Modifications récentes';

  @override
  String get overviewShowAll => 'Tout afficher';

  @override
  String get overviewMoreSets => 'Plus de sets';

  @override
  String get overviewNewestSongs => 'Morceaux les plus récents';

  @override
  String get recentChangesEmpty =>
      'Aucune modification par d\'autres ces 30 derniers jours.';

  @override
  String get changeSongAdded => 'Nouveau morceau';

  @override
  String get changeNewSet => 'Nouveau set';

  @override
  String get changeSongText => 'Texte modifié';

  @override
  String get changeSongPdf => 'PDF modifié';

  @override
  String get changeSongTextAndPdf => 'Texte et PDF modifiés';

  @override
  String changeSetAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux ajoutés',
      one: '1 morceau ajouté',
    );
    return '$_temp0';
  }

  @override
  String changeSetRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux retirés',
      one: '1 morceau retiré',
    );
    return '$_temp0';
  }

  @override
  String changeSetAlsoRemoved(int count) {
    return '$count retirés';
  }

  @override
  String changeSetSequence(String songs) {
    return 'ordre de $songs modifié';
  }

  @override
  String changeQuoted(String title) {
    return '« $title »';
  }

  @override
  String changeBy(String name) {
    return 'par $name';
  }

  @override
  String get repertoire => 'Répertoire';

  @override
  String repertoireOf(String band) {
    return 'Répertoire de $band';
  }

  @override
  String get repertoireLastYear => '12 mois';

  @override
  String get repertoireAllTime => 'Depuis toujours';

  @override
  String get repertoireMostPlayed => 'Les plus joués';

  @override
  String get repertoireStale => 'Pas joués depuis longtemps';

  @override
  String repertoireStaleHint(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'Joué pour la dernière fois il y a plus de $months mois',
      one: 'Joué pour la dernière fois il y a plus d\'un mois',
    );
    return '$_temp0';
  }

  @override
  String get playedFilter => 'Joués';

  @override
  String get playedAll => 'Tous';

  @override
  String get filterByPlayed => 'Filtrer selon les exécutions du groupe';

  @override
  String get repertoireNeverPlayed => 'Jamais joués';

  @override
  String get repertoireNeverPlayedHint =>
      'Morceaux de la bibliothèque qui n\'étaient dans aucun set passé du groupe';

  @override
  String get repertoireNone => 'Aucun';

  @override
  String get repertoireEmpty =>
      'Le groupe n\'a encore joué aucun morceau dans des sets passés.';

  @override
  String repertoirePlays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fois',
      one: 'une fois',
    );
    return '$_temp0';
  }

  @override
  String get repertoireThreshold =>
      'Quand un morceau compte-t-il comme pas joué depuis longtemps ?';

  @override
  String repertoireMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'Après $months mois',
      one: 'Après 1 mois',
    );
    return '$_temp0';
  }

  @override
  String repertoireDefault(int months) {
    return 'Par défaut : après $months mois';
  }

  @override
  String get sortByLastPlayed => 'Dernière exécution';

  @override
  String get playHistoryOtherBands => 'Autres groupes';

  @override
  String playHistoryFetched(String date) {
    return 'État au $date';
  }

  @override
  String get libraryUsage => 'Utilisation de la bibliothèque';

  @override
  String libraryUsageSummary(int count, int total) {
    return 'Aucun groupe ne joue $count morceaux sur $total';
  }

  @override
  String get libraryUsageHint =>
      'Morceaux qui n\'étaient dans aucun set passé d\'aucun groupe de l\'organisation. Mets à la corbeille ce dont plus aucun groupe n\'a besoin.';

  @override
  String get libraryUsageNotLoaded =>
      'Pas encore chargé : synchronise une fois en étant connecté au serveur.';

  @override
  String get libraryUsageAllPlayed =>
      'Chaque morceau de la bibliothèque a été joué par un groupe.';

  @override
  String syncHintSongChanged(String title, String name) {
    return '« $title » a été modifié par $name.';
  }

  @override
  String syncHintSongDeleted(String title, String name) {
    return '« $title » a été supprimé par $name.';
  }

  @override
  String syncHintSetChanged(String title, String name) {
    return 'Le set « $title » a été modifié par $name.';
  }

  @override
  String syncHintSetDeleted(String title, String name) {
    return 'Le set « $title » a été supprimé par $name.';
  }

  @override
  String syncHintSongChangedAnonymous(String title) {
    return '« $title » a été modifié par quelqu\'un d\'autre.';
  }

  @override
  String syncHintSongDeletedAnonymous(String title) {
    return '« $title » a été supprimé par quelqu\'un d\'autre.';
  }

  @override
  String syncHintSetChangedAnonymous(String title) {
    return 'Le set « $title » a été modifié par quelqu\'un d\'autre.';
  }

  @override
  String syncHintSetDeletedAnonymous(String title) {
    return 'Le set « $title » a été supprimé par quelqu\'un d\'autre.';
  }

  @override
  String syncHintAfterLive(String changes) {
    return 'Pendant que tu jouais en live : $changes.';
  }

  @override
  String syncHintSongsChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux modifiés',
      one: '1 morceau modifié',
    );
    return '$_temp0';
  }

  @override
  String syncHintSongsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux supprimés',
      one: '1 morceau supprimé',
    );
    return '$_temp0';
  }

  @override
  String syncHintSetsChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets modifiés',
      one: '1 set modifié',
    );
    return '$_temp0';
  }

  @override
  String syncHintSetsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets supprimés',
      one: '1 set supprimé',
    );
    return '$_temp0';
  }

  @override
  String get syncHintShowChanges => 'Afficher';

  @override
  String get setExportTitle => 'Exporter le set';

  @override
  String get setExportHint =>
      'Le ZIP contient les fichiers ChordPro des morceaux et une description à partir de laquelle setDING réimporte le set en tant que set.';

  @override
  String get setArchiveArrangements =>
      'Arrangements du groupe pour les morceaux (tonalité, ordre, tempo)';

  @override
  String get setArchiveSetSettings =>
      'Tonalité et ordre des morceaux dans ce set';

  @override
  String get setArchiveAttachments => 'Pièces jointes (PDF, images)';

  @override
  String get setArchivePersonal => 'Mes ajustements personnels et notes';

  @override
  String get setArchivePersonalHint =>
      'Laisse désactivé si tu transmets le fichier.';

  @override
  String get setExportStart => 'Exporter';

  @override
  String get exportMenu => 'Exporter …';

  @override
  String get exportFormat => 'Format';

  @override
  String get exportFormatChordPro => 'Fichier ChordPro';

  @override
  String get exportFormatChordProHint =>
      'Pour d\'autres apps, sans pièces jointes ni arrangements';

  @override
  String get exportFormatSetListPdf => 'Setlist en PDF';

  @override
  String get exportFormatSetListPdfHint => 'Pour l\'impression';

  @override
  String get exportFormatArchive => 'Archive setDING (ZIP)';

  @override
  String get exportFormatArchiveHint =>
      'Pour l\'importation dans setDING, avec pièces jointes et arrangements si tu veux';

  @override
  String get songExportHintChordPro =>
      'Le fichier ChordPro contient les paroles et les accords du morceau et s\'ouvre dans toute app qui connaît ChordPro.';

  @override
  String get setExportHintPdf =>
      'La setlist montre chaque morceau avec sa tonalité et son ordre, à imprimer pour la scène.';

  @override
  String get setImport => 'Importer un set';

  @override
  String get setImportFromFile => 'Importer depuis un fichier …';

  @override
  String get setImportTitle => 'Importer un set';

  @override
  String get setImportBand => 'Groupe';

  @override
  String get setImportNoBand =>
      'Il n\'y a dans cette bibliothèque aucun groupe dont tu peux gérer les sets.';

  @override
  String setImportExisting(String name) {
    return 'Le groupe a déjà ce set sous le nom « $name ».';
  }

  @override
  String get setImportReplace => 'Le remplacer';

  @override
  String get setImportCopy => 'Ajouter comme copie';

  @override
  String setImportOverwriteArrangements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '1 morceau',
    );
    return 'Écraser les arrangements du groupe de $_temp0';
  }

  @override
  String get setImportDone => 'Set importé';

  @override
  String get setImportReplaced => 'Le set existant a été remplacé.';

  @override
  String setImportResultArrangements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arrangements de groupe enregistrés',
      one: '1 arrangement de groupe enregistré',
    );
    return '$_temp0';
  }

  @override
  String get setImportResultMissing =>
      'Pas dans la bibliothèque, affichés comme éléments de texte dans le set :';

  @override
  String get setImportOpen => 'Ouvrir le set';

  @override
  String setImportMissingNote(String title) {
    return 'Manquant : $title';
  }

  @override
  String get setArchiveInvalid => 'Ce fichier n\'est pas un set exporté.';

  @override
  String get setArchiveNewer =>
      'Ce set a été exporté avec une version plus récente de setDING. Mets l\'app à jour pour l\'importer.';

  @override
  String setImportFrom(String band, int songs) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs morceaux',
      one: '1 morceau',
      zero: 'aucun morceau',
    );
    return 'de $band · $_temp0';
  }

  @override
  String get setImportHeadingTarget => 'Destination';

  @override
  String get setImportHeadingExisting => 'Set déjà présent';

  @override
  String get setImportHeadingSongs => 'Morceaux';

  @override
  String get setImportHeadingInclude => 'Inclure';

  @override
  String get setExportHeadingInclude => 'Inclure dans l\'archive';

  @override
  String setImportNewName(String name) {
    return 'Sera ajouté sous le nom « $name ».';
  }

  @override
  String setImportSongsHere(int count) {
    return '$count déjà ici avec le même texte';
  }

  @override
  String setImportSongsNew(int count) {
    return '$count nouveaux, ajoutés à la bibliothèque';
  }

  @override
  String setImportSongsDiffering(int count) {
    return '$count ici avec un texte différent';
  }

  @override
  String setImportSongsMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'les affiche',
      one: 'l\'affiche',
    );
    return '$count pas dans la bibliothèque – tu ne peux pas ajouter de morceaux, le set $_temp0 donc comme texte';
  }

  @override
  String get setImportKeep => 'Garder l\'existant';

  @override
  String get setImportAddAll => 'Importer aussi';

  @override
  String setImportCopyName(String name) {
    return '$name (copie)';
  }

  @override
  String setImportCopyNameNumbered(String name, int number) {
    return '$name (copie $number)';
  }

  @override
  String get keyboardShortcuts => 'Raccourcis clavier';

  @override
  String get shortcutsEverywhere => 'Partout';

  @override
  String get shortcutsSong => 'Morceau';

  @override
  String get shortcutsSet => 'Set';

  @override
  String get shortcutsSongList => 'Liste des morceaux';

  @override
  String get shortcutsLive => 'Mode live';

  @override
  String get shortcutBack => 'Retour';

  @override
  String get shortcutHelp => 'Afficher les raccourcis clavier';

  @override
  String get shortcutEditSong => 'Modifier le morceau';

  @override
  String get shortcutEditSet => 'Modifier le set';

  @override
  String get shortcutLive => 'Lancer le mode live';

  @override
  String get shortcutTranspose => 'Transposer vers le haut / bas';

  @override
  String get shortcutPreviousNextSong => 'Morceau précédent / suivant du set';

  @override
  String get shortcutSearch => 'Rechercher des morceaux';

  @override
  String get shortcutNextPage => 'Page suivante';

  @override
  String get shortcutPreviousPage => 'Page précédente';

  @override
  String get shortcutBeat => 'Démarrer / arrêter la pulsation';

  @override
  String get shortcutKeyPageDown => 'Page suivante';

  @override
  String get shortcutKeyPageUp => 'Page précédente';

  @override
  String get shortcutKeySpace => 'Espace';

  @override
  String get shortcutCloseSelection => 'Fermer la sélection';

  @override
  String get settingsHeadingLanguageTheme => 'Langue et thème';

  @override
  String get settingsHeadingEditor => 'Éditeur';

  @override
  String get settingsHeadingAdvanced => 'Avancé';

  @override
  String get settingsHeadingChords => 'Accords';

  @override
  String get settingsHeadingContent => 'Contenu';

  @override
  String get settingsHeadingSetNotes => 'Set et notes';

  @override
  String get settingsHeadingInstrument => 'Instrument et voix';

  @override
  String get settingsHeadingScreen => 'Écran';

  @override
  String get settingsHeadingControls => 'Commandes';

  @override
  String get settingsHeadingClick => 'Clic sur cet appareil';

  @override
  String get settingsHeadingBackup => 'Sauvegarde';

  @override
  String get settingsHeadingThisDevice => 'Cet appareil';

  @override
  String get settingsHeadingHelp => 'Aide et infos';

  @override
  String get settingsHeadingConnection => 'Connexion';

  @override
  String get settingsHeadingKeyboard => 'Clavier';

  @override
  String get settingsHeadingStyle => 'Style';

  @override
  String get settingsHeadingPrototypes => 'Prototypes';

  @override
  String songExportTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Exporter $count morceaux',
      one: 'Exporter le morceau',
    );
    return '$_temp0';
  }

  @override
  String get songExportHint =>
      'Le ZIP contient les fichiers ChordPro et une description à partir de laquelle setDING réimporte les morceaux, plus ce que tu choisis ci-dessous.';

  @override
  String songExportArrangements(String band) {
    return 'Arrangements de « $band » (tonalité, ordre, tempo)';
  }

  @override
  String get songImportTitle => 'Importer des morceaux';

  @override
  String songImportFrom(String library, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '1 morceau',
    );
    return 'de $library · $_temp0';
  }

  @override
  String songImportLibrary(String name) {
    return 'Dans la bibliothèque « $name »';
  }

  @override
  String get songImportArrangementsBand => 'Groupe pour les arrangements';

  @override
  String get songImportNoBand =>
      'Il n\'y a dans cette bibliothèque aucun groupe dont tu peux modifier les arrangements.';

  @override
  String get songImportDone => 'Morceaux importés';

  @override
  String get songArchiveNewer =>
      'Ces morceaux ont été exportés avec une version plus récente de setDING. Mets l\'app à jour pour les importer.';

  @override
  String archiveImportAttachmentsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pièces jointes ajoutées',
      one: '1 pièce jointe ajoutée',
    );
    return '$_temp0 à des morceaux déjà présents';
  }

  @override
  String archiveResultCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pièces jointes ajoutées',
      one: '1 pièce jointe ajoutée',
    );
    return '$_temp0 à des morceaux existants';
  }

  @override
  String songLanguageName(String language) {
    String _temp0 = intl.Intl.selectLogic(language, {
      'de': 'Allemand',
      'gsw': 'Suisse allemand',
      'en': 'Anglais',
      'fr': 'Français',
      'it': 'Italien',
      'es': 'Espagnol',
      'pt': 'Portugais',
      'nl': 'Néerlandais',
      'other': 'Autre',
    });
    return '$_temp0';
  }

  @override
  String songLanguageShort(String language) {
    String _temp0 = intl.Intl.selectLogic(language, {
      'de': 'DE',
      'gsw': 'CH',
      'en': 'EN',
      'fr': 'FR',
      'it': 'IT',
      'es': 'ES',
      'pt': 'PT',
      'nl': 'NL',
      'other': '–',
    });
    return '$_temp0';
  }

  @override
  String get songLanguage => 'Langue';

  @override
  String get songLanguageMenu => 'Langue …';

  @override
  String get allLanguages => 'Toutes les langues';

  @override
  String get noLanguage => 'Aucune langue';

  @override
  String get filterByLanguage => 'Filtrer par langue';

  @override
  String songLanguageAutomatic(String language) {
    return 'Automatique : $language';
  }

  @override
  String get songLanguageNotDetected => 'Automatique (non détectée)';

  @override
  String get songLanguageAutomaticHint =>
      'Détectée à partir des paroles ; un choix manuel l\'emporte toujours.';

  @override
  String songLanguageDetectedTooltip(String language) {
    return '$language (détectée à partir des paroles)';
  }

  @override
  String songLanguageByHandTooltip(String language) {
    return '$language (définie à la main)';
  }

  @override
  String get languageVersions => 'Versions linguistiques';

  @override
  String get linkLanguageVersion => 'Versions linguistiques …';

  @override
  String get unlinkLanguageVersion => 'Retirer des versions linguistiques';

  @override
  String get languageVersionPickerEmpty =>
      'Aucun autre morceau que tu peux lier';

  @override
  String languageVersionsOf(String title) {
    return 'Versions linguistiques de $title';
  }

  @override
  String languageVersionsChosen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Versions liées ($count)',
      zero: 'Versions liées',
    );
    return '$_temp0';
  }

  @override
  String get languageVersionsChosenEmpty =>
      'Pas encore d\'autres versions. Choisis des morceaux dans la bibliothèque.';

  @override
  String get languageVersionsSaved => 'Versions linguistiques enregistrées';

  @override
  String languageVersionsNotAllowed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count morceaux n\'ont pas été liés : tu ne peux pas modifier leurs autres versions.',
      one: 'Un morceau n\'a pas été lié : tu ne peux pas modifier ses autres versions.',
    );
    return '$_temp0';
  }

  @override
  String get languageVersionUnlinked => 'Retiré des versions linguistiques';

  @override
  String otherLanguageVersionsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autres versions linguistiques',
      one: 'Une autre version linguistique',
    );
    return '$_temp0';
  }

  @override
  String get switchLanguageVersion => 'Changer de version linguistique …';

  @override
  String switchedLanguageVersion(String version) {
    return 'Passé à : $version';
  }

  @override
  String switchedLanguageVersionKey(
    String version,
    String newKey,
    String oldKey,
  ) {
    return 'Passé à : $version, en $newKey au lieu de $oldKey dans ce set';
  }

  @override
  String get switchedLanguageVersionSequence =>
      'L\'ordre propre au set ne convient pas à la nouvelle version et a été retiré.';

  @override
  String languageVersionInSet(String title, String key) {
    return '$title · en $key dans ce set';
  }

  @override
  String get switchLanguageVersionTitle => 'Changer de version linguistique';

  @override
  String adjustmentOfferOne(String version, String what) {
    return 'Tes ajustements dans « $version » : $what. Les utiliser aussi pour cette version ?';
  }

  @override
  String get adjustmentOfferMany =>
      'D\'autres versions linguistiques ont tes ajustements. Les utiliser aussi pour cette version ?';

  @override
  String get adjustmentKindTranspose => 'tonalité';

  @override
  String get adjustmentKindCapo => 'capodastre';

  @override
  String get adjustmentKindMidi => 'programme du clavier';

  @override
  String get adjustmentKindClick => 'clic';

  @override
  String get adjustmentOfferCopy => 'Les utiliser';

  @override
  String get adjustmentOfferDismiss => 'Non merci';

  @override
  String get adjustmentOfferPick => 'Utiliser les ajustements de';

  @override
  String adjustmentsCopied(String version) {
    return 'Ajustements de « $version » utilisés';
  }

  @override
  String get autoBackup => 'Sauvegarde automatique';

  @override
  String get autoBackupSwitch => 'Sauvegarder automatiquement';

  @override
  String get autoBackupHint =>
      'Enregistre la bibliothèque « Sur cet appareil » dans un dossier de ton choix, au plus une fois par jour après des modifications. Utilise un dossier de ton stockage cloud pour la garder en sécurité si l\'appareil est perdu.';

  @override
  String get autoBackupFolder => 'Dossier';

  @override
  String get autoBackupFolderNone => 'Aucun dossier choisi';

  @override
  String get autoBackupChooseFolder => 'Choisir un dossier';

  @override
  String get autoBackupDevice => 'Nom de l\'appareil';

  @override
  String get autoBackupDeviceHint =>
      'Fait partie des noms de fichiers, pour que plusieurs appareils puissent utiliser le même dossier.';

  @override
  String get autoBackupDeviceTitle => 'Nom de l\'appareil pour les sauvegardes';

  @override
  String get autoBackupKeep => 'Sauvegardes conservées';

  @override
  String get autoBackupKeepHint =>
      'Les sauvegardes automatiques plus anciennes de cet appareil sont supprimées du dossier.';

  @override
  String get autoBackupNow => 'Sauvegarder maintenant dans le dossier';

  @override
  String get autoBackupRunning => 'Sauvegarde en cours …';

  @override
  String get autoBackupNever => 'Pas encore de sauvegarde automatique.';

  @override
  String autoBackupLast(String date) {
    return 'Dernière sauvegarde automatique : $date';
  }

  @override
  String autoBackupFailed(String date, String reason) {
    return 'Échec le $date : $reason';
  }

  @override
  String get autoBackupErrorUnavailable => 'Le dossier n\'est pas accessible.';

  @override
  String get autoBackupErrorPermission =>
      'setDING ne peut plus écrire dans le dossier. Choisis-le à nouveau.';

  @override
  String get autoBackupErrorFailed => 'La sauvegarde n\'a pas pu être écrite.';

  @override
  String autoBackupHintFailed(String reason) {
    return 'La sauvegarde automatique a échoué : $reason';
  }

  @override
  String autoBackupSaved(String file) {
    return 'Enregistré sous « $file »';
  }

  @override
  String get backupModeCopy => 'Ajouter comme copie';

  @override
  String get backupModeCopyHint =>
      'Les morceaux et sets sont ajoutés avec de nouveaux ID ; rien d\'existant n\'est modifié.';

  @override
  String get backupModeReplace => 'Remplacer la bibliothèque locale';

  @override
  String get backupModeReplaceHint =>
      'La bibliothèque « Sur cet appareil » devient exactement comme dans la sauvegarde, p. ex. sur un nouvel appareil ou pour revenir à un état antérieur.';

  @override
  String get backupReplaceTitle => 'Remplacer la bibliothèque locale ?';

  @override
  String backupReplaceFromDevice(
    String device,
    String date,
    int songs,
    int sets,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs morceaux',
      one: '1 morceau',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'Sauvegarde de « $device » du $date : $_temp0, $_temp1.';
  }

  @override
  String backupReplaceFrom(String date, int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs morceaux',
      one: '1 morceau',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'Sauvegarde du $date : $_temp0, $_temp1.';
  }

  @override
  String backupReplaceNow(int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs morceaux',
      one: '1 morceau',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'Actuellement sur cet appareil : $_temp0, $_temp1. Ils sont retirés, y compris ceux de la corbeille.';
  }

  @override
  String get backupReplaceKeeps =>
      'L\'historique des exécutions revient avec les sets de la sauvegarde. Les réglages et organisations ne sont pas modifiés.';

  @override
  String get backupReplaceSafety =>
      'Enregistrer d\'abord une sauvegarde de sécurité';

  @override
  String backupReplaceSafetyFolder(String folder) {
    return 'Dans le dossier de la sauvegarde automatique ($folder).';
  }

  @override
  String get backupReplaceSafetyChoose => 'Tu choisis où l\'enregistrer.';

  @override
  String get backupReplaceSafetySkip =>
      'Sans sauvegarde de sécurité, la bibliothèque actuelle ne peut pas être restaurée.';

  @override
  String get backupReplaceAction => 'Remplacer';

  @override
  String get backupReplaceRunning => 'Remplacement de la bibliothèque locale …';

  @override
  String backupReplaceDone(int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs morceaux',
      one: '1 morceau',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'Bibliothèque locale remplacée : $_temp0, $_temp1.';
  }

  @override
  String backupReplaceSafetyFailed(String reason) {
    return 'La sauvegarde de sécurité n\'a pas pu être enregistrée, rien n\'a donc été remplacé : $reason';
  }

  @override
  String get showLocalLibrary => 'Afficher la bibliothèque locale';

  @override
  String get showLocalLibraryHint =>
      '« Sur cet appareil » dans les listes de bibliothèques et de groupes. Si tu joues seulement dans des organisations, tu peux la masquer ; ses morceaux et sets restent sur cet appareil.';

  @override
  String get showLocalLibrarySignedOut =>
      'Sans connexion, la bibliothèque locale est toujours affichée.';

  @override
  String localLibraryHidden(int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs morceaux',
      one: '1 morceau',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'La bibliothèque locale est masquée. Ses $_temp0 et $_temp1 restent sur cet appareil et reviennent quand tu l\'affiches à nouveau.';
  }

  @override
  String get localLibraryHiddenAutoBackup =>
      'La sauvegarde automatique continue ; tu peux la désactiver ici.';

  @override
  String get chordViewChords => 'Accords';

  @override
  String get chordViewNashville => 'Nashville';

  @override
  String get chordViewNumerals => 'Chiffres romains';

  @override
  String get liveChordViewChords => 'C';

  @override
  String get liveChordViewNashville => '1';

  @override
  String get liveChordViewNumerals => 'I';

  @override
  String get chordViewDocs =>
      'Comment lire les chiffres Nashville et les chiffres romains';

  @override
  String docsHelp(String topic) {
    return 'Aide : $topic';
  }

  @override
  String get editorDocsTopic => 'Éditeur ChordPro';

  @override
  String get settingsDocs => 'Guide d\'utilisation';

  @override
  String get settingsDocsHint =>
      'Ouvrir la documentation de setDING sur setding.app (en anglais). L\'icône du livre en haut ouvre la page de la section ouverte.';

  @override
  String get overviewReadiness => 'Prêt à jouer';

  @override
  String readinessAllSet(String set) {
    return 'Tout est prêt pour « $set »';
  }

  @override
  String get readinessAllSetNoSet => 'Tout est prêt';

  @override
  String get readinessShowDetails => 'Afficher les détails';

  @override
  String get readinessHideDetails => 'Masquer les détails';

  @override
  String readinessMusician(String who) {
    return 'Musicien : $who';
  }

  @override
  String get readinessNoInstrument => 'Aucun instrument choisi';

  @override
  String readinessMidiConnected(String device) {
    return 'MIDI : $device connecté';
  }

  @override
  String get readinessMidiNotConnected => 'MIDI : clavier non connecté';

  @override
  String get readinessMidiNoOutput => 'MIDI : aucun clavier choisi';

  @override
  String readinessMidiProfile(String profile) {
    return 'Profil : $profile';
  }

  @override
  String get readinessOfflineReady => 'Prochain set disponible hors ligne';

  @override
  String readinessOfflineMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux du prochain set ne sont pas disponibles',
      one: '1 morceau du prochain set n\'est pas disponible',
    );
    return '$_temp0 hors ligne';
  }

  @override
  String readinessSynced(String time) {
    return 'Synchronisé : $time';
  }

  @override
  String get readinessSyncNever => 'Pas encore synchronisé sur cet appareil';

  @override
  String get readinessSyncStale => 'Les données ne sont peut-être pas à jour';

  @override
  String get readinessSyncManual =>
      'La synchronisation est manuelle : synchronise avant le concert.';

  @override
  String get readinessPageTurnerResponds => 'Le tourne-page répond';

  @override
  String readinessPageTurnerLastUsed(String time) {
    return 'Tourne-page : utilisé pour la dernière fois $time';
  }

  @override
  String get readinessPageTurnerNever =>
      'Tourne-page : pas encore utilisé sur cet appareil';

  @override
  String readinessPageTurnerDetail(String mode) {
    return 'Tourne : $mode · appuie ici sur la pédale pour la tester';
  }

  @override
  String get readinessBackupNoFolder =>
      'Sauvegarde automatique : aucun dossier choisi';

  @override
  String get readinessBackupFailed => 'La sauvegarde automatique a échoué';

  @override
  String get keyGuessHint => 'Suggérée d\'après les accords :';

  @override
  String keyGuessUse(String key) {
    return 'Utiliser $key comme tonalité';
  }

  @override
  String get attentionNoKey => 'Pas de tonalité';

  @override
  String overviewTodoNoKey(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux sans tonalité',
      one: '1 morceau sans tonalité',
    );
    return '$_temp0';
  }

  @override
  String readinessPageTurnerConnected(String name) {
    return 'Tourne-page $name connecté';
  }

  @override
  String readinessPageTurnerNotConnected(String name) {
    return 'Tourne-page $name non connecté';
  }

  @override
  String get readinessKeyboardConnected => 'Un clavier est connecté';

  @override
  String get readinessKeyboardNotConnected =>
      'Tourne-page : aucun clavier connecté';

  @override
  String get settingsPageTurner => 'Tourne-page';

  @override
  String get settingsPageTurnerNone => 'Non appairé';

  @override
  String get settingsPageTurnerConnected => 'connecté';

  @override
  String get settingsPageTurnerNotConnected => 'non connecté';

  @override
  String get settingsPageTurnerHint =>
      'Appaire ta pédale pour que la vue d\'ensemble indique si elle est connectée.';

  @override
  String get settingsPageTurnerPair => 'Appairer';

  @override
  String get settingsPageTurnerPairAgain => 'Appairer à nouveau';

  @override
  String get settingsPageTurnerForget => 'Oublier le tourne-page';

  @override
  String get settingsPageTurnerKeyboardOnly =>
      'Cet appareil indique seulement si un clavier est connecté, pas lequel. La vue d\'ensemble l\'affiche.';

  @override
  String get settingsPageTurnerUnsupported =>
      'Pas possible sur cette plateforme. La vue d\'ensemble indique quand le tourne-page a été utilisé pour la dernière fois.';

  @override
  String get pairPageTurnerTitle => 'Appairer un tourne-page';

  @override
  String get pairPageTurnerPrompt => 'Appuie maintenant sur la pédale.';

  @override
  String pageTurnerPaired(String name) {
    return 'Tourne-page appairé : $name';
  }

  @override
  String pageTurnerForgotten(String name) {
    return 'Tourne-page oublié : $name';
  }

  @override
  String get pageTurnerUnnamed => 'Appareil sans nom';

  @override
  String importKeySuggestionsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux importés n\'ont',
      one: '1 morceau importé n\'a',
    );
    return '$_temp0 pas de tonalité. Suggérée d\'après les accords ; un appui définit la tonalité :';
  }

  @override
  String importKeySuggestionsMore(int count) {
    return '… et $count de plus : À faire dans la vue d\'ensemble, Pas de tonalité.';
  }

  @override
  String importKeysSet(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tonalités définies dans $count morceaux',
      one: 'Tonalité définie dans 1 morceau',
      zero: 'Aucune tonalité définie',
    );
    return '$_temp0';
  }

  @override
  String get readinessPageTurnerNotPaired => 'Tourne-page non appairé';

  @override
  String readinessPageTurnerPairDetail(String mode) {
    return 'Appaire-le pour que la vue d\'ensemble indique s\'il est connecté · Tourne : $mode';
  }

  @override
  String get settingsPageTurnerUse => 'J\'utilise un tourne-page';

  @override
  String get settingsPageTurnerUseHint =>
      'Une pédale qui tourne les pages. L\'affiche dans la vue d\'ensemble et propose d\'appairer celle qui est détectée.';

  @override
  String pageTurnerDetected(String name) {
    return 'Tourne-page détecté : $name';
  }

  @override
  String get attentionToReview => 'À vérifier';

  @override
  String get attentionReported => 'Signalé';

  @override
  String overviewTodoToReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux à vérifier',
      one: '1 morceau à vérifier',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoReported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux avec des erreurs signalées',
      one: '1 morceau avec une erreur signalée',
    );
    return '$_temp0';
  }

  @override
  String get songToReviewTooltip => 'Pas encore vérifié';

  @override
  String get songReportedTooltip => 'Erreur signalée';

  @override
  String get songToReviewHint => 'Ce morceau n\'a pas encore été vérifié.';

  @override
  String get songReportedHint => 'Une erreur a été signalée dans ce morceau.';

  @override
  String reviewBannerToReview(String reason) {
    return 'À vérifier : $reason';
  }

  @override
  String reviewBannerReports(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count signalements ouverts',
      one: '1 signalement ouvert',
    );
    return '$_temp0';
  }

  @override
  String get showReports => 'Afficher';

  @override
  String get approveSong => 'Approuver';

  @override
  String get songApproved => 'Morceau approuvé';

  @override
  String get approveAllSongs => 'Tout approuver';

  @override
  String get approveAllSongsTitle => 'Approuver tous les morceaux ?';

  @override
  String approveAllSongsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux seront considérés comme vérifiés.',
      one: '1 morceau sera considéré comme vérifié.',
    );
    return '$_temp0';
  }

  @override
  String songsApproved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux approuvés',
      one: '1 morceau approuvé',
    );
    return '$_temp0';
  }

  @override
  String get resolveReportsTitle => 'Clore les signalements ?';

  @override
  String resolveReportsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Le morceau a $count signalements ouverts. Les clore aussi ?',
      one: 'Le morceau a 1 signalement ouvert. Le clore aussi ?',
    );
    return '$_temp0';
  }

  @override
  String get resolveReports => 'Clore';

  @override
  String get setToReviewMenu => 'Marquer à vérifier …';

  @override
  String get setToReviewTitle => 'Marquer à vérifier';

  @override
  String get reviewReasonLabel => 'Raison';

  @override
  String get reviewReasonHint => 'p. ex. le pont est faux';

  @override
  String get reviewReasonAfterImport => 'Après l\'importation';

  @override
  String setReviewHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count morceaux ne sont pas encore vérifiés ou ont des erreurs signalées',
      one: '1 morceau n\'est pas encore vérifié ou a une erreur signalée',
    );
    return '$_temp0';
  }

  @override
  String get reportMistake => 'Signaler une erreur';

  @override
  String get reportMistakeMenu => 'Signaler une erreur …';

  @override
  String get reportCategoryChords => 'Accords';

  @override
  String get reportCategoryLyrics => 'Paroles';

  @override
  String get reportCategoryKey => 'Tonalité';

  @override
  String get reportCategorySequence => 'Déroulement';

  @override
  String get reportCategoryTempo => 'Tempo';

  @override
  String get reportCategoryFormatting => 'Mise en forme';

  @override
  String get reportCategorySheetMusic => 'Partition (PDF)';

  @override
  String get reportCategoryOther => 'Autre';

  @override
  String get reportComment => 'Commentaire';

  @override
  String get reportCommentHint => 'Qu\'est-ce qui ne va pas ?';

  @override
  String get reportSend => 'Envoyer';

  @override
  String get reportSent => 'Erreur signalée. Merci !';

  @override
  String reportLocation(String place) {
    return 'Endroit : $place';
  }

  @override
  String reportLocationPage(int page) {
    return 'Page $page';
  }

  @override
  String reportLocationPdfPage(int page) {
    return 'Page PDF $page';
  }

  @override
  String reportLocationLine(int line) {
    return 'Ligne $line';
  }

  @override
  String get reportsTitle => 'Signalements';

  @override
  String get reportsEmpty => 'Aucun signalement';

  @override
  String reportsClosed(int count) {
    return 'Clos et retirés ($count)';
  }

  @override
  String get reportByYou => 'par toi';

  @override
  String reportBy(String name) {
    return 'par $name';
  }

  @override
  String get reportWithdrawn => 'retiré';

  @override
  String get reportWithdraw => 'Retirer';

  @override
  String get reportWithdrawnMessage => 'Signalement retiré';

  @override
  String get resolveReport => 'Clore le signalement';

  @override
  String get reportAnswerLabel => 'Réponse';

  @override
  String get reportAnswerHint => 'p. ex. Corrigé, merci !';

  @override
  String get reportResolvedMessage => 'Signalement clos';

  @override
  String get reportReopen => 'Rouvrir';

  @override
  String get reportReopenedMessage => 'Signalement rouvert';

  @override
  String get reportResolvedNoAnswer => 'Clos';

  @override
  String reportAnswer(String answer) {
    return 'Clos : $answer';
  }

  @override
  String reportAnswered(String song, String answer) {
    return 'Ton signalement sur « $song » a été clos : $answer';
  }

  @override
  String reportAnsweredNoText(String song) {
    return 'Ton signalement sur « $song » a été clos.';
  }

  @override
  String reportsAnswered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de tes signalements ont été clos.',
      one: '1 de tes signalements a été clos.',
    );
    return '$_temp0';
  }

  @override
  String get screenshotAdd => 'Joindre une capture';

  @override
  String get screenshotRemove => 'Retirer';

  @override
  String get screenshotMarkTitle => 'Marquer l’endroit';

  @override
  String get screenshotMarkHint =>
      'Dessine sur la capture où se trouve l’erreur.';

  @override
  String get screenshotAttach => 'Joindre';

  @override
  String get screenshotShow => 'Afficher la capture en grand';

  @override
  String get screenshotLoading => 'Chargement de la capture …';

  @override
  String get screenshotUnavailable => 'Capture indisponible (hors ligne ?)';

  @override
  String get lineup => 'Formation';

  @override
  String get lineupWholeBand => 'Tout le groupe';

  @override
  String get lineupSubstitute => 'Remplaçant·e';

  @override
  String get lineupBandMembers => 'Membres du groupe';

  @override
  String get lineupSubstitutes => 'Remplaçant·es';

  @override
  String get lineupNotPlanned => 'Tu n\'es pas prévu·e';

  @override
  String get lineupEdit => 'Choisir la formation';

  @override
  String get lineupAddPeople => 'Ajouter des personnes';

  @override
  String get lineupSearchPeople => 'Rechercher des personnes';

  @override
  String get lineupNoMorePeople =>
      'Toutes les personnes de l\'organisation sont déjà dans la formation.';

  @override
  String get lineupNobody => 'Personne de prévu';

  @override
  String get lineupWholeBandHint =>
      'La formation suit le groupe, nouveaux membres compris.';

  @override
  String get bandSubstituteHint =>
      'Tu joues certains sets de ce groupe comme remplaçant·e et ne vois que ces sets.';

  @override
  String get overviewAsSubstitute => 'Comme remplaçant·e';

  @override
  String get lineupNotify => 'Prévenir la formation';

  @override
  String get lineupCopy => 'Copier';

  @override
  String get lineupCopied => 'Texte copié';

  @override
  String get lineupMail => 'Par e-mail';

  @override
  String get lineupShare => 'Partager …';

  @override
  String get lineupNoAddresses =>
      'Pas de connexion au serveur : choisis toi-même les destinataires.';

  @override
  String lineupMessageIntro(String set) {
    return 'Vous êtes prévu·es pour « $set ».';
  }

  @override
  String get lineupMessageFooter => 'Vous trouvez les morceaux dans setDING.';

  @override
  String get overviewPlanned => 'Tu es prévu·e';

  @override
  String get overviewPlannedSeen => 'Compris';
}
