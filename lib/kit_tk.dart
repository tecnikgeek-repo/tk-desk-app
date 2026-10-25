// Kit grafico comune alle app TK (tk-tv, tk-pdf, tk-ftp, tk-iscrizioni, …) — TecnikGeek.
// FILE IDENTICO IN TUTTE LE APP: si modifica qui e si copia in tutte, così l'aspetto resta unico.
// Ogni app imposta in main.dart `configTk = ConfigTk(...)`: nome, motto, colore d'accento, simbolo, aggiornamenti.
// Contiene: palette, tema, testata, card, pillole, bottoni, dialoghi, splash, Informazioni (software libero
// AGPL-3.0, privacy, licenze e codice sorgente) e aggiornamenti.
// Copyright (C) 2026 Pietro De Filippis (TecnikGeek) — AGPL-3.0-or-later, vedi COPYING
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'tk_pro.dart';

// ───────────────────────── palette comune ─────────────────────────

const navy = Color(0xFF0F172A);
const navy2 = Color(0xFF1E293B);
const navy3 = Color(0xFF334155);
const sfondo = Color(0xFFEEF1F6);
const grigio50 = Color(0xFFF8FAFC);
const grigio100 = Color(0xFFF1F5F9);
const grigio200 = Color(0xFFE2E8F0);
const grigio300 = Color(0xFFCBD5E1);
const grigio400 = Color(0xFF94A3B8);
const grigio500 = Color(0xFF64748B);
const verde = Color(0xFF16A34A);
const rosso = Color(0xFFDC2626);
const bianco = Colors.white;

const gradienteTestata = LinearGradient(colors: [navy, navy2, navy3]);

// ───────────────────────── configurazione dell'app ─────────────────────────

class ConfigTk {
  const ConfigTk({
    required this.nome,
    required this.motto,
    required this.descrizione,
    required this.accento,
    required this.accentoScuro,
    required this.simbolo,
    required this.manifestUrl,
    this.scuro = false,
    this.altrove,
    this.logoOriginale,
    this.avvioColorato = false,
    this.repo,
    this.eccezioneLicenza,
  });

  /// «tk-ftp»
  final String nome;

  /// Riga sotto il nome nello splash, in maiuscolo: «I TUOI SITI IN TASCA».
  final String motto;

  /// Riga sotto il nome in Informazioni: «Client FTP, FTPS e SFTP».
  final String descrizione;

  final Color accento, accentoScuro;

  /// Simbolo bianco dell'app, disegnato dentro il quadrato d'accento di [LogoTk] (riceve il lato del quadrato).
  final Widget Function(double lato) simbolo;

  /// Manifesto degli aggiornamenti Android (`<app>-version.json` su Dropbox).
  final String manifestUrl;

  /// Tema scuro (tk-tv, pensata per il televisore); le altre app hanno il fondo chiaro.
  final bool scuro;

  /// Pulsante «C'è anche per …» in Informazioni: (testo, indirizzo), oppure null.
  final (String, String)? altrove;

  /// Icona originale dell'app: se c'è, [LogoTk] mostra lei dappertutto (riceve il lato).
  final Widget Function(double lato)? logoOriginale;

  /// Splash col fondo nel colore dell'app invece che navy.
  final bool avvioColorato;

  /// Repo GitHub del codice sorgente (`tecnikgeek-repo/<repo>`); di serie `<nome>-app` (tk-pdf → tk-pdf-app).
  final String? repo;

  String get repoGithub => repo ?? '$nome-app';

  /// Librerie non libere coperte dal permesso aggiuntivo AGPL sez. 7 (file `ECCEZIONE-LICENZA.md` del repo),
  /// es. «Syncfusion PDF, Google ML Kit»; null = l'app non ne usa e la riga non compare.
  final String? eccezioneLicenza;

  Color get accentoChiaro => Color.alphaBlend(accento.withValues(alpha: .14), bianco);
  LinearGradient get gradienteAccento => LinearGradient(colors: [accento, accentoScuro]);
}

/// Impostata una volta in main.dart prima di runApp (e nei test).
late ConfigTk configTk;

Color get _acc => configTk.accento;

// ───────────────────────── tema ─────────────────────────

ThemeData temaKit() {
  final c = configTk;
  final scuro = c.scuro;
  final base = ThemeData(
    useMaterial3: true,
    brightness: scuro ? Brightness.dark : Brightness.light,
    colorScheme: scuro
        ? ColorScheme.dark(
            primary: c.accento, onPrimary: bianco, secondary: c.accento, surface: navy2, onSurface: grigio200, error: rosso)
        : ColorScheme.fromSeed(seedColor: c.accento, primary: c.accento, surface: bianco, error: rosso),
    scaffoldBackgroundColor: scuro ? navy : sfondo,
  );
  final campo = scuro ? navy2 : bianco;
  final bordo = scuro ? navy3 : grigio200;
  return base.copyWith(
    textTheme: scuro ? base.textTheme.apply(bodyColor: grigio200, displayColor: bianco) : base.textTheme,
    appBarTheme: const AppBarTheme(systemOverlayStyle: SystemUiOverlayStyle.light),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accento,
        foregroundColor: bianco,
        minimumSize: const Size(0, 48),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scuro ? bianco : navy,
        backgroundColor: scuro ? navy3 : grigio100,
        minimumSize: const Size(0, 48),
        side: BorderSide.none,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: campo,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: bordo)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: bordo)),
      focusedBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.accento, width: 2)),
    ),
    snackBarTheme: SnackBarThemeData(
        backgroundColor: scuro ? navy3 : navy,
        contentTextStyle: const TextStyle(color: bianco),
        behavior: SnackBarBehavior.floating),
    dialogTheme: DialogThemeData(
        backgroundColor: scuro ? navy2 : bianco, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
    listTileTheme: scuro ? null : const ListTileThemeData(iconColor: grigio500, textColor: navy),
    dividerTheme: DividerThemeData(color: scuro ? navy3 : grigio200, space: 1, thickness: 1),
    // il binario vuoto va scritto: sul fondo scuro quello di serie è quasi dell'accento e la barra sembra piena
    progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accento, linearTrackColor: scuro ? navy3 : grigio200, circularTrackColor: Colors.transparent),
  );
}

// ───────────────────────── logo ─────────────────────────

/// Logo dell'app (testata, Informazioni, splash): l'icona originale se l'app ce l'ha, altrimenti il simbolo
/// bianco su quadrato col gradiente d'accento.
class LogoTk extends StatelessWidget {
  const LogoTk({super.key, this.lato = 42});

  final double lato;

  @override
  Widget build(BuildContext context) => configTk.logoOriginale?.call(lato) ?? Container(
        width: lato,
        height: lato,
        decoration: BoxDecoration(
            gradient: configTk.gradienteAccento, borderRadius: BorderRadius.circular(lato * .29)),
        alignment: Alignment.center,
        child: configTk.simbolo(lato),
      );
}

// ───────────────────────── elementi toccabili ─────────────────────────

/// Elemento toccabile che, col telecomando (D-pad), si evidenzia col bordo d'accento; col dito il bordo non c'è.
/// OK tenuto premuto sul telecomando = pressione lunga.
class Selezionabile extends StatefulWidget {
  const Selezionabile({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.raggio = 14,
    this.focusNode,
    this.autofocus = false,
    this.colore,
    this.bordo,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double raggio;
  final FocusNode? focusNode;
  final bool autofocus;
  final Color? colore;
  final BoxBorder? bordo;

  @override
  State<Selezionabile> createState() => _SelezionabileState();
}

class _SelezionabileState extends State<Selezionabile> {
  bool _focus = false;
  bool _lungoFatto = false;

  bool get _evidenzia => _focus && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  void _modo(FocusHighlightMode _) {
    if (mounted && _focus) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_modo);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_modo);
    super.dispose();
  }

  KeyEventResult _tasto(FocusNode _, KeyEvent e) {
    final ok = e.logicalKey == LogicalKeyboardKey.select ||
        e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!ok || widget.onLongPress == null) return KeyEventResult.ignored;
    if (e is KeyDownEvent) _lungoFatto = false;
    if (e is KeyRepeatEvent && !_lungoFatto) {
      _lungoFatto = true;
      widget.onLongPress!();
      return KeyEventResult.handled;
    }
    if (e is KeyUpEvent && _lungoFatto) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.raggio);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _tasto,
      child: Material(
        color: widget.colore ?? Colors.transparent,
        borderRadius: r,
        child: InkWell(
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          borderRadius: r,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onFocusChange: (f) => setState(() => _focus = f),
          focusColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: r,
              border: _evidenzia
                  ? Border.all(color: _acc, width: 3)
                  : (widget.bordo ?? Border.all(color: Colors.transparent, width: 3)),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Icona tonda bianca della testata (cerca, impostazioni, informazioni…).
class AzioneTk extends StatelessWidget {
  const AzioneTk(this.icona, this.descrizione, this.onTap, {super.key});

  final IconData icona;
  final String descrizione;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: descrizione,
        child: Selezionabile(
          raggio: 50,
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(8), child: Icon(icona, color: onTap == null ? grigio500 : bianco)),
        ),
      );
}

/// Pulsante grande a tutta larghezza: pieno d'accento, oppure [chiaro] (grigio su fondo chiaro, navy3 su fondo scuro).
class BottoneTk extends StatelessWidget {
  const BottoneTk({super.key, required this.testo, required this.onTap, this.icona, this.chiaro = false, this.scuro});

  final String testo;
  final IconData? icona;
  final VoidCallback? onTap;
  final bool chiaro;

  /// Forza lo stile per fondo scuro (null = quello del tema).
  final bool? scuro;

  @override
  Widget build(BuildContext context) {
    final suScuro = scuro ?? configTk.scuro;
    final fondo = chiaro ? (suScuro ? navy3 : grigio100) : _acc;
    final testoColore = chiaro && !suScuro ? navy : bianco;
    return Opacity(
      opacity: onTap == null ? .5 : 1,
      child: Selezionabile(
        raggio: 12,
        colore: fondo,
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icona != null) ...[Icon(icona, color: testoColore, size: 20), const SizedBox(width: 8)],
            Flexible(
              child: Text(testo,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: testoColore, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── testate ─────────────────────────

/// Testata delle app TK: fascia navy dritta, logo, titolo (di serie il nome dell'app), sottotitolo,
/// icone a destra ([AzioneTk]); [sotto] per una ricerca o delle schede.
class Testata extends StatelessWidget {
  const Testata({
    super.key,
    this.titolo,
    this.sottotitolo,
    this.azioni,
    this.indietro,
    this.sotto,
    this.logo = true,
    this.marchio,
  });

  final String? titolo;
  final String? sottotitolo;
  final List<Widget>? azioni;
  final VoidCallback? indietro;
  final Widget? sotto;
  final bool logo;

  /// Al posto del logo dell'app (es. il logo del sito in tk-ftp).
  final Widget? marchio;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(gradient: gradienteTestata),
        padding: EdgeInsets.fromLTRB(indietro == null ? 16 : 6, MediaQuery.of(context).padding.top + 14, 10, 14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            if (indietro != null) ...[AzioneTk(Icons.arrow_back, 'Indietro', indietro), const SizedBox(width: 4)],
            if (marchio != null)
              ...[marchio!, const SizedBox(width: 12)]
            else if (logo)
              ...[const LogoTk(), const SizedBox(width: 12)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(titolo ?? configTk.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: bianco, fontSize: 19, fontWeight: FontWeight.bold)),
                if (sottotitolo != null && sottotitolo!.isNotEmpty)
                  Text(sottotitolo!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: grigio300, fontSize: 12)),
              ]),
            ),
            ...?azioni,
          ]),
          if (sotto != null) Padding(padding: const EdgeInsets.only(top: 12), child: sotto),
        ]),
      );
}

/// Testata delle schermate secondarie: indietro + titolo, senza logo.
class TestataSemplice extends StatelessWidget {
  const TestataSemplice({super.key, required this.titolo, this.indietro, this.azioni});

  final String titolo;
  final VoidCallback? indietro;
  final List<Widget>? azioni;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(gradient: gradienteTestata),
        padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 14, 10, 14),
        child: Row(children: [
          if (indietro != null) AzioneTk(Icons.arrow_back, 'Indietro', indietro) else const SizedBox(width: 8),
          const SizedBox(width: 4),
          Expanded(
            child: Text(titolo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: bianco, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ...?azioni,
        ]),
      );
}

// ───────────────────────── contenuti ─────────────────────────

/// Card delle app TK: bianca con ombra morbida sul fondo chiaro, navy2 sul fondo scuro.
class CardTk extends StatelessWidget {
  const CardTk({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.onLongPress});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap, onLongPress;

  @override
  Widget build(BuildContext context) {
    final scuro = configTk.scuro;
    final r = BorderRadius.circular(scuro ? 14 : 18);
    return Container(
      decoration: BoxDecoration(
        color: scuro ? navy2 : bianco,
        borderRadius: r,
        boxShadow: scuro ? null : const [BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: r,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Titoletto di sezione in maiuscolo: «FILE RECENTI», «SITI».
class TitoloSezione extends StatelessWidget {
  const TitoloSezione(this.testo, {super.key, this.colore});

  final String testo;
  final Color? colore;

  @override
  Widget build(BuildContext context) => Text(testo.toUpperCase(),
      style: TextStyle(
          fontSize: 11.5, fontWeight: FontWeight.w800, color: colore ?? grigio500, letterSpacing: .8));
}

/// Pillola/badge in maiuscolo.
class Pilla extends StatelessWidget {
  const Pilla(this.testo, this.colore, {super.key, this.piena = true});

  final String testo;
  final Color colore;
  final bool piena;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
            color: piena ? colore : colore.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
        child: Text(testo.toUpperCase(),
            style: TextStyle(
                color: piena ? bianco : colore, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .4)),
      );
}

// ───────────────────────── dialoghi ─────────────────────────

void avviso(BuildContext context, String testo) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));

Future<bool> conferma(BuildContext context, String titolo, String testo,
        {String si = 'Elimina', bool pericolo = true}) async =>
    await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(titolo),
        content: Text(testo),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: pericolo ? rosso : _acc),
            onPressed: () => Navigator.pop(d, true),
            child: Text(si),
          ),
        ],
      ),
    ) ??
    false;

Future<String?> chiediTesto(BuildContext context, String titolo,
    {String iniziale = '', String suggerimento = '', String ok = 'Salva', bool password = false}) {
  final c = TextEditingController(text: iniziale);
  c.selection = TextSelection(
      baseOffset: 0,
      extentOffset: iniziale.contains('.') && !password ? iniziale.lastIndexOf('.') : iniziale.length);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(titolo),
      content: TextField(
        controller: c,
        autofocus: true,
        obscureText: password,
        decoration: InputDecoration(hintText: suggerimento),
        onSubmitted: (v) => Navigator.pop(d, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: Text(ok)),
      ],
    ),
  );
}

// ───────────────────────── splash ─────────────────────────

/// Mostra lo splash per almeno [durata], poi passa a [child] con una dissolvenza.
class ConAvvio extends StatefulWidget {
  const ConAvvio({super.key, required this.child, this.durata = const Duration(milliseconds: 1800)});

  final Widget child;
  final Duration durata;

  @override
  State<ConAvvio> createState() => _ConAvvioState();
}

class _ConAvvioState extends State<ConAvvio> {
  bool _pronto = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.durata, () {
      if (mounted) setState(() => _pronto = true);
    });
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedSwitcher(duration: const Duration(milliseconds: 400), child: _pronto ? widget.child : const SchermataAvvio());
}

/// Splash: logo che «respira» con alone pulsante su fondo navy, nome e motto, firma e versione in basso.
class SchermataAvvio extends StatefulWidget {
  const SchermataAvvio({super.key});

  @override
  State<SchermataAvvio> createState() => _SchermataAvvioState();
}

class _SchermataAvvioState extends State<SchermataAvvio> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);
  String _versione = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _versione = i.version);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = configTk;
    final colorato = c.avvioColorato;
    final chiaro = colorato ? Colors.white.withValues(alpha: .85) : grigio300;
    final tenue = colorato ? Colors.white.withValues(alpha: .65) : grigio500;
    return Scaffold(
      backgroundColor: colorato ? c.accento : navy,
      body: Container(
        decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: colorato ? [c.accento, c.accentoScuro, c.accento] : const [navy, navy2, navy],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter)),
        child: Stack(children: [
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedBuilder(
                animation: _anim,
                builder: (_, _) {
                  final t = Curves.easeInOut.transform(_anim.value);
                  final scala = .94 + .12 * t;
                  final alone = .25 + .35 * t;
                  return SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(alignment: Alignment.center, children: [
                      Transform.scale(
                        scale: scala,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration:
                              BoxDecoration(shape: BoxShape.circle, color: (colorato ? bianco : c.accento).withValues(alpha: alone * .35)),
                        ),
                      ),
                      Transform.scale(
                        scale: scala,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 8))],
                          ),
                          child: const LogoTk(lato: 104),
                        ),
                      ),
                    ]),
                  );
                },
              ),
              const SizedBox(height: 28),
              Text(c.nome,
                  style: const TextStyle(color: bianco, fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(c.motto.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: chiaro, fontSize: 14, letterSpacing: 4, fontWeight: FontWeight.w500)),
              ),
            ]),
          ),
          Positioned(
            bottom: 36 + MediaQuery.of(context).padding.bottom,
            left: 0,
            right: 0,
            child: Column(children: [
              Text('TecnikGeek',
                  style: TextStyle(color: chiaro, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(_versione.isEmpty ? '' : 'v$_versione', style: TextStyle(color: tenue, fontSize: 11)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── software libero: indirizzi e testi con i link ─────────────────────────

const urlTermini = 'https://pietrodefilippis.it/termini-e-condizioni/';
const urlPrivacy = 'https://pietrodefilippis.it/privacy-policy/';
const urlContatti = 'https://pietrodefilippis.it/contatti/';
const urlAgpl = 'https://www.gnu.org/licenses/agpl-3.0.html';
const autoreTk = 'Pietro De Filippis (TecnikGeek)';

/// Testo della licenza dentro l'app (pubspec: `assets/licenze/COPYING-AGPL-3.0.txt`).
const assetAgpl = 'assets/licenze/COPYING-AGPL-3.0.txt';

/// Codice sorgente di questa versione: `https://github.com/tecnikgeek-repo/<repo>/tree/v<versione>`
String urlSorgente(String versione) => 'https://github.com/tecnikgeek-repo/${configTk.repoGithub}/tree/v$versione';

/// Permesso aggiuntivo (AGPL sez. 7) di questa versione: file `ECCEZIONE-LICENZA.md` alla radice del repo.
String urlEccezioneLicenza(String versione) =>
    'https://github.com/tecnikgeek-repo/${configTk.repoGithub}/blob/v$versione/ECCEZIONE-LICENZA.md';

void _apriLink(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Colore dei link sul fondo navy: l'accento schiarito (come `accento.lighter(150)` dei software).
Color get coloreLinkScuro => Color.lerp(configTk.accento, bianco, .42)!;

bool _agplRegistrata = false;

/// Mette il testo dell'AGPL dell'app nella pagina delle licenze di Flutter (showLicensePage), insieme a quelle
/// dei pacchetti. La chiama da sé la pagina «Licenze e codice sorgente»; si può chiamare anche in main.
void registraLicenzaAgpl() {
  if (_agplRegistrata) return;
  _agplRegistrata = true;
  LicenseRegistry.addLicense(() async* {
    try {
      final testo = await rootBundle.loadString(assetAgpl);
      yield LicenseEntryWithLineBreaks([configTk.nome], testo);
    } catch (_) {}
  });
}

/// Testo con **grassetto** e [link](https://…) che si toccano: i paragrafi del benvenuto e delle schede.
class TestoConLink extends StatefulWidget {
  const TestoConLink(this.testo, {super.key, this.stile, this.coloreLink, this.allineamento = TextAlign.start});

  final String testo;
  final TextStyle? stile;
  final Color? coloreLink;
  final TextAlign allineamento;

  @override
  State<TestoConLink> createState() => _TestoConLinkState();
}

class _TestoConLinkState extends State<TestoConLink> {
  final _tocchi = <TapGestureRecognizer>[];
  static final _segni = RegExp(r'\*\*(.+?)\*\*|\[(.+?)\]\((.+?)\)');

  void _libera() {
    for (final t in _tocchi) {
      t.dispose();
    }
    _tocchi.clear();
  }

  @override
  void dispose() {
    _libera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _libera();
    final base = widget.stile ?? const TextStyle(color: grigio300, fontSize: 14);
    final link = widget.coloreLink ?? coloreLinkScuro;
    final pezzi = <InlineSpan>[];
    var da = 0;
    for (final m in _segni.allMatches(widget.testo)) {
      if (m.start > da) pezzi.add(TextSpan(text: widget.testo.substring(da, m.start)));
      if (m.group(1) != null) {
        pezzi.add(TextSpan(
            text: m.group(1),
            style: TextStyle(fontWeight: FontWeight.w800, color: base.color == grigio300 ? bianco : null)));
      } else {
        final url = m.group(3)!;
        final t = TapGestureRecognizer()..onTap = () => _apriLink(url);
        _tocchi.add(t);
        pezzi.add(TextSpan(
            text: m.group(2),
            recognizer: t,
            style: TextStyle(
                color: link, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: link)));
      }
      da = m.end;
    }
    if (da < widget.testo.length) pezzi.add(TextSpan(text: widget.testo.substring(da)));
    return Text.rich(TextSpan(style: base, children: pezzi), textAlign: widget.allineamento);
  }
}

// ───────────────────────── Informazioni ─────────────────────────

/// Apre la schermata Informazioni.
/// [righe] = dati propri dell'app («Documenti recenti», «12»), letti all'apertura: vanno nella scheda «I tuoi dati»;
/// [interruttori] = interruttori dell'app per la scheda Privacy (es. [RigaInterruttore]), sotto le statistiche;
/// [extra] = pulsanti propri dell'app sopra «Controlla aggiornamenti».
Future<void> apriInformazioni(BuildContext context,
        {Future<List<(String, String)>> Function()? righe,
        List<Widget> Function(BuildContext context)? extra,
        List<Widget> Function(BuildContext context)? interruttori,
        String notaDati = 'Restano su questo telefono.'}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            SchermataInformazioni(righe: righe, extra: extra, interruttori: interruttori, notaDati: notaDati)));

/// Informazioni, uguale in tutte le app e nei software (InformazioniDialog di tk_licenza_qt.py): «INFORMAZIONI»,
/// logo + nome + descrizione, schede Versione, Licenza, Sviluppatore, I tuoi dati, Privacy; «Controlla
/// aggiornamenti», «Licenze e codice sorgente», «Offrimi un caffè»; in fondo Termini · Privacy · Contatti.
class SchermataInformazioni extends StatefulWidget {
  const SchermataInformazioni(
      {super.key, this.righe, this.extra, this.interruttori, this.notaDati = 'Restano su questo telefono.'});

  final Future<List<(String, String)>> Function()? righe;
  final List<Widget> Function(BuildContext context)? extra;
  final List<Widget> Function(BuildContext context)? interruttori;
  final String notaDati;

  @override
  State<SchermataInformazioni> createState() => _SchermataInformazioniState();
}

class _SchermataInformazioniState extends State<SchermataInformazioni> {
  PackageInfo? _info;
  List<(String, String)> _dati = const [];

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _info = i);
    }).catchError((_) {});
    widget.righe?.call().then((r) {
      if (mounted) setState(() => _dati = r);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final c = configTk;
    final v = _info?.version ?? '…';
    final link = coloreLinkScuro;
    const spazio = SizedBox(height: 12);
    return Scaffold(
      backgroundColor: navy,
      body: ListView(
        // spazio per la barra di stato e per quella di navigazione di Android (l'app è disegnata anche sotto)
        padding: EdgeInsets.fromLTRB(
            16, MediaQuery.of(context).padding.top + 8, 16, 20 + MediaQuery.of(context).padding.bottom),
        children: [
          Row(children: [
            AzioneTk(Icons.arrow_back, 'Indietro', () => Navigator.of(context).pop()),
            const SizedBox(width: 6),
            Text('INFORMAZIONI',
                style: TextStyle(color: c.accento, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2)),
          ]),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [
              const LogoTk(lato: 68),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.nome, style: const TextStyle(color: bianco, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(c.descrizione, style: const TextStyle(color: grigio300, fontSize: 13.5)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          _SchedaInfo(titolo: 'Versione', valore: '$v · tutte le funzioni, gratis'),
          spazio,
          const _SchedaInfo(
              titolo: 'Licenza',
              valore: 'Software libero · GNU AGPL-3.0',
              nota: "Fornito così com'è, senza alcuna garanzia."),
          spazio,
          const _SchedaInfo(titolo: 'Sviluppatore', valore: 'TecnikGeek · [pietrodefilippis.it](https://pietrodefilippis.it)'),
          if (_dati.isNotEmpty) ...[
            spazio,
            _SchedaInfo(titolo: 'I tuoi dati', righe: _dati, nota: widget.notaDati),
          ],
          spazio,
          _SchedaInfo(titolo: 'Privacy', figli: [
            const InterruttoreStatistiche(scuro: true),
            ...?widget.interruttori?.call(context),
          ]),
          const SizedBox(height: 16),
          for (final w in widget.extra?.call(context) ?? const <Widget>[]) ...[w, const SizedBox(height: 10)],
          // defaultTargetPlatform (non Platform): così il pulsante compare anche nelle foto dei test
          if (defaultTargetPlatform == TargetPlatform.android) ...[
            BottoneTk(
                testo: 'Controlla aggiornamenti',
                icona: Icons.system_update,
                scuro: true,
                onTap: () => proponiAggiornamento(context)),
            const SizedBox(height: 10),
          ],
          BottoneTk(
              testo: 'Licenze e codice sorgente',
              icona: Icons.code,
              chiaro: true,
              scuro: true,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => SchermataLicenze(versione: _info?.version ?? '')))),
          if (proTk != null) ...[const SizedBox(height: 10), const PulsanteCaffe()],
          if (c.altrove != null) ...[
            const SizedBox(height: 10),
            BottoneTk(
                testo: c.altrove!.$1,
                icona: Icons.desktop_windows_outlined,
                chiaro: true,
                scuro: true,
                onTap: () => _apriLink(c.altrove!.$2)),
          ],
          const SizedBox(height: 20),
          TestoConLink('[Termini]($urlTermini)   ·   [Privacy]($urlPrivacy)   ·   [Contatti]($urlContatti)',
              allineamento: TextAlign.center,
              stile: const TextStyle(color: grigio500, fontSize: 13),
              coloreLink: link),
        ],
      ),
    );
  }
}

/// Scheda navy2 delle Informazioni: titolo d'accento in maiuscolo, un valore (con **grassetto** e [link](…)),
/// oppure righe «nome — valore», oppure [figli]; nota grigia sotto.
class _SchedaInfo extends StatelessWidget {
  const _SchedaInfo({required this.titolo, this.valore, this.righe = const [], this.figli = const [], this.nota});

  final String titolo;
  final String? valore;
  final List<(String, String)> righe;
  final List<Widget> figli;
  final String? nota;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
        decoration: BoxDecoration(color: navy2, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titolo.toUpperCase(),
              style: TextStyle(color: _acc, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 6),
          if (valore != null)
            TestoConLink(valore!, stile: const TextStyle(color: bianco, fontSize: 14.5, fontWeight: FontWeight.w600)),
          for (final r in righe)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Text(r.$1, style: const TextStyle(color: grigio300, fontSize: 14)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(r.$2,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: bianco, fontSize: 14, fontWeight: FontWeight.w600))),
              ]),
            ),
          ...figli,
          if (nota != null && nota!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(nota!, style: const TextStyle(color: grigio400, fontSize: 12.5)),
          ],
        ]),
      );
}

/// Informazioni → «Licenze e codice sorgente» (LicenzeDialog dei software): AGPL dell'app, link al sorgente di
/// questa versione, clausola sul nome; il testo della licenza e le licenze dei componenti (showLicensePage).
class SchermataLicenze extends StatefulWidget {
  const SchermataLicenze({super.key, required this.versione});

  final String versione;

  @override
  State<SchermataLicenze> createState() => _SchermataLicenzeState();
}

class _SchermataLicenzeState extends State<SchermataLicenze> {
  @override
  void initState() {
    super.initState();
    registraLicenzaAgpl();
  }

  @override
  Widget build(BuildContext context) {
    final c = configTk;
    final sorgente = urlSorgente(widget.versione);
    const testo = TextStyle(color: grigio300, fontSize: 14, height: 1.5);
    return Scaffold(
      backgroundColor: navy,
      body: Column(children: [
        TestataSemplice(titolo: 'Licenze e codice sorgente', indietro: () => Navigator.of(context).pop()),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 20 + MediaQuery.of(context).padding.bottom),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: navy2, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TestoConLink('**${c.nome} ${widget.versione}** © 2026 $autoreTk.', stile: testo),
                  const SizedBox(height: 8),
                  const TestoConLink(
                      'Software libero sotto licenza [GNU Affero General Public License v3.0]($urlAgpl), '
                      'senza alcuna garanzia.',
                      stile: testo),
                  const SizedBox(height: 8),
                  TestoConLink('Codice sorgente di questa versione: [$sorgente]($sorgente)', stile: testo),
                  if (c.eccezioneLicenza != null && c.eccezioneLicenza!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TestoConLink(
                        'Permesso aggiuntivo per le librerie: ${c.eccezioneLicenza} '
                        '([ECCEZIONE-LICENZA.md](${urlEccezioneLicenza(widget.versione)})).',
                        stile: testo),
                  ],
                  const SizedBox(height: 8),
                  TestoConLink(
                      'Il nome e il logo «${c.nome}» non sono coperti dalla licenza: una copia modificata deve usare '
                      'un nome diverso.',
                      stile: testo),
                ]),
              ),
              const SizedBox(height: 16),
              BottoneTk(
                  testo: 'Leggi la licenza AGPL-3.0',
                  icona: Icons.article_outlined,
                  scuro: true,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => const _TestoLicenza()))),
              const SizedBox(height: 10),
              BottoneTk(
                  testo: 'Licenze dei componenti',
                  icona: Icons.list_alt,
                  chiaro: true,
                  scuro: true,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => const SchermataComponenti()))),
              const SizedBox(height: 10),
              BottoneTk(
                  testo: 'Apri il codice sorgente',
                  icona: Icons.open_in_new,
                  chiaro: true,
                  scuro: true,
                  onTap: () => _apriLink(sorgente)),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Testo intero della GNU AGPL-3.0 (asset dell'app), a paragrafi che si adattano allo schermo.
class _TestoLicenza extends StatelessWidget {
  const _TestoLicenza();

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: rootBundle.loadString(assetAgpl),
        builder: (_, s) => s.connectionState != ConnectionState.done
            ? const _PaginaLicenze(titolo: 'GNU AGPL-3.0', corpo: _Attesa())
            : TestoLicenze(
                titolo: 'GNU AGPL-3.0',
                sopra: 'Il testo ufficiale è in inglese.',
                voci: [
                  if (s.data != null) LicenseEntryWithLineBreaks(const ['GNU AGPL-3.0'], s.data!),
                ],
                vuoto: 'Testo della licenza non trovato: lo trovi su $urlAgpl'),
      );
}

/// Pagina navy con la testata delle app: la base di «Licenze dei componenti» e dei testi delle licenze.
class _PaginaLicenze extends StatelessWidget {
  const _PaginaLicenze({required this.titolo, required this.corpo});

  final String titolo;
  final Widget corpo;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: navy,
        body: Column(children: [
          TestataSemplice(titolo: titolo, indietro: () => Navigator.of(context).pop()),
          Expanded(child: corpo),
        ]),
      );
}

class _Attesa extends StatelessWidget {
  const _Attesa();

  @override
  Widget build(BuildContext context) => Center(child: CircularProgressIndicator(color: configTk.accento));
}

/// Informazioni → Licenze → «Licenze dei componenti»: le librerie dentro l'app (LicenseRegistry, come la pagina
/// di Flutter) in schede navy2; toccandone una si legge la sua licenza.
class SchermataComponenti extends StatefulWidget {
  const SchermataComponenti({super.key});

  @override
  State<SchermataComponenti> createState() => _SchermataComponentiState();
}

class _SchermataComponentiState extends State<SchermataComponenti> {
  late final Future<List<(String, List<LicenseEntry>)>> _componenti = _carica();

  static Future<List<(String, List<LicenseEntry>)>> _carica() async {
    registraLicenzaAgpl();
    final per = <String, List<LicenseEntry>>{};
    await for (final e in LicenseRegistry.licenses) {
      for (final p in e.packages) {
        (per[p] ??= []).add(e);
      }
    }
    final nomi = per.keys.toList()
      ..sort((a, b) {
        // l'app per prima, poi in ordine alfabetico
        if (a == configTk.nome) return -1;
        if (b == configTk.nome) return 1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    return [for (final n in nomi) (n, per[n]!)];
  }

  @override
  Widget build(BuildContext context) => _PaginaLicenze(
        titolo: 'Licenze dei componenti',
        corpo: FutureBuilder<List<(String, List<LicenseEntry>)>>(
          future: _componenti,
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) return const _Attesa();
            final lista = s.data ?? const [];
            return ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 20 + MediaQuery.of(context).padding.bottom),
              itemCount: lista.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                    child: Text(
                        '${configTk.nome} usa ${lista.length} componenti liberi. Tocca un nome per leggerne la licenza '
                        '(i testi ufficiali sono in inglese).',
                        style: const TextStyle(color: grigio300, fontSize: 13.5, height: 1.45)),
                  );
                }
                final (nome, voci) = lista[i - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: navy2,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => TestoLicenze(titolo: nome, voci: voci))),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(nome,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: bianco, fontSize: 15, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(voci.length == 1 ? '1 licenza' : '${voci.length} licenze',
                                  style: const TextStyle(color: grigio400, fontSize: 12.5)),
                            ]),
                          ),
                          const Icon(Icons.chevron_right, color: grigio400),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}

/// Testo di una o più licenze, paragrafo per paragrafo (rientri e righe centrate come nell'originale), ogni licenza
/// in una scheda navy2; si può selezionare e copiare.
class TestoLicenze extends StatelessWidget {
  const TestoLicenze({super.key, required this.titolo, required this.voci, this.sopra, this.vuoto = 'Nessun testo.'});

  final String titolo;
  final List<LicenseEntry> voci;
  final String? sopra;
  final String vuoto;

  @override
  Widget build(BuildContext context) {
    // una riga della lista per paragrafo: anche i testi lunghissimi scorrono leggeri
    final righe = <LicenseParagraph?>[];
    for (final v in voci) {
      righe.addAll(v.paragraphs);
      if (righe.isNotEmpty && righe.last != null) righe.add(null); // null = fine della scheda
    }
    const stile = TextStyle(color: grigio200, fontSize: 13.5, height: 1.5);
    return _PaginaLicenze(
      titolo: titolo,
      corpo: righe.isEmpty
          ? Center(child: Text(vuoto, style: const TextStyle(color: grigio300)))
          : SelectionArea(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 20 + MediaQuery.of(context).padding.bottom),
                itemCount: righe.length + (sopra == null ? 0 : 1),
                itemBuilder: (_, n) {
                  if (sopra != null && n == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                      child: Text(sopra!, style: const TextStyle(color: grigio400, fontSize: 12.5)),
                    );
                  }
                  final i = sopra == null ? n : n - 1;
                  final p = righe[i];
                  final primo = i == 0 || righe[i - 1] == null;
                  final r = BorderRadius.vertical(
                      top: Radius.circular(primo ? 14 : 0), bottom: Radius.circular(p == null ? 14 : 0));
                  if (p == null) {
                    return Container(
                      height: 16,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: navy2, borderRadius: r),
                    );
                  }
                  final centrato = p.indent == LicenseParagraph.centeredIndent;
                  return Container(
                    decoration: BoxDecoration(color: navy2, borderRadius: r),
                    padding: EdgeInsets.fromLTRB(
                        16 + (centrato ? 0 : 14.0 * p.indent.clamp(0, 6)), primo ? 16 : 10, 16, 0),
                    child: Text(p.text,
                        textAlign: centrato ? TextAlign.center : TextAlign.start,
                        style: centrato ? stile.copyWith(color: bianco, fontWeight: FontWeight.w700) : stile),
                  );
                },
              ),
            ),
    );
  }
}

// ───────────────────────── aggiornamenti (Android) ─────────────────────────
// Manifesto su Dropbox: {"versionCode", "versionName", "apkUrl", "note"}; su iPhone aggiorna lo store.

class Novita {
  Novita(this.versionCode, this.versionName, this.apkUrl, this.note);
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String note;
}

/// «; <codice>» per il manifest: codice casuale creato una volta e conservato sul telefono, così un'installazione
/// conta una volta sola anche se cambia rete (Privacy 4-ter). Non dice chi sei né che telefono è, ed è diverso
/// dal codice delle statistiche.
Future<String> _codiceConteggio() async {
  try {
    final p = await SharedPreferences.getInstance();
    var c = p.getString('tk_codice_conteggio') ?? '';
    if (!RegExp(r'^[a-f0-9]{16}$').hasMatch(c)) {
      final r = Random.secure();
      c = List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
      await p.setString('tk_codice_conteggio', c);
    }
    return '; $c';
  } catch (_) {
    return '';
  }
}

/// Controlla se c'è una versione più nuova. Ritorna null se è già aggiornata.
Future<Novita?> cercaNovita() async {
  final info = await PackageInfo.fromPlatform();
  final attuale = int.tryParse(info.buildNumber) ?? 0;
  final t = DateTime.now().millisecondsSinceEpoch; // per non farsi servire il manifesto vecchio dalla cache
  http.Response? risposta;
  // prima dal sito: stesso manifesto (lo legge da Dropbox) e conta le installazioni attive con un codice anonimo
  // (hash dell'indirizzo, vedi Privacy 4-ter); se il sito non risponde, direttamente da Dropbox
  final nome = RegExp(r'/([a-z]+)-version\.json').firstMatch(configTk.manifestUrl)?.group(1);
  if (nome != null) {
    try {
      final r = await http.get(Uri.parse('https://pietrodefilippis.it/updates/app/$nome.json?t=$t'),
          headers: {'User-Agent': 'tk-app/${info.version} (android${await _codiceConteggio()})'})
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) risposta = r;
    } catch (_) {}
  }
  risposta ??= await http
      .get(Uri.parse('${configTk.manifestUrl}&t=$t'))
      .timeout(const Duration(seconds: 20));
  if (risposta.statusCode != 200) throw 'Il server ha risposto ${risposta.statusCode}';
  final dati = jsonDecode(risposta.body) as Map<String, dynamic>;
  final codice = (dati['versionCode'] as num).toInt();
  if (codice <= attuale) return null;
  return Novita(codice, '${dati['versionName']}', '${dati['apkUrl']}', '${dati['note'] ?? ''}');
}

/// Scarica l'APK e apre l'installazione del sistema.
Future<void> scaricaEInstalla(Novita novita, {void Function(double)? avanzamento}) async {
  final cartella = await getTemporaryDirectory();
  final file = File('${cartella.path}/${configTk.nome}-${novita.versionName}.apk');
  final risposta = await http.Client().send(http.Request('GET', Uri.parse(novita.apkUrl)));
  if (risposta.statusCode != 200) throw 'Scaricamento non riuscito (${risposta.statusCode})';
  final totale = risposta.contentLength ?? 0;
  var scaricati = 0;
  final uscita = file.openWrite();
  await for (final pezzo in risposta.stream) {
    uscita.add(pezzo);
    scaricati += pezzo.length;
    if (totale > 0) avanzamento?.call(scaricati / totale);
  }
  await uscita.close();
  final esito = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
  if (esito.type != ResultType.done) throw esito.message;
}

/// Controlla e, se serve, propone l'aggiornamento (all'avvio in silenzio, da Informazioni con gli avvisi).
Future<void> proponiAggiornamento(BuildContext context, {bool avvisaSeAggiornata = true}) async {
  if (!Platform.isAndroid) return;
  Novita? novita;
  try {
    novita = await cercaNovita();
  } catch (errore) {
    if (context.mounted && avvisaSeAggiornata) avviso(context, 'Controllo non riuscito: $errore');
    return;
  }
  if (!context.mounted) return;
  if (novita == null) {
    if (avvisaSeAggiornata) avviso(context, '${configTk.nome} è già aggiornata all\'ultima versione');
    return;
  }
  final aggiorna = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text('Disponibile la versione ${novita!.versionName}'),
      content: Text(novita.note.isEmpty ? 'Vuoi aggiornare ${configTk.nome}?' : novita.note),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Più tardi')),
        FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Aggiorna')),
      ],
    ),
  );
  if (aggiorna != true || !context.mounted) return;

  final percentuale = ValueNotifier<double>(0);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (d) => AlertDialog(
      title: const Text('Scarico l\'aggiornamento'),
      content: ValueListenableBuilder<double>(
        valueListenable: percentuale,
        builder: (_, valore, _) => Column(mainAxisSize: MainAxisSize.min, children: [
          LinearProgressIndicator(
              value: valore == 0 ? null : valore, minHeight: 8, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 10),
          Text('${(valore * 100).round()}%'),
        ]),
      ),
    ),
  );
  try {
    await scaricaEInstalla(novita, avanzamento: (v) => percentuale.value = v);
    if (context.mounted) Navigator.of(context).pop();
  } catch (errore) {
    if (context.mounted) {
      Navigator.of(context).pop();
      avviso(context, 'Aggiornamento non riuscito: $errore');
    }
  }
}
