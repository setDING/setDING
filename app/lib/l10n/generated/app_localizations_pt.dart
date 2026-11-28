// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'setDING';

  @override
  String get navSets => 'Sets';

  @override
  String get navSongs => 'Músicas';

  @override
  String get navSettings => 'Definições';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get edit => 'Editar';

  @override
  String get add => 'Adicionar';

  @override
  String get ok => 'OK';

  @override
  String get close => 'Fechar';

  @override
  String get rename => 'Mudar o nome';

  @override
  String get discard => 'Descartar';

  @override
  String get untitled => 'Sem título';

  @override
  String errorGeneric(String error) {
    return 'Algo correu mal: $error';
  }

  @override
  String get songsEmpty =>
      'Ainda não há músicas. Cria uma música nova ou importa ficheiros ChordPro.';

  @override
  String get searchSongs => 'Pesquisar músicas';

  @override
  String get searchClear => 'Limpar pesquisa';

  @override
  String get newSong => 'Nova música';

  @override
  String get newPdfSong => 'Nova música PDF';

  @override
  String get importFiles => 'Importar ficheiros';

  @override
  String get importTitle => 'Importar ficheiros ChordPro';

  @override
  String get importDescription =>
      'Suportados: .cho, .chordpro, .chopro, .crd, .pro, .txt, arquivos ZIP com esses ficheiros e cópias de segurança do setDING.';

  @override
  String get importGermanNotation => 'Os ficheiros usam a notação alemã (H/B)';

  @override
  String get importGermanNotationHint =>
      'Os acordes são convertidos para a notação internacional ao importar.';

  @override
  String get importOpenAfter => 'Abrir depois de importar';

  @override
  String get importOpenAfterHint =>
      'Se for importada uma só música, abre logo.';

  @override
  String get chooseFiles => 'Escolher ficheiros';

  @override
  String importResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas importadas',
      one: '1 música importada',
      zero: 'Nenhuma música importada',
    );
    return '$_temp0';
  }

  @override
  String importSkipped(String files) {
    return 'Ignorados: $files';
  }

  @override
  String get deleteSongTitle => 'Eliminar a música?';

  @override
  String deleteSongMessage(String title) {
    return '\"$title\" será eliminada e removida de todos os sets.';
  }

  @override
  String get attachmentsTooltip => 'Tem anexos (PDF, imagens)';

  @override
  String get keyOriginal => 'Original';

  @override
  String get capo => 'Capotraste';

  @override
  String capoValue(int fret) {
    return 'Capotraste $fret';
  }

  @override
  String capoLabel(int fret) {
    return 'Capotraste: $fret';
  }

  @override
  String capoLabelWithKey(int fret, String key) {
    return 'Capotraste: $fret ($key)';
  }

  @override
  String capoAsInSongLabel(String capo) {
    return '$capo, como na música';
  }

  @override
  String get noCapo => 'Sem capotraste';

  @override
  String capoAsInSong(int fret) {
    return 'Capotraste $fret (como na música)';
  }

  @override
  String get allTags => 'Todas';

  @override
  String get tagsFilter => 'Etiquetas';

  @override
  String get filterByTags => 'Filtrar por etiquetas';

  @override
  String tagsFilterMore(String tag, int count) {
    return '$tag +$count';
  }

  @override
  String get notes => 'As minhas notas';

  @override
  String get notesHint => 'Só tu vês esta nota.';

  @override
  String get editSource => 'Editar ChordPro';

  @override
  String get attachments => 'Anexos';

  @override
  String get addAttachment => 'Anexar ficheiro';

  @override
  String get noAttachments => 'Ainda não há anexos.';

  @override
  String attachmentTooLarge(String limit) {
    return 'O ficheiro tem mais de $limit e não pode ser anexado.';
  }

  @override
  String get songLinks => 'Fontes';

  @override
  String get noSongLinks =>
      'Ainda não há fontes. Adiciona gravações no YouTube, Spotify e semelhantes.';

  @override
  String get addSongLink => 'Adicionar link';

  @override
  String get editSongLink => 'Editar link';

  @override
  String get deleteSongLink => 'Remover fonte';

  @override
  String get deleteSongLinkMessage => 'Remover esta fonte da música?';

  @override
  String get songLinkUrl => 'Link (URL)';

  @override
  String get songLinkLabel => 'Etiqueta (opcional)';

  @override
  String get songLinkLabelHint => 'Live 2009';

  @override
  String get songLinkInvalid =>
      'Introduz um link web que comece por https:// (sem |).';

  @override
  String get songLinkFailed => 'Não foi possível abrir o link.';

  @override
  String songSelectNumber(String number) {
    return 'Número CCLI $number';
  }

  @override
  String get attachmentName => 'Nome do anexo';

  @override
  String pagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count páginas',
      one: '1 página',
    );
    return '$_temp0';
  }

  @override
  String get liveView => 'Mostrar no modo ao vivo';

  @override
  String get liveViewChordPro => 'Texto ChordPro';

  @override
  String get exportSong => 'Exportar';

  @override
  String get exported => 'Exportado';

  @override
  String get fileSaved => 'Guardado';

  @override
  String get exportedOpen => 'Abrir';

  @override
  String get openFileFailed => 'Nenhuma app conseguiu abrir o ficheiro.';

  @override
  String get playLive => 'Tocar ao vivo';

  @override
  String get live => 'Ao vivo';

  @override
  String get chordView => 'Vista de acordes';

  @override
  String get useDeviceSetting => 'Como nas definições';

  @override
  String get on => 'Ligado';

  @override
  String get off => 'Desligado';

  @override
  String get fontLarger => 'Texto maior';

  @override
  String get fontSmaller => 'Texto menor';

  @override
  String get fitToPage => 'Ajustar à página';

  @override
  String get resetAdjustments => 'Repor ajustes pessoais';

  @override
  String get personalAdjustments => 'Ajustes pessoais';

  @override
  String get scopePersonal =>
      'Só para ti – a música fica inalterada para todos os outros.';

  @override
  String get scopeSet => 'Para este set – aplica-se a toda a banda.';

  @override
  String get scopeBand =>
      'Para toda a banda – aplica-se em todos os seus sets.';

  @override
  String get scopeSong => 'Para a música – altera-a para todos na organização.';

  @override
  String get keyPickerPersonal => 'O meu tom – só para mim';

  @override
  String get keyPickerSet => 'Tom neste set – para toda a banda';

  @override
  String get keyPickerBand => 'Tom da banda – para todos os seus sets';

  @override
  String get editTitle => 'Editar título';

  @override
  String get title => 'Título';

  @override
  String get artist => 'Artista';

  @override
  String get noContent => 'Esta música ainda não tem texto ChordPro.';

  @override
  String get addChordPro => 'Adicionar texto ChordPro';

  @override
  String keyLabel(String key) {
    return 'Tom: $key';
  }

  @override
  String bpm(int tempo) {
    return '$tempo BPM';
  }

  @override
  String get noKeyForDegrees =>
      'Os números Nashville e os numerais romanos precisam de um tom na música.';

  @override
  String get firstVerseChordsOnly => 'Acordes só na estrofe 1';

  @override
  String get noVersesForFirstVerseChords =>
      'A música não tem mais estrofes com acordes.';

  @override
  String get verseChords => 'Acordes nas estrofes';

  @override
  String get verseChordsAll => 'Acordes em todas as estrofes';

  @override
  String get verseChordsStacked => 'Estrofes empilhadas';

  @override
  String get chorusesStacked => 'Refrões empilhados';

  @override
  String get editorTitleNew => 'Nova música';

  @override
  String get editorTitleEdit => 'Editar música';

  @override
  String get editorTab => 'Texto';

  @override
  String get previewTab => 'Pré-visualização';

  @override
  String get insertVerse => 'Inserir verse';

  @override
  String get insertChorus => 'Inserir chorus';

  @override
  String get insertBridge => 'Inserir bridge';

  @override
  String get insertComment => 'Inserir comentário';

  @override
  String get insertChord => 'Inserir acorde';

  @override
  String get discardChangesTitle => 'Descartar as alterações?';

  @override
  String get discardChangesMessage =>
      'As tuas alterações ainda não foram guardadas.';

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
      'Ainda não há sets. Cria um set para o teu próximo concerto.';

  @override
  String get newSet => 'Novo set';

  @override
  String get editSet => 'Editar set';

  @override
  String get setName => 'Nome';

  @override
  String get gigDate => 'Data';

  @override
  String get venue => 'Local';

  @override
  String get noDate => 'Sem data';

  @override
  String get pickDate => 'Escolher data';

  @override
  String get clearDate => 'Remover data';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos',
      one: '1 elemento',
      zero: 'Vazio',
    );
    return '$_temp0';
  }

  @override
  String offlineMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas não disponíveis offline',
      one: '1 música não disponível offline',
    );
    return '$_temp0';
  }

  @override
  String get offlineMissingTooltip =>
      'Nem todas as músicas e PDF deste set estão no dispositivo. Liga-o à rede e espera pela sincronização.';

  @override
  String syncStale(String time) {
    return 'Última sincronização com o servidor: $time. Os sets neste dispositivo podem não estar atualizados.';
  }

  @override
  String get syncStaleNever =>
      'Este dispositivo ainda não sincronizou com o servidor. Os sets podem não estar atualizados.';

  @override
  String syncUnsent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alterações deste dispositivo ainda não chegaram',
      one: '1 alteração deste dispositivo ainda não chegou',
    );
    return '$_temp0 ao servidor.';
  }

  @override
  String get addSongs => 'Adicionar músicas';

  @override
  String get pause => 'Pausa';

  @override
  String get textItem => 'Texto';

  @override
  String get markerIconBreak => 'Pausa';

  @override
  String get markerIconDrinks => 'Bebidas';

  @override
  String get markerIconAnnouncement => 'Anúncio';

  @override
  String get markerIconMicrophone => 'Discurso';

  @override
  String get markerIconGuest => 'Convidado';

  @override
  String get markerIconEncore => 'Encore';

  @override
  String get markerIconTransition => 'Transição';

  @override
  String get markerIconSolo => 'Solo';

  @override
  String get markerIconApplause => 'Aplausos';

  @override
  String get markerIconInstrument => 'Troca de instrumento';

  @override
  String get markerIconTuning => 'Afinação';

  @override
  String get markerIconClick => 'Clique';

  @override
  String get markerIconLight => 'Luz';

  @override
  String get markerIconEffects => 'Efeitos';

  @override
  String get markerIconCelebration => 'Festa';

  @override
  String get markerIconInfo => 'Nota';

  @override
  String get markerIconWarning => 'Atenção';

  @override
  String get marker => 'Marcador';

  @override
  String get addMarker => 'Adicionar marcador';

  @override
  String get editMarker => 'Editar marcador';

  @override
  String get markerText => 'Texto';

  @override
  String get markerPreview => 'Pré-visualização';

  @override
  String get markerGroupBreak => 'Pausa';

  @override
  String get markerGroupAnnouncement => 'Anúncio';

  @override
  String get markerGroupFlow => 'Decurso';

  @override
  String get markerGroupStage => 'Palco';

  @override
  String get markerGroupShow => 'Espetáculo';

  @override
  String get markerGroupGeneral => 'Geral';

  @override
  String get setEmpty => 'Este set está vazio. Adiciona algumas músicas.';

  @override
  String get deleteSetTitle => 'Eliminar o set?';

  @override
  String deleteSetMessage(String name) {
    return '\"$name\" será eliminado. As músicas são mantidas.';
  }

  @override
  String get removeFromSet => 'Remover do set';

  @override
  String get selectSongs => 'Selecionar músicas';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selecionadas',
      one: '1 selecionada',
      zero: 'Nenhuma selecionada',
    );
    return '$_temp0';
  }

  @override
  String get songMissing => 'A música já não existe';

  @override
  String liveNext(String title) {
    return 'A seguir: $title';
  }

  @override
  String get liveWebNotice =>
      'No navegador não é seguro offline – em palco, usa a app';

  @override
  String liveMidiConnected(String name) {
    return 'Teclado ligado: $name';
  }

  @override
  String get liveMidiNotConnected => 'Teclado não ligado';

  @override
  String get liveMidiSendAgain => 'Enviar o programa novamente';

  @override
  String get liveMidiButton =>
      'Programa do teclado (toque longo: enviar novamente)';

  @override
  String get liveMidiChange => 'Mudar de programa';

  @override
  String get liveMidiSameAsPrevious => 'Igual à música anterior';

  @override
  String liveMidiPreviousProgram(String program, String title) {
    return '$program – de “$title”';
  }

  @override
  String get liveMidiNoPrevious => 'Nenhuma música anterior com programa';

  @override
  String get liveMidiSaved => 'Programa do teclado guardado';

  @override
  String get liveMidiRemoved => 'Programa do teclado removido';

  @override
  String get liveMidiTakeOverWaiting => 'Escolhe um som no teclado';

  @override
  String liveMidiTakeOver(String program) {
    return 'Adotar: $program';
  }

  @override
  String get liveMidiTakeOverHint =>
      'O setDING adota o programa que o teclado envia.';

  @override
  String get liveMidiTakeOverNordHint =>
      'Não chega nada? No Nord, define “Program Change” como “Send” ou “Send & Receive” no menu MIDI.';

  @override
  String get liveMidiTakeOverSame => 'Este já é o programa da música';

  @override
  String get liveWakeLockNotice =>
      'O ecrã pode desligar-se – verifica as definições de energia do dispositivo';

  @override
  String get liveEnd => 'Fim do set';

  @override
  String get liveSetOverview => 'Vista geral do set';

  @override
  String get liveExit => 'Sair do modo ao vivo';

  @override
  String get projectionFullScreen => 'Ecrã inteiro';

  @override
  String get projectionStart => 'Projetar a letra';

  @override
  String get projectionTitle => 'Projeção da letra';

  @override
  String get projectionHint =>
      'Abre este endereço no navegador de um dispositivo na mesma rede (portátil do projetor, televisor, OBS). A letra segue o modo ao vivo.';

  @override
  String get projectionLowerThird => 'Oráculo (OBS)';

  @override
  String get projectionNoNetwork =>
      'Nenhuma rede encontrada. Liga este dispositivo a uma rede Wi-Fi ou ativa o seu hotspot.';

  @override
  String get projectionStop => 'Terminar a projeção';

  @override
  String get projectionLinks => 'Projeção: endereços';

  @override
  String get projectionCopyLink => 'Copiar o endereço';

  @override
  String get projectionLinkCopied => 'Endereço copiado';

  @override
  String get projectionPrevious => 'Diapositivo anterior';

  @override
  String get projectionNext => 'Diapositivo seguinte';

  @override
  String get projectionFollow => 'Voltar a seguir o modo ao vivo';

  @override
  String get projectionBlank => 'Ecrã preto';

  @override
  String get projectionUnblank => 'Voltar a mostrar a letra';

  @override
  String get projectionNoCopyright =>
      'Esta música não tem copyright e é projetada sem ele.';

  @override
  String get projectionStartFailed => 'Não foi possível iniciar a projeção.';

  @override
  String get settingsHeadingProjection => 'Projeção';

  @override
  String get settingsProjectionHint =>
      'Como a letra aparece no navegador do projetor. Para este dispositivo.';

  @override
  String get settingsProjectionColours => 'Cores';

  @override
  String get projectionThemeDark => 'Branco sobre preto';

  @override
  String get projectionThemeLight => 'Preto sobre branco';

  @override
  String get settingsProjectionFont => 'Tipo de letra';

  @override
  String get projectionFontSans => 'Sem serifa';

  @override
  String get projectionFontSerif => 'Com serifa';

  @override
  String get settingsProjectionAlign => 'Alinhamento';

  @override
  String get projectionAlignCenter => 'Centrado';

  @override
  String get projectionAlignLeft => 'À esquerda';

  @override
  String get settingsProjectionLines => 'Linhas por diapositivo';

  @override
  String get settingsProjectionLinesHint =>
      'As secções mais longas são distribuídas por vários diapositivos. Para o oráculo, 2 a 4.';

  @override
  String get settingsProjectionCopyright => 'Copyright';

  @override
  String get projectionCopyrightEvery => 'Em cada diapositivo';

  @override
  String get projectionCopyrightFirstAndLast =>
      'No primeiro e no último diapositivo';

  @override
  String get settingsProjectionSecondLanguage => 'Segunda língua';

  @override
  String get settingsProjectionSecondLanguageHint =>
      'Se uma música tiver uma versão nesta língua, é projetada ao lado.';

  @override
  String get projectionSecondLanguageOff => 'Nenhuma';

  @override
  String get settingsProjectionMarkers => 'Marcadores como texto';

  @override
  String get settingsProjectionMarkersHint =>
      'Mostra o texto de um marcador (p. ex. Oração) em vez de um diapositivo preto.';

  @override
  String get settingsProjectionPreview => 'Mostrar o diapositivo seguinte';

  @override
  String get settingsProjectionPreviewHint =>
      'Em pequeno sob a letra, para um monitor de palco.';

  @override
  String get settingsProjectionTurnsSlides =>
      'Virar a página avança os diapositivos';

  @override
  String get settingsProjectionTurnsSlidesHint =>
      'Durante a projeção, avançar (pedal, teclado, toque) passa primeiro para o diapositivo seguinte da música e só depois do último para a música seguinte. O mesmo para trás.';

  @override
  String get projectionRenew => 'Novo endereço';

  @override
  String get projectionRenewed =>
      'Novo endereço criado. O antigo já não funciona.';

  @override
  String get settingsProjectionAddress => 'Novo endereço de projeção';

  @override
  String get settingsProjectionAddressHint =>
      'O endereço mantém-se neste dispositivo, para que o projetor e o OBS o guardem. Um novo endereço bloqueia as ligações antigas.';

  @override
  String get settingsProjectionShowLabel => 'Mostrar a secção';

  @override
  String get settingsProjectionShowLabelHint =>
      'Em pequeno sobre a letra, p. ex. «Estrofe 1» ou «Refrão».';

  @override
  String liveSongPage(int page, int count) {
    return 'Página $page/$count';
  }

  @override
  String livePosition(int current, int total) {
    return '$current / $total';
  }

  @override
  String get settingsSectionGeneral => 'Geral';

  @override
  String get settingsSectionDisplay => 'Visualização';

  @override
  String get settingsSectionLive => 'Ecrã e modo ao vivo';

  @override
  String get settingsSectionStorage => 'Armazenamento e info';

  @override
  String get settingsSectionMusician => 'Músico';

  @override
  String get settingsCategoryAccountHint =>
      'Início de sessão, servidor e sincronização';

  @override
  String get settingsCategoryGeneralHint => 'Idioma e tema';

  @override
  String get settingsCategoryMusicianHint =>
      'Instrumento, voz, diagramas de acordes, pulsação';

  @override
  String get settingsCategoryDisplayHint =>
      'Notação de acordes, Nashville e numerais romanos, conteúdo, refrão, progresso';

  @override
  String get settingsCategoryLiveHint =>
      'Tamanho do texto, ajustar ao ecrã, colunas, virar página';

  @override
  String get settingsCategoryAboutHint =>
      'Armazenamento, registo de diagnóstico e versão';

  @override
  String get settingsInstrument => 'O meu instrumento';

  @override
  String get settingsInstrumentHint =>
      'Usado para partes condicionais (p. ex. só guitarra) e para os diagramas de acordes.';

  @override
  String get instrumentGuitar => 'Guitarra';

  @override
  String get instrumentUkulele => 'Ukulele';

  @override
  String get instrumentBass => 'Baixo';

  @override
  String get instrumentKeyboard => 'Teclado';

  @override
  String get instrumentVocals => 'Voz';

  @override
  String get instrumentDrums => 'Bateria';

  @override
  String get instrumentOther => 'Outro …';

  @override
  String get settingsUserName => 'Voz ou papel (opcional)';

  @override
  String get settingsUserNameHint =>
      'O teu instrumento já conta. Só é necessário se uma música tiver partes para vozes ou pessoas específicas, p. ex. “alto” ou “tenor”.';

  @override
  String settingsUserNameIsInstrument(String name) {
    return '“$name” é um instrumento. A definição de instrumento já o cobre, por isso podes deixar este campo vazio.';
  }

  @override
  String get settingsDiagrams => 'Diagramas de acordes';

  @override
  String get settingsDiagramsHint =>
      'Mostra as dedilhações de todos os acordes da música para o teu instrumento. Uma música pode defini-lo ela própria com a diretiva diagrams.';

  @override
  String get settingsBassStrings => 'Cordas do baixo';

  @override
  String get settingsBassStringsHint =>
      'Os diagramas de acordes mostram um baixo de 4 cordas (E-A-D-G) ou um baixo de 5 cordas com uma corda Si grave.';

  @override
  String bassStringCount(int count) {
    return '$count cordas';
  }

  @override
  String get diagramsOff => 'Desligados';

  @override
  String get diagramsTop => 'Em cima';

  @override
  String get diagramsBottom => 'Em baixo';

  @override
  String get notSet => 'Não definido';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get languageSystem => 'Idioma do sistema';

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
  String get settingsTheme => 'Tema';

  @override
  String get themeSystem => 'Como o sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';

  @override
  String get settingsAccent => 'Cor de destaque';

  @override
  String get accentBrand => 'Azul setDING';

  @override
  String get accentRed => 'Vermelho';

  @override
  String get accentAmber => 'Âmbar';

  @override
  String get accentGreen => 'Verde';

  @override
  String get accentTeal => 'Verde-azulado';

  @override
  String get accentPurple => 'Roxo';

  @override
  String get accentPink => 'Rosa';

  @override
  String get settingsNotation => 'Notação de acordes';

  @override
  String get notationInternational => 'Internacional (B, Bb)';

  @override
  String get notationGerman => 'Alemã (H, B)';

  @override
  String get settingsChordView => 'Mostrar acordes como';

  @override
  String get settingsChordViewHint =>
      'Acordes (Am7), números Nashville (6m7) ou numerais romanos (vi7). Números e numerais precisam de um tom na música.';

  @override
  String get settingsNumeralSpelling => 'Escrita dos numerais romanos';

  @override
  String get settingsNumeralSpellingHint =>
      'Como os numerais romanos mostram o acorde: por maiúsculas e minúsculas, ii7 – V7 – IΔ7, ou em maiúsculas com o símbolo do acorde, IIm7 – V7 – Imaj7. O símbolo do acorde segue o estilo de acordes.';

  @override
  String get numeralSpellingCasing => 'Maiúsculas/minúsculas';

  @override
  String get numeralSpellingChordSymbol => 'Símbolo do acorde';

  @override
  String get settingsChordStyle => 'Estilo de acordes';

  @override
  String get settingsChordStyleHint =>
      'Como os acordes são escritos, p. ex. Am7, Cmaj7, Em7b5 (padrão) ou A−7, CΔ7, Eø7 (jazz). A música em si não é alterada.';

  @override
  String get chordStyleAsWritten => 'Como está escrito';

  @override
  String get chordStyleStandard => 'Padrão';

  @override
  String get chordStyleJazz => 'Jazz';

  @override
  String get settingsChordSuperscript => 'Extensões em expoente';

  @override
  String get settingsChordSuperscriptHint =>
      'Mostra extensões e alterações mais pequenas e elevadas, p. ex. C⁷. Requer o estilo padrão ou jazz.';

  @override
  String get settingsDisplayMode => 'Conteúdo';

  @override
  String get displayLyricsAndChords => 'Letra e acordes';

  @override
  String get displayLyricsOnly => 'Só a letra';

  @override
  String get settingsFontSize => 'Tamanho do texto';

  @override
  String get settingsColumns => 'Colunas';

  @override
  String get columnsAuto => 'Automático';

  @override
  String get columnsOne => 'Uma';

  @override
  String get columnsTwo => 'Duas';

  @override
  String get settingsPageTurn => 'Virar página';

  @override
  String get pageTurnFull => 'Página inteira';

  @override
  String get pageTurnHalf => 'Meia página';

  @override
  String get settingsAutoFit => 'Ajustar a música ao ecrã';

  @override
  String get settingsAutoFitHint =>
      'A música inteira cabe no ecrã sem deslocar. As secções são dispostas automaticamente em colunas e o texto fica o maior possível.';

  @override
  String get settingsColumnsHint =>
      'Ao ajustar ao ecrã, o número máximo de colunas permitido.';

  @override
  String get columnsThree => 'Três';

  @override
  String get settingsChorusRepeat => 'Refrão repetido';

  @override
  String get settingsChorusRepeatHint =>
      'Automático: um refrão repetido só é mostrado como etiqueta curta se, de outro modo, a música não couber bem no ecrã.';

  @override
  String get chorusRepeatAuto => 'Automático';

  @override
  String get chorusRepeatFull => 'Mostrar completo';

  @override
  String get chorusRepeatLabel => 'Só etiqueta';

  @override
  String get settingsPageTurnHint =>
      'Toca no lado esquerdo ou direito do ecrã para recuar ou avançar. Virador de páginas (pedal) e teclado: seta direita, seta para baixo, Page Down e Espaço avançam; seta esquerda, seta para cima e Page Up recuam. Com pulsação (tempo e pulsação ou clique ativados), manter avançar premido ou premir Enter inicia-a e para-a.';

  @override
  String get settingsSetProgress => 'Barra de progresso do set';

  @override
  String get settingsSetProgressHint =>
      'Uma barra fina por cima da barra inferior mostra as músicas do set e as páginas da música atual: a página atual na cor de destaque, as páginas seguintes num tom mais claro. Os marcadores, como as pausas, são tracejados.';

  @override
  String get settingsBeatSection => 'Pulsação e clique';

  @override
  String get settingsBeatSectionHint =>
      'Tempo e compasso da música, ou o tempo do arranjo da banda. Ativo por predefinição se o teu instrumento for a bateria.';

  @override
  String get settingsBeatDisplay => 'Indicador de pulsação';

  @override
  String get settingsBeatDisplayHint =>
      'Pontos junto ao tempo e ao compasso acendem-se em cada tempo; a contagem inicial mostra números grandes.';

  @override
  String get settingsEdgeFlash => 'Piscar a margem do ecrã';

  @override
  String get settingsEdgeFlashHint =>
      'A margem pisca em cada tempo, o 1 noutra cor – visível pelo canto do olho.';

  @override
  String get settingsClick => 'Clique';

  @override
  String get settingsClickHint =>
      'Reproduz um clique na saída de áudio do dispositivo, p. ex. na mistura in-ear.';

  @override
  String get settingsClickStart => 'Início';

  @override
  String get settingsClickStartHint =>
      'Manualmente: toca no tempo, mantém o pedal de avançar premido ou prime Enter. Passar para outra música do set para a pulsação.';

  @override
  String get clickStartAutomatic => 'Com cada música';

  @override
  String get clickStartManual => 'Manualmente';

  @override
  String get settingsClickDuration => 'Duração';

  @override
  String get clickDurationSong => 'Música inteira';

  @override
  String get clickDurationCountIn => 'Só contagem inicial';

  @override
  String get settingsClickInBackground => 'Em segundo plano';

  @override
  String get settingsClickInBackgroundHint =>
      'Quando a app está minimizada, outra app é aberta ou o ecrã está bloqueado.';

  @override
  String get clickInBackgroundStop => 'Parar';

  @override
  String get clickInBackgroundKeepPlaying => 'Continuar a tocar';

  @override
  String get settingsCountIn => 'Contagem inicial';

  @override
  String get countInOff => 'Desligada';

  @override
  String get countInOneBar => '1 compasso';

  @override
  String get countInTwoBars => '2 compassos';

  @override
  String get settingsClickVolume => 'Volume';

  @override
  String get settingsClickAccent => 'Acento no 1';

  @override
  String get settingsClickSound => 'Som';

  @override
  String get clickSoundClick => 'Clique';

  @override
  String get clickSoundWoodblock => 'Woodblock';

  @override
  String get clickSoundBeep => 'Bipe';

  @override
  String get settingsClickSubdivision => 'Subdivisões';

  @override
  String get settingsClickSubdivisionHint =>
      'Cliques mais suaves entre os tempos. Cada música pode ter as suas nos seus ajustes pessoais.';

  @override
  String get subdivisionOff => 'Desligadas';

  @override
  String get subdivisionEighths => 'Colcheias';

  @override
  String get subdivisionSixteenths => 'Semicolcheias';

  @override
  String get subdivisionTriplets => 'Tercinas';

  @override
  String clickSubdivisionAsInSettings(String value) {
    return 'Como nas definições ($value)';
  }

  @override
  String get clickGrouping => 'Agrupamento';

  @override
  String get clickGroupingNone => 'Sem grupos';

  @override
  String clickGroupingAsInSong(String grouping) {
    return 'Como na música ($grouping)';
  }

  @override
  String get clickGroupingHint =>
      'Tempos acentuados de um compasso irregular, só para ti.';

  @override
  String get settingsAudioLatency => 'Atraso de áudio';

  @override
  String get settingsAudioLatencyHint =>
      'Desloca a visualização para corresponder ao que ouves. Auscultadores com fio precisam de pouco, auscultadores Bluetooth 100–300 ms.';

  @override
  String audioLatencyValue(int ms) {
    return '$ms ms';
  }

  @override
  String get audioLatencyCalibrate => 'Medir o atraso de áudio';

  @override
  String get audioLatencyCalibrateTitle => 'Medir o atraso de áudio';

  @override
  String get audioLatencyCalibrateHint =>
      'Põe os auscultadores que usas em palco e toca a acompanhar cada tempo do clique.';

  @override
  String get audioLatencyTap => 'Tocar';

  @override
  String audioLatencyTaps(int count) {
    return '$count toques';
  }

  @override
  String audioLatencyResult(int ms) {
    return 'Medido: $ms ms';
  }

  @override
  String get audioLatencyApply => 'Aplicar';

  @override
  String get clickNoAudio =>
      'Este dispositivo não tem saída de áudio para o clique.';

  @override
  String get beatStart => 'Iniciar a pulsação';

  @override
  String get beatStop => 'Parar a pulsação';

  @override
  String get beatDisplayLabel => 'Pulsação';

  @override
  String countInBar(int bar, int count) {
    return 'Compasso $bar de $count';
  }

  @override
  String get tempoSlower => 'Mais lento';

  @override
  String get tempoFaster => 'Mais rápido';

  @override
  String get tapTempo => 'Tap tempo';

  @override
  String get tempoReset => 'Voltar ao tempo da música';

  @override
  String get clickNoAudioLive => 'Sem áudio para o clique';

  @override
  String get settingsSongMap => 'Mapa da música em vez de acordes';

  @override
  String get settingsSongMapHint =>
      'O modo ao vivo mostra as partes da música com uma deixa da letra e as notas de bateria.';

  @override
  String get songMapEmpty =>
      'Esta música não tem partes (verse, chorus, …) para mostrar como mapa da música.';

  @override
  String get songMapNoTempo => 'Sem tempo para esta música';

  @override
  String get drumPanelSet => 'Set';

  @override
  String get drumPanelSongMap => 'Mapa da música';

  @override
  String get settingsLiveAppearance => 'Aspeto em palco';

  @override
  String get settingsLiveAppearanceHint =>
      'O modo ao vivo independente do tema da app. O preto poupa energia em ecrãs OLED.';

  @override
  String get liveAppearanceApp => 'Como a app';

  @override
  String get liveAppearanceDark => 'Escuro';

  @override
  String get liveAppearanceBlack => 'Preto';

  @override
  String settingsStorageUsed(String size) {
    return 'Os anexos PDF ocupam $size';
  }

  @override
  String get appMenuEntryAdd => 'Adicionar ao menu de aplicações';

  @override
  String get appMenuEntryAddHint =>
      'setDING com o seu ícone no menu iniciar do teu ambiente de trabalho';

  @override
  String get appMenuEntryInstalled => 'No menu de aplicações';

  @override
  String get appMenuEntryInstalledHint =>
      'O menu iniciar abre este ficheiro AppImage';

  @override
  String get appMenuEntryRemove => 'Remover';

  @override
  String get appMenuEntryAdded => 'O setDING está agora no menu de aplicações';

  @override
  String get appMenuEntryRemoved => 'setDING removido do menu de aplicações';

  @override
  String appMenuEntryFailed(String error) {
    return 'Menu de aplicações não alterado: $error';
  }

  @override
  String get settingsLogCopy => 'Copiar registo de diagnóstico';

  @override
  String get settingsLogCopyHint =>
      'As mensagens recentes da app, p. ex. porque falhou uma sincronização – para colar numa mensagem ao suporte.';

  @override
  String get settingsLogCopied => 'Registo de diagnóstico copiado';

  @override
  String get settingsAbout =>
      'O setDING funciona localmente neste dispositivo. Todos os dados estão disponíveis offline.';

  @override
  String settingsVersion(String version) {
    return 'Versão $version';
  }

  @override
  String get lilypondNotice =>
      'Esta notação Lilypond usa funções que o setDING não consegue desenhar. Fonte:';

  @override
  String get sequenceLabel => 'Sequência da música';

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
  String get editorGroupChords => 'Acordes';

  @override
  String get editorGroupSections => 'Secções';

  @override
  String get editorGroupInfo => 'Info da música';

  @override
  String get editorGroupText => 'Texto';

  @override
  String get editorGroupMore => 'Mais';

  @override
  String get searchMatchCase => 'Diferenciar maiúsculas';

  @override
  String get replaceToggle => 'Substituir';

  @override
  String get replaceWith => 'Substituir por';

  @override
  String get replace => 'Substituir';

  @override
  String get replaceAll => 'Substituir tudo';

  @override
  String replacedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count substituídos',
      one: '1 substituído',
    );
    return '$_temp0';
  }

  @override
  String get convertChordsOverLyrics => 'Converter acordes por cima da letra';

  @override
  String get pastedChordsOverLyrics =>
      'O texto colado tem os acordes por cima da letra.';

  @override
  String get convert => 'Converter';

  @override
  String get convertCcliGrids =>
      'Converter barras de compasso em grelhas de acordes';

  @override
  String ccliGridsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocos de barras de compasso podem',
      one: 'Um bloco de barras de compasso pode',
    );
    return '$_temp0 ser mostrados como grelha de acordes.';
  }

  @override
  String get convertCommentHeadings =>
      'Converter títulos em comentário em secções';

  @override
  String get translateSectionLabels =>
      'Traduzir os nomes das secções para inglês';

  @override
  String commentHeadingsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count secções estão marcadas',
      one: 'Uma secção está marcada',
    );
    return '$_temp0 com um comentário como \"Verse 1\". A conversão transforma-as em secções ChordPro; a música fica com o mesmo aspeto.';
  }

  @override
  String get remove => 'Remover';

  @override
  String get ccliFooterHint =>
      'A música termina com o rodapé CCLI do SongSelect. Ao removê-lo, o número da música e o copyright ficam nos detalhes da música.';

  @override
  String legacyLabelsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count etiquetas de secção estão',
      one: 'Uma etiqueta de secção está',
    );
    return '$_temp0 na forma curta. A especificação ChordPro recomenda label=\"…\".';
  }

  @override
  String songSelectDirectivesHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count diretivas CCLI não seguem',
      one: 'Uma diretiva CCLI não segue',
    );
    return '$_temp0 a especificação ChordPro: ccli passa a x_ccli, footer passa a x_ccli_footer, ccli_license é removida.';
  }

  @override
  String importLegacyLabelsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas importadas escrevem',
      one: '1 música importada escreve',
    );
    return '$_temp0 as etiquetas de secção na forma curta. A conversão escreve-as como label=\"…\", como recomenda a especificação ChordPro; as músicas ficam com o mesmo aspeto.';
  }

  @override
  String get convertLabels => 'Converter etiquetas';

  @override
  String songsLabelsConverted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Etiquetas convertidas em $count músicas',
      one: 'Etiquetas convertidas em 1 música',
      zero: 'Nenhuma etiqueta convertida',
    );
    return '$_temp0';
  }

  @override
  String get hideHint => 'Ocultar dica';

  @override
  String get searchInSong => 'Pesquisar';

  @override
  String get searchNoMatches => 'Sem resultados';

  @override
  String get searchPrevious => 'Resultado anterior';

  @override
  String get searchNext => 'Resultado seguinte';

  @override
  String get searchClose => 'Fechar pesquisa';

  @override
  String searchMatchCount(int current, int total) {
    return '$current de $total';
  }

  @override
  String get editorGroupLines => 'Linhas';

  @override
  String get redo => 'Refazer';

  @override
  String get moveLinesUp => 'Mover linha para cima';

  @override
  String get moveLinesDown => 'Mover linha para baixo';

  @override
  String get moveChordLeft => 'Mover acorde para a esquerda';

  @override
  String get moveChordRight => 'Mover acorde para a direita';

  @override
  String get duplicateLines => 'Duplicar linha';

  @override
  String get deleteLines => 'Eliminar linha';

  @override
  String get toggleComment => 'Comentar linha (#)';

  @override
  String get insertOptionalChord => 'Acorde opcional';

  @override
  String get insertAnnotation => 'Anotação';

  @override
  String get insertNoChord => 'Sem acorde (N.C.)';

  @override
  String get insertDefine => 'Definição de acorde';

  @override
  String get insertChordDiagram => 'Diagrama de acorde';

  @override
  String get insertTranspose => 'Transpor';

  @override
  String get insertTab => 'Tab';

  @override
  String get insertGrid => 'Grelha de acordes';

  @override
  String get insertChorusRecall => 'Repetir chorus';

  @override
  String get metaSubtitle => 'Subtítulo';

  @override
  String get metaComposer => 'Compositor';

  @override
  String get metaLyricist => 'Letrista';

  @override
  String get metaCopyright => 'Copyright';

  @override
  String get metaTag => 'Etiqueta';

  @override
  String get metaYear => 'Ano';

  @override
  String get metaAlbum => 'Álbum';

  @override
  String get metaDuration => 'Duração';

  @override
  String get metaTempo => 'Tempo (BPM)';

  @override
  String get metaTime => 'Compasso';

  @override
  String get metaKey => 'Tom';

  @override
  String get insertCommentItalic => 'Comentário (itálico)';

  @override
  String get insertCommentBox => 'Comentário (caixa)';

  @override
  String get insertHighlight => 'Realce';

  @override
  String get insertBold => 'Negrito';

  @override
  String get insertItalic => 'Itálico';

  @override
  String get insertUnderline => 'Sublinhado';

  @override
  String get insertColour => 'Cor';

  @override
  String get insertColumnBreak => 'Quebra de coluna';

  @override
  String get insertNewPage => 'Quebra de página';

  @override
  String get insertColumns => 'Colunas';

  @override
  String get insertImage => 'Imagem';

  @override
  String get insertAbc => 'Notação ABC';

  @override
  String get insertTextblock => 'Bloco de texto';

  @override
  String get insertNewSong => 'Música seguinte no mesmo ficheiro';

  @override
  String get sequenceEdit => 'Sequência da música para este set';

  @override
  String get sequenceFromSet => 'Sequência alterada para este set';

  @override
  String get sequenceFromBand => 'Sequência da banda';

  @override
  String get bandArrangement => 'Arranjo da banda';

  @override
  String arrangementOf(String band) {
    return 'Arranjo de $band';
  }

  @override
  String get arrangementBand => 'Banda';

  @override
  String get arrangementAsWritten => 'Como na música';

  @override
  String arrangementKey(String key) {
    return 'Tom $key';
  }

  @override
  String get arrangementSequence => 'Sequência';

  @override
  String get arrangementTempo => 'Tempo';

  @override
  String get arrangementTempoLabel => 'Tempo em BPM (vazio = como na música)';

  @override
  String get arrangementReset => 'Repor o arranjo da banda para a música';

  @override
  String sequenceOriginal(Object sequence) {
    return 'Na música: $sequence';
  }

  @override
  String get sequenceNoneInSong => 'A música não tem sequência.';

  @override
  String get sequenceRestore => 'Usar a sequência da música';

  @override
  String get sequenceHint => 'p. ex. I, V1, C, V2, PC, C x2, B, O';

  @override
  String get sequenceAbbreviations =>
      'I Intro · V Verse · PC Pre-chorus · C Chorus · B Bridge · Int Interlude · Solo · T Tag · O Outro · C x2 = duas vezes';

  @override
  String get sequenceEmpty =>
      'Toca nas partes abaixo para construir a sequência, ou arrasta-as para aqui.';

  @override
  String get sequenceReorderHint =>
      'Mantém premida uma parte para a mover para outra posição.';

  @override
  String get sequenceSongParts => 'Partes da música';

  @override
  String get sequenceCommonParts =>
      'Partes comuns (a música ainda não tem secções)';

  @override
  String get sequenceClear => 'Limpar';

  @override
  String get sequenceAsText => 'Editar como texto';

  @override
  String get settingsSectionAccount => 'Conta e sincronização';

  @override
  String get accountSignedOut => 'Sessão não iniciada';

  @override
  String get accountSignedOutHint =>
      'Inicia sessão para partilhar músicas e sets com a tua banda. Sem conta, o setDING continua a funcionar localmente neste dispositivo.';

  @override
  String get accountSignIn => 'Iniciar sessão';

  @override
  String get accountSignUp => 'Criar conta';

  @override
  String get accountJoin => 'Entrar com convite';

  @override
  String get accountSignOut => 'Terminar sessão';

  @override
  String get accountSignOutTitle => 'Terminar sessão?';

  @override
  String get accountSignOutMessage =>
      'As músicas e os sets neste dispositivo são mantidos.';

  @override
  String get accountSignOutMessageWeb =>
      'Os dados neste navegador são eliminados. As músicas e os sets ficam no servidor.';

  @override
  String get accountEmail => 'E-mail';

  @override
  String get accountPassword => 'Palavra-passe';

  @override
  String get accountPasswordConfirm => 'Confirmar palavra-passe';

  @override
  String get accountPasswordShow => 'Mostrar palavra-passe';

  @override
  String get accountPasswordHide => 'Ocultar palavra-passe';

  @override
  String get accountKeepSignedIn => 'Manter sessão iniciada';

  @override
  String get accountKeepSignedInHint =>
      'Só no teu próprio dispositivo. Caso contrário, a sessão termina quando fechas o navegador.';

  @override
  String get accountNameHint =>
      'P. ex. «Andi». Os teus colegas de banda veem-no nas listas em vez do teu nome completo.';

  @override
  String get accountFirstName => 'Nome próprio';

  @override
  String get accountLastName => 'Apelido';

  @override
  String get accountNickname => 'Nome visível (opcional)';

  @override
  String get accountCompleteName => 'Completa o teu nome';

  @override
  String get accountCompleteNameMessage =>
      'Indica o teu nome próprio e apelido, para que os teus colegas de banda te encontrem mais facilmente.';

  @override
  String get settingsHeadingPeople => 'Pessoas';

  @override
  String get settingsNameFormat => 'Mostrar nomes como';

  @override
  String get settingsNameFormatHint =>
      'Como as outras pessoas aparecem nas listas de membros, nas formações e nas alterações.';

  @override
  String get nameFormatNickname => 'Nome visível (senão nome completo)';

  @override
  String get nameFormatFirstLast => 'Nome Apelido';

  @override
  String get nameFormatLastFirst => 'Apelido Nome';

  @override
  String get nameFormatFullWithNickname => 'Nome Apelido (nome visível)';

  @override
  String get accountToSignUp => 'Ainda não tens conta? Cria uma';

  @override
  String get accountToSignIn => 'Já tens conta? Inicia sessão';

  @override
  String get accountForgotPassword => 'Esqueceste a palavra-passe?';

  @override
  String get accountResetTitle => 'Repor palavra-passe';

  @override
  String get accountResetSent =>
      'Se existir uma conta com este endereço, foi enviado um e-mail para repor a palavra-passe.';

  @override
  String get accountFieldRequired => 'Obrigatório.';

  @override
  String accountPasswordTooShort(int min) {
    return 'Pelo menos $min caracteres.';
  }

  @override
  String get accountPasswordMismatch => 'As palavras-passe não coincidem.';

  @override
  String get accountChangeName => 'Alterar nome';

  @override
  String get accountNameChanged => 'Nome alterado.';

  @override
  String get accountChangePassword => 'Alterar palavra-passe';

  @override
  String get accountChangePasswordHint =>
      'A sessão mantém-se neste dispositivo. Nos teus outros dispositivos termina.';

  @override
  String get accountCurrentPassword => 'Palavra-passe atual';

  @override
  String get accountNewPassword => 'Nova palavra-passe';

  @override
  String get accountPasswordWrongCurrent =>
      'A palavra-passe atual está errada.';

  @override
  String get accountPasswordChanged =>
      'Palavra-passe alterada. Inicia sessão novamente nos teus outros dispositivos.';

  @override
  String get accountDelete => 'Eliminar conta';

  @override
  String get accountDeleteHint =>
      'Elimina definitivamente a tua conta e os teus dados pessoais.';

  @override
  String get accountDeleteTitle => 'Eliminar a conta?';

  @override
  String get accountDeleteMessage =>
      'A tua conta, os teus ajustes pessoais, anotações e definições são eliminados definitivamente e a sessão termina em todos os dispositivos. As músicas e os sets ficam nas tuas organizações. As cópias de segurança do servidor guardam uma cópia até 14 dias. Introduz a tua palavra-passe para confirmar.';

  @override
  String get accountDeleteSoleAdmin =>
      'És o único admin destas organizações. Primeiro torna outra pessoa admin ou fecha a organização:';

  @override
  String get accountDeleted => 'A tua conta foi eliminada.';

  @override
  String get dangerZone => 'Zona de perigo';

  @override
  String get accountErrorNetwork =>
      'Sem ligação ao servidor. Verifica a tua ligação à Internet.';

  @override
  String get accountErrorInvalidCredentials =>
      'E-mail ou palavra-passe errados.';

  @override
  String get accountErrorEmailTaken =>
      'Já existe uma conta com este endereço de e-mail.';

  @override
  String get accountErrorInvalidEmail => 'O endereço de e-mail não é válido.';

  @override
  String get accountErrorWeakPassword =>
      'A palavra-passe não cumpre os requisitos do servidor.';

  @override
  String get accountErrorServer =>
      'O servidor comunicou um erro. Tenta novamente mais tarde.';

  @override
  String get accountErrorUpdateRequired =>
      'Esta versão do setDING é demasiado antiga para o servidor. Atualiza a app.';

  @override
  String get updateRequiredTitle => 'Atualiza o setDING';

  @override
  String get updateRequiredBody =>
      'O servidor já não aceita esta versão, por isso nada é sincronizado. As tuas alterações ficam neste dispositivo e são enviadas após a atualização.';

  @override
  String updateRequiredVersions(String current, String minimum) {
    return 'Instalada: $current, necessária: $minimum ou mais recente.';
  }

  @override
  String get updateRequiredHowTo =>
      'No Android, atualiza-a no Obtainium; caso contrário, descarrega a nova versão das releases do setDING no GitHub.';

  @override
  String get updateHowToGooglePlay => 'Atualiza-a no Google Play.';

  @override
  String get updateOpenGooglePlay => 'Abrir no Google Play';

  @override
  String get updateRequiredReload => 'Recarregar';

  @override
  String get updateRequiredCopyLink => 'Copiar link de transferência';

  @override
  String get updateRequiredCopied => 'Link copiado.';

  @override
  String updateAvailableTitle(String version) {
    return 'O setDING $version está disponível';
  }

  @override
  String get updateAvailableDetails => 'Detalhes';

  @override
  String updateAvailableInstalled(String current) {
    return 'Instalada: $current.';
  }

  @override
  String get settingsServer => 'Servidor';

  @override
  String get settingsServerHint => 'Alterá-lo termina a tua sessão.';

  @override
  String get settingsServerInvalid =>
      'O endereço tem de começar por http:// ou https://.';

  @override
  String get settingsServerHttpTitle => 'Ligação não encriptada?';

  @override
  String settingsServerHttpMessage(String host) {
    return '$host não é um servidor local. Com http://, a tua palavra-passe e os teus dados passam pela rede sem encriptação e outros podem lê-los. Usa https:// se o servidor o suportar.';
  }

  @override
  String get settingsServerHttpUse => 'Usar mesmo assim';

  @override
  String get bandLocal => 'Neste dispositivo';

  @override
  String get bandLocalHint => 'Só neste dispositivo, não sincronizado.';

  @override
  String get bandSwitch => 'Mudar de banda';

  @override
  String get bandManage => 'Gerir bandas';

  @override
  String get bandNone => 'Sem banda';

  @override
  String noBandInLibrary(String organization) {
    return 'Não estás em nenhuma banda de $organization. Os sets pertencem a uma banda: cria uma ou pede para seres adicionado.';
  }

  @override
  String get librarySwitch => 'Mudar de biblioteca de músicas';

  @override
  String get bandsTitle => 'Bandas';

  @override
  String get bandsEmpty =>
      'Ainda não estás numa banda. Cria uma banda para as tuas músicas e sets.';

  @override
  String get bandsSignInHint => 'Inicia sessão para criar bandas.';

  @override
  String get bandNew => 'Nova banda';

  @override
  String get bandName => 'Nome da banda';

  @override
  String get bandRoleAdmin => 'Admin';

  @override
  String get bandRoleMember => 'Membro';

  @override
  String get bandMembers => 'Membros';

  @override
  String bandYou(String name) {
    return '$name (tu)';
  }

  @override
  String get bandMakeAdmin => 'Tornar admin';

  @override
  String get bandMakeMember => 'Tornar membro';

  @override
  String get bandRoleLeader => 'Líder';

  @override
  String get bandRolePlanner => 'Planeador de sets';

  @override
  String get orgRoleLibrarian => 'Bibliotecário';

  @override
  String get bandMakeLeader => 'Tornar líder';

  @override
  String get bandMakePlanner => 'Tornar planeador de sets';

  @override
  String get orgMakeLibrarian => 'Tornar bibliotecário';

  @override
  String get orgLibrarianHint =>
      'Os bibliotecários criam, editam e eliminam as músicas da organização.';

  @override
  String get bandPlannerHint =>
      'Os planeadores de sets montam os sets da banda.';

  @override
  String get inviteBandHint =>
      'Cria um link válido durante 7 dias. Quem o abrir entra na organização e nesta banda como membro. Em Membros podes depois alterar o seu papel na banda.';

  @override
  String joinQuestionBand(String band, String org) {
    return 'Entrar em $band ($org)?';
  }

  @override
  String get joinExplanationBand =>
      'Tornas-te membro da organização e da banda e vês as suas músicas e sets.';

  @override
  String get bandRemoveMember => 'Remover da banda';

  @override
  String bandRemoveTitle(String name) {
    return 'Remover $name?';
  }

  @override
  String bandRemoveMessage(String name) {
    return '$name deixará de ver as músicas e os sets da banda.';
  }

  @override
  String get bandLeave => 'Sair da banda';

  @override
  String bandLeaveTitle(String band) {
    return 'Sair de $band?';
  }

  @override
  String get bandLeaveMessage =>
      'Deixarás de ver as músicas e os sets da banda. Um admin pode convidar-te novamente.';

  @override
  String get bandRefresh => 'Atualizar';

  @override
  String get bandErrorLastAdmin => 'Uma banda precisa de pelo menos um admin.';

  @override
  String get bandErrorNotAllowed => 'Não permitido, ou a banda já não existe.';

  @override
  String get accountErrorSignedOut => 'Inicia sessão.';

  @override
  String get copyToBand => 'Copiar para banda';

  @override
  String get copyToBandTitle => 'Copiar para que banda?';

  @override
  String get copyToBandNoTarget =>
      'Não há outra banda para onde possas copiar.';

  @override
  String copiedSongs(int count, String band) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas copiadas para $band',
      one: '1 música copiada para $band',
    );
    return '$_temp0';
  }

  @override
  String copiedSet(String band) {
    return 'Set copiado para $band';
  }

  @override
  String songsSelected(int count) {
    return '$count selecionadas';
  }

  @override
  String get selectAll => 'Selecionar tudo';

  @override
  String get selectMode => 'Selecionar';

  @override
  String get deleteSelected => 'Eliminar seleção';

  @override
  String deleteSongsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eliminar $count músicas?',
      one: 'Eliminar 1 música?',
    );
    return '$_temp0';
  }

  @override
  String deleteSongsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'As $count músicas selecionadas serão eliminadas e removidas de todos os sets.',
      one: 'A música selecionada será eliminada e removida de todos os sets.',
    );
    return '$_temp0 Podes restaurá-las a partir do lixo.';
  }

  @override
  String songsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas eliminadas',
      one: '1 música eliminada',
    );
    return '$_temp0';
  }

  @override
  String get bandRoleOrgAdmin => 'Admin da organização';

  @override
  String get bandOrganization => 'Organização';

  @override
  String get bandNewOrganization => 'Nova organização';

  @override
  String get bandNewHint =>
      'As bandas de uma organização partilham as suas músicas.';

  @override
  String get bandAddMember => 'Adicionar membro';

  @override
  String get bandAddMemberTitle => 'Adicionar quem?';

  @override
  String get bandAddMemberNone => 'Todos na organização já estão nesta banda.';

  @override
  String get bandOrgAdminHint => 'Geres esta banda como admin da organização.';

  @override
  String get bandErrorNotOrgMember =>
      'Esta pessoa não é membro da organização.';

  @override
  String get orgName => 'Nome da organização';

  @override
  String get orgPeople => 'Pessoas';

  @override
  String get orgBands => 'Bandas';

  @override
  String get orgRemove => 'Remover da organização';

  @override
  String orgRemoveTitle(String name) {
    return 'Remover $name?';
  }

  @override
  String orgRemoveMessage(String name) {
    return '$name sairá também de todas as bandas da organização e deixará de ver as suas músicas.';
  }

  @override
  String get orgLeave => 'Sair da organização';

  @override
  String orgLeaveTitle(String org) {
    return 'Sair de $org?';
  }

  @override
  String get orgLeaveMessage =>
      'Sairás também de todas as suas bandas e deixarás de ver as suas músicas.';

  @override
  String get orgSongsShared =>
      'Todas as bandas da organização partilham as mesmas músicas.';

  @override
  String get copyToLibraryTitle => 'Copiar para que biblioteca de músicas?';

  @override
  String get inviteCreate => 'Convidar pessoas';

  @override
  String get inviteCreateHint =>
      'Cria um link válido durante 7 dias. Quem o abrir entra na organização como membro, mas ainda em nenhuma banda. Depois adiciona-o a uma banda; em Pessoas podes alterar o seu papel.';

  @override
  String get inviteLinkTitle => 'Link de convite';

  @override
  String inviteLinkHint(String date) {
    return 'Partilha o link, p. ex. num chat de grupo, ou deixa que digitalizem o código QR. Válido até $date. Podes mostrá-lo novamente a partir da lista de links.';
  }

  @override
  String get inviteCopy => 'Copiar link';

  @override
  String get inviteCopied => 'Link copiado';

  @override
  String get invitesTitle => 'Links de convite';

  @override
  String inviteDates(String created, String expires) {
    return 'Criado a $created, válido até $expires';
  }

  @override
  String get inviteOrganizationOnly => 'Só organização';

  @override
  String get inviteShow => 'Mostrar link';

  @override
  String inviteJoined(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Entraram $count: $names',
      one: 'Entrou: $names',
      zero: 'Ainda ninguém entrou',
    );
    return '$_temp0';
  }

  @override
  String get inviteRevoke => 'Revogar';

  @override
  String get inviteRevokeTitle => 'Revogar o link?';

  @override
  String get inviteRevokeMessage =>
      'O link deixará de funcionar. Quem já entrou continua a ser membro.';

  @override
  String get inviteAskAdmin =>
      'Pede um convite a um admin da organização ou a um líder de banda.';

  @override
  String get inviteErrorUnknown => 'Este convite não existe. Verifica o link.';

  @override
  String get inviteErrorExpired => 'Este convite expirou. Pede um link novo.';

  @override
  String get inviteErrorRevoked =>
      'Este convite foi revogado. Pede um link novo.';

  @override
  String get joinTitle => 'Entrar';

  @override
  String get joinHint => 'Cola o link de convite que recebeste.';

  @override
  String get joinLink => 'Link de convite';

  @override
  String get joinContinue => 'Continuar';

  @override
  String get joinInvalidLink => 'Este não é um link de convite válido.';

  @override
  String get joinScan => 'Ler código QR';

  @override
  String get joinScanHint => 'Aponta a câmara para o código QR do convite';

  @override
  String get scannerClose => 'Fechar o leitor';

  @override
  String get scannerTorchOn => 'Ligar a luz';

  @override
  String get scannerTorchOff => 'Desligar a luz';

  @override
  String get scannerSwitchCamera => 'Trocar de câmara';

  @override
  String get scannerPickImage => 'Ler um código de uma foto';

  @override
  String get scannerStarting => 'A iniciar a câmara …';

  @override
  String get scannerPermissionTitle => 'Sem acesso à câmara';

  @override
  String get scannerPermissionMessage =>
      'Permite que o setDING use a câmara nas definições para ler códigos QR.';

  @override
  String get scannerUnavailableTitle => 'A câmara não está disponível';

  @override
  String get scannerUnavailableMessage =>
      'Talvez outra app a esteja a usar, ou este dispositivo não tem nenhuma.';

  @override
  String get scannerInUseMessage =>
      'Outra app está a usar a câmara. Fecha-a e tenta de novo.';

  @override
  String get scannerPhotoFallback => 'Também podes ler o código de uma foto.';

  @override
  String get scannerOpenSettings => 'Abrir definições';

  @override
  String get scannerTryAgain => 'Tentar de novo';

  @override
  String get scannerChoosePhoto => 'Escolher uma foto';

  @override
  String get scannerNoCodeInPhoto => 'Não há nenhum código nesta foto';

  @override
  String joinQuestion(String org) {
    return 'Entrar em $org?';
  }

  @override
  String get joinExplanation =>
      'Tornas-te membro da organização e vês as suas músicas. Um admin pode depois adicionar-te a uma banda.';

  @override
  String joinAlreadyMember(String org) {
    return 'Já és membro de $org.';
  }

  @override
  String get joinButton => 'Entrar';

  @override
  String joinDone(String org) {
    return 'Entraste em $org.';
  }

  @override
  String get joinSignInFirst => 'Inicia sessão ou cria uma conta para entrar.';

  @override
  String get joinHaveAccount => 'Já tenho uma conta';

  @override
  String get inviteErrorUsed => 'Este convite já foi usado. Pede um link novo.';

  @override
  String get inviteErrorNotStored =>
      'Este link não pode ser mostrado novamente. Cria um novo.';

  @override
  String get accountErrorInvitationRequired =>
      'Este servidor só aceita contas novas com um link de convite.';

  @override
  String get accountErrorEmailNotVerified =>
      'Confirma primeiro o teu endereço de e-mail. Enviámos-te um novo e-mail.';

  @override
  String get bandErrorFounderInvitationRequired =>
      'As organizações novas precisam de um convite de fundador do operador do servidor.';

  @override
  String get accountInviteOnlyHint =>
      'Neste servidor, as contas novas precisam de um link de convite.';

  @override
  String accountVerifyEmail(String email) {
    return 'Quase pronto: enviámos um e-mail para $email. Confirma o teu endereço com o link que contém e depois inicia sessão.';
  }

  @override
  String get accountVerifyResend => 'Enviar o e-mail novamente';

  @override
  String get accountVerifySent => 'E-mail enviado.';

  @override
  String joinFoundQuestion(String org) {
    return 'Fundar $org?';
  }

  @override
  String get joinFoundExplanation =>
      'Crias a organização e tornas-te o seu admin. Depois podes criar bandas e convidar pessoas.';

  @override
  String get joinFoundButton => 'Fundar organização';

  @override
  String joinFoundDone(String org) {
    return 'Fundaste $org.';
  }

  @override
  String get syncTitle => 'Sincronização';

  @override
  String get syncNow => 'Sincronizar agora';

  @override
  String get settingsSyncMode => 'Sincronização';

  @override
  String get syncModeAutomatic => 'Automática';

  @override
  String get syncModeOnStart => 'Ao iniciar';

  @override
  String get syncModeManual => 'Manual';

  @override
  String get syncModeAutomaticHint =>
      'Sincroniza ao iniciar, alguns segundos após alterações, quando algo muda no servidor e a cada 5 minutos.';

  @override
  String get syncModeOnStartHint =>
      'Sincroniza uma vez quando a app inicia e após iniciar sessão. Caso contrário, com \"Sincronizar agora\".';

  @override
  String get syncModeManualHint =>
      'Sincroniza só quando tocas em \"Sincronizar agora\".';

  @override
  String get syncRunning => 'A sincronizar …';

  @override
  String syncLast(String time) {
    return 'Última sincronização: $time';
  }

  @override
  String get syncNever => 'Ainda não sincronizado';

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alterações ainda não estão no servidor.',
      one: '1 alteração ainda não está no servidor.',
      zero: 'Todas as alterações estão no servidor.',
    );
    return '$_temp0';
  }

  @override
  String get syncOffline =>
      'Sem ligação – as alterações serão enviadas mais tarde.';

  @override
  String syncConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas com um conflito – abre-as para decidir.',
      one: '1 música com um conflito – abre-a para decidir.',
    );
    return '$_temp0';
  }

  @override
  String get conflictBanner =>
      'Esta música foi alterada no servidor e neste dispositivo.';

  @override
  String get conflictBannerDeleted =>
      'Esta música foi eliminada no servidor e alterada neste dispositivo.';

  @override
  String get conflictKeepMine => 'Manter a minha';

  @override
  String get conflictTakeServer => 'Usar a versão do servidor';

  @override
  String get conflictKeepBoth => 'Manter ambas';

  @override
  String get conflictCompare => 'Mostrar a versão do servidor';

  @override
  String get conflictServerVersion => 'Versão do servidor';

  @override
  String get conflictKeptBoth =>
      'A tua versão foi guardada como música separada.';

  @override
  String get accountErrorConflict =>
      'Entretanto, a música foi alterada no servidor.';

  @override
  String get pdfMissing =>
      'O PDF ainda não está neste dispositivo. Será transferido na próxima sincronização.';

  @override
  String get pdfLoadFailed =>
      'Não foi possível carregar o PDF do servidor. Verifica a ligação e abre a música novamente.';

  @override
  String get openAttachment => 'Abrir';

  @override
  String get imageMissing => 'A imagem não está neste dispositivo.';

  @override
  String syncMissingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anexos ainda estão a ser transferidos.',
      one: '1 anexo ainda está a ser transferido.',
    );
    return '$_temp0';
  }

  @override
  String get invalidChordProTitle => 'Verificar o ChordPro?';

  @override
  String get invalidChordProMessage =>
      'A música contém partes que provavelmente não serão mostradas como pretendido:';

  @override
  String problemUnclosedDirective(int line) {
    return 'Linha $line: uma chaveta (diretiva) não está fechada.';
  }

  @override
  String problemUnclosedChord(int line) {
    return 'Linha $line: um parêntese reto (acorde) não está fechado.';
  }

  @override
  String problemUnclosedEnvironment(int line) {
    return 'Linha $line: o bloco nunca é terminado e contém todo o resto da música.';
  }

  @override
  String problemTextAfterDirective(int line) {
    return 'Linha $line: texto depois de uma diretiva; a linha inteira é mostrada como letra.';
  }

  @override
  String problemInvalidKey(int line) {
    return 'Linha $line: a diretiva key não indica nenhum tom; a música não tem tom para transpor nem para as vistas de acordes.';
  }

  @override
  String chordProProblemsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count partes do ChordPro provavelmente não serão mostradas como pretendido',
      one:
          '1 parte do ChordPro provavelmente não será mostrada como pretendido',
    );
    return '$_temp0';
  }

  @override
  String chordProProblemsShow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrar os $count problemas de ChordPro',
      one: 'Mostrar o problema de ChordPro',
    );
    return '$_temp0';
  }

  @override
  String setChordProProblemsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas com problemas de ChordPro',
      one: '1 música com problemas de ChordPro',
    );
    return '$_temp0';
  }

  @override
  String get importProblemsTitle => 'Verificar a importação';

  @override
  String importProblemsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas importadas contêm partes',
      one: '1 música importada contém partes',
    );
    return '$_temp0 que provavelmente não serão mostradas como pretendido:';
  }

  @override
  String importProblemItem(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partes',
      one: '1 parte',
    );
    return '$title ($_temp0)';
  }

  @override
  String get importProblemsHint =>
      'As músicas estão marcadas na lista de músicas. A correção automática só altera as partes com uma reparação clara; corrige o resto no editor.';

  @override
  String songsFixed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas corrigidas',
      one: '1 música corrigida',
      zero: 'Nenhuma música corrigida',
    );
    return '$_temp0';
  }

  @override
  String moreProblems(int count) {
    return '… e mais $count.';
  }

  @override
  String get saveAnyway => 'Guardar mesmo assim';

  @override
  String get fixProblems => 'Corrigir automaticamente';

  @override
  String get keepEditing => 'Continuar a editar';

  @override
  String get webSignInHint =>
      'Inicia sessão para gerir organizações, bandas, músicas e sets no navegador.';

  @override
  String get webNoBandTitle => 'Ainda sem banda';

  @override
  String get webNoBandMessage =>
      'Ainda não estás numa banda. Cria uma organização com uma banda ou entra com um link de convite.';

  @override
  String get songDetails => 'Detalhes da música';

  @override
  String get songDetailsTooltip =>
      'Editar título, tom, tempo e mais da música – para todos';

  @override
  String get noKey => 'Sem tom';

  @override
  String get timeHint => 'p. ex. 4/4';

  @override
  String get noSequence => 'Sem sequência';

  @override
  String get sequenceChange => 'Alterar a sequência da música';

  @override
  String get sortSongs => 'Ordenar';

  @override
  String get sortByTitle => 'Título';

  @override
  String get sortByArtist => 'Artista';

  @override
  String get sortByKey => 'Tom';

  @override
  String get sortByRecent => 'Editadas recentemente';

  @override
  String get noArtist => 'Sem artista';

  @override
  String get songConflictTooltip =>
      'Alterada aqui e no servidor – abre a música para decidir';

  @override
  String get pdfOnlyTooltip => 'Só partitura (PDF), sem acordes';

  @override
  String upcomingGigTooltip(String set, String date) {
    return 'Em “$set” a $date';
  }

  @override
  String get foundInLyrics => 'Encontrado na letra';

  @override
  String hiddenParts(String parts) {
    return 'Ocultas (fora da sequência): $parts';
  }

  @override
  String get setsUpcoming => 'Próximos';

  @override
  String get setsUndated => 'Sem data';

  @override
  String setsPast(int count) {
    return 'Passados ($count)';
  }

  @override
  String get showPastSets => 'Mostrar sets passados';

  @override
  String get hidePastSets => 'Ocultar sets passados';

  @override
  String get nextGig => 'Próximo concerto';

  @override
  String gigInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Daqui a $days dias',
      one: 'Amanhã',
      zero: 'Hoje',
    );
    return '$_temp0';
  }

  @override
  String get undo => 'Anular';

  @override
  String songDeleted(String title) {
    return '“$title” eliminada';
  }

  @override
  String setDeleted(String name) {
    return 'Set “$name” eliminado';
  }

  @override
  String attachmentDeleted(String name) {
    return 'Anexo “$name” eliminado';
  }

  @override
  String setItemRemoved(String title) {
    return '“$title” removida do set';
  }

  @override
  String get settingsGroupPersonal => 'Pessoal – em todos os teus dispositivos';

  @override
  String get settingsGroupDevice => 'Este dispositivo';

  @override
  String get settingsGroupAccount => 'Conta e organização';

  @override
  String get settingsScopePersonalHint =>
      'Estas definições pertencem à tua conta e aplicam-se em todos os dispositivos em que tens sessão iniciada.';

  @override
  String get settingsScopePersonalSignedOutHint =>
      'Sem sessão iniciada, estas definições aplicam-se só neste dispositivo. Depois de iniciares sessão, são sincronizadas com a tua conta.';

  @override
  String get settingsScopeDeviceHint =>
      'Estas definições aplicam-se só neste dispositivo e não são sincronizadas.';

  @override
  String get settingsTakenOver => 'As definições da tua conta foram aplicadas.';

  @override
  String get annotationsDraw => 'Desenhar anotações';

  @override
  String get annotationsShow => 'Mostrar anotações';

  @override
  String get annotationsHide => 'Ocultar anotações';

  @override
  String get annotationPen => 'Caneta';

  @override
  String get annotationHighlighter => 'Marcador';

  @override
  String get annotationText => 'Texto';

  @override
  String get annotationTextHint => 'Escreve um texto';

  @override
  String get annotationEraser => 'Borracha (traço inteiro)';

  @override
  String get annotationPartialEraser => 'Borracha (parte de um traço)';

  @override
  String get annotationLasso => 'Selecionar (laço)';

  @override
  String get annotationStamps => 'Carimbos';

  @override
  String get annotationStampsMusic => 'Sinais musicais';

  @override
  String get annotationStampsRepeats => 'Repetições';

  @override
  String get annotationStampsCues => 'Sinais';

  @override
  String annotationColor(Object number) {
    return 'Cor $number';
  }

  @override
  String get annotationSize => 'Espessura da linha';

  @override
  String get annotationSmaller => 'Mais pequeno';

  @override
  String get annotationLarger => 'Maior';

  @override
  String get annotationDeleteSelection => 'Eliminar seleção';

  @override
  String get annotationUndo => 'Anular';

  @override
  String get annotationRedo => 'Refazer';

  @override
  String get annotationMore => 'Mais';

  @override
  String get annotationDrawWithFinger => 'Desenhar com o dedo';

  @override
  String get annotationDone => 'Concluído';

  @override
  String get annotationsDeleteAll => 'Eliminar todas as anotações desta música';

  @override
  String get annotationsDeleted => 'Anotações eliminadas';

  @override
  String get annotationsOtherLayout => 'Desenhadas para outra vista';

  @override
  String get annotationsOtherLayoutLandscape => 'Desenhadas na horizontal';

  @override
  String get annotationsOtherLayoutPortrait => 'Desenhadas na vertical';

  @override
  String annotationsOrphaned(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anotações sem a sua linha',
      one: '1 anotação sem a sua linha',
    );
    return '$_temp0';
  }

  @override
  String get annotationsFull =>
      'Anotações cheias: apaga algumas para desenhar mais';

  @override
  String annotationsNearlyFull(int percent) {
    return 'Anotações a $percent %';
  }

  @override
  String get annotationsPanelTitle => 'Anotações à mão livre';

  @override
  String get annotationsPanelShow => 'Mostrar as minhas anotações';

  @override
  String annotationsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anotações',
      one: '1 anotação',
      zero: 'Ainda nenhuma: desenha-as no modo ao vivo',
    );
    return '$_temp0';
  }

  @override
  String get settingsShowAnnotations => 'Mostrar anotações à mão livre';

  @override
  String get settingsShowAnnotationsHint =>
      'Os teus próprios desenhos em músicas e partituras';

  @override
  String get settingsRepeatedChorusOnce =>
      'Mostrar só uma vez um refrão escrito por extenso';

  @override
  String get settingsRepeatedChorusOnceHint =>
      'Um refrão escrito de novo mais à frente, palavra por palavra, é omitido';

  @override
  String get settingsShowOutsideSequence => 'Mostrar partes fora da sequência';

  @override
  String get settingsShowOutsideSequenceHint =>
      'Esbatidas no modo ao vivo em vez de ocultas';

  @override
  String get settingsAnnotationFinger => 'Desenhar anotações com o dedo';

  @override
  String get settingsAnnotationFingerHint =>
      'Para dispositivos sem caneta; caso contrário, os dedos continuam a virar páginas';

  @override
  String get settingsSpaceStartsBeat => 'Espaço inicia a pulsação';

  @override
  String get settingsSpaceStartsBeatHint =>
      'Espaço inicia e para a pulsação e o clique como Enter, em vez de avançar';

  @override
  String get stampFermata => 'Fermata';

  @override
  String get stampBreath => 'Respiração';

  @override
  String get stampCrescendo => 'Crescendo';

  @override
  String get stampDecrescendo => 'Decrescendo';

  @override
  String get stampRitardando => 'Ritardando';

  @override
  String get stampAccent => 'Acento';

  @override
  String stampRepeat(Object times) {
    return 'Tocar $times×';
  }

  @override
  String get stampRepeatStart => 'Início da repetição';

  @override
  String get stampRepeatEnd => 'Fim da repetição';

  @override
  String get stampCoda => 'Coda';

  @override
  String get stampSegno => 'Segno';

  @override
  String get stampGlasses => 'Atenção';

  @override
  String get stampStop => 'Parar';

  @override
  String get stampEye => 'Olhar';

  @override
  String get stampExclamation => 'Importante';

  @override
  String get stampStar => 'Estrela';

  @override
  String get settingsSectionBands => 'Organização e bandas';

  @override
  String get settingsCategoryBandsHint =>
      'Organizações, bandas, membros e convites';

  @override
  String get settingsBandsJoinHint =>
      'Entra numa organização ou banda com um link de convite.';

  @override
  String get settingsSectionSongDisplay => 'Visualização das músicas';

  @override
  String get settingsCategorySongDisplayHint =>
      'Estilos por secção: acordes, letra, títulos, barras';

  @override
  String get songDisplayPreview => 'Pré-visualização';

  @override
  String get songDisplayPreset => 'Predefinição';

  @override
  String get songDisplayPresetClassic => 'Clássico';

  @override
  String get songDisplayPresetColorCoded => 'Por cores';

  @override
  String get songDisplayPresetChorusFocus => 'Foco no refrão';

  @override
  String get songDisplayPresetSinger => 'Voz';

  @override
  String get songDisplayPresetGuitar => 'Guitarra';

  @override
  String get songDisplayPresetMinimal => 'Mínimo';

  @override
  String get songDisplayPresetBlackWhite => 'Preto/branco';

  @override
  String get songDisplayPresetCustom => 'Personalizado';

  @override
  String get songDisplayDiscardTitle => 'Descartar os estilos personalizados?';

  @override
  String songDisplayDiscardMessage(String name) {
    return 'A predefinição “$name” substitui os teus estilos personalizados.';
  }

  @override
  String get songDisplayDiscard => 'Descartar';

  @override
  String get songDisplayFont => 'Tipo de letra';

  @override
  String get songDisplayFontStandard => 'Padrão';

  @override
  String get songDisplayFontMonospace => 'Monoespaçado';

  @override
  String get songDisplaySection => 'Secção';

  @override
  String get songDisplayTypeStandard => 'Padrão';

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
      'Estilo base para cada secção sem estilo próprio e para secções não reconhecidas (p. ex. tabs, grelhas, nomes personalizados).';

  @override
  String get songDisplayStyle => 'Estilo';

  @override
  String get songDisplayOwnStyle => 'Estilo próprio';

  @override
  String songDisplayLike(String name) {
    return 'Como $name';
  }

  @override
  String songDisplayInheritsHint(String chain) {
    return 'Herda tudo de: $chain. As alterações aí também se aplicam aqui.';
  }

  @override
  String get songDisplayChords => 'Acordes';

  @override
  String get songDisplayLyrics => 'Letra';

  @override
  String get songDisplayHeading => 'Título';

  @override
  String get songDisplayBar => 'Barra de avanço';

  @override
  String get songDisplayBold => 'Negrito';

  @override
  String get songDisplayItalic => 'Itálico';

  @override
  String get songDisplaySize => 'Tamanho';

  @override
  String get songDisplayColor => 'Cor';

  @override
  String get songDisplayShowHeading => 'Mostrar título';

  @override
  String get songDisplayShowBar => 'Mostrar barra';

  @override
  String get songDisplayBarWidth => 'Largura';

  @override
  String get songDisplayIndent => 'Avanço';

  @override
  String get songDisplayTint => 'Colorir o fundo';

  @override
  String get songDisplaySizeSmall => 'S';

  @override
  String get songDisplaySizeMedium => 'M';

  @override
  String get songDisplaySizeLarge => 'L';

  @override
  String get songDisplaySizeExtraLarge => 'XL';

  @override
  String get songDisplayBarThin => 'Fina';

  @override
  String get songDisplayBarMedium => 'Média';

  @override
  String get songDisplayBarWide => 'Larga';

  @override
  String get songDisplayIndentNone => 'Nenhum';

  @override
  String get songDisplayIndentNormal => 'Normal';

  @override
  String get songDisplayIndentLarge => 'Grande';

  @override
  String get songColorAuto => 'Automático';

  @override
  String get songColorBlue => 'Azul';

  @override
  String get songColorAmber => 'Âmbar';

  @override
  String get songColorRed => 'Vermelho';

  @override
  String get songColorGreen => 'Verde';

  @override
  String get songColorTeal => 'Verde-azulado';

  @override
  String get songColorPurple => 'Roxo';

  @override
  String get songColorPink => 'Rosa';

  @override
  String get songColorGrey => 'Cinzento';

  @override
  String get songColorBlackWhite => 'Preto/branco';

  @override
  String get songDisplayCustomise => 'Personalizar a visualização';

  @override
  String get songDisplayCustomiseHint =>
      'Acordes, letra, títulos, barras e cores';

  @override
  String get songDisplayEditorTitle =>
      'Personalizar a visualização das músicas';

  @override
  String get songDisplayDemoSong => 'Música de demonstração';

  @override
  String get songDisplayLibrarySong => 'Música da biblioteca …';

  @override
  String get songDisplayPickSong => 'Música para a pré-visualização';

  @override
  String get songDisplayResizePreview =>
      'Arrasta para redimensionar a pré-visualização';

  @override
  String get appUpdateInstall => 'Instalar';

  @override
  String appUpdateInstallTitle(String version) {
    return 'Instalar o setDING $version?';
  }

  @override
  String get appUpdateInstallBody =>
      'O setDING fecha, instala a nova versão e reinicia. Os teus dados ficam neste dispositivo.';

  @override
  String get appUpdateDownloading => 'A transferir a atualização …';

  @override
  String get appUpdateFailed =>
      'Não foi possível instalar a atualização. Tenta novamente mais tarde.';

  @override
  String get whatsNewTitle => 'Novidades';

  @override
  String whatsNewAvailable(String version) {
    return 'Novidades no setDING $version';
  }

  @override
  String get whatsNewShow => 'Mostrar';

  @override
  String whatsNewVersion(String version) {
    return 'Versão $version';
  }

  @override
  String get whatsNewAllChanges => 'Todas as alterações';

  @override
  String get midiTestTitle => 'Teste MIDI (protótipo)';

  @override
  String get midiTestTileHint =>
      'Enviar um program change para um teclado ligado por USB, p. ex. um Nord Stage 3';

  @override
  String get midiTestHint =>
      'Envia um program change para um teclado ligado por USB, para testar o MIDI neste dispositivo. O que o teclado envia, p. ex. quando escolhes nele um programa ou um song, aparece no registo.';

  @override
  String get midiTestDevices => 'Dispositivos';

  @override
  String get midiTestRefresh => 'Procurar novamente';

  @override
  String get midiTestNoDevices =>
      'Nenhum dispositivo MIDI encontrado. Liga o teclado por USB e procura novamente.';

  @override
  String get midiTestConnect => 'Ligar';

  @override
  String get midiTestDisconnect => 'Desligar';

  @override
  String get midiTestConnected => 'Ligado';

  @override
  String get midiTestChannel => 'Canal MIDI';

  @override
  String get midiTestModeNordProgram => 'Programa Nord';

  @override
  String get midiTestModeNordSong => 'Song Nord';

  @override
  String get midiTestModeNordLive => 'Live Nord';

  @override
  String get midiTestModeRaw => 'Valores em bruto';

  @override
  String get midiTestBank => 'Banco';

  @override
  String get midiTestLive => 'Memória live';

  @override
  String get midiTestMsb => 'Bank select MSB (CC 0, 0–127)';

  @override
  String get midiTestLsb => 'Bank select LSB (CC 32, 0–127)';

  @override
  String get midiTestProgram => 'Programa (1–128)';

  @override
  String get midiTestEmptyNotSent => 'Um bank select vazio não é enviado.';

  @override
  String get midiTestInvalid => 'Verifica os valores';

  @override
  String get midiTestSend => 'Enviar';

  @override
  String get midiTestLog => 'Registo';

  @override
  String get midiTestCopy => 'Copiar registo';

  @override
  String get midiTestCopied => 'Registo copiado';

  @override
  String get midiTestClear => 'Limpar registo';

  @override
  String midiTestSent(String bytes) {
    return 'Enviado: $bytes';
  }

  @override
  String midiTestReceivedCc(
    int controller,
    int value,
    int channel,
    String bytes,
  ) {
    return 'Recebido: CC $controller = $value (canal $channel) – $bytes';
  }

  @override
  String midiTestReceivedPc(
    int number,
    int program,
    int channel,
    String bytes,
  ) {
    return 'Recebido: program change $number (valor $program, canal $channel) – $bytes';
  }

  @override
  String midiTestReceivedOther(String bytes) {
    return 'Recebido: $bytes';
  }

  @override
  String midiTestError(String message) {
    return 'Erro: $message';
  }

  @override
  String get midiTestModeCc => 'Control change';

  @override
  String get midiTestController => 'Controlador (CC 0–127)';

  @override
  String get midiTestValue => 'Valor (0–127)';

  @override
  String get midiTestCcHint =>
      'Nord Stage 3 segundo o midi.guide: CC 2 modo live, CC 3 modo song, CC 5 parte do song. Que valores fazem o quê faz parte do teste.';

  @override
  String get midiGuideTitle => 'Teste guiado';

  @override
  String get midiGuideHint =>
      'Toca em “Enviar”, olha para o ecrã do Nord e toca no que aconteceu. Não é preciso definir nada no Nord. As respostas ficam guardadas no registo.';

  @override
  String get midiGuideNordSend => 'Nord Stage 3 – enviar';

  @override
  String get midiGuideNordReceive => 'Nord Stage 3 – receber';

  @override
  String get midiGuideMotifSend => 'Motif XF – enviar';

  @override
  String get midiGuideMotifReceive => 'Motif XF – receber';

  @override
  String get midiGuideNordReceiveHint =>
      'No Nord, define “Program Change” como “Send” ou “Send & Receive” no menu MIDI, e define aqui o canal para o canal global do Nord. Depois escolhe no Nord qualquer programa, live memory ou parte de song, p. ex. com o botão rotativo ou os botões de modo. O setDING mostra o que chegou; toca se corresponde ao ecrã. Os resultados ficam guardados no registo.';

  @override
  String get midiGuideMotifSendHint =>
      'No Motif XF, em Utility → Control (F5) → MIDI (SF2): define MIDI IN/OUT como USB, ativa a receção de bank select e program change, define o Basic Receive Channel para o canal daqui e o Device Number para “all” ou 1, e guarda com Store. Toca em “Enviar”, olha para o ecrã do Motif e toca no que aconteceu. As respostas ficam guardadas no registo.';

  @override
  String get midiGuideMotifReceiveHint =>
      'No Motif XF, em Utility → Control (F5) → MIDI (SF2): define MIDI IN/OUT como USB, ativa o envio de bank select e program change e define o Transmit Channel para o canal daqui, e guarda com Store. Depois escolhe no Motif qualquer voice ou performance, também em bancos diferentes e duas vezes no mesmo banco. O setDING mostra o que chegou; toca se corresponde ao ecrã. Os resultados ficam guardados no registo.';

  @override
  String midiGuideMotifExpected(String name) {
    return 'O Motif mostra $name.';
  }

  @override
  String get midiGuideWaiting => 'Escolhe um som no teclado …';

  @override
  String midiGuideFreeReceived(String name) {
    return 'Recebido: $name';
  }

  @override
  String get midiGuideMatches => 'Corresponde ao ecrã';

  @override
  String get midiGuideNoMatch => 'Não corresponde';

  @override
  String midiGuideFreeResult(String name, String values, String answer) {
    return 'Recebido $name ($values): $answer';
  }

  @override
  String midiGuideChecked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sons verificados',
      one: '1 som verificado',
      zero: 'Ainda nada verificado',
    );
    return '$_temp0';
  }

  @override
  String midiGuideStep(int current, int total, String title) {
    return 'Passo $current de $total: $title';
  }

  @override
  String midiGuideExpected(String expected) {
    return 'Esperado: $expected';
  }

  @override
  String get midiGuideDone => 'Teste terminado. As respostas estão no registo.';

  @override
  String get midiGuideRestart => 'Recomeçar';

  @override
  String get midiGuideBack => 'Voltar';

  @override
  String get midiGuideSkip => 'Saltar';

  @override
  String midiGuideResult(int current, String title, String answer) {
    return 'Passo $current ($title): $answer';
  }

  @override
  String midiGuideProgram(String name) {
    return 'Programa $name';
  }

  @override
  String midiGuideProgramExpected(String name) {
    return 'O Nord mostra $name.';
  }

  @override
  String midiGuideLive(int number) {
    return 'Live memory $number';
  }

  @override
  String midiGuideLiveExpected(int number) {
    return 'O Nord mostra Live $number.';
  }

  @override
  String get midiGuideSongModeOn => 'Modo song ligado (CC 3 = 127)';

  @override
  String get midiGuideSongModeOnExpected => 'O Nord passa para o modo song.';

  @override
  String get midiGuideSongModeOff => 'Modo song desligado (CC 3 = 0)';

  @override
  String get midiGuideSongModeOffExpected => 'O Nord sai do modo song.';

  @override
  String get midiGuideAnswerAsExpected => 'Como esperado';

  @override
  String get midiGuideAnswerDifferent => 'Outra coisa';

  @override
  String get midiGuideAnswerNothing => 'Não aconteceu nada';

  @override
  String get midiTestFree => 'Envio livre';

  @override
  String get midiTestPage => 'Página';

  @override
  String get midiTestButton => 'Botão';

  @override
  String midiGuideSong(int song, int part) {
    return 'Song $song, parte $part';
  }

  @override
  String midiGuideSongExpected(int song, int part) {
    return 'O Nord mostra o song $song, parte $part.';
  }

  @override
  String get midiTestSong => 'Song';

  @override
  String get midiTestPart => 'Parte';

  @override
  String get settingsEditorTypingAids =>
      'Fechar parênteses e secções automaticamente';

  @override
  String get settingsEditorTypingAidsHint =>
      'No editor ChordPro: [ acrescenta ], Enter depois do início de uma secção acrescenta o seu fim, e mudar o nome do início de uma secção muda também o do seu fim.';

  @override
  String get settingsDeveloperMode => 'Modo de programador';

  @override
  String get settingsDeveloperModeHint =>
      'Mostra a categoria “Desenvolvimento” com funções experimentais para testar. Não é necessário para o uso normal.';

  @override
  String get settingsGroupDevelopment => 'Desenvolvimento';

  @override
  String get settingsSectionDevelopment => 'Funções de teste';

  @override
  String get settingsCategoryDevelopmentHint => 'Experimental, só para testes';

  @override
  String get settingsDevelopmentNoteTitle => 'Funções experimentais';

  @override
  String get settingsDevelopmentNote =>
      'Estas funções são para testes. Podem mudar, ter erros ou desaparecer novamente. Não se destinam a atuações. Oculta-as com “Modo de programador” em Geral.';

  @override
  String get settingsSectionMidi => 'Teclado (MIDI)';

  @override
  String get settingsCategoryMidiHint =>
      'Program changes para um teclado ligado por USB';

  @override
  String get settingsMidiEnabled => 'Program changes MIDI';

  @override
  String get settingsMidiEnabledHint =>
      'No modo ao vivo, o teclado muda para o programa guardado para cada música.';

  @override
  String settingsMidiConnected(String name) {
    return 'Ligado a $name';
  }

  @override
  String get settingsMidiNotConnected => 'Não ligado';

  @override
  String get settingsMidiOutput => 'Saída';

  @override
  String get settingsMidiOutputHint =>
      'O teclado ligado por USB. O setDING volta a ligar-se sozinho quando é ligado.';

  @override
  String get settingsMidiNoDevices =>
      'Nenhum dispositivo MIDI encontrado. Liga o teclado por USB e procura novamente.';

  @override
  String get settingsMidiSearch => 'Procurar novamente';

  @override
  String settingsMidiOutputMissing(String name) {
    return '$name (não ligado)';
  }

  @override
  String get settingsMidiProfile => 'Perfil do dispositivo';

  @override
  String get settingsMidiProfileHint =>
      'Como os programas do teclado são introduzidos e mostrados. “Genérico” usa bank select e número de programa e funciona com qualquer teclado.';

  @override
  String get midiProfileNordStage3 => 'Nord Stage 3';

  @override
  String get midiProfileGeneric => 'Genérico';

  @override
  String get settingsMidiChannel => 'Canal MIDI';

  @override
  String get settingsMidiChannelHint => 'O canal em que o teclado recebe.';

  @override
  String get settingsMidiTakeOver => 'Adotar programas do teclado';

  @override
  String get settingsMidiTakeOverHint =>
      'Enquanto o programa do teclado está aberto no modo ao vivo, o setDING mostra o som que escolhes no teclado e, se quiseres, adota-o na música. O teclado tem de enviar bank select e program change.';

  @override
  String get settingsMidiTakeOverNordHint =>
      'Enquanto o programa do teclado está aberto no modo ao vivo, o setDING mostra o som que escolhes no Nord e, se quiseres, adota-o na música. No Nord, define “Program Change” como “Send” ou “Send & Receive” no menu MIDI.';

  @override
  String get settingsMidiNordHint =>
      'No Nord Stage 3, ativa a receção de “Program Change” no seu menu MIDI, e define aqui o canal para o canal global do Nord. A numeração dos songs do Nord depende da versão do SO do Nord (verificada com o SO 2.54); se um song não corresponder, usa o perfil “Genérico”.';

  @override
  String get midiProgramTitle => 'Programa do teclado';

  @override
  String get midiProgramHint =>
      'Enviado para o teclado no modo ao vivo quando esta música chega.';

  @override
  String get midiProgramNone => 'Nenhum: o teclado mantém o seu som';

  @override
  String get midiProgramChoose => 'Escolher programa';

  @override
  String get midiProgramPreviewSwitch => 'Enviar ao selecionar';

  @override
  String get midiProgramPreviewHint =>
      'Cada escolha vai logo para o teclado; Cancelar repõe o programa anterior.';

  @override
  String get midiProgramRemove => 'Remover programa';

  @override
  String get midiProgramTest => 'Testar';

  @override
  String get midiProgramTestHint => 'Envia o programa para o teclado uma vez';

  @override
  String get midiProgramNotConnected => 'Teclado não ligado';

  @override
  String get midiProgramOff =>
      'Os program changes MIDI estão desligados neste dispositivo (definições: Teclado (MIDI)).';

  @override
  String midiProgramSent(String device) {
    return 'Enviado para $device';
  }

  @override
  String get midiProgramSendFailed => 'Não foi possível enviar o programa';

  @override
  String get midiProgramKindProgram => 'Programa';

  @override
  String get midiProgramKindLive => 'Live memory';

  @override
  String get midiProgramKindSong => 'Song';

  @override
  String get midiProgramKindGeneric => 'Outros valores';

  @override
  String get midiProgramBank => 'Banco';

  @override
  String get midiProgramPageButton => 'Página (fila) e botão';

  @override
  String get midiProgramSongNumber => 'Song';

  @override
  String get midiProgramPreviousSong => 'Song anterior';

  @override
  String get midiProgramNextSong => 'Song seguinte';

  @override
  String get midiProgramPart => 'Parte';

  @override
  String get midiProgramSongHint =>
      'A numeração dos songs do Nord depende da versão do SO do Nord (verificada com o SO 2.54). Se um song não corresponder, usa o perfil “Genérico” nas definições.';

  @override
  String get midiProgramsTitle => 'Programas do teclado';

  @override
  String midiProgramDevice(String profile) {
    return 'Este dispositivo: $profile';
  }

  @override
  String get midiProgramForOtherKeyboard => 'Programa para outro teclado';

  @override
  String midiProgramUnknownKeyboard(String id) {
    return 'Teclado desconhecido ($id)';
  }

  @override
  String get midiProgramMsb => 'Bank select MSB (opcional)';

  @override
  String get midiProgramLsb => 'Bank select LSB (opcional)';

  @override
  String get midiProgramNumber => 'Programa';

  @override
  String midiProgramRange(int min, int max) {
    return '$min–$max';
  }

  @override
  String midiProgramOutOfRange(int min, int max) {
    return 'Introduz um número de $min a $max';
  }

  @override
  String midiProgramValueNord(String name) {
    return 'Programa $name';
  }

  @override
  String get midiProfileMotifXf => 'Yamaha Motif XF';

  @override
  String get settingsMidiMotifHint =>
      'No Motif XF, em Utility → Control (F5) → MIDI (SF2): define MIDI IN/OUT como USB, ativa a receção de Bank Select e Program Change, define o Basic Receive Channel para o canal daqui e o Device Number para “all” ou 1, e guarda com Store. O setDING muda o Motif para o modo voice ou performance sozinho antes de cada programa.';

  @override
  String get midiProgramKindPerformance => 'Performance';

  @override
  String get midiProgramKindVoice => 'Voice';

  @override
  String get midiProgramGroup => 'Grupo';

  @override
  String get midiProgramMotifNumber => 'Número';

  @override
  String get midiProgramMotifHint =>
      'Como no ecrã do Motif XF, p. ex. USR1 A01. O setDING muda o Motif para o modo voice ou performance antes de enviar.';

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
    return 'Song $song, parte $part';
  }

  @override
  String midiProgramValueGeneric(int program) {
    return 'Programa $program';
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
  String get trash => 'Lixo';

  @override
  String trashWithCount(int count) {
    return 'Lixo ($count)';
  }

  @override
  String get trashSongsTitle => 'Músicas eliminadas';

  @override
  String get trashSetsTitle => 'Sets eliminados';

  @override
  String trashEmpty(int days) {
    return 'O lixo está vazio. As músicas e os sets eliminados podem ser restaurados aqui durante $days dias.';
  }

  @override
  String trashHint(int days) {
    return 'As músicas e os sets eliminados podem ser restaurados durante $days dias. Depois disso, são removidos definitivamente.';
  }

  @override
  String trashDeletedOn(String date) {
    return 'eliminado a $date';
  }

  @override
  String trashDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'faltam $days dias',
      one: 'falta 1 dia',
      zero: 'último dia',
    );
    return '$_temp0';
  }

  @override
  String get trashRestore => 'Restaurar';

  @override
  String trashRestored(String title) {
    return '\"$title\" restaurado';
  }

  @override
  String get trashGroupToday => 'Hoje';

  @override
  String get trashGroupWeek => 'Esta semana';

  @override
  String get trashGroupOlder => 'Mais antigos';

  @override
  String trashMenu(String title) {
    return 'Ações para \"$title\"';
  }

  @override
  String get trashPurge => 'Eliminar definitivamente';

  @override
  String get trashPurgeTitle => 'Eliminar definitivamente?';

  @override
  String trashPurgeOne(String title) {
    return '\"$title\" será eliminado definitivamente. Não é possível anular.';
  }

  @override
  String trashPurgeMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos serão eliminados',
      one: '1 elemento será eliminado',
    );
    return '$_temp0 definitivamente. Não é possível anular.';
  }

  @override
  String get trashEmptyAction => 'Esvaziar o lixo';

  @override
  String get trashEmptyTitle => 'Esvaziar o lixo?';

  @override
  String trashPurged(String title) {
    return '\"$title\" eliminado definitivamente';
  }

  @override
  String trashPurgedMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos eliminados',
      one: '1 elemento eliminado',
    );
    return '$_temp0 definitivamente';
  }

  @override
  String trashRestoredMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos restaurados',
      one: '1 elemento restaurado',
    );
    return '$_temp0';
  }

  @override
  String get backupExport => 'Fazer cópia da biblioteca';

  @override
  String get backupSyncing => 'A sincronizar com o servidor …';

  @override
  String get backupCollecting => 'A criar a cópia de segurança …';

  @override
  String get backupSaved => 'Cópia de segurança guardada.';

  @override
  String get backupFailedTitle => 'Cópia de segurança impossível';

  @override
  String get backupSyncDeferred =>
      'O modo ao vivo está aberto. Fecha-o e tenta novamente.';

  @override
  String get backupSyncFailed =>
      'A sincronização com o servidor falhou. A cópia de segurança de uma organização precisa de uma ligação funcional, para conter tudo. Tenta novamente quando estiveres online.';

  @override
  String get backupPendingChanges =>
      'Há alterações neste dispositivo que ainda não chegaram ao servidor. Espera pela sincronização e tenta novamente.';

  @override
  String get backupConflicts =>
      'Algumas músicas têm um conflito de sincronização. Resolve primeiro os conflitos.';

  @override
  String get backupMissingFiles =>
      'Ainda não foram transferidos todos os anexos. Espera pela transferência e tenta novamente.';

  @override
  String backupFileMissing(String name, String song) {
    return 'Não foi possível carregar o anexo \"$name\" de \"$song\".';
  }

  @override
  String get backupInvalid =>
      'Este ficheiro não é uma cópia de segurança do setDING.';

  @override
  String get backupNewer =>
      'Esta cópia de segurança foi feita com uma versão mais recente do setDING. Atualiza a app para a importar.';

  @override
  String get backupImportTitle => 'Importar cópia de segurança';

  @override
  String backupImportSummary(String library, int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs músicas',
      one: '1 música',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'Cópia de segurança de \"$library\": $_temp0, $_temp1.';
  }

  @override
  String get backupImportCopyHint =>
      'Tudo é importado como cópia para a biblioteca atual. Nada existente é alterado.';

  @override
  String backupImportIdentical(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas já estão',
      one: '1 música já está',
    );
    return '$_temp0 aqui com o mesmo texto e serão usadas tal como estão.';
  }

  @override
  String backupImportDiffering(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas existem',
      one: '1 música existe',
    );
    return '$_temp0 aqui com um texto diferente:';
  }

  @override
  String get backupKeepExisting => 'Manter as músicas existentes';

  @override
  String get backupAddAll => 'Importar como músicas adicionais';

  @override
  String get backupImportSetsTo => 'Os sets vão para:';

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
  String get backupSkipSets => 'Não importar';

  @override
  String get backupImportStart => 'Importar';

  @override
  String get backupImportDone => 'Cópia de segurança importada';

  @override
  String backupResultSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas importadas',
      one: '1 música importada',
    );
    return '$_temp0';
  }

  @override
  String backupResultIdentical(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas já estavam aqui',
      one: '1 música já estava aqui',
    );
    return '$_temp0';
  }

  @override
  String backupResultKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas existentes mantidas',
      one: '1 música existente mantida',
    );
    return '$_temp0';
  }

  @override
  String backupResultSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets importados',
      one: '1 set importado',
      zero: 'Nenhum set importado',
    );
    return '$_temp0';
  }

  @override
  String backupResultFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anexos',
      one: '1 anexo',
    );
    return '$_temp0';
  }

  @override
  String backupResultAdditional(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Estas músicas existem agora duas vezes. Compara-as com as existentes e elimina as que não precisas:',
      one: 'Esta música existe agora duas vezes. Compara-a com a existente e elimina a que não precisas:',
    );
    return '$_temp0';
  }

  @override
  String get bandDelete => 'Eliminar banda';

  @override
  String bandDeleteTitle(String band) {
    return 'Eliminar $band?';
  }

  @override
  String bandDeleteMessage(int days) {
    return 'Os seus sets, arranjos de banda e participações são eliminados com ela, e os seus convites abertos são revogados. As músicas ficam na biblioteca da organização. Os admins da organização podem restaurar a banda a partir do lixo durante $days dias. Para guardar uma cópia fora do setDING, faz primeiro uma cópia da biblioteca.';
  }

  @override
  String bandDeleteSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
      zero: 'nenhum set',
    );
    return '$_temp0';
  }

  @override
  String bandDeleteMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membros',
      one: '1 membro',
      zero: 'nenhum membro',
    );
    return '$_temp0';
  }

  @override
  String bandDeleteInvites(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count convites abertos',
      one: '1 convite aberto',
      zero: 'nenhum convite aberto',
    );
    return '$_temp0';
  }

  @override
  String get bandDeleteLastBand =>
      'Esta é a última banda da organização. A organização e a sua biblioteca de músicas mantêm-se.';

  @override
  String bandDeleteConfirmName(String band) {
    return 'Escreve \"$band\" para confirmar';
  }

  @override
  String bandDeleted(String band) {
    return '$band eliminada';
  }

  @override
  String get trashBandsTitle => 'Bandas eliminadas';

  @override
  String trashBandsEmpty(int days) {
    return 'Nenhuma banda eliminada. As bandas eliminadas podem ser restauradas aqui durante $days dias.';
  }

  @override
  String trashBandsHint(int days) {
    return 'As bandas eliminadas podem ser restauradas com os seus sets, arranjos e membros durante $days dias. Depois disso, são removidas definitivamente.';
  }

  @override
  String bandsGone(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$names já não estão disponíveis para ti: as bandas foram eliminadas ou já não és membro.',
      one:
          '$names já não está disponível para ti: a banda foi eliminada ou já não és membro.',
    );
    return '$_temp0';
  }

  @override
  String get backupAll => 'Fazer cópia de tudo';

  @override
  String get backupAllName => 'tudo';

  @override
  String get backupAllHint =>
      'As tuas bibliotecas com músicas, sets e anexos, os teus ajustes pessoais e notas, e as tuas definições, num só ficheiro.';

  @override
  String get backupNever => 'Ainda sem cópia de segurança neste dispositivo.';

  @override
  String backupLast(String date) {
    return 'Última cópia de segurança: $date';
  }

  @override
  String get backupRestore => 'Restaurar cópia de segurança';

  @override
  String get backupRestoreHint =>
      'Importa um ficheiro de cópia de segurança como cópia, ou substitui a biblioteca “Neste dispositivo” pela sua cópia de segurança.';

  @override
  String get backupRestoreTitle => 'Restaurar cópia de segurança';

  @override
  String backupLibraryTo(String library, int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs músicas',
      one: '1 música',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return '\"$library\" ($_temp0, $_temp1) para';
  }

  @override
  String get backupImportDifferingAll =>
      'Músicas que existem aqui com um texto diferente:';

  @override
  String get backupRestorePersonal =>
      'Restaurar os meus ajustes pessoais e notas';

  @override
  String backupPersonalOf(String library, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas',
      one: '1 música',
    );
    return '$library: $_temp0';
  }

  @override
  String get backupRestoreSettings => 'Restaurar as minhas definições';

  @override
  String get backupRestoreSettingsHint =>
      'Substitui as tuas definições atuais pelas da cópia de segurança.';

  @override
  String get backupRestoreStart => 'Restaurar';

  @override
  String get backupRestoreDone => 'Cópia de segurança restaurada';

  @override
  String backupResultPersonal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas',
      one: '1 música',
    );
    return 'Ajustes pessoais e notas de $_temp0 restaurados';
  }

  @override
  String get backupResultSettings => 'Definições restauradas';

  @override
  String backupReminder(int days) {
    return 'A tua biblioteca neste dispositivo não tem cópia de segurança há $days dias.';
  }

  @override
  String get backupReminderAction => 'Fazer cópia';

  @override
  String get orgClose => 'Fechar organização';

  @override
  String orgCloseTitle(String org) {
    return 'Fechar $org?';
  }

  @override
  String orgCloseMessage(int days) {
    return 'As suas bandas, sets, músicas e anexos e os ajustes pessoais de todos para as suas músicas são removidos, e os seus convites são revogados. Os membros são informados na próxima sincronização. Os seus admins podem restaurá-la a partir do lixo durante $days dias; depois disso, tudo é eliminado definitivamente.';
  }

  @override
  String orgCloseBands(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bandas',
      one: '1 banda',
      zero: 'nenhuma banda',
    );
    return '$_temp0';
  }

  @override
  String orgCloseSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas',
      one: '1 música',
      zero: 'nenhuma música',
    );
    return '$_temp0';
  }

  @override
  String orgClosePeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pessoas',
      one: '1 pessoa',
    );
    return '$_temp0';
  }

  @override
  String get orgCloseBackup => 'Fazer cópia primeiro';

  @override
  String orgClosed(String org) {
    return '$org fechada';
  }

  @override
  String get orgsClosedTitle => 'Organizações fechadas';

  @override
  String orgsClosedEmpty(int days) {
    return 'Nenhuma organização fechada. Os seus admins podem restaurar aqui as organizações fechadas durante $days dias.';
  }

  @override
  String orgsClosedHint(int days) {
    return 'As organizações fechadas podem ser restauradas com todo o seu conteúdo durante $days dias. Depois disso, são eliminadas definitivamente.';
  }

  @override
  String orgClosedOn(String date) {
    return 'fechada a $date';
  }

  @override
  String orgClosedBy(String name) {
    return 'por $name';
  }

  @override
  String orgClosedNotice(String org, String name, int days) {
    return '$org foi fechada por $name. Os seus admins podem restaurá-la durante $days dias.';
  }

  @override
  String orgClosedNoticeAnonymous(String org, int days) {
    return '$org foi fechada. Os seus admins podem restaurá-la durante $days dias.';
  }

  @override
  String get navOverview => 'Vista geral';

  @override
  String get overviewNextSet => 'Próximo set';

  @override
  String get overviewLastEditedSet => 'Último set editado';

  @override
  String overviewSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas',
      one: '1 música',
      zero: 'Nenhuma música',
    );
    return '$_temp0';
  }

  @override
  String get overviewStartLive => 'Começar ao vivo';

  @override
  String get overviewOpenSet => 'Abrir set';

  @override
  String get overviewTodo => 'Por fazer';

  @override
  String overviewTodoProblems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas com problemas de ChordPro',
      one: '1 música com problemas de ChordPro',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas com conflitos de sincronização',
      one: '1 música com um conflito de sincronização',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoSheetMusicOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas só com partitura (PDF)',
      one: '1 música só com partitura (PDF)',
    );
    return '$_temp0';
  }

  @override
  String get attentionProblems => 'Problemas de ChordPro';

  @override
  String get attentionConflicts => 'Conflitos de sincronização';

  @override
  String get attentionSheetMusicOnly => 'Só partitura';

  @override
  String chordProConversionsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Converter $count partes do ChordPro',
      one: 'Converter 1 parte do ChordPro',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoConversions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas com conversões possíveis',
      one: '1 música com conversões possíveis',
    );
    return '$_temp0';
  }

  @override
  String get attentionConversions => 'Convertíveis';

  @override
  String get convertAllSongs => 'Converter todas';

  @override
  String get convertAllSongsTitle => 'Converter todas as músicas?';

  @override
  String convertAllSongsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'As $count músicas são convertidas',
      one: 'A música é convertida',
    );
    return '$_temp0 para todos: diretivas CCLI e etiquetas de secção como recomenda a especificação ChordPro, barras de compasso CCLI como grelhas, rodapé CCLI removido.';
  }

  @override
  String songsConverted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas convertidas',
      one: '1 música convertida',
    );
    return '$_temp0';
  }

  @override
  String songConverted(String title) {
    return '“$title” convertida';
  }

  @override
  String get songsFilterEmpty => 'Já não há músicas neste filtro.';

  @override
  String get playHistory => 'Tocada';

  @override
  String playHistoryOf(String band) {
    return 'Tocada por $band';
  }

  @override
  String playHistoryNone(String band) {
    return '$band ainda não tocou esta música num set passado.';
  }

  @override
  String get playHistoryTotal => 'no total';

  @override
  String get playHistoryLastYear => 'últimos 12 meses';

  @override
  String get playHistoryLast => 'última vez';

  @override
  String playHistoryFirst(String date) {
    return 'Primeira vez a $date';
  }

  @override
  String playHistoryShowAll(int count) {
    return 'Mostrar as $count';
  }

  @override
  String playHistoryDiffers(String key) {
    return 'Destacado: um tom diferente do de hoje ($key)';
  }

  @override
  String get playHistoryApproximate =>
      '≈ derivado do arranjo de hoje: o set não tem valores guardados';

  @override
  String keyHistoryLast(String key, String date) {
    return 'Última vez em $key a $date';
  }

  @override
  String keyHistoryMostly(String key, int count, int total) {
    return 'sobretudo em $key ($count de $total)';
  }

  @override
  String songLastPlayed(String date) {
    return 'Tocada pela última vez a $date';
  }

  @override
  String get songNeverPlayed => 'Nunca tocada';

  @override
  String get overviewRecentChanges => 'Alterações recentes';

  @override
  String get overviewShowAll => 'Mostrar tudo';

  @override
  String get overviewMoreSets => 'Mais sets';

  @override
  String get overviewNewestSongs => 'Músicas mais recentes';

  @override
  String get recentChangesEmpty =>
      'Nenhuma alteração de outros nos últimos 30 dias.';

  @override
  String get changeSongAdded => 'Nova música';

  @override
  String get changeNewSet => 'Novo set';

  @override
  String get changeSongText => 'Texto alterado';

  @override
  String get changeSongAttachment => 'Anexo alterado';

  @override
  String get changeSongTextAndAttachment => 'Texto e anexo alterados';

  @override
  String changeSetAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas adicionadas',
      one: '1 música adicionada',
    );
    return '$_temp0';
  }

  @override
  String changeSetRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas removidas',
      one: '1 música removida',
    );
    return '$_temp0';
  }

  @override
  String changeSetAlsoRemoved(int count) {
    return '$count removidas';
  }

  @override
  String changeSetSequence(String songs) {
    return 'sequência de $songs alterada';
  }

  @override
  String changeQuoted(String title) {
    return '\"$title\"';
  }

  @override
  String changeBy(String name) {
    return 'por $name';
  }

  @override
  String get repertoire => 'Repertório';

  @override
  String repertoireOf(String band) {
    return 'Repertório de $band';
  }

  @override
  String get repertoireLastYear => '12 meses';

  @override
  String get repertoireAllTime => 'Desde sempre';

  @override
  String get repertoireMostPlayed => 'Mais tocadas';

  @override
  String get repertoireStale => 'Sem tocar há algum tempo';

  @override
  String repertoireStaleHint(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'Tocada pela última vez há mais de $months meses',
      one: 'Tocada pela última vez há mais de um mês',
    );
    return '$_temp0';
  }

  @override
  String get playedFilter => 'Tocadas';

  @override
  String get playedAll => 'Todas';

  @override
  String get filterByPlayed => 'Filtrar pelas atuações da banda';

  @override
  String get repertoireNeverPlayed => 'Nunca tocadas';

  @override
  String get repertoireNeverPlayedHint =>
      'Músicas da biblioteca que não estiveram em nenhum set passado da banda';

  @override
  String get repertoireNone => 'Nenhuma';

  @override
  String get repertoireEmpty =>
      'A banda ainda não tocou músicas em sets passados.';

  @override
  String repertoirePlays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vezes',
      one: 'uma vez',
    );
    return '$_temp0';
  }

  @override
  String get repertoireThreshold =>
      'Quando conta uma música como não tocada há algum tempo?';

  @override
  String repertoireMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'Após $months meses',
      one: 'Após 1 mês',
    );
    return '$_temp0';
  }

  @override
  String repertoireDefault(int months) {
    return 'Predefinição: após $months meses';
  }

  @override
  String get sortByLastPlayed => 'Última vez tocada';

  @override
  String get playHistoryOtherBands => 'Outras bandas';

  @override
  String playHistoryFetched(String date) {
    return 'Em $date';
  }

  @override
  String get libraryUsage => 'Uso da biblioteca';

  @override
  String libraryUsageSummary(int count, int total) {
    return 'Nenhuma banda toca $count de $total músicas';
  }

  @override
  String get libraryUsageHint =>
      'Músicas que não estiveram em nenhum set passado de nenhuma banda da organização. Move para o lixo o que nenhuma banda precisa mais.';

  @override
  String get libraryUsageNotLoaded =>
      'Ainda não carregado: sincroniza uma vez com ligação ao servidor.';

  @override
  String get libraryUsageAllPlayed =>
      'Todas as músicas da biblioteca foram tocadas por uma banda.';

  @override
  String syncHintSongChanged(String title, String name) {
    return '\"$title\" foi alterada por $name.';
  }

  @override
  String syncHintSongDeleted(String title, String name) {
    return '\"$title\" foi eliminada por $name.';
  }

  @override
  String syncHintSetChanged(String title, String name) {
    return 'O set \"$title\" foi alterado por $name.';
  }

  @override
  String syncHintSetDeleted(String title, String name) {
    return 'O set \"$title\" foi eliminado por $name.';
  }

  @override
  String syncHintSongChangedAnonymous(String title) {
    return '\"$title\" foi alterada por outra pessoa.';
  }

  @override
  String syncHintSongDeletedAnonymous(String title) {
    return '\"$title\" foi eliminada por outra pessoa.';
  }

  @override
  String syncHintSetChangedAnonymous(String title) {
    return 'O set \"$title\" foi alterado por outra pessoa.';
  }

  @override
  String syncHintSetDeletedAnonymous(String title) {
    return 'O set \"$title\" foi eliminado por outra pessoa.';
  }

  @override
  String syncHintAfterLive(String changes) {
    return 'Enquanto tocavas ao vivo: $changes.';
  }

  @override
  String syncHintSongsChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas alteradas',
      one: '1 música alterada',
    );
    return '$_temp0';
  }

  @override
  String syncHintSongsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas eliminadas',
      one: '1 música eliminada',
    );
    return '$_temp0';
  }

  @override
  String syncHintSetsChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets alterados',
      one: '1 set alterado',
    );
    return '$_temp0';
  }

  @override
  String syncHintSetsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets eliminados',
      one: '1 set eliminado',
    );
    return '$_temp0';
  }

  @override
  String get syncHintShowChanges => 'Mostrar';

  @override
  String get setExportTitle => 'Exportar set';

  @override
  String get setExportHint =>
      'O ZIP contém os ficheiros ChordPro das músicas e uma descrição a partir da qual o setDING volta a importar o set como set.';

  @override
  String get setArchiveArrangements =>
      'Arranjos da banda para as músicas (tom, sequência, tempo)';

  @override
  String get setArchiveSetSettings => 'Tom e sequência das músicas neste set';

  @override
  String get setArchiveAttachments => 'Anexos (PDF, imagens)';

  @override
  String get setArchivePersonal => 'Os meus ajustes pessoais e notas';

  @override
  String get setArchivePersonalHint =>
      'Deixa desligado se passares o ficheiro a outros.';

  @override
  String get setExportStart => 'Exportar';

  @override
  String get exportMenu => 'Exportar …';

  @override
  String get exportFormat => 'Formato';

  @override
  String get exportFormatChordPro => 'Ficheiro ChordPro';

  @override
  String get exportFormatChordProHint =>
      'Para outras apps, sem anexos nem arranjos';

  @override
  String get exportFormatSetListPdf => 'Alinhamento em PDF';

  @override
  String get exportFormatSetListPdfHint => 'Para imprimir';

  @override
  String get exportFormatArchive => 'Arquivo setDING (ZIP)';

  @override
  String get exportFormatArchiveHint =>
      'Para importar no setDING, com anexos e arranjos se quiseres';

  @override
  String get songExportHintChordPro =>
      'O ficheiro ChordPro contém a letra e os acordes da música e abre em qualquer app que conheça ChordPro.';

  @override
  String get setExportHintPdf =>
      'O alinhamento mostra cada música com o seu tom e sequência, para imprimir para o palco.';

  @override
  String get setImport => 'Importar set';

  @override
  String get setImportFromFile => 'Importar de ficheiro …';

  @override
  String get setImportTitle => 'Importar set';

  @override
  String get setImportBand => 'Banda';

  @override
  String get setImportNoBand =>
      'Não há nesta biblioteca nenhuma banda cujos sets possas gerir.';

  @override
  String setImportExisting(String name) {
    return 'A banda já tem este set como \"$name\".';
  }

  @override
  String get setImportReplace => 'Substituí-lo';

  @override
  String get setImportCopy => 'Adicionar como cópia';

  @override
  String setImportOverwriteArrangements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas',
      one: '1 música',
    );
    return 'Substituir os arranjos da banda de $_temp0';
  }

  @override
  String get setImportDone => 'Set importado';

  @override
  String get setImportReplaced => 'O set existente foi substituído.';

  @override
  String setImportResultArrangements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arranjos de banda guardados',
      one: '1 arranjo de banda guardado',
    );
    return '$_temp0';
  }

  @override
  String get setImportResultMissing =>
      'Não estão na biblioteca, mostradas como elementos de texto no set:';

  @override
  String get setImportOpen => 'Abrir set';

  @override
  String setImportMissingNote(String title) {
    return 'Em falta: $title';
  }

  @override
  String get setArchiveInvalid => 'Este ficheiro não é um set exportado.';

  @override
  String get setArchiveNewer =>
      'Este set foi exportado com uma versão mais recente do setDING. Atualiza a app para o importar.';

  @override
  String setImportFrom(String band, int songs) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs músicas',
      one: '1 música',
      zero: 'nenhuma música',
    );
    return 'de $band · $_temp0';
  }

  @override
  String get setImportHeadingTarget => 'Destino';

  @override
  String get setImportHeadingExisting => 'Set já existente';

  @override
  String get setImportHeadingSongs => 'Músicas';

  @override
  String get setImportHeadingInclude => 'Incluir';

  @override
  String get setExportHeadingInclude => 'Incluir no arquivo';

  @override
  String setImportNewName(String name) {
    return 'Será adicionado como \"$name\".';
  }

  @override
  String setImportSongsHere(int count) {
    return '$count já aqui com o mesmo texto';
  }

  @override
  String setImportSongsNew(int count) {
    return '$count novas, adicionadas à biblioteca';
  }

  @override
  String setImportSongsDiffering(int count) {
    return '$count aqui com um texto diferente';
  }

  @override
  String setImportSongsMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mostra-as',
      one: 'mostra-a',
    );
    return '$count não estão na biblioteca – não podes adicionar músicas, por isso o set $_temp0 como texto';
  }

  @override
  String get setImportKeep => 'Manter existentes';

  @override
  String get setImportAddAll => 'Importar também';

  @override
  String setImportCopyName(String name) {
    return '$name (cópia)';
  }

  @override
  String setImportCopyNameNumbered(String name, int number) {
    return '$name (cópia $number)';
  }

  @override
  String get keyboardShortcuts => 'Atalhos de teclado';

  @override
  String get shortcutsEverywhere => 'Em todo o lado';

  @override
  String get shortcutsSong => 'Música';

  @override
  String get shortcutsSet => 'Set';

  @override
  String get shortcutsSongList => 'Lista de músicas';

  @override
  String get shortcutsLive => 'Modo ao vivo';

  @override
  String get shortcutBack => 'Voltar';

  @override
  String get shortcutHelp => 'Mostrar os atalhos de teclado';

  @override
  String get shortcutEditSong => 'Editar a música';

  @override
  String get shortcutEditSet => 'Editar o set';

  @override
  String get shortcutLive => 'Iniciar o modo ao vivo';

  @override
  String get shortcutTranspose => 'Transpor para cima / baixo';

  @override
  String get shortcutPreviousNextSong => 'Música anterior / seguinte do set';

  @override
  String get shortcutSearch => 'Pesquisar músicas';

  @override
  String get shortcutNextPage => 'Página seguinte';

  @override
  String get shortcutPreviousPage => 'Página anterior';

  @override
  String get shortcutBeat => 'Iniciar / parar a pulsação';

  @override
  String get shortcutKeyPageDown => 'Page Down';

  @override
  String get shortcutKeyPageUp => 'Page Up';

  @override
  String get shortcutKeySpace => 'Espaço';

  @override
  String get shortcutCloseSelection => 'Fechar a seleção';

  @override
  String get settingsHeadingLanguageTheme => 'Idioma e tema';

  @override
  String get settingsHeadingEditor => 'Editor';

  @override
  String get settingsHeadingAdvanced => 'Avançado';

  @override
  String get settingsHeadingChords => 'Acordes';

  @override
  String get settingsHeadingContent => 'Conteúdo';

  @override
  String get settingsHeadingSetNotes => 'Set e notas';

  @override
  String get settingsHeadingInstrument => 'Instrumento e voz';

  @override
  String get settingsHeadingScreen => 'Ecrã';

  @override
  String get settingsHeadingControls => 'Controlos';

  @override
  String get settingsHeadingClick => 'Clique neste dispositivo';

  @override
  String get settingsHeadingBackup => 'Cópia de segurança';

  @override
  String get settingsHeadingThisDevice => 'Este dispositivo';

  @override
  String get settingsHeadingHelp => 'Ajuda e info';

  @override
  String get settingsHeadingConnection => 'Ligação';

  @override
  String get settingsHeadingKeyboard => 'Teclado';

  @override
  String get settingsHeadingStyle => 'Estilo';

  @override
  String get settingsHeadingPrototypes => 'Protótipos';

  @override
  String songExportTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Exportar $count músicas',
      one: 'Exportar música',
    );
    return '$_temp0';
  }

  @override
  String get songExportHint =>
      'O ZIP contém os ficheiros ChordPro e uma descrição a partir da qual o setDING volta a importar as músicas, mais o que escolheres abaixo.';

  @override
  String songExportArrangements(String band) {
    return 'Arranjos de \"$band\" (tom, sequência, tempo)';
  }

  @override
  String get songImportTitle => 'Importar músicas';

  @override
  String songImportFrom(String library, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas',
      one: '1 música',
    );
    return 'de $library · $_temp0';
  }

  @override
  String songImportLibrary(String name) {
    return 'Para a biblioteca \"$name\"';
  }

  @override
  String get songImportArrangementsBand => 'Banda para os arranjos';

  @override
  String get songImportNoBand =>
      'Não há nesta biblioteca nenhuma banda cujos arranjos possas alterar.';

  @override
  String get songImportDone => 'Músicas importadas';

  @override
  String get songArchiveNewer =>
      'Estas músicas foram exportadas com uma versão mais recente do setDING. Atualiza a app para as importar.';

  @override
  String archiveImportAttachmentsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anexos adicionados',
      one: '1 anexo adicionado',
    );
    return '$_temp0 a músicas que já estão aqui';
  }

  @override
  String archiveResultCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anexos adicionados',
      one: '1 anexo adicionado',
    );
    return '$_temp0 a músicas existentes';
  }

  @override
  String songLanguageName(String language) {
    String _temp0 = intl.Intl.selectLogic(language, {
      'de': 'Alemão',
      'gsw': 'Alemão suíço',
      'en': 'Inglês',
      'fr': 'Francês',
      'it': 'Italiano',
      'es': 'Espanhol',
      'pt': 'Português',
      'nl': 'Neerlandês',
      'other': 'Outro',
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
  String get songLanguage => 'Idioma';

  @override
  String get songLanguageMenu => 'Idioma …';

  @override
  String get allLanguages => 'Todos os idiomas';

  @override
  String get noLanguage => 'Sem idioma';

  @override
  String get filterByLanguage => 'Filtrar por idioma';

  @override
  String songLanguageAutomatic(String language) {
    return 'Automático: $language';
  }

  @override
  String get songLanguageNotDetected => 'Automático (não detetado)';

  @override
  String get songLanguageAutomaticHint =>
      'Detetado a partir da letra; uma escolha manual tem sempre prioridade.';

  @override
  String songLanguageDetectedTooltip(String language) {
    return '$language (detetado a partir da letra)';
  }

  @override
  String songLanguageByHandTooltip(String language) {
    return '$language (definido à mão)';
  }

  @override
  String get languageVersions => 'Versões noutros idiomas';

  @override
  String get linkLanguageVersion => 'Versões noutros idiomas …';

  @override
  String get unlinkLanguageVersion => 'Remover das versões noutros idiomas';

  @override
  String get languageVersionPickerEmpty =>
      'Não há outras músicas que possas associar';

  @override
  String languageVersionsOf(String title) {
    return 'Versões noutros idiomas de $title';
  }

  @override
  String languageVersionsChosen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Versões associadas ($count)',
      zero: 'Versões associadas',
    );
    return '$_temp0';
  }

  @override
  String get languageVersionsChosenEmpty =>
      'Ainda não há outras versões. Escolhe músicas da biblioteca.';

  @override
  String get languageVersionsSaved => 'Versões noutros idiomas guardadas';

  @override
  String languageVersionsNotAllowed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count músicas não foram associadas: não podes alterar as suas outras versões.',
      one: 'Uma música não foi associada: não podes alterar as suas outras versões.',
    );
    return '$_temp0';
  }

  @override
  String get languageVersionUnlinked => 'Removida das versões noutros idiomas';

  @override
  String otherLanguageVersionsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count versões noutros idiomas',
      one: 'Outra versão noutro idioma',
    );
    return '$_temp0';
  }

  @override
  String get switchLanguageVersion => 'Mudar de versão de idioma …';

  @override
  String switchedLanguageVersion(String version) {
    return 'Mudado para: $version';
  }

  @override
  String switchedLanguageVersionKey(
    String version,
    String newKey,
    String oldKey,
  ) {
    return 'Mudado para: $version, em $newKey em vez de $oldKey neste set';
  }

  @override
  String get switchedLanguageVersionSequence =>
      'A sequência própria do set não se ajusta à nova versão e foi removida.';

  @override
  String languageVersionInSet(String title, String key) {
    return '$title · em $key neste set';
  }

  @override
  String get switchLanguageVersionTitle => 'Mudar de versão de idioma';

  @override
  String adjustmentOfferOne(String version, String what) {
    return 'Os teus ajustes em “$version”: $what. Usá-los também para esta versão?';
  }

  @override
  String get adjustmentOfferMany =>
      'Outras versões de idioma têm os teus ajustes. Usá-los também para esta versão?';

  @override
  String get adjustmentKindTranspose => 'tom';

  @override
  String get adjustmentKindCapo => 'capotraste';

  @override
  String get adjustmentKindMidi => 'programa do teclado';

  @override
  String get adjustmentKindClick => 'clique';

  @override
  String get adjustmentOfferCopy => 'Usá-los';

  @override
  String get adjustmentOfferDismiss => 'Não, obrigado';

  @override
  String get adjustmentOfferPick => 'Usar os ajustes de';

  @override
  String adjustmentsCopied(String version) {
    return 'Ajustes de “$version” usados';
  }

  @override
  String get autoBackup => 'Cópia de segurança automática';

  @override
  String get autoBackupSwitch => 'Fazer cópia automaticamente';

  @override
  String get autoBackupHint =>
      'Guarda a biblioteca “Neste dispositivo” numa pasta à tua escolha, no máximo uma vez por dia após alterações. Usa uma pasta do teu armazenamento na nuvem para a manter segura se perderes o dispositivo.';

  @override
  String get autoBackupFolder => 'Pasta';

  @override
  String get autoBackupFolderNone => 'Nenhuma pasta escolhida';

  @override
  String get autoBackupChooseFolder => 'Escolher pasta';

  @override
  String get autoBackupDevice => 'Nome do dispositivo';

  @override
  String get autoBackupDeviceHint =>
      'Faz parte dos nomes dos ficheiros, para que vários dispositivos possam usar a mesma pasta.';

  @override
  String get autoBackupDeviceTitle => 'Nome do dispositivo para as cópias';

  @override
  String get autoBackupKeep => 'Cópias mantidas';

  @override
  String get autoBackupKeepHint =>
      'As cópias automáticas mais antigas deste dispositivo são eliminadas da pasta.';

  @override
  String get autoBackupNow => 'Fazer cópia na pasta agora';

  @override
  String get autoBackupRunning => 'A fazer cópia …';

  @override
  String get autoBackupNever => 'Ainda sem cópia automática.';

  @override
  String autoBackupLast(String date) {
    return 'Última cópia automática: $date';
  }

  @override
  String autoBackupFailed(String date, String reason) {
    return 'Falhou a $date: $reason';
  }

  @override
  String get autoBackupErrorUnavailable => 'A pasta não está acessível.';

  @override
  String get autoBackupErrorPermission =>
      'O setDING já não pode escrever na pasta. Escolhe-a novamente.';

  @override
  String get autoBackupErrorFailed =>
      'Não foi possível escrever a cópia de segurança.';

  @override
  String autoBackupHintFailed(String reason) {
    return 'A cópia automática falhou: $reason';
  }

  @override
  String autoBackupSaved(String file) {
    return 'Guardado como “$file”';
  }

  @override
  String get backupModeCopy => 'Adicionar como cópia';

  @override
  String get backupModeCopyHint =>
      'As músicas e os sets são adicionados com novos ID; nada existente é alterado.';

  @override
  String get backupModeReplace => 'Substituir a biblioteca local';

  @override
  String get backupModeReplaceHint =>
      'A biblioteca “Neste dispositivo” fica exatamente como na cópia, p. ex. num dispositivo novo ou para voltar a um estado anterior.';

  @override
  String get backupReplaceTitle => 'Substituir a biblioteca local?';

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
      other: '$songs músicas',
      one: '1 música',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'Cópia de “$device” de $date: $_temp0, $_temp1.';
  }

  @override
  String backupReplaceFrom(String date, int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs músicas',
      one: '1 música',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'Cópia de $date: $_temp0, $_temp1.';
  }

  @override
  String backupReplaceNow(int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs músicas',
      one: '1 música',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'Agora neste dispositivo: $_temp0, $_temp1. São removidos, incluindo os do lixo.';
  }

  @override
  String get backupReplaceKeeps =>
      'O histórico de atuações volta com os sets da cópia. As definições e organizações não são alteradas.';

  @override
  String get backupReplaceSafety =>
      'Guardar primeiro uma cópia de segurança de reserva';

  @override
  String backupReplaceSafetyFolder(String folder) {
    return 'Na pasta da cópia automática ($folder).';
  }

  @override
  String get backupReplaceSafetyChoose => 'Escolhes onde a guardar.';

  @override
  String get backupReplaceSafetySkip =>
      'Sem uma cópia de reserva, a biblioteca atual não pode ser restaurada.';

  @override
  String get backupReplaceAction => 'Substituir';

  @override
  String get backupReplaceRunning => 'A substituir a biblioteca local …';

  @override
  String backupReplaceDone(int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs músicas',
      one: '1 música',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'Biblioteca local substituída: $_temp0, $_temp1.';
  }

  @override
  String backupReplaceSafetyFailed(String reason) {
    return 'Não foi possível guardar a cópia de reserva, por isso nada foi substituído: $reason';
  }

  @override
  String get showLocalLibrary => 'Mostrar a biblioteca local';

  @override
  String get showLocalLibraryHint =>
      '“Neste dispositivo” nas listas de bibliotecas e bandas. Se tocas só em organizações, podes ocultá-la; as suas músicas e sets ficam neste dispositivo.';

  @override
  String get showLocalLibrarySignedOut =>
      'Sem sessão iniciada, a biblioteca local é sempre mostrada.';

  @override
  String localLibraryHidden(int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs músicas',
      one: '1 música',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'A biblioteca local está oculta. As suas $_temp0 e $_temp1 ficam neste dispositivo e voltam quando a mostrares de novo.';
  }

  @override
  String get localLibraryHiddenAutoBackup =>
      'A cópia automática continua a funcionar; podes desligá-la aqui.';

  @override
  String get chordViewChords => 'Acordes';

  @override
  String get chordViewNashville => 'Nashville';

  @override
  String get chordViewNumerals => 'Numerais';

  @override
  String get liveChordViewChords => 'C';

  @override
  String get liveChordViewNashville => '1';

  @override
  String get liveChordViewNumerals => 'I';

  @override
  String get chordViewDocs =>
      'Como ler os números Nashville e os numerais romanos';

  @override
  String docsHelp(String topic) {
    return 'Ajuda: $topic';
  }

  @override
  String get editorDocsTopic => 'Editor ChordPro';

  @override
  String get settingsDocs => 'Guia do utilizador';

  @override
  String get settingsDocsHint =>
      'Abrir a documentação do setDING em setding.app (em inglês). O ícone do livro no topo abre a página da secção aberta.';

  @override
  String get overviewReadiness => 'Prontos para tocar';

  @override
  String readinessAllSet(String set) {
    return 'Tudo pronto para “$set”';
  }

  @override
  String get readinessAllSetNoSet => 'Tudo pronto';

  @override
  String get readinessShowDetails => 'Mostrar detalhes';

  @override
  String get readinessHideDetails => 'Ocultar detalhes';

  @override
  String readinessMusician(String who) {
    return 'Músico: $who';
  }

  @override
  String get readinessNoInstrument => 'Nenhum instrumento escolhido';

  @override
  String readinessMidiConnected(String device) {
    return 'MIDI: $device ligado';
  }

  @override
  String get readinessMidiNotConnected => 'MIDI: teclado não ligado';

  @override
  String get readinessMidiNoOutput => 'MIDI: nenhum teclado escolhido';

  @override
  String readinessMidiProfile(String profile) {
    return 'Perfil: $profile';
  }

  @override
  String get readinessOfflineReady => 'Próximo set disponível offline';

  @override
  String readinessOfflineMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas do próximo set não estão disponíveis',
      one: '1 música do próximo set não está disponível',
    );
    return '$_temp0 offline';
  }

  @override
  String readinessSynced(String time) {
    return 'Sincronizado: $time';
  }

  @override
  String get readinessSyncNever => 'Ainda não sincronizado neste dispositivo';

  @override
  String get readinessSyncStale => 'Os dados podem não estar atualizados';

  @override
  String get readinessSyncManual =>
      'A sincronização é manual: sincroniza antes do concerto.';

  @override
  String get readinessPageTurnerResponds => 'O virador de páginas responde';

  @override
  String readinessPageTurnerLastUsed(String time) {
    return 'Virador de páginas: usado pela última vez $time';
  }

  @override
  String get readinessPageTurnerNever =>
      'Virador de páginas: ainda não usado neste dispositivo';

  @override
  String readinessPageTurnerDetail(String mode) {
    return 'Vira: $mode · prime aqui o pedal para o testar';
  }

  @override
  String get readinessBackupNoFolder =>
      'Cópia automática: nenhuma pasta escolhida';

  @override
  String get readinessBackupFailed => 'A cópia automática falhou';

  @override
  String get keyGuessHint => 'Sugerido a partir dos acordes:';

  @override
  String keyGuessUse(String key) {
    return 'Usar $key como tom';
  }

  @override
  String get attentionNoKey => 'Sem tom';

  @override
  String overviewTodoNoKey(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas sem tom',
      one: '1 música sem tom',
    );
    return '$_temp0';
  }

  @override
  String readinessPageTurnerConnected(String name) {
    return 'Virador de páginas $name ligado';
  }

  @override
  String readinessPageTurnerNotConnected(String name) {
    return 'Virador de páginas $name não ligado';
  }

  @override
  String get readinessKeyboardConnected => 'Está ligado um teclado';

  @override
  String get readinessKeyboardNotConnected =>
      'Virador de páginas: nenhum teclado ligado';

  @override
  String get settingsPageTurner => 'Virador de páginas';

  @override
  String get settingsPageTurnerNone => 'Não emparelhado';

  @override
  String get settingsPageTurnerConnected => 'ligado';

  @override
  String get settingsPageTurnerNotConnected => 'não ligado';

  @override
  String get settingsPageTurnerHint =>
      'Emparelha o teu pedal para que a vista geral mostre se está ligado.';

  @override
  String get settingsPageTurnerPair => 'Emparelhar';

  @override
  String get settingsPageTurnerPairAgain => 'Emparelhar novamente';

  @override
  String get settingsPageTurnerForget => 'Esquecer virador de páginas';

  @override
  String get settingsPageTurnerKeyboardOnly =>
      'Este dispositivo só indica se está ligado um teclado, não qual. A vista geral mostra-o.';

  @override
  String get settingsPageTurnerUnsupported =>
      'Não é possível nesta plataforma. A vista geral mostra quando o virador de páginas foi usado pela última vez.';

  @override
  String get pairPageTurnerTitle => 'Emparelhar virador de páginas';

  @override
  String get pairPageTurnerPrompt => 'Prime agora o pedal.';

  @override
  String pageTurnerPaired(String name) {
    return 'Virador de páginas emparelhado: $name';
  }

  @override
  String pageTurnerForgotten(String name) {
    return 'Virador de páginas esquecido: $name';
  }

  @override
  String get pageTurnerUnnamed => 'Dispositivo sem nome';

  @override
  String importKeySuggestionsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas importadas não têm',
      one: '1 música importada não tem',
    );
    return '$_temp0 tom. Sugerido a partir dos acordes; um toque define o tom:';
  }

  @override
  String importKeySuggestionsMore(int count) {
    return '… e mais $count: Por fazer na vista geral, Sem tom.';
  }

  @override
  String importKeysSet(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tons definidos em $count músicas',
      one: 'Tom definido em 1 música',
      zero: 'Nenhum tom definido',
    );
    return '$_temp0';
  }

  @override
  String get readinessPageTurnerNotPaired =>
      'Virador de páginas não emparelhado';

  @override
  String readinessPageTurnerPairDetail(String mode) {
    return 'Emparelha-o para que a vista geral mostre se está ligado · Vira: $mode';
  }

  @override
  String get settingsPageTurnerUse => 'Uso um virador de páginas';

  @override
  String get settingsPageTurnerUseHint =>
      'Um pedal que vira as páginas. Mostra-o na vista geral e propõe emparelhar um que seja detetado.';

  @override
  String pageTurnerDetected(String name) {
    return 'Virador de páginas detetado: $name';
  }

  @override
  String get attentionToReview => 'Por rever';

  @override
  String get attentionReported => 'Reportado';

  @override
  String overviewTodoToReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas por rever',
      one: '1 música por rever',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoReported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas com erros reportados',
      one: '1 música com um erro reportado',
    );
    return '$_temp0';
  }

  @override
  String get songToReviewTooltip => 'Ainda não revista';

  @override
  String get songReportedTooltip => 'Erro reportado';

  @override
  String get songToReviewHint => 'Esta música ainda não foi revista.';

  @override
  String get songReportedHint => 'Foi reportado um erro nesta música.';

  @override
  String reviewBannerToReview(String reason) {
    return 'Por rever: $reason';
  }

  @override
  String reviewBannerReports(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count relatos em aberto',
      one: '1 relato em aberto',
    );
    return '$_temp0';
  }

  @override
  String get showReports => 'Mostrar';

  @override
  String get approveSong => 'Aprovar';

  @override
  String get songApproved => 'Música aprovada';

  @override
  String get approveAllSongs => 'Aprovar todas';

  @override
  String get approveAllSongsTitle => 'Aprovar todas as músicas?';

  @override
  String approveAllSongsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas passarão a contar como revistas.',
      one: '1 música passará a contar como revista.',
    );
    return '$_temp0';
  }

  @override
  String songsApproved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas aprovadas',
      one: '1 música aprovada',
    );
    return '$_temp0';
  }

  @override
  String get resolveReportsTitle => 'Resolver os relatos?';

  @override
  String resolveReportsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'A música tem $count relatos em aberto. Marcá-los também como resolvidos?',
      one: 'A música tem 1 relato em aberto. Marcá-lo também como resolvido?',
    );
    return '$_temp0';
  }

  @override
  String get resolveReports => 'Resolver';

  @override
  String get setToReviewMenu => 'Marcar para rever …';

  @override
  String get setToReviewTitle => 'Marcar para rever';

  @override
  String get reviewReasonLabel => 'Motivo';

  @override
  String get reviewReasonHint => 'p. ex. a ponte está errada';

  @override
  String get reviewReasonAfterImport => 'Após a importação';

  @override
  String setReviewHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas ainda não foram revistas ou têm erros reportados',
      one: '1 música ainda não foi revista ou tem um erro reportado',
    );
    return '$_temp0';
  }

  @override
  String get reportMistake => 'Reportar um erro';

  @override
  String get reportMistakeMenu => 'Reportar um erro …';

  @override
  String get reportCategoryChords => 'Acordes';

  @override
  String get reportCategoryLyrics => 'Letra';

  @override
  String get reportCategoryKey => 'Tom';

  @override
  String get reportCategorySequence => 'Sequência';

  @override
  String get reportCategoryTempo => 'Andamento';

  @override
  String get reportCategoryFormatting => 'Formatação';

  @override
  String get reportCategorySheetMusic => 'Partitura (PDF)';

  @override
  String get reportCategoryOther => 'Outro';

  @override
  String get reportComment => 'Comentário';

  @override
  String get reportCommentHint => 'O que está errado?';

  @override
  String get reportSend => 'Enviar';

  @override
  String get reportSent => 'Erro reportado. Obrigado!';

  @override
  String reportLocation(String place) {
    return 'Local: $place';
  }

  @override
  String reportLocationPage(int page) {
    return 'Página $page';
  }

  @override
  String reportLocationPdfPage(int page) {
    return 'Página PDF $page';
  }

  @override
  String reportLocationLine(int line) {
    return 'Linha $line';
  }

  @override
  String get reportsTitle => 'Relatos de erros';

  @override
  String get reportsEmpty => 'Sem relatos';

  @override
  String reportsClosed(int count) {
    return 'Resolvidos e retirados ($count)';
  }

  @override
  String get reportByYou => 'por ti';

  @override
  String reportBy(String name) {
    return 'por $name';
  }

  @override
  String get reportWithdrawn => 'retirado';

  @override
  String get reportWithdraw => 'Retirar';

  @override
  String get reportWithdrawnMessage => 'Relato retirado';

  @override
  String get resolveReport => 'Resolver o relato';

  @override
  String get reportAnswerLabel => 'Resposta';

  @override
  String get reportAnswerHint => 'p. ex. Corrigido, obrigado!';

  @override
  String get reportResolvedMessage => 'Relato resolvido';

  @override
  String get reportReopen => 'Reabrir';

  @override
  String get reportReopenedMessage => 'Relato reaberto';

  @override
  String get reportResolvedNoAnswer => 'Resolvido';

  @override
  String reportAnswer(String answer) {
    return 'Resolvido: $answer';
  }

  @override
  String reportAnswered(String song, String answer) {
    return 'O teu relato sobre «$song» foi resolvido: $answer';
  }

  @override
  String reportAnsweredNoText(String song) {
    return 'O teu relato sobre «$song» foi resolvido.';
  }

  @override
  String reportsAnswered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dos teus relatos foram resolvidos.',
      one: '1 dos teus relatos foi resolvido.',
    );
    return '$_temp0';
  }

  @override
  String get screenshotAdd => 'Anexar captura';

  @override
  String get screenshotRemove => 'Remover';

  @override
  String get screenshotMarkTitle => 'Marcar o local';

  @override
  String get screenshotMarkHint => 'Desenha na captura onde está o erro.';

  @override
  String get screenshotAttach => 'Anexar';

  @override
  String get screenshotShow => 'Ver a captura em tamanho real';

  @override
  String get screenshotLoading => 'A carregar a captura …';

  @override
  String get screenshotUnavailable => 'Captura indisponível (offline?)';

  @override
  String get lineup => 'Formação';

  @override
  String get lineupWholeBand => 'Toda a banda';

  @override
  String get lineupSubstitute => 'Substituto';

  @override
  String get lineupBandMembers => 'Membros da banda';

  @override
  String get lineupSubstitutes => 'Substitutos';

  @override
  String get lineupNotPlanned => 'Não estás previsto';

  @override
  String get lineupEdit => 'Escolher a formação';

  @override
  String get lineupAddPeople => 'Adicionar pessoas';

  @override
  String get lineupSearchPeople => 'Procurar pessoas';

  @override
  String get lineupNoMorePeople =>
      'Todas as pessoas da organização já estão na formação.';

  @override
  String get lineupNoAccount => 'Sem conta';

  @override
  String get lineupPeopleWithoutAccount => 'Pessoas sem conta';

  @override
  String get lineupNewContact => 'Nova pessoa sem conta';

  @override
  String get contactEmail => 'Endereço de e-mail (opcional)';

  @override
  String get contactEmailHint =>
      'Só a veem as pessoas que planeiam sets. «Avisar a formação» escreve para este endereço.';

  @override
  String get contactNameHint => 'Só é preciso o nome próprio.';

  @override
  String get contactsHint =>
      'Pessoas que tocam convosco mas não usam o setDING. Podem fazer parte da formação dos sets.';

  @override
  String get contactEditTitle => 'Editar pessoa';

  @override
  String get contactInvite => 'Convidar para o setDING';

  @override
  String get contactInviteChooseBand => 'Convidar para que banda?';

  @override
  String contactDeleteTitle(String name) {
    return 'Eliminar $name?';
  }

  @override
  String contactDeleteMessage(String name) {
    return '$name deixa de ser proposto para formações e o endereço de e-mail é removido. Os sets em que $name figura mantêm o nome.';
  }

  @override
  String contactInviteTitle(String name) {
    return 'Convite pessoal para $name';
  }

  @override
  String contactInviteHint(String date, String name) {
    return 'O link serve uma vez, até $date. Quem criar uma conta com ele fica com os sets em que $name está previsto.';
  }

  @override
  String get contactInviteSubject => 'Convite para o setDING';

  @override
  String contactInviteBody(String name, String organization, String url) {
    return 'Olá, $name\n\nEstás convidado a juntar-te a $organization no setDING, onde encontras os acordes das nossas músicas e os sets em que estás previsto. Abre este link para criar a tua conta:\n$url';
  }

  @override
  String joinPersonal(String name) {
    return 'Este convite é para $name.';
  }

  @override
  String joinPersonalExplanation(String name) {
    return 'A tua conta fica com os sets em que $name está previsto.';
  }

  @override
  String get joinPersonalButton => 'Aceitar o convite';

  @override
  String get lineupNobody => 'Ninguém previsto';

  @override
  String get lineupWholeBandHint =>
      'A formação segue a banda, incluindo novos membros.';

  @override
  String get bandSubstituteHint =>
      'Tocas alguns sets desta banda como substituto e só vês esses sets.';

  @override
  String get overviewAsSubstitute => 'Como substituto';

  @override
  String get lineupNotify => 'Avisar a formação';

  @override
  String get lineupCopy => 'Copiar';

  @override
  String get lineupCopied => 'Texto copiado';

  @override
  String get lineupMail => 'Por e-mail';

  @override
  String get lineupShare => 'Partilhar …';

  @override
  String get lineupNoAddresses =>
      'Sem ligação ao servidor: escolhe tu os destinatários.';

  @override
  String lineupMessageIntro(String set) {
    return 'Estão previstos para «$set».';
  }

  @override
  String get lineupMessageFooter => 'Encontram as músicas no setDING.';

  @override
  String get overviewPlanned => 'Estás previsto';

  @override
  String get overviewPlannedSeen => 'Entendido';

  @override
  String linkSwitchedTo(String name) {
    return 'Mudou para $name';
  }

  @override
  String get linkNotAvailableTitle => 'Não disponível neste dispositivo';

  @override
  String get linkNotAvailableMessage =>
      'Ainda não está sincronizado neste dispositivo, ou não tens acesso.';

  @override
  String get linkNoAccessMessage =>
      'Não disponível: foi eliminado, ou não tens acesso.';

  @override
  String get linkSignInMessage => 'Inicia sessão para o veres.';

  @override
  String get linkShare => 'Partilhar link';

  @override
  String get linkCopied => 'Link copiado';

  @override
  String attachmentOnlyHere(String reason) {
    return 'Só neste dispositivo: $reason';
  }

  @override
  String get uploadRefusalNotAllowed => 'sem permissão para carregar';

  @override
  String get uploadRefusalTooLarge =>
      'o ficheiro é demasiado grande para o servidor';

  @override
  String get uploadRefusalOther => 'recusado pelo servidor';

  @override
  String attachmentUploadRefused(String name, String song, String reason) {
    return 'O servidor não aceitou “$name” de “$song” ($reason). O anexo fica só neste dispositivo.';
  }

  @override
  String attachmentUploadsRefused(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'O servidor não aceitou $count anexos. Ficam só neste dispositivo.',
      one: 'O servidor não aceitou 1 anexo. Fica só neste dispositivo.',
    );
    return '$_temp0';
  }

  @override
  String get retryUpload => 'Carregar de novo';

  @override
  String get uploadRefusalStorageFull =>
      'o armazenamento da organização está cheio';

  @override
  String attachmentChangeUndone(String name, String song) {
    return 'O servidor não aceitou a alteração de “$name” de “$song”. Foi desfeita neste dispositivo.';
  }

  @override
  String attachmentChangesUndone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'O servidor não aceitou as alterações de $count anexos. Foram desfeitas neste dispositivo.',
      one: 'O servidor não aceitou a alteração de 1 anexo. Foi desfeita neste dispositivo.',
    );
    return '$_temp0';
  }

  @override
  String attachmentPdfLimit(String limit) {
    return 'PDF ou imagem, no máximo $limit';
  }

  @override
  String storageFree(String free, String limit) {
    return '$free livres de $limit';
  }

  @override
  String get storageTitle => 'Armazenamento';

  @override
  String storageUsage(String used, String limit) {
    return 'Armazenamento: $used de $limit';
  }

  @override
  String storageUsageUnlimited(String used) {
    return 'Armazenamento: $used';
  }

  @override
  String get storageTrashCounts =>
      'Os anexos eliminados contam até serem eliminados definitivamente.';

  @override
  String get storageNearlyFull =>
      'O armazenamento da organização está quase cheio.';

  @override
  String attachmentDoesNotFit(
    String name,
    String size,
    String used,
    String limit,
  ) {
    return '«$name» ($size) já não cabe no armazenamento da organização: $used de $limit ocupados. Os anexos eliminados contam até serem eliminados definitivamente.';
  }

  @override
  String trashAttachmentOf(String song, String size) {
    return 'Anexo em «$song» · $size';
  }

  @override
  String importSkippedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anexos não foram importados porque são demasiado grandes:',
      one: '1 anexo não foi importado porque é demasiado grande:',
    );
    return '$_temp0';
  }

  @override
  String importSkippedFile(String song, String size, String limit) {
    return '«$song» · $size (no máximo $limit)';
  }

  @override
  String attachmentWrongType(String name, String type) {
    return '«$name» não é um ficheiro $type válido e não pode ser anexado.';
  }

  @override
  String importSkippedWrongType(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count imagens não foram importadas porque o conteúdo não corresponde ao tipo de ficheiro:',
      one: '1 imagem não foi importada porque o conteúdo não corresponde ao tipo de ficheiro:',
    );
    return '$_temp0';
  }
}
