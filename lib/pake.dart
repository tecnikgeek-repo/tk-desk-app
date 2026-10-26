// SPAKE2 (RFC 9382) su edwards25519: telefono e computer si accordano su una chiave segreta partendo dalla password,
// senza che dai messaggi del centralino si possa ricavare la password (nemmeno provandole tutte).
// Gemello di tkdesk/pake.py del programma per computer: stessi punti M e N, stesso transcript, stesse conferme.
// test/pake_test.dart controlla i numeri calcolati in Python: se cambia uno, cambia anche l'altro.
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

final _p = BigInt.two.pow(255) - BigInt.from(19);
final _q = BigInt.two.pow(252) + BigInt.parse('27742317777372353535851937790883648493');
final _d = (BigInt.from(-121665) * BigInt.from(121666).modPow(_p - BigInt.two, _p)) % _p;
final _i = BigInt.two.modPow((_p - BigInt.one) ~/ BigInt.from(4), _p);
final _zero = [BigInt.zero, BigInt.one, BigInt.one, BigInt.zero];

const mHex = '386914f26c2e1caac68649408df3fbdbf67e3f3b363f0aa1c5293286992596a8'; // _ricava_punto(b"tk-desk SPAKE2 M")
const nHex = 'f63c33fd12a038342e218573ce338c1124caf4664b116b00f5bc280db2e2a3e8'; // _ricava_punto(b"tk-desk SPAKE2 N")

class ErrorePake implements Exception {
  ErrorePake(this.messaggio);
  final String messaggio;
  @override
  String toString() => messaggio;
}

List<BigInt> _somma(List<BigInt> a, List<BigInt> b) {
  final x = (a[1] - a[0]) * (b[1] - b[0]) % _p;
  final y = (a[1] + a[0]) * (b[1] + b[0]) % _p;
  final c = BigInt.two * a[3] * b[3] * _d % _p;
  final d = BigInt.two * a[2] * b[2] % _p;
  final e = y - x, f = d - c, g = d + c, h = y + x;
  return [e * f % _p, g * h % _p, f * g % _p, e * h % _p];
}

List<BigInt> _per(BigInt n, List<BigInt> a) {
  var r = _zero;
  var q = a;
  while (n > BigInt.zero) {
    if (n.isOdd) r = _somma(r, q);
    q = _somma(q, q);
    n = n >> 1;
  }
  return r;
}

List<BigInt> _meno(List<BigInt> a) => [(-a[0]) % _p, a[1], a[2], (-a[3]) % _p];

BigInt? _x(BigInt y, int segno) {
  if (y >= _p) return null;
  final x2 = (y * y - BigInt.one) * (_d * y * y + BigInt.one).modPow(_p - BigInt.two, _p) % _p;
  if (x2 == BigInt.zero) return segno == 1 ? null : BigInt.zero;
  var x = x2.modPow((_p + BigInt.from(3)) ~/ BigInt.from(8), _p);
  if ((x * x - x2) % _p != BigInt.zero) x = x * _i % _p;
  if ((x * x - x2) % _p != BigInt.zero) return null;
  if ((x.isOdd ? 1 : 0) != segno) x = _p - x;
  return x;
}

BigInt _daLE(List<int> b) {
  var n = BigInt.zero;
  for (var k = b.length - 1; k >= 0; k--) {
    n = (n << 8) | BigInt.from(b[k]);
  }
  return n;
}

List<int> _inLE(BigInt n, int lunghezza) {
  final out = List<int>.filled(lunghezza, 0);
  final ff = BigInt.from(255);
  for (var k = 0; k < lunghezza; k++) {
    out[k] = (n & ff).toInt();
    n = n >> 8;
  }
  return out;
}

/// 32 byte → punto, o null se non è un punto della curva.
List<BigInt>? decodifica(List<int> b) {
  if (b.length != 32) return null;
  var y = _daLE(b);
  final segno = (y >> 255).toInt();
  y = y & ((BigInt.one << 255) - BigInt.one);
  final x = _x(y, segno);
  return x == null ? null : [x, y, BigInt.one, x * y % _p];
}

List<int> codifica(List<BigInt> p) {
  final zi = p[2].modPow(_p - BigInt.two, _p);
  final x = p[0] * zi % _p, y = p[1] * zi % _p;
  return _inLE(y | (BigInt.from(x.isOdd ? 1 : 0) << 255), 32);
}

final _gy = BigInt.from(4) * BigInt.from(5).modPow(_p - BigInt.two, _p) % _p;
final g = [_x(_gy, 0)!, _gy, BigInt.one, _x(_gy, 0)! * _gy % _p];
final _identita = _hex(codifica(_zero));
final puntoM = decodifica(_daHex(mHex))!;
final puntoN = decodifica(_daHex(nHex))!;

String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

List<int> _daHex(String s) {
  if (s.length.isOdd || !RegExp(r'^[0-9a-fA-F]*$').hasMatch(s)) throw ErrorePake('messaggio non valido');
  return [for (var k = 0; k < s.length; k += 2) int.parse(s.substring(k, k + 2), radix: 16)];
}

/// Ordine del gruppo: per controllare che M e N stiano nel sottogruppo giusto (test).
BigInt get ordine => _q;
List<BigInt> perScalare(BigInt n, List<BigInt> p) => _per(n, p);
String identitaHex() => _identita;

bool _uguali(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var k = 0; k < a.length; k++) {
    diff |= a.codeUnitAt(k) ^ b.codeUnitAt(k);
  }
  return diff == 0;
}

List<int> _pezzo(List<int> b) => [..._inLE(BigInt.from(b.length), 8), ...b];

Future<List<int>> _hmac(List<int> chiave, List<int> dati) async =>
    (await Hmac.sha256().calculateMac(dati, secretKey: SecretKey(chiave))).bytes;

/// Una parte della stretta di mano. `ruolo` 'A' (chi chiama: il telefono) o 'B'; `chiave` = 32 byte da chiaveDa2.
class Spake2 {
  Spake2(this.ruolo, String idA, String idB, List<int> chiave, {BigInt? casuale})
      : _idA = utf8.encode(idA),
        _idB = utf8.encode(idB),
        _w = _daLE(chiave) % _q {
    if (ruolo != 'A' && ruolo != 'B') throw ArgumentError('ruolo');
    _s = casuale ?? _casuale();
    final mio = ruolo == 'A' ? puntoM : puntoN;
    _altroPunto = ruolo == 'A' ? puntoN : puntoM;
    _mio = codifica(_somma(_per(_s, g), _per(_w, mio)));
  }

  final String ruolo;
  final List<int> _idA, _idB;
  final BigInt _w;
  late final BigInt _s;
  late final List<BigInt> _altroPunto;
  late final List<int> _mio;
  Map<String, Object>? _chiavi;

  static BigInt _casuale() {
    final r = Random.secure();
    return _daLE(List<int>.generate(64, (_) => r.nextInt(256))) % (_q - BigInt.one) + BigInt.one;
  }

  /// Da mandare all'altra parte (esadecimale).
  String messaggio() => _hex(_mio);

  /// Messaggio dell'altra parte → chiavi della sessione. ErrorePake se il messaggio non è valido.
  Future<void> finisci(String altroHex) async {
    final altro = _daHex(altroHex);
    final punto = decodifica(altro);
    if (punto == null || _hex(altro) == _hex(_mio) || _hex(codifica(_per(BigInt.from(8), punto))) == _identita) {
      throw ErrorePake('messaggio non valido');
    }
    final k = _per(_s, _per(BigInt.from(8), _somma(punto, _meno(_per(_w, _altroPunto)))));
    final kb = codifica(k);
    if (_hex(kb) == _identita) throw ErrorePake('messaggio non valido');
    final pa = ruolo == 'A' ? _mio : altro, pb = ruolo == 'A' ? altro : _mio;
    final tt = [for (final x in [_idA, _idB, pa, pb, kb, _inLE(_w, 32)]) ..._pezzo(x)];
    final s = (await Sha256().hash(tt)).bytes;
    final ka = await _hmac(s, utf8.encode('tk-desk conferma A'));
    final kb2 = await _hmac(s, utf8.encode('tk-desk conferma B'));
    _chiavi = {
      'A': _hex(await _hmac(ka, tt)),
      'B': _hex(await _hmac(kb2, tt)),
      'sigillo': await _hmac(s, utf8.encode('tk-desk messaggi')),
    };
  }

  /// La mia conferma: dimostra all'altro che conosco la password.
  String conferma() => _chiavi![ruolo] as String;

  bool confermaValida(String? c) => _chiavi != null && _uguali(_chiavi![ruolo == 'A' ? 'B' : 'A'] as String, c ?? '');

  Future<String> sigilla(String etichetta, String testo) async =>
      _hex(await _hmac(_chiavi!['sigillo'] as List<int>, [...utf8.encode('$etichetta|'), ...utf8.encode(testo)]));

  Future<bool> sigilloValido(String etichetta, String testo, String? sigillo) async =>
      _chiavi != null && _uguali(await sigilla(etichetta, testo), sigillo ?? '');
}
