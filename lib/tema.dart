// Colori e pezzi propri di tk-desk; tutto il resto (testata, card, dialoghi, Informazioni, splash) è nel kit comune.
// Copyright (C) 2026 Pietro De Filippis (TecnikGeek) — AGPL-3.0-or-later, vedi COPYING
import 'package:flutter/material.dart';

import 'kit_tk.dart';

export 'kit_tk.dart';

// verde smeraldo, come tk-desk per computer
const accento = Color(0xFF059669);
const accentoScuro = Color(0xFF047857);
const accentoChiaro = Color(0xFFD1FAE5);
const accento2 = Color(0xFF10B981);

/// Simbolo di tk-desk: schermo bianco col piede e la freccia del mouse.
Widget simboloDesk(double lato) => SizedBox(
      width: lato,
      height: lato,
      child: CustomPaint(painter: PittoreLogo(fondo: false)),
    );

const configDesk = ConfigTk(
  nome: 'tk-desk',
  motto: 'Il tuo computer in tasca',
  descrizione: 'Controllo remoto di PC e Mac',
  accento: accento,
  accentoScuro: accentoScuro,
  simbolo: simboloDesk,
  manifestUrl:
      'https://dl.dropboxusercontent.com/scl/fi/1uh07ixekeq6rnarm9kex/tkdesk-version.json?rlkey=bvfmm4ilyzoeba16hqux1wtfe',
  altrove: ("C'è anche per Windows e Mac", 'https://pietrodefilippis.it/software/'),
);

/// Frasi di tk-desk nel benvenuto (sopra la riga sulla privacy): l'avviso antitruffa come nel programma per
/// computer e cosa va in rete per collegarsi.
const righeBenvenutoDesk = [
  '**Non dare mai ID e password a chi ti chiama o ti scrive dicendo di essere un tecnico, la banca o la polizia.** '
      'Usa tk-desk solo con persone che conosci.',
  'Per collegarti, il telefono si presenta al centralino di pietrodefilippis.it con un ID e il suo nome (lo vede il '
      'computer che controlli) e usa i server STUN di Google per trovare la strada diretta. Lo schermo e i comandi '
      "passano cifrati da telefono a computer: il centralino non li vede. Se la strada diretta non c'è (dati "
      'mobili), passano cifrati da un ponte TURN di Cloudflare.',
];

/// Nota della scheda «I tuoi dati» in Informazioni.
const notaDatiDesk = "I computer recenti restano su questo telefono. Il centralino conosce solo l'ID e il nome del "
    'telefono, non le password né lo schermo.';

/// Logo: schermo bianco con il piede e la freccia del mouse (verde smeraldo). Con [fondo] è l'icona dell'app.
class PittoreLogo extends CustomPainter {
  PittoreLogo({this.fondo = true});

  final bool fondo;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    if (fondo) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * .24)),
        Paint()..shader = const LinearGradient(colors: [navy2, navy]).createShader(Offset.zero & size),
      );
    }
    final bianco_ = Paint()..color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s * .14, s * .2, s * .72, s * .48), Radius.circular(s * .06)),
        bianco_);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s * .19, s * .25, s * .62, s * .38), Radius.circular(s * .03)),
        Paint()..color = fondo ? navy2 : accentoScuro);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s * .44, s * .68, s * .12, s * .08), Radius.circular(s * .01)),
        bianco_);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s * .32, s * .75, s * .36, s * .06), Radius.circular(s * .03)),
        bianco_);
    final freccia = Path()..moveTo(s * .42, s * .3);
    for (final p in const [(.42, .58), (.49, .51), (.54, .62), (.59, .6), (.54, .49), (.64, .49)]) {
      freccia.lineTo(s * p.$1, s * p.$2);
    }
    freccia.close();
    canvas.drawPath(freccia, Paint()..color = fondo ? accento2 : Colors.white);
    canvas.drawPath(
        freccia,
        Paint()
          ..color = fondo ? Colors.white : accentoScuro
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .02
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// «123456789» → «123 456 789»
String formattaId(String id) {
  final c = id.replaceAll(RegExp(r'\D'), '');
  final g = <String>[];
  for (var i = 0; i < c.length; i += 3) {
    g.add(c.substring(i, i + 3 > c.length ? c.length : i + 3));
  }
  return g.join(' ');
}

/// 9 cifre esatte, altrimenti ''.
String pulisciId(String testo) {
  final c = testo.replaceAll(RegExp(r'\D'), '');
  return c.length == 9 ? c : '';
}
