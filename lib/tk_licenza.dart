// tk_licenza — software libero (AGPL-3.0), donazione facoltativa e statistiche col consenso (Flutter).
//
// Copia IDENTICA in ogni app TK (lib/tk_licenza.dart): l'originale sta in
// Dropbox\CLAUDE\tk-software\librerie\tk_licenza.dart. Gemella di tk_licenza.py dei software per computer.
//
// Dal 2026-10-25 le app TK sono software libero (AGPL-3.0) con TUTTE le funzioni per tutti: niente chiavi,
// niente Free/Pro. La donazione è libera e non sblocca nulla.
//
// pubspec.yaml: http, shared_preferences (NON servono più cryptography, device_info_plus, android_id)
//
// Uso:
//   final lic = Licenza(slug: 'tk-pdf-app', versione: '1.7.0');
//   await lic.carica();               // all'avvio
//   lic.avvia();                      // in sottofondo: segnale del giorno, SOLO se l'utente ha detto sì
//   lic.sbloccato                     // sempre vero (resta per il codice che lo chiede ancora)
//   lic.consensoStatistiche           // null = non ha ancora risposto, true/false = la sua scelta
//   await lic.impostaStatistiche(true);
//
// Statistiche: una volta al giorno /ping-app con nome, versione, sistema e un codice CASUALE creato la prima
// volta (non ricavato dal telefono), solo dopo il sì nel benvenuto o in Informazioni. Nient'altro va in rete.
// Copyright (C) 2026 Pietro De Filippis (TecnikGeek) — AGPL-3.0-or-later, vedi COPYING

import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _server = 'https://pietrodefilippis.it/wp-json/tk-license/v1';
const Duration _timeout = Duration(seconds: 10);
const String _donazioneRiserva = 'https://pietrodefilippis.it/donazione/';

/// Spiegazione delle statistiche, uguale ai software per computer (TESTO_STATISTICHE di tk_licenza_qt.py).
const String testoStatistiche = "Aiutami a contare le installazioni: una volta al giorno l'app invia il suo nome, "
    'la versione e il sistema operativo, con un codice casuale. Niente file, nomi, email o contenuti. '
    'Puoi cambiare idea quando vuoi, in Informazioni.';

/// Versione breve per la scheda Privacy di Informazioni.
const String testoStatisticheBreve =
    'Una volta al giorno: nome, versione e sistema, con un codice casuale. Niente file né contenuti.';

/// Risposta delle vecchie azioni del Pro (restano solo perché il codice delle app compili).
class EsitoLicenza {
  const EsitoLicenza(this.ok, this.messaggio);
  final bool ok;
  final String messaggio;
}

/// La pagina di donazione di PayPal si apre in inglese se il link non dice la lingua: la aggiunge.
String urlItaliano(String url) {
  if (url.contains('paypal.com/donate') && !url.contains('locale.x=')) {
    return '$url${url.contains('?') ? '&' : '?'}locale.x=it_IT';
  }
  return url;
}

const _tuttoGratis = EsitoLicenza(true, 'Tutte le funzioni sono già gratis per tutti.');

class Licenza {
  /// [freeProPredefinito] non conta più (resta per compatibilità).
  Licenza({required this.slug, required this.versione, this.freeProPredefinito = false});

  final String slug;
  final String versione;
  final bool freeProPredefinito;

  String dispositivo = '';
  SharedPreferences? _prefs;
  Map<String, dynamic> _stato = {};

  String get dominio => 'dev-$dispositivo';
  String get _k => 'tk_licenza_$slug';

  // ---------------------------------------------------------------- avvio
  Future<void> carica() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      final s = _prefs!.getString(_k);
      if (s != null) _stato = (jsonDecode(s) as Map).cast<String, dynamic>();
    } catch (_) {
      _stato = {};
    }
    dispositivo = await _dispositivo();
  }

  /// In sottofondo: segnale del giorno, solo col consenso. Nient'altro va in rete.
  void avvia() {
    () async {
      try {
        await segnale();
      } catch (_) {}
    }();
  }

  Future<void> _salva() async {
    try {
      await _prefs?.setString(_k, jsonEncode(_stato));
    } catch (_) {}
  }

  String get chiave => (_stato['chiave'] as String?) ?? '';

  // ---------------------------------------------------------------- dispositivo anonimo
  /// Codice casuale creato la prima volta e conservato: non si legge nulla dal telefono.
  Future<String> _dispositivo() async {
    var c = (_stato['casuale'] as String?) ?? '';
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(c)) {
      final r = Random.secure();
      c = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      _stato['casuale'] = c;
      // il codice ricavato dal telefono delle versioni vecchie non serve più
      await _prefs?.remove('tk_licenza_casuale');
      await _salva();
    }
    return c;
  }

  static String piattaforma() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    return 'linux';
  }

  // ---------------------------------------------------------------- stato (tutto per tutti)
  /// Sempre falso: niente chiavi Pro.
  bool get isPro => false;

  /// Sempre falso: software libero, nessuna funzione a pagamento (l'app non mostra il Pro).
  bool get freePro => false;

  bool get proGratis => false;
  String get proGratisFino => '';

  /// Sempre vero: tutte le funzioni sono per tutti.
  bool get sbloccato => true;

  String get piano => 'free';
  String get scadenza => '';
  String get donazione =>
      urlItaliano((((_stato['prodotto'] as Map?) ?? const {})['donazione'] as String?) ?? _donazioneRiserva);
  String get chiaveMascherata => '';

  /// Codice breve dell'app e del telefono (es. TKPDFA-4F7Q2A): resta per compatibilità.
  String get codiceDonazione {
    final nome = slug.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    return '${nome.substring(0, nome.length < 6 ? nome.length : 6)}-${dispositivo.substring(0, 6).toUpperCase()}';
  }

  // ---------------------------------------------------------------- statistiche (col consenso)
  /// null = l'utente non ha ancora risposto; true/false = la sua scelta.
  bool? get consensoStatistiche {
    final v = ricordo('statistiche');
    return v is bool ? v : null;
  }

  Future<void> impostaStatistiche(bool si) async {
    await ricorda('statistiche', si);
    if (si) avvia();
  }

  /// Il benvenuto del primo avvio è già stato mostrato.
  bool get benvenutoVisto => ricordo('benvenuto_agpl', false) == true;

  // ---------------------------------------------------------------- piccola memoria dell'app
  dynamic ricordo(String nome, [dynamic predefinito]) =>
      ((_stato['ricordi'] as Map?) ?? const {})[nome] ?? predefinito;

  Future<void> ricorda(String nome, dynamic valore) async {
    final r = ((_stato['ricordi'] as Map?) ?? {}).cast<String, dynamic>();
    r[nome] = valore;
    _stato['ricordi'] = r;
    await _salva();
  }

  // ---------------------------------------------------------------- vecchie azioni del Pro (non vanno in rete)
  Future<void> aggiornaProdotto({bool forza = false}) async {}
  Future<void> ricontrolla({bool forza = false}) async {}
  Future<EsitoLicenza> attiva(String testo) async => _tuttoGratis;
  Future<EsitoLicenza> riscatta(String testo) async => _tuttoGratis;
  Future<EsitoLicenza> attivaOCodice(String testo) async => _tuttoGratis;
  Future<EsitoLicenza> richiediPro(String email, {String nome = '', String nota = ''}) async => _tuttoGratis;

  /// Toglie la chiave delle versioni vecchie rimasta in memoria (senza chiamare il server).
  Future<void> disattiva() async {
    _stato.remove('chiave');
    _stato.remove('risposta');
    await _salva();
  }

  // ---------------------------------------------------------------- rete
  /// Una volta al giorno, SOLO col consenso: questa app è in uso (conteggio delle installazioni).
  Future<void> segnale() async {
    if (consensoStatistiche != true) return;
    final oggi = DateTime.now().toIso8601String().substring(0, 10);
    if (_stato['segnale'] == oggi) return;
    final r = await http
        .post(Uri.parse('$_server/ping-app'),
            headers: {
              'User-Agent': '$slug/$versione (${piattaforma()})',
              'Content-Type': 'application/json',
              'Cache-Control': 'no-cache',
            },
            body: jsonEncode({
              'slug': slug, 'version': versione, 'device': dispositivo,
              'platform': piattaforma(), 'os': Platform.operatingSystemVersion, 'plan': piano,
            }))
        .timeout(_timeout);
    Map<String, dynamic>? d;
    try {
      d = (jsonDecode(utf8.decode(r.bodyBytes)) as Map).cast<String, dynamic>();
    } catch (_) {}
    if (d?['ok'] == true) {
      _stato['segnale'] = oggi;
      await _salva();
    }
  }
}
