// Caratteri veri per le anteprime dei test (senza, flutter_test disegna ogni lettera come un quadratino):
// Roboto e le icone Material dalla cache di Flutter. Sul computer i file hanno il nome in minuscolo,
// su altre installazioni con le maiuscole: si cercano tutti e due.
import 'dart:io';

import 'package:flutter/services.dart';

File? _trova(String cartella, String nome) {
  for (final n in [nome, nome.toLowerCase()]) {
    final f = File('$cartella/$n');
    if (f.existsSync()) return f;
  }
  return null;
}

Future<void> caricaCaratteri() async {
  final dir = '${Platform.environment['FLUTTER_ROOT'] ?? r'C:\dev\flutter'}/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final n in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']) {
    final f = _trova(dir, n);
    if (f != null) roboto.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  }
  await roboto.load();
  final icone = _trova(dir, 'MaterialIcons-Regular.otf');
  if (icone != null) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icone.readAsBytesSync().buffer)))).load();
  }
}
