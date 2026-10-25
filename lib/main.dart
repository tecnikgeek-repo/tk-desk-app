// tk-desk per Android e iPhone: controlla PC e Mac dal telefono — TecnikGeek (pietrodefilippis.it)
// Copyright (C) 2026 Pietro De Filippis (TecnikGeek) — AGPL-3.0-or-later, vedi COPYING
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'centralino.dart';
import 'home.dart';
import 'tema.dart';
import 'tk_licenza.dart';
import 'tk_pro.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configTk = configDesk;
  registraLicenzaAgpl();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final versione = await _avviaLicenza();
  final ce = Centralino()..versione = versione;
  await ce.prepara();
  ce.nome = await _nomeTelefono();
  runApp(AppTkDesk(centralino: ce));
}

/// Benvenuto, statistiche (solo col consenso) e invito al caffè: tutte le funzioni sono per tutti.
Future<String> _avviaLicenza() async {
  var versione = '1.0.0';
  try {
    final info = await PackageInfo.fromPlatform();
    versione = info.version;
    final lic = Licenza(slug: 'tk-desk-app', versione: info.version);
    await lic.carica();
    proTk = ProTk(lic);
    lic.avvia(); // segnale del giorno in sottofondo, SOLO se l'utente ha detto sì alle statistiche
  } catch (_) {
    proTk = null; // senza memoria niente benvenuto né statistiche: l'app funziona lo stesso
  }
  return versione;
}

/// Nome che vede il computer quando lo controlli («Pixel 8», «iPhone di Pietro»). Si legge qui ma va in rete (al
/// centralino e al computer) solo dopo il benvenuto, quando usi l'app. Nessun codice del telefono: solo il nome.
Future<String> _nomeTelefono() async {
  try {
    final d = DeviceInfoPlugin();
    final a = await d.deviceInfo;
    final m = a.data;
    final nome = (m['name'] ?? m['model'] ?? m['device'] ?? 'Telefono').toString();
    return nome.length > 60 ? nome.substring(0, 60) : nome;
  } catch (_) {
    return 'Telefono';
  }
}

class AppTkDesk extends StatelessWidget {
  const AppTkDesk({super.key, required this.centralino});
  final Centralino centralino;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'tk-desk',
      debugShowCheckedModeBanner: false,
      theme: temaKit(),
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ConAvvio(child: SchermataHome(centralino: centralino)),
    );
  }
}
