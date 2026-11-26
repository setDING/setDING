// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'setDING';

  @override
  String get navSets => 'Sets';

  @override
  String get navSongs => 'Canciones';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get edit => 'Editar';

  @override
  String get add => 'Añadir';

  @override
  String get ok => 'OK';

  @override
  String get close => 'Cerrar';

  @override
  String get rename => 'Renombrar';

  @override
  String get discard => 'Descartar';

  @override
  String get untitled => 'Sin título';

  @override
  String errorGeneric(String error) {
    return 'Algo salió mal: $error';
  }

  @override
  String get songsEmpty =>
      'Aún no hay canciones. Crea una canción nueva o importa archivos ChordPro.';

  @override
  String get searchSongs => 'Buscar canciones';

  @override
  String get searchClear => 'Borrar búsqueda';

  @override
  String get newSong => 'Nueva canción';

  @override
  String get newPdfSong => 'Nueva canción PDF';

  @override
  String get importFiles => 'Importar archivos';

  @override
  String get importTitle => 'Importar archivos ChordPro';

  @override
  String get importDescription =>
      'Compatibles: .cho, .chordpro, .chopro, .crd, .pro, .txt, archivos ZIP con estos archivos y copias de seguridad de setDING.';

  @override
  String get importGermanNotation =>
      'Los archivos usan la notación alemana (H/B)';

  @override
  String get importGermanNotationHint =>
      'Los acordes se convierten a la notación internacional al importar.';

  @override
  String get importOpenAfter => 'Abrir después de importar';

  @override
  String get importOpenAfterHint =>
      'Si se importa una sola canción, se abre enseguida.';

  @override
  String get chooseFiles => 'Elegir archivos';

  @override
  String importResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones importadas',
      one: '1 canción importada',
      zero: 'No se importó ninguna canción',
    );
    return '$_temp0';
  }

  @override
  String importSkipped(String files) {
    return 'Omitidos: $files';
  }

  @override
  String get deleteSongTitle => '¿Eliminar la canción?';

  @override
  String deleteSongMessage(String title) {
    return '\"$title\" se eliminará y se quitará de todos los sets.';
  }

  @override
  String get attachmentsTooltip => 'Tiene adjuntos PDF';

  @override
  String get keyOriginal => 'Original';

  @override
  String get capo => 'Cejilla';

  @override
  String capoValue(int fret) {
    return 'Cejilla $fret';
  }

  @override
  String capoLabel(int fret) {
    return 'Cejilla: $fret';
  }

  @override
  String capoLabelWithKey(int fret, String key) {
    return 'Cejilla: $fret ($key)';
  }

  @override
  String capoAsInSongLabel(String capo) {
    return '$capo, como en la canción';
  }

  @override
  String get noCapo => 'Sin cejilla';

  @override
  String capoAsInSong(int fret) {
    return 'Cejilla $fret (como en la canción)';
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
  String get notes => 'Mis notas';

  @override
  String get notesHint => 'Solo tú ves esta nota.';

  @override
  String get editSource => 'Editar ChordPro';

  @override
  String get attachments => 'Adjuntos';

  @override
  String get addAttachment => 'Adjuntar archivo';

  @override
  String get noAttachments => 'Aún no hay adjuntos.';

  @override
  String get attachmentTooLarge =>
      'El archivo supera los 20 MB y no se puede adjuntar.';

  @override
  String get songLinks => 'Fuentes';

  @override
  String get noSongLinks =>
      'Aún no hay fuentes. Añade grabaciones de YouTube, Spotify y similares.';

  @override
  String get addSongLink => 'Añadir enlace';

  @override
  String get editSongLink => 'Editar enlace';

  @override
  String get deleteSongLink => 'Quitar fuente';

  @override
  String get deleteSongLinkMessage => '¿Quitar esta fuente de la canción?';

  @override
  String get songLinkUrl => 'Enlace (URL)';

  @override
  String get songLinkLabel => 'Etiqueta (opcional)';

  @override
  String get songLinkLabelHint => 'Live 2009';

  @override
  String get songLinkInvalid =>
      'Introduce un enlace web que empiece por https:// (sin |).';

  @override
  String get songLinkFailed => 'No se pudo abrir el enlace.';

  @override
  String songSelectNumber(String number) {
    return 'Número CCLI $number';
  }

  @override
  String get attachmentName => 'Nombre del adjunto';

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
  String get liveView => 'Mostrar en modo en vivo';

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
  String get openFileFailed => 'Ninguna app pudo abrir el archivo.';

  @override
  String get playLive => 'Tocar en vivo';

  @override
  String get live => 'En vivo';

  @override
  String get chordView => 'Vista de acordes';

  @override
  String get useDeviceSetting => 'Como en los ajustes';

  @override
  String get on => 'Activado';

  @override
  String get off => 'Desactivado';

  @override
  String get fontLarger => 'Texto más grande';

  @override
  String get fontSmaller => 'Texto más pequeño';

  @override
  String get fitToPage => 'Ajustar a la página';

  @override
  String get resetAdjustments => 'Restablecer ajustes personales';

  @override
  String get personalAdjustments => 'Ajustes personales';

  @override
  String get scopePersonal =>
      'Solo para ti: la canción no cambia para nadie más.';

  @override
  String get scopeSet => 'Para este set: se aplica a toda la banda.';

  @override
  String get scopeBand => 'Para toda la banda: se aplica en todos sus sets.';

  @override
  String get scopeSong =>
      'Para la canción: la cambia para todos en la organización.';

  @override
  String get keyPickerPersonal => 'Mi tonalidad – solo para mí';

  @override
  String get keyPickerSet => 'Tonalidad en este set – para toda la banda';

  @override
  String get keyPickerBand => 'Tonalidad de la banda – para todos sus sets';

  @override
  String get editTitle => 'Editar título';

  @override
  String get title => 'Título';

  @override
  String get artist => 'Artista';

  @override
  String get noContent => 'Esta canción aún no tiene texto ChordPro.';

  @override
  String get addChordPro => 'Añadir texto ChordPro';

  @override
  String keyLabel(String key) {
    return 'Tonalidad: $key';
  }

  @override
  String bpm(int tempo) {
    return '$tempo BPM';
  }

  @override
  String get noKeyForDegrees =>
      'Los números Nashville y los números romanos necesitan una tonalidad en la canción.';

  @override
  String get firstVerseChordsOnly => 'Acordes solo en la estrofa 1';

  @override
  String get noVersesForFirstVerseChords =>
      'La canción no tiene más estrofas con acordes.';

  @override
  String get verseChords => 'Acordes en las estrofas';

  @override
  String get verseChordsAll => 'Acordes en todas las estrofas';

  @override
  String get verseChordsStacked => 'Estrofas apiladas';

  @override
  String get chorusesStacked => 'Estribillos apilados';

  @override
  String get editorTitleNew => 'Nueva canción';

  @override
  String get editorTitleEdit => 'Editar canción';

  @override
  String get editorTab => 'Texto';

  @override
  String get previewTab => 'Vista previa';

  @override
  String get insertVerse => 'Insertar verse';

  @override
  String get insertChorus => 'Insertar chorus';

  @override
  String get insertBridge => 'Insertar bridge';

  @override
  String get insertComment => 'Insertar comentario';

  @override
  String get insertChord => 'Insertar acorde';

  @override
  String get discardChangesTitle => '¿Descartar los cambios?';

  @override
  String get discardChangesMessage => 'Tus cambios aún no se han guardado.';

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
      'Aún no hay sets. Crea un set para tu próximo concierto.';

  @override
  String get newSet => 'Nuevo set';

  @override
  String get editSet => 'Editar set';

  @override
  String get setName => 'Nombre';

  @override
  String get gigDate => 'Fecha';

  @override
  String get venue => 'Lugar';

  @override
  String get noDate => 'Sin fecha';

  @override
  String get pickDate => 'Elegir fecha';

  @override
  String get clearDate => 'Quitar fecha';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos',
      one: '1 elemento',
      zero: 'Vacío',
    );
    return '$_temp0';
  }

  @override
  String offlineMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones no disponibles sin conexión',
      one: '1 canción no disponible sin conexión',
    );
    return '$_temp0';
  }

  @override
  String get offlineMissingTooltip =>
      'No todas las canciones y PDF de este set están en el dispositivo. Conéctalo a la red y espera la sincronización.';

  @override
  String syncStale(String time) {
    return 'Última sincronización con el servidor: $time. Puede que los sets de este dispositivo no estén actualizados.';
  }

  @override
  String get syncStaleNever =>
      'Este dispositivo aún no se ha sincronizado con el servidor. Puede que los sets no estén actualizados.';

  @override
  String syncUnsent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cambios de este dispositivo aún no han llegado',
      one: '1 cambio de este dispositivo aún no ha llegado',
    );
    return '$_temp0 al servidor.';
  }

  @override
  String get addSongs => 'Añadir canciones';

  @override
  String get pause => 'Pausa';

  @override
  String get textItem => 'Texto';

  @override
  String get markerIconBreak => 'Pausa';

  @override
  String get markerIconDrinks => 'Bebidas';

  @override
  String get markerIconAnnouncement => 'Anuncio';

  @override
  String get markerIconMicrophone => 'Discurso';

  @override
  String get markerIconGuest => 'Invitado';

  @override
  String get markerIconEncore => 'Bis';

  @override
  String get markerIconTransition => 'Transición';

  @override
  String get markerIconSolo => 'Solo';

  @override
  String get markerIconApplause => 'Aplausos';

  @override
  String get markerIconInstrument => 'Cambio de instrumento';

  @override
  String get markerIconTuning => 'Afinación';

  @override
  String get markerIconClick => 'Clic';

  @override
  String get markerIconLight => 'Luz';

  @override
  String get markerIconEffects => 'Efectos';

  @override
  String get markerIconCelebration => 'Celebración';

  @override
  String get markerIconInfo => 'Nota';

  @override
  String get markerIconWarning => 'Atención';

  @override
  String get marker => 'Marcador';

  @override
  String get addMarker => 'Añadir marcador';

  @override
  String get editMarker => 'Editar marcador';

  @override
  String get markerText => 'Texto';

  @override
  String get markerPreview => 'Vista previa';

  @override
  String get markerGroupBreak => 'Pausa';

  @override
  String get markerGroupAnnouncement => 'Anuncio';

  @override
  String get markerGroupFlow => 'Desarrollo';

  @override
  String get markerGroupStage => 'Escenario';

  @override
  String get markerGroupShow => 'Show';

  @override
  String get markerGroupGeneral => 'General';

  @override
  String get setEmpty => 'Este set está vacío. Añade algunas canciones.';

  @override
  String get deleteSetTitle => '¿Eliminar el set?';

  @override
  String deleteSetMessage(String name) {
    return '\"$name\" se eliminará. Las canciones se conservan.';
  }

  @override
  String get removeFromSet => 'Quitar del set';

  @override
  String get selectSongs => 'Seleccionar canciones';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seleccionadas',
      one: '1 seleccionada',
      zero: 'Ninguna seleccionada',
    );
    return '$_temp0';
  }

  @override
  String get songMissing => 'La canción ya no existe';

  @override
  String liveNext(String title) {
    return 'Siguiente: $title';
  }

  @override
  String get liveWebNotice =>
      'En el navegador no es seguro sin conexión: en el escenario, usa la app';

  @override
  String liveMidiConnected(String name) {
    return 'Teclado conectado: $name';
  }

  @override
  String get liveMidiNotConnected => 'Teclado no conectado';

  @override
  String get liveMidiSendAgain => 'Enviar programa de nuevo';

  @override
  String get liveMidiButton =>
      'Programa del teclado (pulsación larga: enviar de nuevo)';

  @override
  String get liveMidiChange => 'Cambiar programa';

  @override
  String get liveMidiSameAsPrevious => 'Igual que la canción anterior';

  @override
  String liveMidiPreviousProgram(String program, String title) {
    return '$program – de “$title”';
  }

  @override
  String get liveMidiNoPrevious => 'Ninguna canción anterior con un programa';

  @override
  String get liveMidiSaved => 'Programa del teclado guardado';

  @override
  String get liveMidiRemoved => 'Programa del teclado quitado';

  @override
  String get liveMidiTakeOverWaiting => 'Elige un sonido en el teclado';

  @override
  String liveMidiTakeOver(String program) {
    return 'Adoptar: $program';
  }

  @override
  String get liveMidiTakeOverHint =>
      'setDING adopta el programa que envía el teclado.';

  @override
  String get liveMidiTakeOverNordHint =>
      '¿No llega nada? En el Nord, ajusta “Program Change” a “Send” o “Send & Receive” en el menú MIDI.';

  @override
  String get liveMidiTakeOverSame => 'Este ya es el programa de la canción';

  @override
  String get liveWakeLockNotice =>
      'La pantalla podría apagarse: revisa los ajustes de energía del dispositivo';

  @override
  String get liveEnd => 'Fin del set';

  @override
  String get liveSetOverview => 'Resumen del set';

  @override
  String get liveExit => 'Salir del modo en vivo';

  @override
  String liveSongPage(int page, int count) {
    return 'Página $page/$count';
  }

  @override
  String livePosition(int current, int total) {
    return '$current / $total';
  }

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionDisplay => 'Visualización';

  @override
  String get settingsSectionLive => 'Pantalla y modo en vivo';

  @override
  String get settingsSectionStorage => 'Almacenamiento e información';

  @override
  String get settingsSectionMusician => 'Músico';

  @override
  String get settingsCategoryAccountHint =>
      'Inicio de sesión, servidor y sincronización';

  @override
  String get settingsCategoryGeneralHint => 'Idioma y tema';

  @override
  String get settingsCategoryMusicianHint =>
      'Instrumento, voz, diagramas de acordes, pulso';

  @override
  String get settingsCategoryDisplayHint =>
      'Notación de acordes, Nashville y números romanos, contenido, estribillo, progreso';

  @override
  String get settingsCategoryLiveHint =>
      'Tamaño de letra, ajustar a la pantalla, columnas, pasar página';

  @override
  String get settingsCategoryAboutHint =>
      'Almacenamiento, registro de diagnóstico y versión';

  @override
  String get settingsInstrument => 'Mi instrumento';

  @override
  String get settingsInstrumentHint =>
      'Se usa para las partes condicionales (p. ej. solo guitarra) y para los diagramas de acordes.';

  @override
  String get instrumentGuitar => 'Guitarra';

  @override
  String get instrumentUkulele => 'Ukelele';

  @override
  String get instrumentBass => 'Bajo';

  @override
  String get instrumentKeyboard => 'Teclado';

  @override
  String get instrumentVocals => 'Voz';

  @override
  String get instrumentDrums => 'Batería';

  @override
  String get instrumentOther => 'Otro …';

  @override
  String get settingsUserName => 'Voz o papel (opcional)';

  @override
  String get settingsUserNameHint =>
      'Tu instrumento ya cuenta. Solo hace falta si una canción tiene partes para voces o personas concretas, p. ej. “alto” o “tenor”.';

  @override
  String settingsUserNameIsInstrument(String name) {
    return '“$name” es un instrumento. El ajuste de instrumento ya lo cubre, así que puedes dejar este campo vacío.';
  }

  @override
  String get settingsDiagrams => 'Diagramas de acordes';

  @override
  String get settingsDiagramsHint =>
      'Muestra las digitaciones de todos los acordes de la canción para tu instrumento. Una canción puede definirlo ella misma con la directiva diagrams.';

  @override
  String get settingsBassStrings => 'Cuerdas del bajo';

  @override
  String get settingsBassStringsHint =>
      'Los diagramas de acordes muestran un bajo de 4 cuerdas (E-A-D-G) o un bajo de 5 cuerdas con una cuerda de si grave.';

  @override
  String bassStringCount(int count) {
    return '$count cuerdas';
  }

  @override
  String get diagramsOff => 'Desactivados';

  @override
  String get diagramsTop => 'Arriba';

  @override
  String get diagramsBottom => 'Abajo';

  @override
  String get notSet => 'Sin definir';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get languageSystem => 'Idioma del sistema';

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
  String get themeSystem => 'Como el sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get settingsAccent => 'Color de acento';

  @override
  String get accentBrand => 'Azul setDING';

  @override
  String get accentRed => 'Rojo';

  @override
  String get accentAmber => 'Ámbar';

  @override
  String get accentGreen => 'Verde';

  @override
  String get accentTeal => 'Verde azulado';

  @override
  String get accentPurple => 'Morado';

  @override
  String get accentPink => 'Rosa';

  @override
  String get settingsNotation => 'Notación de acordes';

  @override
  String get notationInternational => 'Internacional (B, Bb)';

  @override
  String get notationGerman => 'Alemana (H, B)';

  @override
  String get settingsChordView => 'Mostrar acordes como';

  @override
  String get settingsChordViewHint =>
      'Acordes (Am7), números Nashville (6m7) o números romanos (vi7). Los números necesitan una tonalidad en la canción.';

  @override
  String get settingsNumeralSpelling => 'Escritura de números romanos';

  @override
  String get settingsNumeralSpellingHint =>
      'Cómo muestran el acorde los números romanos: con mayúsculas y minúsculas, ii7 – V7 – IΔ7, o en mayúsculas con el símbolo del acorde, IIm7 – V7 – Imaj7. El símbolo del acorde sigue el estilo de acordes.';

  @override
  String get numeralSpellingCasing => 'Mayúsculas/minúsculas';

  @override
  String get numeralSpellingChordSymbol => 'Símbolo del acorde';

  @override
  String get settingsChordStyle => 'Estilo de acordes';

  @override
  String get settingsChordStyleHint =>
      'Cómo se escriben los acordes, p. ej. Am7, Cmaj7, Em7b5 (estándar) o A−7, CΔ7, Eø7 (jazz). La canción en sí no se modifica.';

  @override
  String get chordStyleAsWritten => 'Tal como está escrito';

  @override
  String get chordStyleStandard => 'Estándar';

  @override
  String get chordStyleJazz => 'Jazz';

  @override
  String get settingsChordSuperscript => 'Extensiones en superíndice';

  @override
  String get settingsChordSuperscriptHint =>
      'Muestra extensiones y alteraciones más pequeñas y elevadas, p. ej. C⁷. Requiere el estilo estándar o jazz.';

  @override
  String get settingsDisplayMode => 'Contenido';

  @override
  String get displayLyricsAndChords => 'Letra y acordes';

  @override
  String get displayLyricsOnly => 'Solo letra';

  @override
  String get settingsFontSize => 'Tamaño de letra';

  @override
  String get settingsColumns => 'Columnas';

  @override
  String get columnsAuto => 'Automático';

  @override
  String get columnsOne => 'Una';

  @override
  String get columnsTwo => 'Dos';

  @override
  String get settingsPageTurn => 'Pasar página';

  @override
  String get pageTurnFull => 'Página completa';

  @override
  String get pageTurnHalf => 'Media página';

  @override
  String get settingsAutoFit => 'Ajustar la canción a la pantalla';

  @override
  String get settingsAutoFitHint =>
      'Toda la canción cabe en la pantalla sin desplazarse. Las secciones se organizan automáticamente en columnas y el texto es lo más grande posible.';

  @override
  String get settingsColumnsHint =>
      'Al ajustar a la pantalla, el número máximo de columnas permitido.';

  @override
  String get columnsThree => 'Tres';

  @override
  String get settingsChorusRepeat => 'Estribillo repetido';

  @override
  String get settingsChorusRepeatHint =>
      'Automático: un estribillo repetido se muestra solo como etiqueta corta si la canción de otro modo no cabría bien en la pantalla.';

  @override
  String get chorusRepeatAuto => 'Automático';

  @override
  String get chorusRepeatFull => 'Mostrar completo';

  @override
  String get chorusRepeatLabel => 'Solo etiqueta';

  @override
  String get settingsPageTurnHint =>
      'Toca el lado izquierdo o derecho de la pantalla para retroceder o avanzar. Pasapáginas (pedal) y teclado: flecha derecha, flecha abajo, Av Pág y Espacio avanzan; flecha izquierda, flecha arriba y Re Pág retroceden. Con un pulso (tempo y pulso o clic activados), mantener avanzar o pulsar Intro lo inicia y lo detiene.';

  @override
  String get settingsSetProgress => 'Barra de progreso del set';

  @override
  String get settingsSetProgressHint =>
      'Una barra fina sobre la barra inferior muestra las canciones del set y las páginas de la canción actual: la página actual en el color de acento, las páginas siguientes en un tono más claro. Los marcadores como las pausas aparecen discontinuos.';

  @override
  String get settingsBeatSection => 'Pulso y clic';

  @override
  String get settingsBeatSectionHint =>
      'Tempo y compás de la canción, o el tempo del arreglo de la banda. Activado por defecto si tu instrumento es la batería.';

  @override
  String get settingsBeatDisplay => 'Indicador de pulso';

  @override
  String get settingsBeatDisplayHint =>
      'Los puntos junto al tempo y al compás se iluminan en cada tiempo; la cuenta previa muestra números grandes.';

  @override
  String get settingsEdgeFlash => 'Hacer parpadear el borde de la pantalla';

  @override
  String get settingsEdgeFlashHint =>
      'El borde parpadea en cada tiempo, el 1 en otro color: visible con el rabillo del ojo.';

  @override
  String get settingsClick => 'Clic';

  @override
  String get settingsClickHint =>
      'Reproduce un clic en la salida de audio del dispositivo, p. ej. en la mezcla in-ear.';

  @override
  String get settingsClickStart => 'Inicio';

  @override
  String get settingsClickStartHint =>
      'Manualmente: toca el tempo, mantén el pedal de avanzar o pulsa Intro. Pasar a otra canción del set detiene el pulso.';

  @override
  String get clickStartAutomatic => 'Con cada canción';

  @override
  String get clickStartManual => 'Manualmente';

  @override
  String get settingsClickDuration => 'Duración';

  @override
  String get clickDurationSong => 'Toda la canción';

  @override
  String get clickDurationCountIn => 'Solo cuenta previa';

  @override
  String get settingsClickInBackground => 'En segundo plano';

  @override
  String get settingsClickInBackgroundHint =>
      'Cuando la app está minimizada, se abre otra app o la pantalla está bloqueada.';

  @override
  String get clickInBackgroundStop => 'Detener';

  @override
  String get clickInBackgroundKeepPlaying => 'Seguir sonando';

  @override
  String get settingsCountIn => 'Cuenta previa';

  @override
  String get countInOff => 'Desactivada';

  @override
  String get countInOneBar => '1 compás';

  @override
  String get countInTwoBars => '2 compases';

  @override
  String get settingsClickVolume => 'Volumen';

  @override
  String get settingsClickAccent => 'Acento en el 1';

  @override
  String get settingsClickSound => 'Sonido';

  @override
  String get clickSoundClick => 'Clic';

  @override
  String get clickSoundWoodblock => 'Woodblock';

  @override
  String get clickSoundBeep => 'Pitido';

  @override
  String get settingsClickSubdivision => 'Subdivisiones';

  @override
  String get settingsClickSubdivisionHint =>
      'Clics más suaves entre los tiempos. Cada canción puede tener las suyas en sus ajustes personales.';

  @override
  String get subdivisionOff => 'Desactivadas';

  @override
  String get subdivisionEighths => 'Corcheas';

  @override
  String get subdivisionSixteenths => 'Semicorcheas';

  @override
  String get subdivisionTriplets => 'Tresillos';

  @override
  String clickSubdivisionAsInSettings(String value) {
    return 'Como en los ajustes ($value)';
  }

  @override
  String get clickGrouping => 'Agrupación';

  @override
  String get clickGroupingNone => 'Sin grupos';

  @override
  String clickGroupingAsInSong(String grouping) {
    return 'Como en la canción ($grouping)';
  }

  @override
  String get clickGroupingHint =>
      'Tiempos acentuados de un compás irregular, solo para ti.';

  @override
  String get settingsAudioLatency => 'Retardo de audio';

  @override
  String get settingsAudioLatencyHint =>
      'Desplaza la visualización para que coincida con lo que oyes. Los auriculares con cable necesitan poco, los Bluetooth 100–300 ms.';

  @override
  String audioLatencyValue(int ms) {
    return '$ms ms';
  }

  @override
  String get audioLatencyCalibrate => 'Medir el retardo de audio';

  @override
  String get audioLatencyCalibrateTitle => 'Medir el retardo de audio';

  @override
  String get audioLatencyCalibrateHint =>
      'Ponte los auriculares que usas en el escenario y toca al ritmo de cada tiempo del clic.';

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
      'En este dispositivo no hay salida de audio para el clic.';

  @override
  String get beatStart => 'Iniciar el pulso';

  @override
  String get beatStop => 'Detener el pulso';

  @override
  String get beatDisplayLabel => 'Pulso';

  @override
  String countInBar(int bar, int count) {
    return 'Compás $bar de $count';
  }

  @override
  String get tempoSlower => 'Más lento';

  @override
  String get tempoFaster => 'Más rápido';

  @override
  String get tapTempo => 'Tap tempo';

  @override
  String get tempoReset => 'Volver al tempo de la canción';

  @override
  String get clickNoAudioLive => 'Sin audio para el clic';

  @override
  String get settingsSongMap => 'Mapa de la canción en lugar de acordes';

  @override
  String get settingsSongMapHint =>
      'El modo en vivo muestra las partes de la canción con una referencia de la letra y las notas de batería.';

  @override
  String get songMapEmpty =>
      'Esta canción no tiene partes (verse, chorus, …) para mostrar como mapa de la canción.';

  @override
  String get songMapNoTempo => 'Sin tempo para esta canción';

  @override
  String get drumPanelSet => 'Set';

  @override
  String get drumPanelSongMap => 'Mapa de la canción';

  @override
  String get settingsLiveAppearance => 'Aspecto en el escenario';

  @override
  String get settingsLiveAppearanceHint =>
      'El modo en vivo, independiente del tema de la app. El negro ahorra energía en pantallas OLED.';

  @override
  String get liveAppearanceApp => 'Como la app';

  @override
  String get liveAppearanceDark => 'Oscuro';

  @override
  String get liveAppearanceBlack => 'Negro';

  @override
  String settingsStorageUsed(String size) {
    return 'Los adjuntos PDF ocupan $size';
  }

  @override
  String get appMenuEntryAdd => 'Añadir al menú de aplicaciones';

  @override
  String get appMenuEntryAddHint =>
      'setDING con su icono en el menú de inicio de tu escritorio';

  @override
  String get appMenuEntryInstalled => 'En el menú de aplicaciones';

  @override
  String get appMenuEntryInstalledHint =>
      'El menú de inicio abre este archivo AppImage';

  @override
  String get appMenuEntryRemove => 'Quitar';

  @override
  String get appMenuEntryAdded => 'setDING ya está en el menú de aplicaciones';

  @override
  String get appMenuEntryRemoved => 'setDING quitado del menú de aplicaciones';

  @override
  String appMenuEntryFailed(String error) {
    return 'Menú de aplicaciones sin cambios: $error';
  }

  @override
  String get settingsLogCopy => 'Copiar registro de diagnóstico';

  @override
  String get settingsLogCopyHint =>
      'Los mensajes recientes de la app, p. ej. por qué falló una sincronización, para pegarlos en un mensaje al soporte.';

  @override
  String get settingsLogCopied => 'Registro de diagnóstico copiado';

  @override
  String get settingsAbout =>
      'setDING funciona localmente en este dispositivo. Todos los datos están disponibles sin conexión.';

  @override
  String settingsVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get lilypondNotice =>
      'Esta notación Lilypond usa funciones que setDING no puede dibujar. Fuente:';

  @override
  String get sequenceLabel => 'Secuencia de la canción';

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
  String get editorGroupSections => 'Secciones';

  @override
  String get editorGroupInfo => 'Info de la canción';

  @override
  String get editorGroupText => 'Texto';

  @override
  String get editorGroupMore => 'Más';

  @override
  String get searchMatchCase => 'Distinguir mayúsculas';

  @override
  String get replaceToggle => 'Reemplazar';

  @override
  String get replaceWith => 'Reemplazar por';

  @override
  String get replace => 'Reemplazar';

  @override
  String get replaceAll => 'Reemplazar todo';

  @override
  String replacedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reemplazados',
      one: '1 reemplazado',
    );
    return '$_temp0';
  }

  @override
  String get convertChordsOverLyrics => 'Convertir acordes sobre la letra';

  @override
  String get pastedChordsOverLyrics =>
      'El texto pegado tiene los acordes sobre la letra.';

  @override
  String get convert => 'Convertir';

  @override
  String get convertCcliGrids =>
      'Convertir barras de compás en cuadrículas de acordes';

  @override
  String ccliGridsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bloques de barras de compás se pueden',
      one: 'Un bloque de barras de compás se puede',
    );
    return '$_temp0 mostrar como cuadrícula de acordes.';
  }

  @override
  String get convertCommentHeadings =>
      'Convertir títulos de comentario en secciones';

  @override
  String get translateSectionLabels =>
      'Traducir los nombres de sección al inglés';

  @override
  String commentHeadingsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count secciones están marcadas',
      one: 'Una sección está marcada',
    );
    return '$_temp0 con un comentario como \"Verse 1\". Al convertir se crean secciones ChordPro; la canción se ve igual.';
  }

  @override
  String get remove => 'Quitar';

  @override
  String get ccliFooterHint =>
      'La canción termina con el pie CCLI de SongSelect. Al quitarlo, el número de canción y el copyright se mantienen en los detalles de la canción.';

  @override
  String legacyLabelsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count etiquetas de sección están',
      one: 'Una etiqueta de sección está',
    );
    return '$_temp0 en la forma corta. La especificación ChordPro recomienda label=\"…\".';
  }

  @override
  String songSelectDirectivesHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count directivas CCLI no siguen',
      one: 'Una directiva CCLI no sigue',
    );
    return '$_temp0 la especificación ChordPro: ccli pasa a x_ccli, footer pasa a x_ccli_footer, ccli_license se elimina.';
  }

  @override
  String importLegacyLabelsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones importadas escriben',
      one: '1 canción importada escribe',
    );
    return '$_temp0 las etiquetas de sección en la forma corta. Al convertir se escriben como label=\"…\", como recomienda la especificación ChordPro; las canciones se ven igual.';
  }

  @override
  String get convertLabels => 'Convertir etiquetas';

  @override
  String songsLabelsConverted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Etiquetas convertidas en $count canciones',
      one: 'Etiquetas convertidas en 1 canción',
      zero: 'No se convirtió ninguna etiqueta',
    );
    return '$_temp0';
  }

  @override
  String get hideHint => 'Ocultar sugerencia';

  @override
  String get searchInSong => 'Buscar';

  @override
  String get searchNoMatches => 'Sin coincidencias';

  @override
  String get searchPrevious => 'Coincidencia anterior';

  @override
  String get searchNext => 'Coincidencia siguiente';

  @override
  String get searchClose => 'Cerrar búsqueda';

  @override
  String searchMatchCount(int current, int total) {
    return '$current de $total';
  }

  @override
  String get editorGroupLines => 'Líneas';

  @override
  String get redo => 'Rehacer';

  @override
  String get moveLinesUp => 'Subir línea';

  @override
  String get moveLinesDown => 'Bajar línea';

  @override
  String get moveChordLeft => 'Mover acorde a la izquierda';

  @override
  String get moveChordRight => 'Mover acorde a la derecha';

  @override
  String get duplicateLines => 'Duplicar línea';

  @override
  String get deleteLines => 'Eliminar línea';

  @override
  String get toggleComment => 'Comentar línea (#)';

  @override
  String get insertOptionalChord => 'Acorde opcional';

  @override
  String get insertAnnotation => 'Anotación';

  @override
  String get insertNoChord => 'Sin acorde (N.C.)';

  @override
  String get insertDefine => 'Definición de acorde';

  @override
  String get insertChordDiagram => 'Diagrama de acorde';

  @override
  String get insertTranspose => 'Transponer';

  @override
  String get insertTab => 'Tab';

  @override
  String get insertGrid => 'Cuadrícula de acordes';

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
  String get metaYear => 'Año';

  @override
  String get metaAlbum => 'Álbum';

  @override
  String get metaDuration => 'Duración';

  @override
  String get metaTempo => 'Tempo (BPM)';

  @override
  String get metaTime => 'Compás';

  @override
  String get metaKey => 'Tonalidad';

  @override
  String get insertCommentItalic => 'Comentario (cursiva)';

  @override
  String get insertCommentBox => 'Comentario (recuadro)';

  @override
  String get insertHighlight => 'Resaltado';

  @override
  String get insertBold => 'Negrita';

  @override
  String get insertItalic => 'Cursiva';

  @override
  String get insertUnderline => 'Subrayado';

  @override
  String get insertColour => 'Color';

  @override
  String get insertColumnBreak => 'Salto de columna';

  @override
  String get insertNewPage => 'Salto de página';

  @override
  String get insertColumns => 'Columnas';

  @override
  String get insertImage => 'Imagen';

  @override
  String get insertAbc => 'Notación ABC';

  @override
  String get insertTextblock => 'Bloque de texto';

  @override
  String get insertNewSong => 'Siguiente canción en el mismo archivo';

  @override
  String get sequenceEdit => 'Secuencia de la canción para este set';

  @override
  String get sequenceFromSet => 'Secuencia cambiada para este set';

  @override
  String get sequenceFromBand => 'Secuencia de la banda';

  @override
  String get bandArrangement => 'Arreglo de la banda';

  @override
  String arrangementOf(String band) {
    return 'Arreglo de $band';
  }

  @override
  String get arrangementBand => 'Banda';

  @override
  String get arrangementAsWritten => 'Como en la canción';

  @override
  String arrangementKey(String key) {
    return 'Tonalidad $key';
  }

  @override
  String get arrangementSequence => 'Secuencia';

  @override
  String get arrangementTempo => 'Tempo';

  @override
  String get arrangementTempoLabel =>
      'Tempo en BPM (vacío = como en la canción)';

  @override
  String get arrangementReset =>
      'Restablecer el arreglo de la banda a la canción';

  @override
  String sequenceOriginal(Object sequence) {
    return 'En la canción: $sequence';
  }

  @override
  String get sequenceNoneInSong => 'La canción no tiene secuencia.';

  @override
  String get sequenceRestore => 'Usar la secuencia de la canción';

  @override
  String get sequenceHint => 'p. ej. I, V1, C, V2, PC, C x2, B, O';

  @override
  String get sequenceAbbreviations =>
      'I Intro · V Verse · PC Pre-chorus · C Chorus · B Bridge · Int Interlude · Solo · T Tag · O Outro · C x2 = dos veces';

  @override
  String get sequenceEmpty =>
      'Toca las partes de abajo para construir la secuencia, o arrástralas aquí.';

  @override
  String get sequenceReorderHint =>
      'Mantén pulsada una parte para moverla a otra posición.';

  @override
  String get sequenceSongParts => 'Partes de la canción';

  @override
  String get sequenceCommonParts =>
      'Partes comunes (la canción aún no tiene secciones)';

  @override
  String get sequenceClear => 'Vaciar';

  @override
  String get sequenceAsText => 'Editar como texto';

  @override
  String get settingsSectionAccount => 'Cuenta y sincronización';

  @override
  String get accountSignedOut => 'Sin sesión iniciada';

  @override
  String get accountSignedOutHint =>
      'Inicia sesión para compartir canciones y sets con tu banda. Sin cuenta, setDING sigue funcionando localmente en este dispositivo.';

  @override
  String get accountSignIn => 'Iniciar sesión';

  @override
  String get accountSignUp => 'Crear cuenta';

  @override
  String get accountJoin => 'Unirse con una invitación';

  @override
  String get accountSignOut => 'Cerrar sesión';

  @override
  String get accountSignOutTitle => '¿Cerrar sesión?';

  @override
  String get accountSignOutMessage =>
      'Las canciones y los sets de este dispositivo se conservan.';

  @override
  String get accountSignOutMessageWeb =>
      'Los datos de este navegador se eliminan. Las canciones y los sets se quedan en el servidor.';

  @override
  String get accountEmail => 'Correo electrónico';

  @override
  String get accountPassword => 'Contraseña';

  @override
  String get accountPasswordConfirm => 'Confirmar contraseña';

  @override
  String get accountPasswordShow => 'Mostrar contraseña';

  @override
  String get accountPasswordHide => 'Ocultar contraseña';

  @override
  String get accountKeepSignedIn => 'Mantener la sesión iniciada';

  @override
  String get accountKeepSignedInHint =>
      'Solo en tu propio dispositivo. Si no, se cierra la sesión al cerrar el navegador.';

  @override
  String get accountNameHint =>
      'P. ej. «Andi». Tus compañeros de banda lo ven en las listas en lugar de tu nombre completo.';

  @override
  String get accountFirstName => 'Nombre';

  @override
  String get accountLastName => 'Apellido';

  @override
  String get accountNickname => 'Nombre visible (opcional)';

  @override
  String get accountCompleteName => 'Completa tu nombre';

  @override
  String get accountCompleteNameMessage =>
      'Introduce tu nombre y apellido, así tus compañeros de banda te encuentran más fácilmente.';

  @override
  String get settingsHeadingPeople => 'Personas';

  @override
  String get settingsNameFormat => 'Mostrar nombres como';

  @override
  String get settingsNameFormatHint =>
      'Cómo aparecen otras personas en las listas de miembros, en las formaciones y en los cambios.';

  @override
  String get nameFormatNickname => 'Nombre visible (si no, nombre completo)';

  @override
  String get nameFormatFirstLast => 'Nombre Apellido';

  @override
  String get nameFormatLastFirst => 'Apellido Nombre';

  @override
  String get nameFormatFullWithNickname => 'Nombre Apellido (nombre visible)';

  @override
  String get accountToSignUp => '¿Aún no tienes cuenta? Crea una';

  @override
  String get accountToSignIn => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get accountForgotPassword => '¿Olvidaste la contraseña?';

  @override
  String get accountResetTitle => 'Restablecer contraseña';

  @override
  String get accountResetSent =>
      'Si existe una cuenta con esta dirección, se ha enviado un correo para restablecer la contraseña.';

  @override
  String get accountFieldRequired => 'Obligatorio.';

  @override
  String accountPasswordTooShort(int min) {
    return 'Al menos $min caracteres.';
  }

  @override
  String get accountPasswordMismatch => 'Las contraseñas no coinciden.';

  @override
  String get accountChangeName => 'Cambiar nombre';

  @override
  String get accountNameChanged => 'Nombre cambiado.';

  @override
  String get accountChangePassword => 'Cambiar contraseña';

  @override
  String get accountChangePasswordHint =>
      'Sigues con la sesión iniciada en este dispositivo. En tus otros dispositivos se cierra.';

  @override
  String get accountCurrentPassword => 'Contraseña actual';

  @override
  String get accountNewPassword => 'Contraseña nueva';

  @override
  String get accountPasswordWrongCurrent =>
      'La contraseña actual es incorrecta.';

  @override
  String get accountPasswordChanged =>
      'Contraseña cambiada. Vuelve a iniciar sesión en tus otros dispositivos.';

  @override
  String get accountDelete => 'Eliminar cuenta';

  @override
  String get accountDeleteHint =>
      'Elimina definitivamente tu cuenta y tus datos personales.';

  @override
  String get accountDeleteTitle => '¿Eliminar la cuenta?';

  @override
  String get accountDeleteMessage =>
      'Tu cuenta, tus ajustes personales, anotaciones y configuración se eliminan definitivamente y se cierra la sesión en todos los dispositivos. Las canciones y los sets se quedan en tus organizaciones. Las copias de seguridad del servidor guardan una copia hasta 14 días. Introduce tu contraseña para confirmar.';

  @override
  String get accountDeleteSoleAdmin =>
      'Eres el único admin de estas organizaciones. Primero haz admin a otra persona o cierra la organización:';

  @override
  String get accountDeleted => 'Tu cuenta se ha eliminado.';

  @override
  String get dangerZone => 'Zona de peligro';

  @override
  String get accountErrorNetwork =>
      'No hay conexión con el servidor. Comprueba tu conexión a Internet.';

  @override
  String get accountErrorInvalidCredentials =>
      'Correo o contraseña incorrectos.';

  @override
  String get accountErrorEmailTaken =>
      'Ya existe una cuenta con esta dirección de correo.';

  @override
  String get accountErrorInvalidEmail => 'La dirección de correo no es válida.';

  @override
  String get accountErrorWeakPassword =>
      'La contraseña no cumple los requisitos del servidor.';

  @override
  String get accountErrorServer =>
      'El servidor informó de un error. Inténtalo de nuevo más tarde.';

  @override
  String get accountErrorUpdateRequired =>
      'Esta versión de setDING es demasiado antigua para el servidor. Actualiza la app.';

  @override
  String get updateRequiredTitle => 'Actualiza setDING';

  @override
  String get updateRequiredBody =>
      'El servidor ya no acepta esta versión, así que no se sincroniza nada. Tus cambios se quedan en este dispositivo y se envían tras la actualización.';

  @override
  String updateRequiredVersions(String current, String minimum) {
    return 'Instalada: $current, necesaria: $minimum o posterior.';
  }

  @override
  String get updateRequiredHowTo =>
      'En Android, actualízala en Obtainium; si no, descarga la nueva versión de las releases de setDING en GitHub.';

  @override
  String get updateRequiredReload => 'Recargar';

  @override
  String get updateRequiredCopyLink => 'Copiar enlace de descarga';

  @override
  String get updateRequiredCopied => 'Enlace copiado.';

  @override
  String updateAvailableTitle(String version) {
    return 'setDING $version está disponible';
  }

  @override
  String get updateAvailableDetails => 'Detalles';

  @override
  String updateAvailableInstalled(String current) {
    return 'Instalada: $current.';
  }

  @override
  String get settingsServer => 'Servidor';

  @override
  String get settingsServerHint => 'Cambiarlo cierra tu sesión.';

  @override
  String get settingsServerInvalid =>
      'La dirección debe empezar por http:// o https://.';

  @override
  String get bandLocal => 'En este dispositivo';

  @override
  String get bandLocalHint => 'Solo en este dispositivo, sin sincronizar.';

  @override
  String get bandSwitch => 'Cambiar de banda';

  @override
  String get bandManage => 'Gestionar bandas';

  @override
  String get bandNone => 'Sin banda';

  @override
  String noBandInLibrary(String organization) {
    return 'No estás en ninguna banda de $organization. Los sets pertenecen a una banda: crea una o pide que te añadan.';
  }

  @override
  String get librarySwitch => 'Cambiar de biblioteca de canciones';

  @override
  String get bandsTitle => 'Bandas';

  @override
  String get bandsEmpty =>
      'Aún no estás en ninguna banda. Crea una banda para tus canciones y sets.';

  @override
  String get bandsSignInHint => 'Inicia sesión para crear bandas.';

  @override
  String get bandNew => 'Nueva banda';

  @override
  String get bandName => 'Nombre de la banda';

  @override
  String get bandRoleAdmin => 'Admin';

  @override
  String get bandRoleMember => 'Miembro';

  @override
  String get bandMembers => 'Miembros';

  @override
  String bandYou(String name) {
    return '$name (tú)';
  }

  @override
  String get bandMakeAdmin => 'Hacer admin';

  @override
  String get bandMakeMember => 'Hacer miembro';

  @override
  String get bandRoleLeader => 'Líder';

  @override
  String get bandRolePlanner => 'Planificador de sets';

  @override
  String get orgRoleLibrarian => 'Bibliotecario';

  @override
  String get bandMakeLeader => 'Hacer líder';

  @override
  String get bandMakePlanner => 'Hacer planificador de sets';

  @override
  String get orgMakeLibrarian => 'Hacer bibliotecario';

  @override
  String get orgLibrarianHint =>
      'Los bibliotecarios crean, editan y eliminan las canciones de la organización.';

  @override
  String get bandPlannerHint =>
      'Los planificadores de sets preparan los sets de la banda.';

  @override
  String get inviteBandHint =>
      'Crea un enlace válido durante 7 días. Quien lo abra se une a la organización y a esta banda como miembro. En Miembros puedes cambiar después su papel en la banda.';

  @override
  String joinQuestionBand(String band, String org) {
    return '¿Unirte a $band ($org)?';
  }

  @override
  String get joinExplanationBand =>
      'Te conviertes en miembro de la organización y de la banda y ves sus canciones y sets.';

  @override
  String get bandRemoveMember => 'Quitar de la banda';

  @override
  String bandRemoveTitle(String name) {
    return '¿Quitar a $name?';
  }

  @override
  String bandRemoveMessage(String name) {
    return '$name dejará de ver las canciones y los sets de la banda.';
  }

  @override
  String get bandLeave => 'Dejar la banda';

  @override
  String bandLeaveTitle(String band) {
    return '¿Dejar $band?';
  }

  @override
  String get bandLeaveMessage =>
      'Dejarás de ver las canciones y los sets de la banda. Un admin puede volver a invitarte.';

  @override
  String get bandRefresh => 'Actualizar';

  @override
  String get bandErrorLastAdmin => 'Una banda necesita al menos un admin.';

  @override
  String get bandErrorNotAllowed => 'No permitido, o la banda ya no existe.';

  @override
  String get accountErrorSignedOut => 'Inicia sesión.';

  @override
  String get copyToBand => 'Copiar a una banda';

  @override
  String get copyToBandTitle => '¿Copiar a qué banda?';

  @override
  String get copyToBandNoTarget =>
      'No hay ninguna otra banda a la que puedas copiar.';

  @override
  String copiedSongs(int count, String band) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones copiadas a $band',
      one: '1 canción copiada a $band',
    );
    return '$_temp0';
  }

  @override
  String copiedSet(String band) {
    return 'Set copiado a $band';
  }

  @override
  String songsSelected(int count) {
    return '$count seleccionadas';
  }

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get selectMode => 'Seleccionar';

  @override
  String get deleteSelected => 'Eliminar selección';

  @override
  String deleteSongsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Eliminar $count canciones?',
      one: '¿Eliminar 1 canción?',
    );
    return '$_temp0';
  }

  @override
  String deleteSongsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Las $count canciones seleccionadas se eliminarán y se quitarán de todos los sets.',
      one: 'La canción seleccionada se eliminará y se quitará de todos los sets.',
    );
    return '$_temp0 Puedes restaurarlas desde la papelera.';
  }

  @override
  String songsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones eliminadas',
      one: '1 canción eliminada',
    );
    return '$_temp0';
  }

  @override
  String get bandRoleOrgAdmin => 'Admin de la organización';

  @override
  String get bandOrganization => 'Organización';

  @override
  String get bandNewOrganization => 'Nueva organización';

  @override
  String get bandNewHint =>
      'Las bandas de una organización comparten sus canciones.';

  @override
  String get bandAddMember => 'Añadir miembro';

  @override
  String get bandAddMemberTitle => '¿A quién añadir?';

  @override
  String get bandAddMemberNone =>
      'Todos en la organización ya están en esta banda.';

  @override
  String get bandOrgAdminHint =>
      'Gestionas esta banda como admin de la organización.';

  @override
  String get bandErrorNotOrgMember =>
      'Esta persona no es miembro de la organización.';

  @override
  String get orgName => 'Nombre de la organización';

  @override
  String get orgPeople => 'Personas';

  @override
  String get orgBands => 'Bandas';

  @override
  String get orgRemove => 'Quitar de la organización';

  @override
  String orgRemoveTitle(String name) {
    return '¿Quitar a $name?';
  }

  @override
  String orgRemoveMessage(String name) {
    return '$name también dejará todas las bandas de la organización y ya no verá sus canciones.';
  }

  @override
  String get orgLeave => 'Dejar la organización';

  @override
  String orgLeaveTitle(String org) {
    return '¿Dejar $org?';
  }

  @override
  String get orgLeaveMessage =>
      'También dejarás todas sus bandas y ya no verás sus canciones.';

  @override
  String get orgSongsShared =>
      'Todas las bandas de la organización comparten las mismas canciones.';

  @override
  String get copyToLibraryTitle => '¿Copiar a qué biblioteca de canciones?';

  @override
  String get inviteCreate => 'Invitar a personas';

  @override
  String get inviteCreateHint =>
      'Crea un enlace válido durante 7 días. Quien lo abra se une a la organización como miembro, pero aún a ninguna banda. Después añádelo a una banda; en Personas puedes cambiar su papel.';

  @override
  String get inviteLinkTitle => 'Enlace de invitación';

  @override
  String inviteLinkHint(String date) {
    return 'Comparte el enlace, p. ej. en un chat de grupo, o deja que escaneen el código QR. Válido hasta el $date. Puedes volver a mostrarlo desde la lista de enlaces.';
  }

  @override
  String get inviteCopy => 'Copiar enlace';

  @override
  String get inviteCopied => 'Enlace copiado';

  @override
  String get invitesTitle => 'Enlaces de invitación';

  @override
  String inviteDates(String created, String expires) {
    return 'Creado el $created, válido hasta el $expires';
  }

  @override
  String get inviteOrganizationOnly => 'Solo la organización';

  @override
  String get inviteShow => 'Mostrar enlace';

  @override
  String inviteJoined(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se han unido $count: $names',
      one: 'Se ha unido: $names',
      zero: 'Aún no se ha unido nadie',
    );
    return '$_temp0';
  }

  @override
  String get inviteRevoke => 'Revocar';

  @override
  String get inviteRevokeTitle => '¿Revocar el enlace?';

  @override
  String get inviteRevokeMessage =>
      'El enlace dejará de funcionar. Quienes ya se unieron siguen siendo miembros.';

  @override
  String get inviteAskAdmin =>
      'Pide una invitación a un admin de la organización o a un líder de banda.';

  @override
  String get inviteErrorUnknown =>
      'Esta invitación no existe. Comprueba el enlace.';

  @override
  String get inviteErrorExpired =>
      'Esta invitación ha caducado. Pide un enlace nuevo.';

  @override
  String get inviteErrorRevoked =>
      'Esta invitación se revocó. Pide un enlace nuevo.';

  @override
  String get joinTitle => 'Unirse';

  @override
  String get joinHint => 'Pega el enlace de invitación que recibiste.';

  @override
  String get joinLink => 'Enlace de invitación';

  @override
  String get joinContinue => 'Continuar';

  @override
  String get joinInvalidLink => 'Este no es un enlace de invitación válido.';

  @override
  String get joinScan => 'Escanear código QR';

  @override
  String get joinScanHint => 'Apunta la cámara al código QR de la invitación';

  @override
  String get scannerClose => 'Cerrar el escáner';

  @override
  String get scannerTorchOn => 'Encender la luz';

  @override
  String get scannerTorchOff => 'Apagar la luz';

  @override
  String get scannerSwitchCamera => 'Cambiar de cámara';

  @override
  String get scannerPickImage => 'Leer un código de una foto';

  @override
  String get scannerStarting => 'Iniciando la cámara …';

  @override
  String get scannerPermissionTitle => 'Sin acceso a la cámara';

  @override
  String get scannerPermissionMessage =>
      'Permite a setDING usar la cámara en los ajustes para escanear códigos QR.';

  @override
  String get scannerUnavailableTitle => 'La cámara no está disponible';

  @override
  String get scannerUnavailableMessage =>
      'Quizá otra app la está usando, o este dispositivo no tiene.';

  @override
  String get scannerInUseMessage =>
      'Otra app está usando la cámara. Ciérrala e inténtalo de nuevo.';

  @override
  String get scannerPhotoFallback =>
      'También puedes leer el código de una foto.';

  @override
  String get scannerOpenSettings => 'Abrir ajustes';

  @override
  String get scannerTryAgain => 'Intentar de nuevo';

  @override
  String get scannerChoosePhoto => 'Elegir una foto';

  @override
  String get scannerNoCodeInPhoto => 'No hay ningún código en esta foto';

  @override
  String joinQuestion(String org) {
    return '¿Unirte a $org?';
  }

  @override
  String get joinExplanation =>
      'Te conviertes en miembro de la organización y ves sus canciones. Después, un admin puede añadirte a una banda.';

  @override
  String joinAlreadyMember(String org) {
    return 'Ya eres miembro de $org.';
  }

  @override
  String get joinButton => 'Unirse';

  @override
  String joinDone(String org) {
    return 'Te uniste a $org.';
  }

  @override
  String get joinSignInFirst => 'Inicia sesión o crea una cuenta para unirte.';

  @override
  String get joinHaveAccount => 'Ya tengo una cuenta';

  @override
  String get inviteErrorUsed =>
      'Esta invitación ya se usó. Pide un enlace nuevo.';

  @override
  String get inviteErrorNotStored =>
      'Este enlace no se puede volver a mostrar. Crea uno nuevo.';

  @override
  String get accountErrorInvitationRequired =>
      'Este servidor solo acepta cuentas nuevas con un enlace de invitación.';

  @override
  String get accountErrorEmailNotVerified =>
      'Confirma primero tu dirección de correo. Te hemos enviado un correo nuevo.';

  @override
  String get bandErrorFounderInvitationRequired =>
      'Las organizaciones nuevas necesitan una invitación de fundador del operador del servidor.';

  @override
  String get accountInviteOnlyHint =>
      'En este servidor, las cuentas nuevas necesitan un enlace de invitación.';

  @override
  String accountVerifyEmail(String email) {
    return 'Casi listo: enviamos un correo a $email. Confirma tu dirección con el enlace que contiene y luego inicia sesión.';
  }

  @override
  String get accountVerifyResend => 'Enviar el correo de nuevo';

  @override
  String get accountVerifySent => 'Correo enviado.';

  @override
  String joinFoundQuestion(String org) {
    return '¿Fundar $org?';
  }

  @override
  String get joinFoundExplanation =>
      'Creas la organización y te conviertes en su admin. Después puedes crear bandas e invitar a personas.';

  @override
  String get joinFoundButton => 'Fundar organización';

  @override
  String joinFoundDone(String org) {
    return 'Fundaste $org.';
  }

  @override
  String get syncTitle => 'Sincronización';

  @override
  String get syncNow => 'Sincronizar ahora';

  @override
  String get settingsSyncMode => 'Sincronización';

  @override
  String get syncModeAutomatic => 'Automática';

  @override
  String get syncModeOnStart => 'Al iniciar';

  @override
  String get syncModeManual => 'Manual';

  @override
  String get syncModeAutomaticHint =>
      'Sincroniza al iniciar, unos segundos después de los cambios, cuando algo cambia en el servidor y cada 5 minutos.';

  @override
  String get syncModeOnStartHint =>
      'Sincroniza una vez al iniciar la app y tras iniciar sesión. Si no, con \"Sincronizar ahora\".';

  @override
  String get syncModeManualHint =>
      'Sincroniza solo cuando tocas \"Sincronizar ahora\".';

  @override
  String get syncRunning => 'Sincronizando …';

  @override
  String syncLast(String time) {
    return 'Última sincronización: $time';
  }

  @override
  String get syncNever => 'Aún no sincronizado';

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cambios aún no están en el servidor.',
      one: '1 cambio aún no está en el servidor.',
      zero: 'Todos los cambios están en el servidor.',
    );
    return '$_temp0';
  }

  @override
  String get syncOffline => 'Sin conexión: los cambios se enviarán más tarde.';

  @override
  String syncConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones con un conflicto: ábrelas para decidir.',
      one: '1 canción con un conflicto: ábrela para decidir.',
    );
    return '$_temp0';
  }

  @override
  String get conflictBanner =>
      'Esta canción se cambió en el servidor y en este dispositivo.';

  @override
  String get conflictBannerDeleted =>
      'Esta canción se eliminó en el servidor y se cambió en este dispositivo.';

  @override
  String get conflictKeepMine => 'Mantener la mía';

  @override
  String get conflictTakeServer => 'Usar la versión del servidor';

  @override
  String get conflictKeepBoth => 'Mantener ambas';

  @override
  String get conflictCompare => 'Mostrar la versión del servidor';

  @override
  String get conflictServerVersion => 'Versión del servidor';

  @override
  String get conflictKeptBoth =>
      'Tu versión se guardó como una canción aparte.';

  @override
  String get accountErrorConflict =>
      'La canción se cambió en el servidor mientras tanto.';

  @override
  String get pdfMissing =>
      'El PDF aún no está en este dispositivo. Se descargará con la próxima sincronización.';

  @override
  String get pdfLoadFailed =>
      'No se pudo cargar el PDF desde el servidor. Comprueba la conexión y vuelve a abrir la canción.';

  @override
  String get openAttachment => 'Abrir';

  @override
  String get imageMissing => 'La imagen no está en este dispositivo.';

  @override
  String syncMissingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count PDF aún se están descargando.',
      one: '1 PDF aún se está descargando.',
    );
    return '$_temp0';
  }

  @override
  String get invalidChordProTitle => '¿Revisar el ChordPro?';

  @override
  String get invalidChordProMessage =>
      'La canción contiene partes que probablemente no se mostrarán como se esperaba:';

  @override
  String problemUnclosedDirective(int line) {
    return 'Línea $line: una llave (directiva) no está cerrada.';
  }

  @override
  String problemUnclosedChord(int line) {
    return 'Línea $line: un corchete (acorde) no está cerrado.';
  }

  @override
  String problemUnclosedEnvironment(int line) {
    return 'Línea $line: el bloque nunca se cierra y contiene todo el resto de la canción.';
  }

  @override
  String problemTextAfterDirective(int line) {
    return 'Línea $line: texto después de una directiva; toda la línea se muestra como letra.';
  }

  @override
  String problemInvalidKey(int line) {
    return 'Línea $line: la directiva key no indica ninguna tonalidad; la canción no tiene tonalidad para transponer ni para las vistas de acordes.';
  }

  @override
  String chordProProblemsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count partes del ChordPro probablemente no se mostrarán como se esperaba',
      one: '1 parte del ChordPro probablemente no se mostrará como se esperaba',
    );
    return '$_temp0';
  }

  @override
  String chordProProblemsShow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrar los $count problemas de ChordPro',
      one: 'Mostrar el problema de ChordPro',
    );
    return '$_temp0';
  }

  @override
  String setChordProProblemsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones con problemas de ChordPro',
      one: '1 canción con problemas de ChordPro',
    );
    return '$_temp0';
  }

  @override
  String get importProblemsTitle => 'Revisar la importación';

  @override
  String importProblemsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones importadas contienen partes',
      one: '1 canción importada contiene partes',
    );
    return '$_temp0 que probablemente no se mostrarán como se esperaba:';
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
      'Las canciones están marcadas en la lista de canciones. La corrección automática solo cambia las partes con una reparación clara; corrige el resto en el editor.';

  @override
  String songsFixed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones corregidas',
      one: '1 canción corregida',
      zero: 'No se corrigió ninguna canción',
    );
    return '$_temp0';
  }

  @override
  String moreProblems(int count) {
    return '… y $count más.';
  }

  @override
  String get saveAnyway => 'Guardar de todos modos';

  @override
  String get fixProblems => 'Corregir automáticamente';

  @override
  String get keepEditing => 'Seguir editando';

  @override
  String get webSignInHint =>
      'Inicia sesión para gestionar organizaciones, bandas, canciones y sets en el navegador.';

  @override
  String get webNoBandTitle => 'Aún no hay banda';

  @override
  String get webNoBandMessage =>
      'Aún no estás en ninguna banda. Crea una organización con una banda o únete con un enlace de invitación.';

  @override
  String get songDetails => 'Detalles de la canción';

  @override
  String get songDetailsTooltip =>
      'Editar título, tonalidad, tempo y más de la canción, para todos';

  @override
  String get noKey => 'Sin tonalidad';

  @override
  String get timeHint => 'p. ej. 4/4';

  @override
  String get noSequence => 'Sin secuencia';

  @override
  String get sequenceChange => 'Cambiar la secuencia de la canción';

  @override
  String get sortSongs => 'Ordenar';

  @override
  String get sortByTitle => 'Título';

  @override
  String get sortByArtist => 'Artista';

  @override
  String get sortByKey => 'Tonalidad';

  @override
  String get sortByRecent => 'Editadas recientemente';

  @override
  String get noArtist => 'Sin artista';

  @override
  String get songConflictTooltip =>
      'Cambiada aquí y en el servidor: abre la canción para decidir';

  @override
  String get pdfOnlyTooltip => 'Solo partitura (PDF), sin acordes';

  @override
  String upcomingGigTooltip(String set, String date) {
    return 'En “$set” el $date';
  }

  @override
  String get foundInLyrics => 'Encontrado en la letra';

  @override
  String hiddenParts(String parts) {
    return 'Ocultas (no están en la secuencia): $parts';
  }

  @override
  String get setsUpcoming => 'Próximos';

  @override
  String get setsUndated => 'Sin fecha';

  @override
  String setsPast(int count) {
    return 'Pasados ($count)';
  }

  @override
  String get showPastSets => 'Mostrar sets pasados';

  @override
  String get hidePastSets => 'Ocultar sets pasados';

  @override
  String get nextGig => 'Próximo concierto';

  @override
  String gigInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'En $days días',
      one: 'Mañana',
      zero: 'Hoy',
    );
    return '$_temp0';
  }

  @override
  String get undo => 'Deshacer';

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
    return 'Adjunto “$name” eliminado';
  }

  @override
  String setItemRemoved(String title) {
    return '“$title” quitada del set';
  }

  @override
  String get settingsGroupPersonal => 'Personal: en todos tus dispositivos';

  @override
  String get settingsGroupDevice => 'Este dispositivo';

  @override
  String get settingsGroupAccount => 'Cuenta y organización';

  @override
  String get settingsScopePersonalHint =>
      'Estos ajustes pertenecen a tu cuenta y se aplican en todos los dispositivos en los que hayas iniciado sesión.';

  @override
  String get settingsScopePersonalSignedOutHint =>
      'Sin sesión iniciada, estos ajustes solo se aplican en este dispositivo. Tras iniciar sesión, se sincronizan con tu cuenta.';

  @override
  String get settingsScopeDeviceHint =>
      'Estos ajustes solo se aplican en este dispositivo y no se sincronizan.';

  @override
  String get settingsTakenOver => 'Se han aplicado los ajustes de tu cuenta.';

  @override
  String get annotationsDraw => 'Dibujar anotaciones';

  @override
  String get annotationsShow => 'Mostrar anotaciones';

  @override
  String get annotationsHide => 'Ocultar anotaciones';

  @override
  String get annotationPen => 'Bolígrafo';

  @override
  String get annotationHighlighter => 'Rotulador';

  @override
  String get annotationText => 'Texto';

  @override
  String get annotationTextHint => 'Escribe un texto';

  @override
  String get annotationEraser => 'Borrador (trazo entero)';

  @override
  String get annotationPartialEraser => 'Borrador (parte de un trazo)';

  @override
  String get annotationLasso => 'Seleccionar (lazo)';

  @override
  String get annotationStamps => 'Sellos';

  @override
  String get annotationStampsMusic => 'Signos musicales';

  @override
  String get annotationStampsRepeats => 'Repeticiones';

  @override
  String get annotationStampsCues => 'Señales';

  @override
  String annotationColor(Object number) {
    return 'Color $number';
  }

  @override
  String get annotationSize => 'Grosor de línea';

  @override
  String get annotationSmaller => 'Más pequeño';

  @override
  String get annotationLarger => 'Más grande';

  @override
  String get annotationDeleteSelection => 'Eliminar selección';

  @override
  String get annotationUndo => 'Deshacer';

  @override
  String get annotationRedo => 'Rehacer';

  @override
  String get annotationMore => 'Más';

  @override
  String get annotationDrawWithFinger => 'Dibujar con el dedo';

  @override
  String get annotationDone => 'Hecho';

  @override
  String get annotationsDeleteAll =>
      'Eliminar todas las anotaciones de esta canción';

  @override
  String get annotationsDeleted => 'Anotaciones eliminadas';

  @override
  String get annotationsOtherLayout => 'Dibujadas para otra vista';

  @override
  String get annotationsOtherLayoutLandscape => 'Dibujadas en horizontal';

  @override
  String get annotationsOtherLayoutPortrait => 'Dibujadas en vertical';

  @override
  String annotationsOrphaned(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anotaciones sin su línea',
      one: '1 anotación sin su línea',
    );
    return '$_temp0';
  }

  @override
  String get annotationsFull =>
      'Anotaciones llenas: borra algunas para dibujar más';

  @override
  String annotationsNearlyFull(int percent) {
    return 'Anotaciones al $percent %';
  }

  @override
  String get annotationsPanelTitle => 'Anotaciones a mano alzada';

  @override
  String get annotationsPanelShow => 'Mostrar mis anotaciones';

  @override
  String annotationsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anotaciones',
      one: '1 anotación',
      zero: 'Ninguna aún: dibújalas en el modo en vivo',
    );
    return '$_temp0';
  }

  @override
  String get settingsShowAnnotations => 'Mostrar anotaciones a mano alzada';

  @override
  String get settingsShowAnnotationsHint =>
      'Tus propios dibujos en canciones y partituras';

  @override
  String get settingsRepeatedChorusOnce =>
      'Mostrar solo una vez un estribillo escrito completo';

  @override
  String get settingsRepeatedChorusOnceHint =>
      'Se omite un estribillo que vuelve a aparecer más adelante palabra por palabra';

  @override
  String get settingsShowOutsideSequence =>
      'Mostrar las partes fuera de la secuencia';

  @override
  String get settingsShowOutsideSequenceHint =>
      'Atenuadas en el modo en vivo en lugar de ocultas';

  @override
  String get settingsAnnotationFinger => 'Dibujar anotaciones con el dedo';

  @override
  String get settingsAnnotationFingerHint =>
      'Para dispositivos sin lápiz; si no, los dedos siguen pasando páginas';

  @override
  String get settingsSpaceStartsBeat => 'Espacio inicia el pulso';

  @override
  String get settingsSpaceStartsBeatHint =>
      'Espacio inicia y detiene el pulso y el clic como Intro, en lugar de avanzar';

  @override
  String get stampFermata => 'Calderón';

  @override
  String get stampBreath => 'Respiración';

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
  String get stampRepeatStart => 'Inicio de repetición';

  @override
  String get stampRepeatEnd => 'Fin de repetición';

  @override
  String get stampCoda => 'Coda';

  @override
  String get stampSegno => 'Segno';

  @override
  String get stampGlasses => 'Atención';

  @override
  String get stampStop => 'Stop';

  @override
  String get stampEye => 'Mirar';

  @override
  String get stampExclamation => 'Importante';

  @override
  String get stampStar => 'Estrella';

  @override
  String get settingsSectionBands => 'Organización y bandas';

  @override
  String get settingsCategoryBandsHint =>
      'Organizaciones, bandas, miembros e invitaciones';

  @override
  String get settingsBandsJoinHint =>
      'Únete a una organización o banda con un enlace de invitación.';

  @override
  String get settingsSectionSongDisplay => 'Visualización de canciones';

  @override
  String get settingsCategorySongDisplayHint =>
      'Estilos por sección: acordes, letra, títulos, barras';

  @override
  String get songDisplayPreview => 'Vista previa';

  @override
  String get songDisplayPreset => 'Preajuste';

  @override
  String get songDisplayPresetClassic => 'Clásico';

  @override
  String get songDisplayPresetColorCoded => 'Por colores';

  @override
  String get songDisplayPresetChorusFocus => 'Foco en el estribillo';

  @override
  String get songDisplayPresetSinger => 'Voz';

  @override
  String get songDisplayPresetGuitar => 'Guitarra';

  @override
  String get songDisplayPresetMinimal => 'Mínimo';

  @override
  String get songDisplayPresetBlackWhite => 'Blanco/negro';

  @override
  String get songDisplayPresetCustom => 'Personalizado';

  @override
  String get songDisplayDiscardTitle =>
      '¿Descartar los estilos personalizados?';

  @override
  String songDisplayDiscardMessage(String name) {
    return 'El preajuste “$name” reemplaza tus estilos personalizados.';
  }

  @override
  String get songDisplayDiscard => 'Descartar';

  @override
  String get songDisplayFont => 'Fuente';

  @override
  String get songDisplayFontStandard => 'Estándar';

  @override
  String get songDisplayFontMonospace => 'Monoespaciada';

  @override
  String get songDisplaySection => 'Sección';

  @override
  String get songDisplayTypeStandard => 'Estándar';

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
      'Estilo base para cada sección sin estilo propio y para las secciones no reconocidas (p. ej. tabs, cuadrículas, nombres personalizados).';

  @override
  String get songDisplayStyle => 'Estilo';

  @override
  String get songDisplayOwnStyle => 'Estilo propio';

  @override
  String songDisplayLike(String name) {
    return 'Como $name';
  }

  @override
  String songDisplayInheritsHint(String chain) {
    return 'Lo toma todo de: $chain. Los cambios allí también se aplican aquí.';
  }

  @override
  String get songDisplayChords => 'Acordes';

  @override
  String get songDisplayLyrics => 'Letra';

  @override
  String get songDisplayHeading => 'Título';

  @override
  String get songDisplayBar => 'Barra de sangría';

  @override
  String get songDisplayBold => 'Negrita';

  @override
  String get songDisplayItalic => 'Cursiva';

  @override
  String get songDisplaySize => 'Tamaño';

  @override
  String get songDisplayColor => 'Color';

  @override
  String get songDisplayShowHeading => 'Mostrar título';

  @override
  String get songDisplayShowBar => 'Mostrar barra';

  @override
  String get songDisplayBarWidth => 'Ancho';

  @override
  String get songDisplayIndent => 'Sangría';

  @override
  String get songDisplayTint => 'Teñir el fondo';

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
  String get songDisplayBarMedium => 'Media';

  @override
  String get songDisplayBarWide => 'Ancha';

  @override
  String get songDisplayIndentNone => 'Ninguna';

  @override
  String get songDisplayIndentNormal => 'Normal';

  @override
  String get songDisplayIndentLarge => 'Grande';

  @override
  String get songColorAuto => 'Automático';

  @override
  String get songColorBlue => 'Azul';

  @override
  String get songColorAmber => 'Ámbar';

  @override
  String get songColorRed => 'Rojo';

  @override
  String get songColorGreen => 'Verde';

  @override
  String get songColorTeal => 'Verde azulado';

  @override
  String get songColorPurple => 'Morado';

  @override
  String get songColorPink => 'Rosa';

  @override
  String get songColorGrey => 'Gris';

  @override
  String get songColorBlackWhite => 'Blanco/negro';

  @override
  String get songDisplayCustomise => 'Personalizar la visualización';

  @override
  String get songDisplayCustomiseHint =>
      'Acordes, letra, títulos, barras y colores';

  @override
  String get songDisplayEditorTitle =>
      'Personalizar la visualización de canciones';

  @override
  String get songDisplayDemoSong => 'Canción de demostración';

  @override
  String get songDisplayLibrarySong => 'Canción de la biblioteca …';

  @override
  String get songDisplayPickSong => 'Canción para la vista previa';

  @override
  String get songDisplayResizePreview =>
      'Arrastra para cambiar el tamaño de la vista previa';

  @override
  String get appUpdateInstall => 'Instalar';

  @override
  String appUpdateInstallTitle(String version) {
    return '¿Instalar setDING $version?';
  }

  @override
  String get appUpdateInstallBody =>
      'setDING se cierra, instala la nueva versión y se vuelve a iniciar. Tus datos se quedan en este dispositivo.';

  @override
  String get appUpdateDownloading => 'Descargando la actualización …';

  @override
  String get appUpdateFailed =>
      'No se pudo instalar la actualización. Inténtalo de nuevo más tarde.';

  @override
  String get whatsNewTitle => 'Novedades';

  @override
  String whatsNewAvailable(String version) {
    return 'Novedades en setDING $version';
  }

  @override
  String get whatsNewShow => 'Mostrar';

  @override
  String whatsNewVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get whatsNewAllChanges => 'Todos los cambios';

  @override
  String get midiTestTitle => 'Prueba MIDI (prototipo)';

  @override
  String get midiTestTileHint =>
      'Enviar un program change a un teclado conectado por USB, p. ej. un Nord Stage 3';

  @override
  String get midiTestHint =>
      'Envía un program change a un teclado conectado por USB, para probar el MIDI en este dispositivo. Lo que envía el teclado, p. ej. al elegir en él un programa o un song, aparece en el registro.';

  @override
  String get midiTestDevices => 'Dispositivos';

  @override
  String get midiTestRefresh => 'Buscar de nuevo';

  @override
  String get midiTestNoDevices =>
      'No se encontró ningún dispositivo MIDI. Conecta el teclado por USB y busca de nuevo.';

  @override
  String get midiTestConnect => 'Conectar';

  @override
  String get midiTestDisconnect => 'Desconectar';

  @override
  String get midiTestConnected => 'Conectado';

  @override
  String get midiTestChannel => 'Canal MIDI';

  @override
  String get midiTestModeNordProgram => 'Programa Nord';

  @override
  String get midiTestModeNordSong => 'Song Nord';

  @override
  String get midiTestModeNordLive => 'Live Nord';

  @override
  String get midiTestModeRaw => 'Valores sin procesar';

  @override
  String get midiTestBank => 'Banco';

  @override
  String get midiTestLive => 'Memoria live';

  @override
  String get midiTestMsb => 'Bank select MSB (CC 0, 0–127)';

  @override
  String get midiTestLsb => 'Bank select LSB (CC 32, 0–127)';

  @override
  String get midiTestProgram => 'Programa (1–128)';

  @override
  String get midiTestEmptyNotSent => 'Un bank select vacío no se envía.';

  @override
  String get midiTestInvalid => 'Revisa los valores';

  @override
  String get midiTestSend => 'Enviar';

  @override
  String get midiTestLog => 'Registro';

  @override
  String get midiTestCopy => 'Copiar registro';

  @override
  String get midiTestCopied => 'Registro copiado';

  @override
  String get midiTestClear => 'Vaciar registro';

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
    return 'Recibido: CC $controller = $value (canal $channel) – $bytes';
  }

  @override
  String midiTestReceivedPc(
    int number,
    int program,
    int channel,
    String bytes,
  ) {
    return 'Recibido: program change $number (valor $program, canal $channel) – $bytes';
  }

  @override
  String midiTestReceivedOther(String bytes) {
    return 'Recibido: $bytes';
  }

  @override
  String midiTestError(String message) {
    return 'Error: $message';
  }

  @override
  String get midiTestModeCc => 'Control change';

  @override
  String get midiTestController => 'Controlador (CC 0–127)';

  @override
  String get midiTestValue => 'Valor (0–127)';

  @override
  String get midiTestCcHint =>
      'Nord Stage 3 según midi.guide: CC 2 modo live, CC 3 modo song, CC 5 parte del song. Qué valores hacen qué forma parte de la prueba.';

  @override
  String get midiGuideTitle => 'Prueba guiada';

  @override
  String get midiGuideHint =>
      'Toca “Enviar”, mira la pantalla del Nord y toca lo que ocurrió. No hay que ajustar nada en el Nord. Las respuestas se guardan en el registro.';

  @override
  String get midiGuideNordSend => 'Nord Stage 3 – enviar';

  @override
  String get midiGuideNordReceive => 'Nord Stage 3 – recibir';

  @override
  String get midiGuideMotifSend => 'Motif XF – enviar';

  @override
  String get midiGuideMotifReceive => 'Motif XF – recibir';

  @override
  String get midiGuideNordReceiveHint =>
      'En el Nord, ajusta “Program Change” a “Send” o “Send & Receive” en el menú MIDI y ajusta aquí el canal al canal global del Nord. Luego elige en el Nord cualquier programa, live memory o parte de song, p. ej. con la rueda o los botones de modo. setDING muestra lo que llegó; toca si coincide con la pantalla. Los resultados se guardan en el registro.';

  @override
  String get midiGuideMotifSendHint =>
      'En el Motif XF, en Utility → Control (F5) → MIDI (SF2): ajusta MIDI IN/OUT a USB, activa la recepción de bank select y program change, ajusta el Basic Receive Channel al canal de aquí y el Device Number a “all” o 1, y guarda con Store. Toca “Enviar”, mira la pantalla del Motif y toca lo que ocurrió. Las respuestas se guardan en el registro.';

  @override
  String get midiGuideMotifReceiveHint =>
      'En el Motif XF, en Utility → Control (F5) → MIDI (SF2): ajusta MIDI IN/OUT a USB, activa el envío de bank select y program change y ajusta el Transmit Channel al canal de aquí, y guarda con Store. Luego elige en el Motif cualquier voice o performance, también en distintos bancos y dos veces en el mismo banco. setDING muestra lo que llegó; toca si coincide con la pantalla. Los resultados se guardan en el registro.';

  @override
  String midiGuideMotifExpected(String name) {
    return 'El Motif muestra $name.';
  }

  @override
  String get midiGuideWaiting => 'Elige un sonido en el teclado …';

  @override
  String midiGuideFreeReceived(String name) {
    return 'Recibido: $name';
  }

  @override
  String get midiGuideMatches => 'Coincide con la pantalla';

  @override
  String get midiGuideNoMatch => 'No coincide';

  @override
  String midiGuideFreeResult(String name, String values, String answer) {
    return 'Recibido $name ($values): $answer';
  }

  @override
  String midiGuideChecked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sonidos comprobados',
      one: '1 sonido comprobado',
      zero: 'Aún no se ha comprobado nada',
    );
    return '$_temp0';
  }

  @override
  String midiGuideStep(int current, int total, String title) {
    return 'Paso $current de $total: $title';
  }

  @override
  String midiGuideExpected(String expected) {
    return 'Esperado: $expected';
  }

  @override
  String get midiGuideDone =>
      'Prueba terminada. Las respuestas están en el registro.';

  @override
  String get midiGuideRestart => 'Empezar de nuevo';

  @override
  String get midiGuideBack => 'Atrás';

  @override
  String get midiGuideSkip => 'Omitir';

  @override
  String midiGuideResult(int current, String title, String answer) {
    return 'Paso $current ($title): $answer';
  }

  @override
  String midiGuideProgram(String name) {
    return 'Programa $name';
  }

  @override
  String midiGuideProgramExpected(String name) {
    return 'El Nord muestra $name.';
  }

  @override
  String midiGuideLive(int number) {
    return 'Live memory $number';
  }

  @override
  String midiGuideLiveExpected(int number) {
    return 'El Nord muestra Live $number.';
  }

  @override
  String get midiGuideSongModeOn => 'Modo song activado (CC 3 = 127)';

  @override
  String get midiGuideSongModeOnExpected => 'El Nord pasa al modo song.';

  @override
  String get midiGuideSongModeOff => 'Modo song desactivado (CC 3 = 0)';

  @override
  String get midiGuideSongModeOffExpected => 'El Nord sale del modo song.';

  @override
  String get midiGuideAnswerAsExpected => 'Como se esperaba';

  @override
  String get midiGuideAnswerDifferent => 'Otra cosa';

  @override
  String get midiGuideAnswerNothing => 'No pasó nada';

  @override
  String get midiTestFree => 'Envío libre';

  @override
  String get midiTestPage => 'Página';

  @override
  String get midiTestButton => 'Botón';

  @override
  String midiGuideSong(int song, int part) {
    return 'Song $song, parte $part';
  }

  @override
  String midiGuideSongExpected(int song, int part) {
    return 'El Nord muestra el song $song, parte $part.';
  }

  @override
  String get midiTestSong => 'Song';

  @override
  String get midiTestPart => 'Parte';

  @override
  String get settingsEditorTypingAids =>
      'Cerrar corchetes y secciones automáticamente';

  @override
  String get settingsEditorTypingAidsHint =>
      'En el editor ChordPro: [ añade ], Intro tras el inicio de una sección añade su final, y renombrar el inicio de una sección también renombra su final.';

  @override
  String get settingsDeveloperMode => 'Modo desarrollador';

  @override
  String get settingsDeveloperModeHint =>
      'Muestra la categoría “Desarrollo” con funciones experimentales para probar. No es necesario para el uso normal.';

  @override
  String get settingsGroupDevelopment => 'Desarrollo';

  @override
  String get settingsSectionDevelopment => 'Funciones de prueba';

  @override
  String get settingsCategoryDevelopmentHint =>
      'Experimental, solo para pruebas';

  @override
  String get settingsDevelopmentNoteTitle => 'Funciones experimentales';

  @override
  String get settingsDevelopmentNote =>
      'Estas funciones son para pruebas. Pueden cambiar, tener errores o volver a desaparecer. No están pensadas para actuaciones. Ocúltalas con “Modo desarrollador” en General.';

  @override
  String get settingsSectionMidi => 'Teclado (MIDI)';

  @override
  String get settingsCategoryMidiHint =>
      'Program changes a un teclado conectado por USB';

  @override
  String get settingsMidiEnabled => 'Program changes MIDI';

  @override
  String get settingsMidiEnabledHint =>
      'En el modo en vivo, el teclado cambia al programa guardado para cada canción.';

  @override
  String settingsMidiConnected(String name) {
    return 'Conectado a $name';
  }

  @override
  String get settingsMidiNotConnected => 'No conectado';

  @override
  String get settingsMidiOutput => 'Salida';

  @override
  String get settingsMidiOutputHint =>
      'El teclado conectado por USB. setDING se vuelve a conectar solo cuando se enchufa.';

  @override
  String get settingsMidiNoDevices =>
      'No se encontró ningún dispositivo MIDI. Conecta el teclado por USB y busca de nuevo.';

  @override
  String get settingsMidiSearch => 'Buscar de nuevo';

  @override
  String settingsMidiOutputMissing(String name) {
    return '$name (no enchufado)';
  }

  @override
  String get settingsMidiProfile => 'Perfil del dispositivo';

  @override
  String get settingsMidiProfileHint =>
      'Cómo se introducen y muestran los programas del teclado. “Genérico” usa bank select y número de programa y funciona con cualquier teclado.';

  @override
  String get midiProfileNordStage3 => 'Nord Stage 3';

  @override
  String get midiProfileGeneric => 'Genérico';

  @override
  String get settingsMidiChannel => 'Canal MIDI';

  @override
  String get settingsMidiChannelHint => 'El canal en el que recibe el teclado.';

  @override
  String get settingsMidiTakeOver => 'Adoptar programas del teclado';

  @override
  String get settingsMidiTakeOverHint =>
      'Mientras el programa del teclado está abierto en el modo en vivo, setDING muestra el sonido que eliges en el teclado y, si quieres, lo adopta en la canción. El teclado tiene que enviar bank select y program change.';

  @override
  String get settingsMidiTakeOverNordHint =>
      'Mientras el programa del teclado está abierto en el modo en vivo, setDING muestra el sonido que eliges en el Nord y, si quieres, lo adopta en la canción. En el Nord, ajusta “Program Change” a “Send” o “Send & Receive” en el menú MIDI.';

  @override
  String get settingsMidiNordHint =>
      'En el Nord Stage 3, activa la recepción de “Program Change” en su menú MIDI y ajusta aquí el canal al canal global del Nord. La numeración de los songs del Nord depende de la versión del SO del Nord (comprobado con el SO 2.54); si un song no coincide, usa el perfil “Genérico”.';

  @override
  String get midiProgramTitle => 'Programa del teclado';

  @override
  String get midiProgramHint =>
      'Se envía al teclado en el modo en vivo cuando llega esta canción.';

  @override
  String get midiProgramNone => 'Ninguno: el teclado mantiene su sonido';

  @override
  String get midiProgramChoose => 'Elegir programa';

  @override
  String get midiProgramPreviewSwitch => 'Enviar al seleccionar';

  @override
  String get midiProgramPreviewHint =>
      'Cada elección va al teclado al instante; Cancelar restaura el programa anterior.';

  @override
  String get midiProgramRemove => 'Quitar programa';

  @override
  String get midiProgramTest => 'Probar';

  @override
  String get midiProgramTestHint => 'Envía el programa al teclado una vez';

  @override
  String get midiProgramNotConnected => 'Teclado no conectado';

  @override
  String get midiProgramOff =>
      'Los program changes MIDI están desactivados en este dispositivo (ajustes: Teclado (MIDI)).';

  @override
  String midiProgramSent(String device) {
    return 'Enviado a $device';
  }

  @override
  String get midiProgramSendFailed => 'No se pudo enviar el programa';

  @override
  String get midiProgramKindProgram => 'Programa';

  @override
  String get midiProgramKindLive => 'Live memory';

  @override
  String get midiProgramKindSong => 'Song';

  @override
  String get midiProgramKindGeneric => 'Otros valores';

  @override
  String get midiProgramBank => 'Banco';

  @override
  String get midiProgramPageButton => 'Página (fila) y botón';

  @override
  String get midiProgramSongNumber => 'Song';

  @override
  String get midiProgramPreviousSong => 'Song anterior';

  @override
  String get midiProgramNextSong => 'Song siguiente';

  @override
  String get midiProgramPart => 'Parte';

  @override
  String get midiProgramSongHint =>
      'La numeración de los songs del Nord depende de la versión del SO del Nord (comprobado con el SO 2.54). Si un song no coincide, usa el perfil “Genérico” en los ajustes.';

  @override
  String get midiProgramsTitle => 'Programas del teclado';

  @override
  String midiProgramDevice(String profile) {
    return 'Este dispositivo: $profile';
  }

  @override
  String get midiProgramForOtherKeyboard => 'Programa para otro teclado';

  @override
  String midiProgramUnknownKeyboard(String id) {
    return 'Teclado desconocido ($id)';
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
    return 'Introduce un número de $min a $max';
  }

  @override
  String midiProgramValueNord(String name) {
    return 'Programa $name';
  }

  @override
  String get midiProfileMotifXf => 'Yamaha Motif XF';

  @override
  String get settingsMidiMotifHint =>
      'En el Motif XF, en Utility → Control (F5) → MIDI (SF2): ajusta MIDI IN/OUT a USB, activa la recepción de Bank Select y Program Change, ajusta el Basic Receive Channel al canal de aquí y el Device Number a “all” o 1, y guarda con Store. setDING pone el Motif en modo voice o performance por sí mismo antes de cada programa.';

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
      'Como en la pantalla del Motif XF, p. ej. USR1 A01. setDING pone el Motif en modo voice o performance antes de enviar.';

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
  String get trash => 'Papelera';

  @override
  String trashWithCount(int count) {
    return 'Papelera ($count)';
  }

  @override
  String get trashSongsTitle => 'Canciones eliminadas';

  @override
  String get trashSetsTitle => 'Sets eliminados';

  @override
  String trashEmpty(int days) {
    return 'La papelera está vacía. Las canciones y los sets eliminados se pueden restaurar aquí durante $days días.';
  }

  @override
  String trashHint(int days) {
    return 'Las canciones y los sets eliminados se pueden restaurar durante $days días. Después se eliminan definitivamente.';
  }

  @override
  String trashDeletedOn(String date) {
    return 'eliminado el $date';
  }

  @override
  String trashDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'quedan $days días',
      one: 'queda 1 día',
      zero: 'último día',
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
  String get trashGroupToday => 'Hoy';

  @override
  String get trashGroupWeek => 'Esta semana';

  @override
  String get trashGroupOlder => 'Más antiguos';

  @override
  String trashMenu(String title) {
    return 'Acciones para \"$title\"';
  }

  @override
  String get trashPurge => 'Eliminar definitivamente';

  @override
  String get trashPurgeTitle => '¿Eliminar definitivamente?';

  @override
  String trashPurgeOne(String title) {
    return '\"$title\" se eliminará definitivamente. No se puede deshacer.';
  }

  @override
  String trashPurgeMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos se eliminarán',
      one: '1 elemento se eliminará',
    );
    return '$_temp0 definitivamente. No se puede deshacer.';
  }

  @override
  String get trashEmptyAction => 'Vaciar papelera';

  @override
  String get trashEmptyTitle => '¿Vaciar la papelera?';

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
  String get backupExport => 'Hacer copia de la biblioteca';

  @override
  String get backupSyncing => 'Sincronizando con el servidor …';

  @override
  String get backupCollecting => 'Creando la copia de seguridad …';

  @override
  String get backupSaved => 'Copia de seguridad guardada.';

  @override
  String get backupFailedTitle => 'Copia de seguridad no posible';

  @override
  String get backupSyncDeferred =>
      'El modo en vivo está abierto. Ciérralo e inténtalo de nuevo.';

  @override
  String get backupSyncFailed =>
      'La sincronización con el servidor falló. La copia de seguridad de una organización necesita una conexión que funcione, para que lo contenga todo. Inténtalo de nuevo cuando tengas conexión.';

  @override
  String get backupPendingChanges =>
      'Hay cambios de este dispositivo que aún no han llegado al servidor. Espera la sincronización e inténtalo de nuevo.';

  @override
  String get backupConflicts =>
      'Algunas canciones tienen un conflicto de sincronización. Resuelve primero los conflictos.';

  @override
  String get backupMissingFiles =>
      'Aún no se han descargado todos los adjuntos. Espera a la descarga e inténtalo de nuevo.';

  @override
  String backupFileMissing(String name, String song) {
    return 'No se pudo cargar el adjunto \"$name\" de \"$song\".';
  }

  @override
  String get backupInvalid =>
      'Este archivo no es una copia de seguridad de setDING.';

  @override
  String get backupNewer =>
      'Esta copia de seguridad se hizo con una versión más reciente de setDING. Actualiza la app para importarla.';

  @override
  String get backupImportTitle => 'Importar copia de seguridad';

  @override
  String backupImportSummary(String library, int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs canciones',
      one: '1 canción',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'Copia de seguridad de \"$library\": $_temp0, $_temp1.';
  }

  @override
  String get backupImportCopyHint =>
      'Todo se importa como copia en la biblioteca actual. No se cambia nada existente.';

  @override
  String backupImportIdentical(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones ya están',
      one: '1 canción ya está',
    );
    return '$_temp0 aquí con el mismo texto y se usarán tal cual.';
  }

  @override
  String backupImportDiffering(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones existen',
      one: '1 canción existe',
    );
    return '$_temp0 aquí con un texto distinto:';
  }

  @override
  String get backupKeepExisting => 'Mantener las canciones existentes';

  @override
  String get backupAddAll => 'Importar como canciones adicionales';

  @override
  String get backupImportSetsTo => 'Los sets van a:';

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
  String get backupSkipSets => 'No importar';

  @override
  String get backupImportStart => 'Importar';

  @override
  String get backupImportDone => 'Copia de seguridad importada';

  @override
  String backupResultSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones importadas',
      one: '1 canción importada',
    );
    return '$_temp0';
  }

  @override
  String backupResultIdentical(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones ya estaban aquí',
      one: '1 canción ya estaba aquí',
    );
    return '$_temp0';
  }

  @override
  String backupResultKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones existentes mantenidas',
      one: '1 canción existente mantenida',
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
      zero: 'Ningún set importado',
    );
    return '$_temp0';
  }

  @override
  String backupResultFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count adjuntos',
      one: '1 adjunto',
    );
    return '$_temp0';
  }

  @override
  String backupResultAdditional(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Estas canciones ahora existen dos veces. Compáralas con las existentes y elimina las que no necesites:',
      one: 'Esta canción ahora existe dos veces. Compárala con la existente y elimina la que no necesites:',
    );
    return '$_temp0';
  }

  @override
  String get bandDelete => 'Eliminar banda';

  @override
  String bandDeleteTitle(String band) {
    return '¿Eliminar $band?';
  }

  @override
  String bandDeleteMessage(int days) {
    return 'Sus sets, arreglos de banda y membresías se eliminan con ella, y sus invitaciones abiertas se revocan. Las canciones se quedan en la biblioteca de la organización. Los admins de la organización pueden restaurar la banda desde la papelera durante $days días. Para guardar una copia fuera de setDING, haz primero una copia de la biblioteca.';
  }

  @override
  String bandDeleteSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
      zero: 'ningún set',
    );
    return '$_temp0';
  }

  @override
  String bandDeleteMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '1 miembro',
      zero: 'ningún miembro',
    );
    return '$_temp0';
  }

  @override
  String bandDeleteInvites(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitaciones abiertas',
      one: '1 invitación abierta',
      zero: 'ninguna invitación abierta',
    );
    return '$_temp0';
  }

  @override
  String get bandDeleteLastBand =>
      'Esta es la última banda de la organización. La organización y su biblioteca de canciones se mantienen.';

  @override
  String bandDeleteConfirmName(String band) {
    return 'Escribe \"$band\" para confirmar';
  }

  @override
  String bandDeleted(String band) {
    return '$band eliminada';
  }

  @override
  String get trashBandsTitle => 'Bandas eliminadas';

  @override
  String trashBandsEmpty(int days) {
    return 'No hay bandas eliminadas. Las bandas eliminadas se pueden restaurar aquí durante $days días.';
  }

  @override
  String trashBandsHint(int days) {
    return 'Las bandas eliminadas se pueden restaurar con sus sets, arreglos y miembros durante $days días. Después se eliminan definitivamente.';
  }

  @override
  String bandsGone(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$names ya no están disponibles para ti: las bandas se eliminaron o ya no eres miembro.',
      one:
          '$names ya no está disponible para ti: la banda se eliminó o ya no eres miembro.',
    );
    return '$_temp0';
  }

  @override
  String get backupAll => 'Hacer copia de todo';

  @override
  String get backupAllName => 'todo';

  @override
  String get backupAllHint =>
      'Tus bibliotecas con canciones, sets y adjuntos, tus ajustes personales y notas, y tu configuración, en un solo archivo.';

  @override
  String get backupNever =>
      'Aún no hay copia de seguridad en este dispositivo.';

  @override
  String backupLast(String date) {
    return 'Última copia de seguridad: $date';
  }

  @override
  String get backupRestore => 'Restaurar copia de seguridad';

  @override
  String get backupRestoreHint =>
      'Importa un archivo de copia de seguridad como copia, o reemplaza la biblioteca “En este dispositivo” por su copia de seguridad.';

  @override
  String get backupRestoreTitle => 'Restaurar copia de seguridad';

  @override
  String backupLibraryTo(String library, int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs canciones',
      one: '1 canción',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return '\"$library\" ($_temp0, $_temp1) en';
  }

  @override
  String get backupImportDifferingAll =>
      'Canciones que existen aquí con un texto distinto:';

  @override
  String get backupRestorePersonal =>
      'Restaurar mis ajustes personales y notas';

  @override
  String backupPersonalOf(String library, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '1 canción',
    );
    return '$library: $_temp0';
  }

  @override
  String get backupRestoreSettings => 'Restaurar mi configuración';

  @override
  String get backupRestoreSettingsHint =>
      'Reemplaza tu configuración actual por la de la copia de seguridad.';

  @override
  String get backupRestoreStart => 'Restaurar';

  @override
  String get backupRestoreDone => 'Copia de seguridad restaurada';

  @override
  String backupResultPersonal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '1 canción',
    );
    return 'Ajustes personales y notas de $_temp0 restaurados';
  }

  @override
  String get backupResultSettings => 'Configuración restaurada';

  @override
  String backupReminder(int days) {
    return 'Tu biblioteca en este dispositivo no tiene copia de seguridad desde hace $days días.';
  }

  @override
  String get backupReminderAction => 'Hacer copia';

  @override
  String get orgClose => 'Cerrar organización';

  @override
  String orgCloseTitle(String org) {
    return '¿Cerrar $org?';
  }

  @override
  String orgCloseMessage(int days) {
    return 'Se quitan sus bandas, sets, canciones y adjuntos y los ajustes personales de todos para sus canciones, y se revocan sus invitaciones. Los miembros se enteran en su próxima sincronización. Sus admins pueden restaurarla desde la papelera durante $days días; después todo se elimina definitivamente.';
  }

  @override
  String orgCloseBands(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bandas',
      one: '1 banda',
      zero: 'ninguna banda',
    );
    return '$_temp0';
  }

  @override
  String orgCloseSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '1 canción',
      zero: 'ninguna canción',
    );
    return '$_temp0';
  }

  @override
  String orgClosePeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas',
      one: '1 persona',
    );
    return '$_temp0';
  }

  @override
  String get orgCloseBackup => 'Hacer copia primero';

  @override
  String orgClosed(String org) {
    return '$org cerrada';
  }

  @override
  String get orgsClosedTitle => 'Organizaciones cerradas';

  @override
  String orgsClosedEmpty(int days) {
    return 'No hay organizaciones cerradas. Sus admins pueden restaurar aquí las organizaciones cerradas durante $days días.';
  }

  @override
  String orgsClosedHint(int days) {
    return 'Las organizaciones cerradas se pueden restaurar con todo su contenido durante $days días. Después se eliminan definitivamente.';
  }

  @override
  String orgClosedOn(String date) {
    return 'cerrada el $date';
  }

  @override
  String orgClosedBy(String name) {
    return 'por $name';
  }

  @override
  String orgClosedNotice(String org, String name, int days) {
    return '$name cerró $org. Sus admins pueden restaurarla durante $days días.';
  }

  @override
  String orgClosedNoticeAnonymous(String org, int days) {
    return '$org se cerró. Sus admins pueden restaurarla durante $days días.';
  }

  @override
  String get navOverview => 'Resumen';

  @override
  String get overviewNextSet => 'Próximo set';

  @override
  String get overviewLastEditedSet => 'Último set editado';

  @override
  String overviewSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '1 canción',
      zero: 'Ninguna canción',
    );
    return '$_temp0';
  }

  @override
  String get overviewStartLive => 'Empezar en vivo';

  @override
  String get overviewOpenSet => 'Abrir set';

  @override
  String get overviewTodo => 'Pendiente';

  @override
  String overviewTodoProblems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones con problemas de ChordPro',
      one: '1 canción con problemas de ChordPro',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones con conflictos de sincronización',
      one: '1 canción con un conflicto de sincronización',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoSheetMusicOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones solo con partitura (PDF)',
      one: '1 canción solo con partitura (PDF)',
    );
    return '$_temp0';
  }

  @override
  String get attentionProblems => 'Problemas de ChordPro';

  @override
  String get attentionConflicts => 'Conflictos de sincronización';

  @override
  String get attentionSheetMusicOnly => 'Solo partitura';

  @override
  String chordProConversionsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Convertir $count partes del ChordPro',
      one: 'Convertir 1 parte del ChordPro',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoConversions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones con posibles conversiones',
      one: '1 canción con posibles conversiones',
    );
    return '$_temp0';
  }

  @override
  String get attentionConversions => 'Convertibles';

  @override
  String get convertAllSongs => 'Convertir todas';

  @override
  String get convertAllSongsTitle => '¿Convertir todas las canciones?';

  @override
  String convertAllSongsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Las $count canciones se convierten',
      one: 'La canción se convierte',
    );
    return '$_temp0 para todos: directivas CCLI y etiquetas de sección como recomienda la especificación ChordPro, barras de compás CCLI como cuadrículas, pie CCLI quitado.';
  }

  @override
  String songsConverted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones convertidas',
      one: '1 canción convertida',
    );
    return '$_temp0';
  }

  @override
  String songConverted(String title) {
    return '“$title” convertida';
  }

  @override
  String get songsFilterEmpty => 'No quedan canciones en este filtro.';

  @override
  String get playHistory => 'Tocada';

  @override
  String playHistoryOf(String band) {
    return 'Tocada por $band';
  }

  @override
  String playHistoryNone(String band) {
    return '$band aún no ha tocado esta canción en un set pasado.';
  }

  @override
  String get playHistoryTotal => 'en total';

  @override
  String get playHistoryLastYear => 'últimos 12 meses';

  @override
  String get playHistoryLast => 'última vez';

  @override
  String playHistoryFirst(String date) {
    return 'Primera vez el $date';
  }

  @override
  String playHistoryShowAll(int count) {
    return 'Mostrar las $count';
  }

  @override
  String playHistoryDiffers(String key) {
    return 'Resaltado: una tonalidad distinta de la de hoy ($key)';
  }

  @override
  String get playHistoryApproximate =>
      '≈ derivado del arreglo de hoy: el set no tiene valores guardados';

  @override
  String keyHistoryLast(String key, String date) {
    return 'Última vez en $key el $date';
  }

  @override
  String keyHistoryMostly(String key, int count, int total) {
    return 'sobre todo en $key ($count de $total)';
  }

  @override
  String songLastPlayed(String date) {
    return 'Tocada por última vez el $date';
  }

  @override
  String get songNeverPlayed => 'Nunca tocada';

  @override
  String get overviewRecentChanges => 'Cambios recientes';

  @override
  String get overviewShowAll => 'Mostrar todo';

  @override
  String get overviewMoreSets => 'Más sets';

  @override
  String get overviewNewestSongs => 'Canciones más recientes';

  @override
  String get recentChangesEmpty =>
      'Ningún cambio de otros en los últimos 30 días.';

  @override
  String get changeSongAdded => 'Nueva canción';

  @override
  String get changeNewSet => 'Nuevo set';

  @override
  String get changeSongText => 'Texto cambiado';

  @override
  String get changeSongPdf => 'PDF cambiado';

  @override
  String get changeSongTextAndPdf => 'Texto y PDF cambiados';

  @override
  String changeSetAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones añadidas',
      one: '1 canción añadida',
    );
    return '$_temp0';
  }

  @override
  String changeSetRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones quitadas',
      one: '1 canción quitada',
    );
    return '$_temp0';
  }

  @override
  String changeSetAlsoRemoved(int count) {
    return '$count quitadas';
  }

  @override
  String changeSetSequence(String songs) {
    return 'secuencia de $songs cambiada';
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
  String get repertoire => 'Repertorio';

  @override
  String repertoireOf(String band) {
    return 'Repertorio de $band';
  }

  @override
  String get repertoireLastYear => '12 meses';

  @override
  String get repertoireAllTime => 'Desde siempre';

  @override
  String get repertoireMostPlayed => 'Más tocadas';

  @override
  String get repertoireStale => 'Sin tocar desde hace tiempo';

  @override
  String repertoireStaleHint(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'Tocada por última vez hace más de $months meses',
      one: 'Tocada por última vez hace más de un mes',
    );
    return '$_temp0';
  }

  @override
  String get playedFilter => 'Tocadas';

  @override
  String get playedAll => 'Todas';

  @override
  String get filterByPlayed => 'Filtrar por interpretaciones de la banda';

  @override
  String get repertoireNeverPlayed => 'Nunca tocadas';

  @override
  String get repertoireNeverPlayedHint =>
      'Canciones de la biblioteca que no estuvieron en ningún set pasado de la banda';

  @override
  String get repertoireNone => 'Ninguna';

  @override
  String get repertoireEmpty =>
      'La banda aún no ha tocado canciones en sets pasados.';

  @override
  String repertoirePlays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count veces',
      one: 'una vez',
    );
    return '$_temp0';
  }

  @override
  String get repertoireThreshold =>
      '¿Cuándo cuenta una canción como sin tocar desde hace tiempo?';

  @override
  String repertoireMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'Tras $months meses',
      one: 'Tras 1 mes',
    );
    return '$_temp0';
  }

  @override
  String repertoireDefault(int months) {
    return 'Por defecto: tras $months meses';
  }

  @override
  String get sortByLastPlayed => 'Última vez tocada';

  @override
  String get playHistoryOtherBands => 'Otras bandas';

  @override
  String playHistoryFetched(String date) {
    return 'A fecha de $date';
  }

  @override
  String get libraryUsage => 'Uso de la biblioteca';

  @override
  String libraryUsageSummary(int count, int total) {
    return 'Ninguna banda toca $count de $total canciones';
  }

  @override
  String get libraryUsageHint =>
      'Canciones que no estuvieron en ningún set pasado de ninguna banda de la organización. Mueve a la papelera lo que ninguna banda necesite ya.';

  @override
  String get libraryUsageNotLoaded =>
      'Aún no cargado: sincroniza una vez con conexión al servidor.';

  @override
  String get libraryUsageAllPlayed =>
      'Todas las canciones de la biblioteca han sido tocadas por alguna banda.';

  @override
  String syncHintSongChanged(String title, String name) {
    return '$name cambió \"$title\".';
  }

  @override
  String syncHintSongDeleted(String title, String name) {
    return '$name eliminó \"$title\".';
  }

  @override
  String syncHintSetChanged(String title, String name) {
    return '$name cambió el set \"$title\".';
  }

  @override
  String syncHintSetDeleted(String title, String name) {
    return '$name eliminó el set \"$title\".';
  }

  @override
  String syncHintSongChangedAnonymous(String title) {
    return 'Otra persona cambió \"$title\".';
  }

  @override
  String syncHintSongDeletedAnonymous(String title) {
    return 'Otra persona eliminó \"$title\".';
  }

  @override
  String syncHintSetChangedAnonymous(String title) {
    return 'Otra persona cambió el set \"$title\".';
  }

  @override
  String syncHintSetDeletedAnonymous(String title) {
    return 'Otra persona eliminó el set \"$title\".';
  }

  @override
  String syncHintAfterLive(String changes) {
    return 'Mientras tocabas en vivo: $changes.';
  }

  @override
  String syncHintSongsChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones cambiadas',
      one: '1 canción cambiada',
    );
    return '$_temp0';
  }

  @override
  String syncHintSongsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones eliminadas',
      one: '1 canción eliminada',
    );
    return '$_temp0';
  }

  @override
  String syncHintSetsChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets cambiados',
      one: '1 set cambiado',
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
      'El ZIP contiene los archivos ChordPro de las canciones y una descripción con la que setDING vuelve a importar el set como set.';

  @override
  String get setArchiveArrangements =>
      'Arreglos de la banda para las canciones (tonalidad, secuencia, tempo)';

  @override
  String get setArchiveSetSettings =>
      'Tonalidad y secuencia de las canciones en este set';

  @override
  String get setArchiveAttachments => 'Adjuntos (PDF, imágenes)';

  @override
  String get setArchivePersonal => 'Mis ajustes personales y notas';

  @override
  String get setArchivePersonalHint =>
      'Déjalo desactivado si pasas el archivo a otros.';

  @override
  String get setExportStart => 'Exportar';

  @override
  String get exportMenu => 'Exportar …';

  @override
  String get exportFormat => 'Formato';

  @override
  String get exportFormatChordPro => 'Archivo ChordPro';

  @override
  String get exportFormatChordProHint =>
      'Para otras apps, sin adjuntos ni arreglos';

  @override
  String get exportFormatSetListPdf => 'Setlist en PDF';

  @override
  String get exportFormatSetListPdfHint => 'Para imprimir';

  @override
  String get exportFormatArchive => 'Archivo setDING (ZIP)';

  @override
  String get exportFormatArchiveHint =>
      'Para importar en setDING, con adjuntos y arreglos si quieres';

  @override
  String get songExportHintChordPro =>
      'El archivo ChordPro contiene la letra y los acordes de la canción y se abre en cualquier app que conozca ChordPro.';

  @override
  String get setExportHintPdf =>
      'El setlist muestra cada canción con su tonalidad y secuencia, para imprimirlo para el escenario.';

  @override
  String get setImport => 'Importar set';

  @override
  String get setImportFromFile => 'Importar desde archivo …';

  @override
  String get setImportTitle => 'Importar set';

  @override
  String get setImportBand => 'Banda';

  @override
  String get setImportNoBand =>
      'En esta biblioteca no hay ninguna banda cuyos sets puedas gestionar.';

  @override
  String setImportExisting(String name) {
    return 'La banda ya tiene este set como \"$name\".';
  }

  @override
  String get setImportReplace => 'Reemplazarlo';

  @override
  String get setImportCopy => 'Añadir como copia';

  @override
  String setImportOverwriteArrangements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '1 canción',
    );
    return 'Sobrescribir los arreglos de la banda de $_temp0';
  }

  @override
  String get setImportDone => 'Set importado';

  @override
  String get setImportReplaced => 'El set existente se reemplazó.';

  @override
  String setImportResultArrangements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arreglos de banda guardados',
      one: '1 arreglo de banda guardado',
    );
    return '$_temp0';
  }

  @override
  String get setImportResultMissing =>
      'No están en la biblioteca, se muestran como elementos de texto en el set:';

  @override
  String get setImportOpen => 'Abrir set';

  @override
  String setImportMissingNote(String title) {
    return 'Falta: $title';
  }

  @override
  String get setArchiveInvalid => 'Este archivo no es un set exportado.';

  @override
  String get setArchiveNewer =>
      'Este set se exportó con una versión más reciente de setDING. Actualiza la app para importarlo.';

  @override
  String setImportFrom(String band, int songs) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs canciones',
      one: '1 canción',
      zero: 'ninguna canción',
    );
    return 'de $band · $_temp0';
  }

  @override
  String get setImportHeadingTarget => 'Destino';

  @override
  String get setImportHeadingExisting => 'Set ya existente';

  @override
  String get setImportHeadingSongs => 'Canciones';

  @override
  String get setImportHeadingInclude => 'Incluir';

  @override
  String get setExportHeadingInclude => 'Incluir en el archivo';

  @override
  String setImportNewName(String name) {
    return 'Se añadirá como \"$name\".';
  }

  @override
  String setImportSongsHere(int count) {
    return '$count ya aquí con el mismo texto';
  }

  @override
  String setImportSongsNew(int count) {
    return '$count nuevas, añadidas a la biblioteca';
  }

  @override
  String setImportSongsDiffering(int count) {
    return '$count aquí con un texto distinto';
  }

  @override
  String setImportSongsMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'las muestra',
      one: 'la muestra',
    );
    return '$count no están en la biblioteca: no puedes añadir canciones, así que el set $_temp0 como texto';
  }

  @override
  String get setImportKeep => 'Mantener existentes';

  @override
  String get setImportAddAll => 'Importar también';

  @override
  String setImportCopyName(String name) {
    return '$name (copia)';
  }

  @override
  String setImportCopyNameNumbered(String name, int number) {
    return '$name (copia $number)';
  }

  @override
  String get keyboardShortcuts => 'Atajos de teclado';

  @override
  String get shortcutsEverywhere => 'En todas partes';

  @override
  String get shortcutsSong => 'Canción';

  @override
  String get shortcutsSet => 'Set';

  @override
  String get shortcutsSongList => 'Lista de canciones';

  @override
  String get shortcutsLive => 'Modo en vivo';

  @override
  String get shortcutBack => 'Atrás';

  @override
  String get shortcutHelp => 'Mostrar los atajos de teclado';

  @override
  String get shortcutEditSong => 'Editar la canción';

  @override
  String get shortcutEditSet => 'Editar el set';

  @override
  String get shortcutLive => 'Iniciar el modo en vivo';

  @override
  String get shortcutTranspose => 'Transponer arriba / abajo';

  @override
  String get shortcutPreviousNextSong => 'Canción anterior / siguiente del set';

  @override
  String get shortcutSearch => 'Buscar canciones';

  @override
  String get shortcutNextPage => 'Página siguiente';

  @override
  String get shortcutPreviousPage => 'Página anterior';

  @override
  String get shortcutBeat => 'Iniciar / detener el pulso';

  @override
  String get shortcutKeyPageDown => 'Av Pág';

  @override
  String get shortcutKeyPageUp => 'Re Pág';

  @override
  String get shortcutKeySpace => 'Espacio';

  @override
  String get shortcutCloseSelection => 'Cerrar la selección';

  @override
  String get settingsHeadingLanguageTheme => 'Idioma y tema';

  @override
  String get settingsHeadingEditor => 'Editor';

  @override
  String get settingsHeadingAdvanced => 'Avanzado';

  @override
  String get settingsHeadingChords => 'Acordes';

  @override
  String get settingsHeadingContent => 'Contenido';

  @override
  String get settingsHeadingSetNotes => 'Set y notas';

  @override
  String get settingsHeadingInstrument => 'Instrumento y voz';

  @override
  String get settingsHeadingScreen => 'Pantalla';

  @override
  String get settingsHeadingControls => 'Controles';

  @override
  String get settingsHeadingClick => 'Clic en este dispositivo';

  @override
  String get settingsHeadingBackup => 'Copia de seguridad';

  @override
  String get settingsHeadingThisDevice => 'Este dispositivo';

  @override
  String get settingsHeadingHelp => 'Ayuda e información';

  @override
  String get settingsHeadingConnection => 'Conexión';

  @override
  String get settingsHeadingKeyboard => 'Teclado';

  @override
  String get settingsHeadingStyle => 'Estilo';

  @override
  String get settingsHeadingPrototypes => 'Prototipos';

  @override
  String songExportTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Exportar $count canciones',
      one: 'Exportar canción',
    );
    return '$_temp0';
  }

  @override
  String get songExportHint =>
      'El ZIP contiene los archivos ChordPro y una descripción con la que setDING vuelve a importar las canciones, más lo que elijas abajo.';

  @override
  String songExportArrangements(String band) {
    return 'Arreglos de \"$band\" (tonalidad, secuencia, tempo)';
  }

  @override
  String get songImportTitle => 'Importar canciones';

  @override
  String songImportFrom(String library, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '1 canción',
    );
    return 'de $library · $_temp0';
  }

  @override
  String songImportLibrary(String name) {
    return 'En la biblioteca \"$name\"';
  }

  @override
  String get songImportArrangementsBand => 'Banda para los arreglos';

  @override
  String get songImportNoBand =>
      'En esta biblioteca no hay ninguna banda cuyos arreglos puedas cambiar.';

  @override
  String get songImportDone => 'Canciones importadas';

  @override
  String get songArchiveNewer =>
      'Estas canciones se exportaron con una versión más reciente de setDING. Actualiza la app para importarlas.';

  @override
  String archiveImportAttachmentsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count adjuntos añadidos',
      one: '1 adjunto añadido',
    );
    return '$_temp0 a canciones que ya están aquí';
  }

  @override
  String archiveResultCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count adjuntos añadidos',
      one: '1 adjunto añadido',
    );
    return '$_temp0 a canciones existentes';
  }

  @override
  String songLanguageName(String language) {
    String _temp0 = intl.Intl.selectLogic(language, {
      'de': 'Alemán',
      'gsw': 'Alemán suizo',
      'en': 'Inglés',
      'fr': 'Francés',
      'it': 'Italiano',
      'es': 'Español',
      'pt': 'Portugués',
      'nl': 'Neerlandés',
      'other': 'Otro',
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
  String get allLanguages => 'Todos los idiomas';

  @override
  String get noLanguage => 'Sin idioma';

  @override
  String get filterByLanguage => 'Filtrar por idioma';

  @override
  String songLanguageAutomatic(String language) {
    return 'Automático: $language';
  }

  @override
  String get songLanguageNotDetected => 'Automático (no detectado)';

  @override
  String get songLanguageAutomaticHint =>
      'Detectado a partir de la letra; una elección manual siempre tiene prioridad.';

  @override
  String songLanguageDetectedTooltip(String language) {
    return '$language (detectado a partir de la letra)';
  }

  @override
  String songLanguageByHandTooltip(String language) {
    return '$language (elegido a mano)';
  }

  @override
  String get languageVersions => 'Versiones en otros idiomas';

  @override
  String get linkLanguageVersion => 'Versiones en otros idiomas …';

  @override
  String get unlinkLanguageVersion =>
      'Quitar de las versiones en otros idiomas';

  @override
  String get languageVersionPickerEmpty =>
      'No hay más canciones que puedas vincular';

  @override
  String languageVersionsOf(String title) {
    return 'Versiones en otros idiomas de $title';
  }

  @override
  String languageVersionsChosen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Versiones vinculadas ($count)',
      zero: 'Versiones vinculadas',
    );
    return '$_temp0';
  }

  @override
  String get languageVersionsChosenEmpty =>
      'Aún no hay otras versiones. Elige canciones de la biblioteca.';

  @override
  String get languageVersionsSaved => 'Versiones en otros idiomas guardadas';

  @override
  String languageVersionsNotAllowed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count canciones no se vincularon: no puedes cambiar sus otras versiones.',
      one: 'Una canción no se vinculó: no puedes cambiar sus otras versiones.',
    );
    return '$_temp0';
  }

  @override
  String get languageVersionUnlinked =>
      'Quitada de las versiones en otros idiomas';

  @override
  String otherLanguageVersionsTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count versiones en otros idiomas',
      one: 'Otra versión en otro idioma',
    );
    return '$_temp0';
  }

  @override
  String get switchLanguageVersion => 'Cambiar de versión de idioma …';

  @override
  String switchedLanguageVersion(String version) {
    return 'Cambiado a: $version';
  }

  @override
  String switchedLanguageVersionKey(
    String version,
    String newKey,
    String oldKey,
  ) {
    return 'Cambiado a: $version, en $newKey en lugar de $oldKey en este set';
  }

  @override
  String get switchedLanguageVersionSequence =>
      'La secuencia propia del set no encaja con la nueva versión y se quitó.';

  @override
  String languageVersionInSet(String title, String key) {
    return '$title · en $key en este set';
  }

  @override
  String get switchLanguageVersionTitle => 'Cambiar de versión de idioma';

  @override
  String adjustmentOfferOne(String version, String what) {
    return 'Tus ajustes en “$version”: $what. ¿Usarlos también para esta versión?';
  }

  @override
  String get adjustmentOfferMany =>
      'Otras versiones de idioma tienen tus ajustes. ¿Usarlos también para esta versión?';

  @override
  String get adjustmentKindTranspose => 'tonalidad';

  @override
  String get adjustmentKindCapo => 'cejilla';

  @override
  String get adjustmentKindMidi => 'programa del teclado';

  @override
  String get adjustmentKindClick => 'clic';

  @override
  String get adjustmentOfferCopy => 'Usarlos';

  @override
  String get adjustmentOfferDismiss => 'No, gracias';

  @override
  String get adjustmentOfferPick => 'Usar los ajustes de';

  @override
  String adjustmentsCopied(String version) {
    return 'Ajustes de “$version” usados';
  }

  @override
  String get autoBackup => 'Copia de seguridad automática';

  @override
  String get autoBackupSwitch => 'Hacer copia automáticamente';

  @override
  String get autoBackupHint =>
      'Guarda la biblioteca “En este dispositivo” en una carpeta que elijas, como mucho una vez al día tras cambios. Usa una carpeta de tu almacenamiento en la nube para tenerla a salvo si pierdes el dispositivo.';

  @override
  String get autoBackupFolder => 'Carpeta';

  @override
  String get autoBackupFolderNone => 'Ninguna carpeta elegida';

  @override
  String get autoBackupChooseFolder => 'Elegir carpeta';

  @override
  String get autoBackupDevice => 'Nombre del dispositivo';

  @override
  String get autoBackupDeviceHint =>
      'Forma parte de los nombres de archivo, para que varios dispositivos puedan usar la misma carpeta.';

  @override
  String get autoBackupDeviceTitle => 'Nombre del dispositivo para las copias';

  @override
  String get autoBackupKeep => 'Copias conservadas';

  @override
  String get autoBackupKeepHint =>
      'Las copias automáticas más antiguas de este dispositivo se eliminan de la carpeta.';

  @override
  String get autoBackupNow => 'Hacer copia en la carpeta ahora';

  @override
  String get autoBackupRunning => 'Haciendo copia …';

  @override
  String get autoBackupNever => 'Aún no hay copia automática.';

  @override
  String autoBackupLast(String date) {
    return 'Última copia automática: $date';
  }

  @override
  String autoBackupFailed(String date, String reason) {
    return 'Falló el $date: $reason';
  }

  @override
  String get autoBackupErrorUnavailable => 'No se puede acceder a la carpeta.';

  @override
  String get autoBackupErrorPermission =>
      'setDING ya no puede escribir en la carpeta. Vuelve a elegirla.';

  @override
  String get autoBackupErrorFailed =>
      'No se pudo escribir la copia de seguridad.';

  @override
  String autoBackupHintFailed(String reason) {
    return 'La copia automática falló: $reason';
  }

  @override
  String autoBackupSaved(String file) {
    return 'Guardado como “$file”';
  }

  @override
  String get backupModeCopy => 'Añadir como copia';

  @override
  String get backupModeCopyHint =>
      'Las canciones y los sets se añaden con nuevos ID; no se cambia nada existente.';

  @override
  String get backupModeReplace => 'Reemplazar la biblioteca local';

  @override
  String get backupModeReplaceHint =>
      'La biblioteca “En este dispositivo” queda exactamente como en la copia, p. ej. en un dispositivo nuevo o para volver a un estado anterior.';

  @override
  String get backupReplaceTitle => '¿Reemplazar la biblioteca local?';

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
      other: '$songs canciones',
      one: '1 canción',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'Copia de “$device” del $date: $_temp0, $_temp1.';
  }

  @override
  String backupReplaceFrom(String date, int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs canciones',
      one: '1 canción',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'Copia del $date: $_temp0, $_temp1.';
  }

  @override
  String backupReplaceNow(int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs canciones',
      one: '1 canción',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'Ahora en este dispositivo: $_temp0, $_temp1. Se quitan, también los de la papelera.';
  }

  @override
  String get backupReplaceKeeps =>
      'El historial de interpretaciones vuelve con los sets de la copia. La configuración y las organizaciones no cambian.';

  @override
  String get backupReplaceSafety =>
      'Guardar primero una copia de seguridad de respaldo';

  @override
  String backupReplaceSafetyFolder(String folder) {
    return 'En la carpeta de la copia automática ($folder).';
  }

  @override
  String get backupReplaceSafetyChoose => 'Tú eliges dónde guardarla.';

  @override
  String get backupReplaceSafetySkip =>
      'Sin una copia de respaldo, la biblioteca actual no se puede restaurar.';

  @override
  String get backupReplaceAction => 'Reemplazar';

  @override
  String get backupReplaceRunning => 'Reemplazando la biblioteca local …';

  @override
  String backupReplaceDone(int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs canciones',
      one: '1 canción',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'Biblioteca local reemplazada: $_temp0, $_temp1.';
  }

  @override
  String backupReplaceSafetyFailed(String reason) {
    return 'No se pudo guardar la copia de respaldo, así que no se reemplazó nada: $reason';
  }

  @override
  String get showLocalLibrary => 'Mostrar la biblioteca local';

  @override
  String get showLocalLibraryHint =>
      '“En este dispositivo” en las listas de bibliotecas y bandas. Si solo tocas en organizaciones, puedes ocultarla; sus canciones y sets se quedan en este dispositivo.';

  @override
  String get showLocalLibrarySignedOut =>
      'Sin sesión iniciada, la biblioteca local siempre se muestra.';

  @override
  String localLibraryHidden(int songs, int sets) {
    String _temp0 = intl.Intl.pluralLogic(
      songs,
      locale: localeName,
      other: '$songs canciones',
      one: '1 canción',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return 'La biblioteca local está oculta. Sus $_temp0 y $_temp1 se quedan en este dispositivo y vuelven cuando la muestres de nuevo.';
  }

  @override
  String get localLibraryHiddenAutoBackup =>
      'La copia automática sigue funcionando; puedes desactivarla aquí.';

  @override
  String get chordViewChords => 'Acordes';

  @override
  String get chordViewNashville => 'Nashville';

  @override
  String get chordViewNumerals => 'Números romanos';

  @override
  String get liveChordViewChords => 'C';

  @override
  String get liveChordViewNashville => '1';

  @override
  String get liveChordViewNumerals => 'I';

  @override
  String get chordViewDocs =>
      'Cómo leer los números Nashville y los números romanos';

  @override
  String docsHelp(String topic) {
    return 'Ayuda: $topic';
  }

  @override
  String get editorDocsTopic => 'Editor ChordPro';

  @override
  String get settingsDocs => 'Guía de uso';

  @override
  String get settingsDocsHint =>
      'Abrir la documentación de setDING en setding.app (en inglés). El icono del libro arriba abre la página de la sección abierta.';

  @override
  String get overviewReadiness => 'Listos para tocar';

  @override
  String readinessAllSet(String set) {
    return 'Todo listo para “$set”';
  }

  @override
  String get readinessAllSetNoSet => 'Todo listo';

  @override
  String get readinessShowDetails => 'Mostrar detalles';

  @override
  String get readinessHideDetails => 'Ocultar detalles';

  @override
  String readinessMusician(String who) {
    return 'Músico: $who';
  }

  @override
  String get readinessNoInstrument => 'Ningún instrumento elegido';

  @override
  String readinessMidiConnected(String device) {
    return 'MIDI: $device conectado';
  }

  @override
  String get readinessMidiNotConnected => 'MIDI: teclado no conectado';

  @override
  String get readinessMidiNoOutput => 'MIDI: ningún teclado elegido';

  @override
  String readinessMidiProfile(String profile) {
    return 'Perfil: $profile';
  }

  @override
  String get readinessOfflineReady => 'Próximo set disponible sin conexión';

  @override
  String readinessOfflineMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones del próximo set no están disponibles',
      one: '1 canción del próximo set no está disponible',
    );
    return '$_temp0 sin conexión';
  }

  @override
  String readinessSynced(String time) {
    return 'Sincronizado: $time';
  }

  @override
  String get readinessSyncNever => 'Aún no sincronizado en este dispositivo';

  @override
  String get readinessSyncStale => 'Puede que los datos no estén actualizados';

  @override
  String get readinessSyncManual =>
      'La sincronización es manual: sincroniza antes del concierto.';

  @override
  String get readinessPageTurnerResponds => 'El pasapáginas responde';

  @override
  String readinessPageTurnerLastUsed(String time) {
    return 'Pasapáginas: usado por última vez $time';
  }

  @override
  String get readinessPageTurnerNever =>
      'Pasapáginas: aún no usado en este dispositivo';

  @override
  String readinessPageTurnerDetail(String mode) {
    return 'Pasa: $mode · pulsa aquí el pedal para probarlo';
  }

  @override
  String get readinessBackupNoFolder =>
      'Copia automática: ninguna carpeta elegida';

  @override
  String get readinessBackupFailed => 'La copia automática falló';

  @override
  String get keyGuessHint => 'Sugerida a partir de los acordes:';

  @override
  String keyGuessUse(String key) {
    return 'Usar $key como tonalidad';
  }

  @override
  String get attentionNoKey => 'Sin tonalidad';

  @override
  String overviewTodoNoKey(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones sin tonalidad',
      one: '1 canción sin tonalidad',
    );
    return '$_temp0';
  }

  @override
  String readinessPageTurnerConnected(String name) {
    return 'Pasapáginas $name conectado';
  }

  @override
  String readinessPageTurnerNotConnected(String name) {
    return 'Pasapáginas $name no conectado';
  }

  @override
  String get readinessKeyboardConnected => 'Hay un teclado conectado';

  @override
  String get readinessKeyboardNotConnected =>
      'Pasapáginas: ningún teclado conectado';

  @override
  String get settingsPageTurner => 'Pasapáginas';

  @override
  String get settingsPageTurnerNone => 'No emparejado';

  @override
  String get settingsPageTurnerConnected => 'conectado';

  @override
  String get settingsPageTurnerNotConnected => 'no conectado';

  @override
  String get settingsPageTurnerHint =>
      'Empareja tu pedal para que el resumen muestre si está conectado.';

  @override
  String get settingsPageTurnerPair => 'Emparejar';

  @override
  String get settingsPageTurnerPairAgain => 'Emparejar de nuevo';

  @override
  String get settingsPageTurnerForget => 'Olvidar pasapáginas';

  @override
  String get settingsPageTurnerKeyboardOnly =>
      'Este dispositivo solo indica si hay un teclado conectado, no cuál. El resumen lo muestra.';

  @override
  String get settingsPageTurnerUnsupported =>
      'No es posible en esta plataforma. El resumen muestra cuándo se usó el pasapáginas por última vez.';

  @override
  String get pairPageTurnerTitle => 'Emparejar pasapáginas';

  @override
  String get pairPageTurnerPrompt => 'Pulsa ahora el pedal.';

  @override
  String pageTurnerPaired(String name) {
    return 'Pasapáginas emparejado: $name';
  }

  @override
  String pageTurnerForgotten(String name) {
    return 'Pasapáginas olvidado: $name';
  }

  @override
  String get pageTurnerUnnamed => 'Dispositivo sin nombre';

  @override
  String importKeySuggestionsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones importadas no tienen',
      one: '1 canción importada no tiene',
    );
    return '$_temp0 tonalidad. Sugerida a partir de los acordes; un toque fija la tonalidad:';
  }

  @override
  String importKeySuggestionsMore(int count) {
    return '… y $count más: Pendiente en el resumen, Sin tonalidad.';
  }

  @override
  String importKeysSet(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tonalidades fijadas en $count canciones',
      one: 'Tonalidad fijada en 1 canción',
      zero: 'Ninguna tonalidad fijada',
    );
    return '$_temp0';
  }

  @override
  String get readinessPageTurnerNotPaired => 'Pasapáginas no emparejado';

  @override
  String readinessPageTurnerPairDetail(String mode) {
    return 'Emparéjalo para que el resumen muestre si está conectado · Pasa: $mode';
  }

  @override
  String get settingsPageTurnerUse => 'Uso un pasapáginas';

  @override
  String get settingsPageTurnerUseHint =>
      'Un pedal que pasa las páginas. Lo muestra en el resumen y ofrece emparejar uno detectado.';

  @override
  String pageTurnerDetected(String name) {
    return 'Pasapáginas detectado: $name';
  }

  @override
  String get attentionToReview => 'Por revisar';

  @override
  String get attentionReported => 'Reportado';

  @override
  String overviewTodoToReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones por revisar',
      one: '1 canción por revisar',
    );
    return '$_temp0';
  }

  @override
  String overviewTodoReported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones con errores reportados',
      one: '1 canción con un error reportado',
    );
    return '$_temp0';
  }

  @override
  String get songToReviewTooltip => 'Aún no revisada';

  @override
  String get songReportedTooltip => 'Error reportado';

  @override
  String get songToReviewHint => 'Esta canción aún no se ha revisado.';

  @override
  String get songReportedHint => 'Se ha reportado un error en esta canción.';

  @override
  String reviewBannerToReview(String reason) {
    return 'Por revisar: $reason';
  }

  @override
  String reviewBannerReports(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reportes abiertos',
      one: '1 reporte abierto',
    );
    return '$_temp0';
  }

  @override
  String get showReports => 'Mostrar';

  @override
  String get approveSong => 'Aprobar';

  @override
  String get songApproved => 'Canción aprobada';

  @override
  String get approveAllSongs => 'Aprobar todas';

  @override
  String get approveAllSongsTitle => '¿Aprobar todas las canciones?';

  @override
  String approveAllSongsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones se considerarán revisadas.',
      one: '1 canción se considerará revisada.',
    );
    return '$_temp0';
  }

  @override
  String songsApproved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones aprobadas',
      one: '1 canción aprobada',
    );
    return '$_temp0';
  }

  @override
  String get resolveReportsTitle => '¿Resolver los reportes?';

  @override
  String resolveReportsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'La canción tiene $count reportes abiertos. ¿Marcarlos también como resueltos?',
      one: 'La canción tiene 1 reporte abierto. ¿Marcarlo también como resuelto?',
    );
    return '$_temp0';
  }

  @override
  String get resolveReports => 'Resolver';

  @override
  String get setToReviewMenu => 'Marcar para revisar …';

  @override
  String get setToReviewTitle => 'Marcar para revisar';

  @override
  String get reviewReasonLabel => 'Motivo';

  @override
  String get reviewReasonHint => 'p. ej. el puente está mal';

  @override
  String get reviewReasonAfterImport => 'Tras la importación';

  @override
  String setReviewHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count canciones aún no están revisadas o tienen errores reportados',
      one: '1 canción aún no está revisada o tiene un error reportado',
    );
    return '$_temp0';
  }

  @override
  String get reportMistake => 'Reportar un error';

  @override
  String get reportMistakeMenu => 'Reportar un error …';

  @override
  String get reportCategoryChords => 'Acordes';

  @override
  String get reportCategoryLyrics => 'Letra';

  @override
  String get reportCategoryKey => 'Tonalidad';

  @override
  String get reportCategorySequence => 'Secuencia';

  @override
  String get reportCategoryTempo => 'Tempo';

  @override
  String get reportCategoryFormatting => 'Formato';

  @override
  String get reportCategorySheetMusic => 'Partitura (PDF)';

  @override
  String get reportCategoryOther => 'Otro';

  @override
  String get reportComment => 'Comentario';

  @override
  String get reportCommentHint => '¿Qué está mal?';

  @override
  String get reportSend => 'Enviar';

  @override
  String get reportSent => 'Error reportado. ¡Gracias!';

  @override
  String reportLocation(String place) {
    return 'Lugar: $place';
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
    return 'Línea $line';
  }

  @override
  String get reportsTitle => 'Reportes de errores';

  @override
  String get reportsEmpty => 'Sin reportes';

  @override
  String reportsClosed(int count) {
    return 'Resueltos y retirados ($count)';
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
  String get reportWithdrawnMessage => 'Reporte retirado';

  @override
  String get resolveReport => 'Resolver el reporte';

  @override
  String get reportAnswerLabel => 'Respuesta';

  @override
  String get reportAnswerHint => 'p. ej. Corregido, ¡gracias!';

  @override
  String get reportResolvedMessage => 'Reporte resuelto';

  @override
  String get reportReopen => 'Reabrir';

  @override
  String get reportReopenedMessage => 'Reporte reabierto';

  @override
  String get reportResolvedNoAnswer => 'Resuelto';

  @override
  String reportAnswer(String answer) {
    return 'Resuelto: $answer';
  }

  @override
  String reportAnswered(String song, String answer) {
    return 'Tu reporte sobre «$song» se ha resuelto: $answer';
  }

  @override
  String reportAnsweredNoText(String song) {
    return 'Tu reporte sobre «$song» se ha resuelto.';
  }

  @override
  String reportsAnswered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de tus reportes se han resuelto.',
      one: '1 de tus reportes se ha resuelto.',
    );
    return '$_temp0';
  }

  @override
  String get screenshotAdd => 'Adjuntar captura';

  @override
  String get screenshotRemove => 'Quitar';

  @override
  String get screenshotMarkTitle => 'Marcar el lugar';

  @override
  String get screenshotMarkHint => 'Dibuja en la captura dónde está el error.';

  @override
  String get screenshotAttach => 'Adjuntar';

  @override
  String get screenshotShow => 'Ver la captura a tamaño completo';

  @override
  String get screenshotLoading => 'Cargando la captura …';

  @override
  String get screenshotUnavailable => 'Captura no disponible (¿sin conexión?)';

  @override
  String get lineup => 'Formación';

  @override
  String get lineupWholeBand => 'Toda la banda';

  @override
  String get lineupSubstitute => 'Sustituto';

  @override
  String get lineupBandMembers => 'Miembros de la banda';

  @override
  String get lineupSubstitutes => 'Sustitutos';

  @override
  String get lineupNotPlanned => 'No estás previsto';

  @override
  String get lineupEdit => 'Elegir la formación';

  @override
  String get lineupAddPeople => 'Añadir personas';

  @override
  String get lineupSearchPeople => 'Buscar personas';

  @override
  String get lineupNoMorePeople =>
      'Todas las personas de la organización ya están en la formación.';

  @override
  String get lineupNoAccount => 'Sin cuenta';

  @override
  String get lineupPeopleWithoutAccount => 'Personas sin cuenta';

  @override
  String get lineupNewContact => 'Nueva persona sin cuenta';

  @override
  String get contactEmail => 'Correo electrónico (opcional)';

  @override
  String get contactEmailHint =>
      'Solo la ven las personas que planifican sets. «Avisar a la formación» escribe a esta dirección.';

  @override
  String get contactNameHint => 'Solo hace falta el nombre.';

  @override
  String get contactsHint =>
      'Personas que tocan con vosotros pero no usan setDING. Pueden formar parte de la formación de los sets.';

  @override
  String get contactEditTitle => 'Editar persona';

  @override
  String get contactInvite => 'Invitar a setDING';

  @override
  String get contactInviteChooseBand => '¿Invitar a qué banda?';

  @override
  String contactDeleteTitle(String name) {
    return '¿Eliminar a $name?';
  }

  @override
  String contactDeleteMessage(String name) {
    return '$name ya no se ofrece para las formaciones y se elimina el correo electrónico. Los sets en los que figura $name conservan el nombre.';
  }

  @override
  String contactInviteTitle(String name) {
    return 'Invitación personal para $name';
  }

  @override
  String contactInviteHint(String date, String name) {
    return 'El enlace sirve una vez, hasta el $date. Quien cree una cuenta con él asume los sets en los que $name está previsto.';
  }

  @override
  String get contactInviteSubject => 'Invitación a setDING';

  @override
  String contactInviteBody(String name, String organization, String url) {
    return 'Hola, $name\n\nTe invitamos a unirte a $organization en setDING, donde encontrarás los acordes de nuestras canciones y los sets en los que estás previsto. Abre este enlace para crear tu cuenta:\n$url';
  }

  @override
  String joinPersonal(String name) {
    return 'Esta invitación es para $name.';
  }

  @override
  String joinPersonalExplanation(String name) {
    return 'Tu cuenta asume los sets en los que $name está previsto.';
  }

  @override
  String get joinPersonalButton => 'Aceptar la invitación';

  @override
  String get lineupNobody => 'Nadie previsto';

  @override
  String get lineupWholeBandHint =>
      'La formación sigue a la banda, incluidos los nuevos miembros.';

  @override
  String get bandSubstituteHint =>
      'Tocas algunos sets de esta banda como sustituto y solo ves esos sets.';

  @override
  String get overviewAsSubstitute => 'Como sustituto';

  @override
  String get lineupNotify => 'Avisar a la formación';

  @override
  String get lineupCopy => 'Copiar';

  @override
  String get lineupCopied => 'Texto copiado';

  @override
  String get lineupMail => 'Por correo';

  @override
  String get lineupShare => 'Compartir …';

  @override
  String get lineupNoAddresses =>
      'Sin conexión con el servidor: elige tú los destinatarios.';

  @override
  String lineupMessageIntro(String set) {
    return 'Estáis previstos para «$set».';
  }

  @override
  String get lineupMessageFooter => 'Encontráis las canciones en setDING.';

  @override
  String get overviewPlanned => 'Estás previsto';

  @override
  String get overviewPlannedSeen => 'Entendido';
}
