// Sessione tk-desk dal telefono (chi CONTROLLA): stessa sequenza del programma per computer (tkdesk/sessione.py).
// Stretta di mano SPAKE2 dal centralino (protocollo 3): chiamata → sfida (conferma del computer: se è sbagliata, la
// password è sbagliata) → offerta WebRTC sigillata con la chiave della sessione → risposta sigillata → collegamento
// diretto e cifrato. Canale dati «tk» con gli stessi messaggi JSON (mm, mb, mw, k, c, schermo, chat, appunti, fine…).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'centralino.dart';
import 'pake.dart';

const _stun = [
  {'urls': 'stun:stun.l.google.com:19302'},
  {'urls': 'stun:stun1.l.google.com:19302'},
];

String _motivoRifiuto(Map<String, dynamic> d) {
  if (d['v'] != protocollo) return "Su quel computer c'è una versione vecchia di tk-desk: va aggiornata.";
  final minuti = (((d['attesa'] as num?)?.toInt() ?? 60) / 60).round().clamp(1, 999);
  switch (d['motivo']) {
    case 'password':
      return 'Password sbagliata.';
    case 'bloccato':
      return 'Troppe password sbagliate: il computer non accetta tentativi per $minuti minut${minuti == 1 ? 'o' : 'i'}.';
    case 'occupato':
      return 'Quel computer è già in una sessione con qualcun altro.';
    case 'rifiutato':
      return "L'altra persona non ha accettato il collegamento (o non ha risposto in 30 secondi).";
    case 'manomesso':
      return 'Il collegamento è stato alterato per strada: interrotto per sicurezza.';
    case 'aggiorna':
      return 'Questa versione di tk-desk non si collega più: aggiornala.';
  }
  return 'Collegamento rifiutato.';
}

class SessioneDesk extends ChangeNotifier {
  SessioneDesk(this.ce, this.idRemoto, this.password);

  final Centralino ce;
  final String idRemoto, password;

  final renderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  RTCDataChannel? _canale;

  String stato = 'Preparo il collegamento…';
  bool aperta = false;
  String? chiusa; // motivo, quando la sessione è finita
  String avviso = ''; // problema segnalato dal computer (es. permessi del Mac)
  Map<String, dynamic> info = {};
  Offset? cursore; // posizione 0..1 del puntatore del computer
  final chat = <(bool, String)>[]; // (scritto da me, testo)
  int chatNuovi = 0;
  void Function(String testo)? suAppunti;
  void Function(String testo)? suChat;

  String get nome => (info['nome'] ?? '').toString();
  String get piattaforma => (info['piattaforma'] ?? '').toString();
  List<Map<String, dynamic>> get schermi =>
      ((info['schermi'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  int get schermoAttivo => (info['attivo'] as num?)?.toInt() ?? 0;

  /// Passi del collegamento con l'ora: se non riesce si vedono sotto il messaggio (per l'assistenza).
  final registro = <String>[];
  final _inizio = DateTime.now();

  void _passo(String s) {
    final ms = DateTime.now().difference(_inizio).inMilliseconds;
    registro.add('${(ms / 1000).toStringAsFixed(1)}s $s');
  }

  void _stato(String s) {
    stato = s;
    _passo(s);
    notifyListeners();
  }

  Future<void> avvia() async {
    await renderer.initialize();
    renderer.onResize = notifyListeners;
    try {
      if (ce.id.isEmpty) await ce.registra();
      if (idRemoto == ce.id) {
        await _chiudi('Questo è l\'ID di questo telefono.');
        return;
      }
      await _collega();
    } on ErroreCentralino catch (e) {
      await _chiudi(e.messaggio);
    } catch (e, st) {
      _passo('errore: $e');
      _passo(st.toString().split('\n').take(3).join(' | '));
      await _chiudi('Collegamento non riuscito: $e');
    }
  }

  Future<void> _collega() async {
    final ponte = await ce.ponte();
    _passo(ponte.isEmpty ? 'ponte: non disponibile (solo collegamento diretto)' : 'ponte: pronto');
    final pc = await createPeerConnection({'iceServers': [..._stun, ...ponte], 'sdpSemantics': 'unified-plan'});
    _pc = pc;
    await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo, init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly));
    await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio, init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly));
    final canale = await pc.createDataChannel('tk', RTCDataChannelInit());
    _canale = canale;
    final aperto = Completer<void>();
    canale.onDataChannelState = (s) {
      _passo('canale: ${s.name}');
      if (s == RTCDataChannelState.RTCDataChannelOpen && !aperto.isCompleted) aperto.complete();
      if (s == RTCDataChannelState.RTCDataChannelClosed && aperta) _chiudi('Collegamento interrotto.');
    };
    canale.onMessage = (m) {
      if (!m.isBinary) _messaggio(m.text);
    };
    pc.onTrack = (e) async {
      if (e.track.kind != 'video') return;
      if (e.streams.isNotEmpty) {
        renderer.srcObject = e.streams.first;
      } else {
        final s = await createLocalMediaStream('tk-desk');
        await s.addTrack(e.track);
        renderer.srcObject = s;
      }
      notifyListeners();
    };
    pc.onIceConnectionState = (s) => _passo('ice: ${s.name}');
    pc.onConnectionState = (s) {
      _passo('collegamento: ${s.name}');
      if ((s == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
              s == RTCPeerConnectionState.RTCPeerConnectionStateClosed) &&
          chiusa == null) {
        _chiudi('Collegamento interrotto.');
      }
    };

    // offerta completa di indirizzi (il computer non riceve indirizzi a parte): si aspetta la raccolta, max 4 s
    final raccolti = Completer<void>();
    pc.onIceGatheringState = (s) {
      if (s == RTCIceGatheringState.RTCIceGatheringStateComplete && !raccolti.isCompleted) raccolti.complete();
    };
    await pc.setLocalDescription(await pc.createOffer({}));
    await raccolti.future.timeout(const Duration(seconds: 4), onTimeout: () {});
    final offerta = (await pc.getLocalDescription())!.sdp!;
    _passo('offerta pronta: ${RegExp('a=candidate').allMatches(offerta).length} indirizzi');

    _stato('Preparo la chiamata…');
    final sp = Spake2('A', ce.id, idRemoto, await chiaveDa2(password, idRemoto));
    final n = nuovoCodice();
    await ce.invia(idRemoto, 'chiamata', {'v': protocollo, 'n': n, 'p': sp.messaggio(), 'fissa': eFissa(password)});
    _stato("Chiamo il computer… Dall'altra parte devono premere «Accetta».");
    const nonRisponde = "Il computer non risponde: controlla che tk-desk sia aperto e che l'altra persona abbia "
        'premuto «Accetta».';
    var m = await _prendi(n, 30);
    if (chiusa != null) return;
    if (m == null) return _chiudi(nonRisponde);
    _passo('dal computer: ${m.tipo} ${m.dati['motivo'] ?? ''} v${m.dati['v'] ?? '?'}');
    if (m.tipo == 'sfida') {
      var giusta = false;
      try {
        await sp.finisci((m.dati['p'] ?? '').toString());
        giusta = sp.confermaValida(m.dati['c']?.toString());
      } on ErrorePake {
        giusta = false;
      }
      if (!giusta) {
        await ce.invia(idRemoto, 'offerta', {'n': n, 'c': ''}); // il computer conta il tentativo subito
        return _chiudi('Password sbagliata.');
      }
      final corpo = jsonEncode({
        'sdp': offerta,
        'nome': ce.nome,
        'piattaforma': Platform.isIOS ? 'ios' : 'android',
        'versione': ce.versione,
      });
      await ce.invia(idRemoto, 'offerta', {'n': n, 'c': sp.conferma(), 'corpo': corpo, 'sigillo': await sp.sigilla('offerta', corpo)});
      // risposta (o rifiuto): fino a 50 secondi (30 per «Accetta» sul computer + margine)
      m = await _prendi(n, 50);
      if (chiusa != null) return;
      if (m == null) return _chiudi(nonRisponde);
      _passo('dal computer: ${m.tipo} ${m.dati['motivo'] ?? ''}');
    }
    if (m.tipo == 'rifiuto') return _chiudi(_motivoRifiuto(m.dati));
    String sdp;
    try {
      final corpo = (m.dati['corpo'] ?? '').toString();
      if (m.tipo != 'risposta' || !await sp.sigilloValido('risposta', corpo, m.dati['sigillo']?.toString())) {
        throw const FormatException('sigillo');
      }
      final r = jsonDecode(corpo) as Map<String, dynamic>;
      sdp = r['sdp'].toString();
      info['nome'] = (r['nome'] ?? '').toString();
    } catch (_) {
      return _chiudi('Risposta non firmata: collegamento interrotto per sicurezza.');
    }
    _stato('Collegamento in corso…');
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    _passo('risposta applicata: ${RegExp('a=candidate').allMatches(sdp).length} indirizzi del computer');
    try {
      await aperto.future.timeout(const Duration(seconds: 25));
    } on TimeoutException {
      return _chiudi('Il telefono e il computer non riescono a collegarsi, nemmeno passando dal ponte. '
          'Controlla la connessione e riprova, per esempio con il Wi-Fi.');
    }
  }

  /// Il prossimo messaggio del computer per QUESTA chiamata (codice [n]): quelli di una chiamata di prima si buttano.
  /// Un rifiuto senza codice viene da una tk-desk di prima e vale (dice che va aggiornata).
  Future<Messaggio?> _prendi(String n, int secondi) async {
    final limite = DateTime.now().add(Duration(seconds: secondi));
    while (chiusa == null && DateTime.now().isBefore(limite)) {
      for (final m in await ce.ricevi()) {
        if (m.da != idRemoto) continue;
        final suo = (m.dati['n'] ?? '').toString();
        if (suo == n || (m.tipo == 'rifiuto' && suo.isEmpty)) return m;
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    return null;
  }

  void _messaggio(String testo) {
    Map<String, dynamic> d;
    try {
      d = jsonDecode(testo) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (d['t']) {
      case 'info':
        info.addAll(d);
        if (!aperta) {
          aperta = true;
          stato = '';
          final p = d['permessi'];
          if (p is Map && (p['accesso'] == false || p['schermo'] == false)) {
            avviso = 'Sul computer manca il permesso '
                '${p['accesso'] == false ? 'Accessibilità (mouse e tastiera)' : 'Registrazione schermo'}: '
                'chi è davanti deve concederlo.';
          }
        }
        notifyListeners();
      case 'cur':
        final x = (d['x'] as num?)?.toDouble() ?? -1, y = (d['y'] as num?)?.toDouble() ?? -1;
        cursore = x < 0 ? null : Offset(x, y);
        notifyListeners();
      case 'chat':
        final s = (d['s'] ?? '').toString();
        chat.add((false, s));
        chatNuovi++;
        suChat?.call(s);
        notifyListeners();
      case 'appunti':
        suAppunti?.call((d['s'] ?? '').toString());
      case 'avviso':
        avviso = (d['s'] ?? '').toString();
        notifyListeners();
      case 'fine':
        _chiudi('Sessione chiusa dall\'altro computer.');
    }
  }

  void manda(Map<String, dynamic> d) {
    final c = _canale;
    if (c != null && c.state == RTCDataChannelState.RTCDataChannelOpen) {
      c.send(RTCDataChannelMessage(jsonEncode(d)));
    }
  }

  void scriviChat(String s) {
    chat.add((true, s));
    manda({'t': 'chat', 's': s});
    notifyListeners();
  }

  Future<void> termina() async {
    if (chiusa != null) return;
    manda({'t': 'fine'});
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await _chiudi('Sessione chiusa.');
  }

  /// Se il collegamento è passato dal ponte, quanti byte sono arrivati (per il limite mensile del centralino).
  Future<void> _segnalaUso() async {
    final pc = _pc;
    if (pc == null) return;
    try {
      final report = await pc.getStats();
      final perId = {for (final r in report) r.id: r};
      var ponte = false;
      var byte = 0;
      for (final r in report) {
        if (r.type == 'candidate-pair' && r.values['nominated'] == true && r.values['state'] == 'succeeded') {
          final l = perId[r.values['localCandidateId']], rem = perId[r.values['remoteCandidateId']];
          if (l?.values['candidateType'] == 'relay' || rem?.values['candidateType'] == 'relay') ponte = true;
        }
        if (r.type == 'inbound-rtp') byte += (r.values['bytesReceived'] as num?)?.toInt() ?? 0;
      }
      if (ponte && byte > 0) {
        _passo('passata dal ponte: ${(byte / 1e6).toStringAsFixed(1)} MB');
        await ce.uso((byte * 1.1).round());
      }
    } catch (_) {}
  }

  Future<void> _chiudi(String motivo) async {
    if (chiusa != null) return;
    _passo('fine: $motivo');
    if (aperta) await _segnalaUso();
    chiusa = motivo;
    aperta = false;
    notifyListeners();
    try {
      await _canale?.close();
    } catch (_) {}
    try {
      await _pc?.close();
    } catch (_) {}
  }

  @override
  void dispose() {
    _chiudi('Sessione chiusa.');
    renderer.srcObject = null;
    renderer.dispose();
    super.dispose();
  }
}

/// Tasti speciali con il nome che usano i messaggi «k» (vedi tkdesk/comandi.py).
class Tasto {
  const Tasto(this.etichetta, this.nome, {this.modificatore = false});
  final String etichetta, nome;
  final bool modificatore;
}
