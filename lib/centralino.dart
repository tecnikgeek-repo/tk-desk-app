// Centralino di tk-desk (tk-license-server /desk/*): ID del telefono e messaggi per far conoscere i due dispositivi.
// Identico al programma per computer (tkdesk/centralino.py): stessa chiave dalla password (PBKDF2-SHA256, 600.000 giri,
// sale «tk-desk-v2|<ID del computer>»), che entra in SPAKE2 (pake.dart, protocollo 3): il server non vede né la
// password né lo schermo, e dai suoi messaggi la password non si ricava. Le versioni di prima (firma HMAC) non si
// collegano più: il centralino le rifiuta.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const serverDesk = 'https://pietrodefilippis.it/wp-json/tk-license/v1/desk';
const protocollo = 3; // SPAKE2: il centralino rifiuta chi ne dichiara uno più vecchio

class ErroreCentralino implements Exception {
  ErroreCentralino(this.messaggio, [this.codice = '']);
  final String messaggio;
  final String codice;
  @override
  String toString() => messaggio;
}

String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

String _casuale(int byte) {
  final r = Random.secure();
  return _hex(List<int>.generate(byte, (_) => r.nextInt(256)));
}

/// La monouso (6 cifre) senza spazi né maiuscole, la fissa così com'è.
String _normalizza(String password) {
  var pw = password.trim();
  if (pw.replaceAll(' ', '').length <= 6) pw = pw.replaceAll(' ', '').toLowerCase();
  return pw;
}

/// La monouso ha 6 cifre, la fissa almeno 8 caratteri: chi chiama dice quale delle due sta usando.
bool eFissa(String password) => password.trim().replaceAll(' ', '').length > 6;

/// Chiave della password per SPAKE2 (600.000 giri), come tk-desk per computer (centralino.chiave2).
Future<List<int>> chiaveDa2(String password, String idControllato) async {
  final k = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 600000, bits: 256).deriveKey(
    secretKey: SecretKey(utf8.encode(_normalizza(password))),
    nonce: utf8.encode('tk-desk-v2|$idControllato'),
  );
  return k.extractBytes();
}

/// Codice di una chiamata: il computer lo ripete nelle risposte (un rifiuto in ritardo non si confonde).
String nuovoCodice() => _casuale(8);

class Messaggio {
  Messaggio(this.da, this.tipo, this.dati);
  final String da, tipo;
  final Map<String, dynamic> dati;
}

class Centralino {
  String id = '';
  late String _segreto, _dispositivo;
  String nome = 'Telefono';
  String versione = '1.0.0';

  Future<void> prepara() async {
    final p = await SharedPreferences.getInstance();
    _segreto = p.getString('desk_segreto') ?? '';
    if (_segreto.length < 32) {
      _segreto = _casuale(24);
      await p.setString('desk_segreto', _segreto);
    }
    _dispositivo = p.getString('desk_dispositivo') ?? '';
    if (_dispositivo.length < 16) {
      _dispositivo = _casuale(20);
      await p.setString('desk_dispositivo', _dispositivo);
    }
    id = p.getString('desk_id') ?? '';
  }

  Future<Map<String, dynamic>> _post(String rotta, Map<String, dynamic> dati, {Duration attesa = const Duration(seconds: 15)}) async {
    http.Response r;
    try {
      r = await http
          .post(Uri.parse('$serverDesk/$rotta'),
              headers: {'Content-Type': 'application/json', 'User-Agent': 'tk-desk-app/$versione', 'Cache-Control': 'no-cache'},
              body: jsonEncode(dati))
          .timeout(attesa);
    } on SocketException {
      throw ErroreCentralino('Nessuna connessione a internet.', 'rete');
    } catch (_) {
      throw ErroreCentralino('Server non raggiungibile: riprova tra poco.', 'rete');
    }
    Map<String, dynamic> j;
    try {
      j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ErroreCentralino('Risposta del server non valida (${r.statusCode}).', 'risposta');
    }
    if (j['ok'] != true) throw ErroreCentralino((j['message'] ?? 'Errore del server.').toString(), (j['code'] ?? '').toString());
    return j;
  }

  Future<String> registra() async {
    final j = await _post('registra', {
      'dispositivo': _dispositivo,
      'segreto': _segreto,
      'nome': nome,
      'piattaforma': Platform.isIOS ? 'ios' : 'android',
      'versione': versione,
      'protocollo': protocollo,
    });
    id = j['id'].toString();
    final p = await SharedPreferences.getInstance();
    await p.setString('desk_id', id);
    return id;
  }

  Future<void> invia(String a, String tipo, Map<String, dynamic> dati) =>
      _post('invia', {'id': id, 'segreto': _segreto, 'a': a, 'tipo': tipo, 'dati': jsonEncode(dati)});

  Future<List<Messaggio>> ricevi() async {
    final j = await _post('ricevi', {'id': id, 'segreto': _segreto}, attesa: const Duration(seconds: 20));
    final out = <Messaggio>[];
    for (final m in (j['messaggi'] as List? ?? const [])) {
      try {
        out.add(Messaggio(m['da'].toString(), m['tipo'].toString(), jsonDecode(m['dati'].toString()) as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }

  /// Ponte TURN (Cloudflare) per quando il collegamento diretto non riesce (dati mobili, hotspot, reti aziendali):
  /// permesso temporaneo dal centralino, le chiavi restano sul server. Vuoto = solo collegamento diretto.
  Future<List<Map<String, dynamic>>> ponte() async {
    try {
      final j = await _post('ice', {'id': id, 'segreto': _segreto});
      return [
        for (final s in (j['ice'] as List? ?? const []))
          {'urls': List<String>.from(s['urls'] as List), 'username': s['username'], 'credential': s['credential']},
      ];
    } catch (_) {
      return const [];
    }
  }

  /// A fine sessione: byte passati dal ponte (il centralino tiene il conto del mese).
  Future<void> uso(int byte) async {
    try {
      await _post('uso', {'id': id, 'segreto': _segreto, 'byte': byte});
    } catch (_) {}
  }

  /// Quali computer sono accesi adesso (per i recenti).
  Future<Map<String, bool>> stato(List<String> ids) async {
    if (ids.isEmpty) return {};
    final j = await _post('stato', {'id': id, 'segreto': _segreto, 'ids': ids});
    final c = j['computer'];
    final out = <String, bool>{};
    if (c is Map) {
      c.forEach((k, v) => out[k.toString()] = v is Map && v['acceso'] == true);
    }
    return out;
  }
}
