// Schermata della sessione: lo schermo del computer, i gesti per mouse e tastiera, chat e tasti speciali.
//
// Gesti (come le app di controllo remoto più diffuse):
//  - modalità TOUCHPAD (predefinita): un dito sposta il puntatore, tocco = clic, tocco lungo = clic destro;
//  - modalità TOCCO DIRETTO: il clic va dove tocchi, trascinare = trascinare col tasto premuto;
//  - due dita: allarga/stringi = zoom, su/giù = rotella (senza zoom) o sposta la vista (con zoom);
//  - CLIC DESTRO, in tutte e due le modalità: tocco con due dita, tocco lungo, oppure il pulsante «tasto destro»
//    della barra (il tocco seguente diventa un clic destro).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'sessione.dart';
import 'tema.dart';

class SchermataSessione extends StatefulWidget {
  const SchermataSessione({super.key, required this.sessione, this.suAperta});
  final SessioneDesk sessione;
  final void Function(SessioneDesk s)? suAperta;

  @override
  State<SchermataSessione> createState() => _SchermataSessioneState();
}

class _SchermataSessioneState extends State<SchermataSessione> {
  SessioneDesk get s => widget.sessione;
  bool touchpad = true;
  bool _destro = false; // pulsante «tasto destro»: il prossimo tocco è un clic destro
  DateTime? _dueDitaDa; // tocco con due dita = clic destro, se le dita non si muovono
  Offset _dueDitaPunto = Offset.zero;
  bool _dueDitaMosse = false;
  bool barra = true;
  bool tastiera = false;
  final _campo = TextEditingController(text: _base);
  final _fuoco = FocusNode();
  static const _base = '  '; // due spazi: se diventano uno, è stato premuto il tasto «cancella»
  final _modificatori = <String>{};

  // zoom e spostamento della vista
  double _zoom = 1, _zoomInizio = 1;
  Offset _sposta = Offset.zero, _spostaInizio = Offset.zero, _focaleInizio = Offset.zero;
  int _dita = 0;
  bool _haZoomato = false;
  double _rotella = 0;

  // puntatore stimato qui (touchpad): risponde subito, poi si riallinea con quello del computer
  Offset _puntatore = const Offset(.5, .5);
  DateTime _ultimoMioMovimento = DateTime(2000);
  Offset? _trascinoDa;
  Timer? _timerMossa;
  Offset? _mossaDaMandare;
  bool _avvisoMostrato = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    s.addListener(_cambiato);
    s.suAppunti = (t) => Clipboard.setData(ClipboardData(text: t));
    s.suChat = (t) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${s.nome.isEmpty ? 'Computer' : s.nome}: $t'),
        action: SnackBarAction(label: 'Rispondi', onPressed: _apriChat),
      ));
    };
    _timerMossa = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final m = _mossaDaMandare;
      if (m != null) {
        _mossaDaMandare = null;
        s.manda({'t': 'mm', 'x': _r(m.dx), 'y': _r(m.dy)});
      }
    });
    s.avvia();
  }

  bool _eraAperta = false;

  void _cambiato() {
    if (!mounted) return;
    if (s.aperta && !_eraAperta) {
      _eraAperta = true;
      widget.suAperta?.call(s);
    }
    final c = s.cursore;
    if (c != null && DateTime.now().difference(_ultimoMioMovimento).inMilliseconds > 600) _puntatore = c;
    if (s.avviso.isNotEmpty && !_avvisoMostrato) {
      _avvisoMostrato = true;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.avviso), duration: const Duration(seconds: 8)));
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timerMossa?.cancel();
    s.removeListener(_cambiato);
    s.termina();
    s.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _campo.dispose();
    _fuoco.dispose();
    super.dispose();
  }

  static double _r(double v) => (v.clamp(0.0, 1.0) * 100000).round() / 100000;

  // ───────────────────────── geometria: punto sullo schermo del telefono ↔ punto 0..1 del computer
  Rect _rettVideo(Size area) {
    final w = s.renderer.videoWidth, h = s.renderer.videoHeight;
    if (w == 0 || h == 0) return Offset.zero & area;
    final sc = math.min(area.width / w, area.height / h);
    final vw = w * sc, vh = h * sc;
    return Rect.fromLTWH((area.width - vw) / 2, (area.height - vh) / 2, vw, vh);
  }

  Offset _normalizza(Offset p, Size area) {
    final r = _rettVideo(area);
    final q = (p - _sposta) / _zoom; // punto nel contenuto senza zoom
    return Offset(((q.dx - r.left) / r.width).clamp(0.0, 1.0), ((q.dy - r.top) / r.height).clamp(0.0, 1.0));
  }

  Offset _suSchermo(Offset n, Size area) {
    final r = _rettVideo(area);
    return Offset(r.left + n.dx * r.width, r.top + n.dy * r.height) * _zoom + _sposta;
  }

  void _limitaVista(Size area) {
    if (_zoom <= 1) {
      _zoom = 1;
      _sposta = Offset.zero;
      return;
    }
    final minX = area.width - area.width * _zoom, minY = area.height - area.height * _zoom;
    _sposta = Offset(_sposta.dx.clamp(minX, 0.0), _sposta.dy.clamp(minY, 0.0));
  }

  /// Con lo zoom la vista segue il puntatore (touchpad).
  void _seguiPuntatore(Size area) {
    if (_zoom <= 1) return;
    final p = _suSchermo(_puntatore, area);
    const m = 40.0;
    var d = Offset.zero;
    if (p.dx < m) d = d.translate(m - p.dx, 0);
    if (p.dx > area.width - m) d = d.translate(area.width - m - p.dx, 0);
    if (p.dy < m) d = d.translate(0, m - p.dy);
    if (p.dy > area.height - m) d = d.translate(0, area.height - m - p.dy);
    _sposta += d;
    _limitaVista(area);
  }

  // ───────────────────────── comandi
  void _muovi(Offset n) {
    _puntatore = n;
    _ultimoMioMovimento = DateTime.now();
    _mossaDaMandare = n;
  }

  void _clic(String tasto, Offset n) {
    final x = _r(n.dx), y = _r(n.dy);
    s.manda({'t': 'mb', 'b': tasto, 'd': 1, 'x': x, 'y': y});
    s.manda({'t': 'mb', 'b': tasto, 'd': 0, 'x': x, 'y': y});
  }

  void _tocco(TapUpDetails d, Size area) {
    if (!touchpad) _muovi(_normalizza(d.localPosition, area));
    if (_destro) {
      HapticFeedback.mediumImpact();
      _clic('r', _puntatore);
      _destro = false;
    } else {
      _clic('l', _puntatore);
    }
    setState(() {});
  }

  void _toccoLungo(LongPressStartDetails d, Size area) {
    if (!touchpad) _muovi(_normalizza(d.localPosition, area));
    HapticFeedback.mediumImpact();
    _clic('r', _puntatore);
    setState(() {});
  }

  void _inizio(ScaleStartDetails d, Size area) {
    _dita = d.pointerCount;
    _zoomInizio = _zoom;
    _spostaInizio = _sposta;
    _focaleInizio = d.localFocalPoint;
    _haZoomato = false;
    _rotella = 0;
    if (_dita == 1 && !touchpad) {
      final n = _normalizza(d.localFocalPoint, area);
      _muovi(n);
      _trascinoDa = n;
    }
  }

  void _aggiorna(ScaleUpdateDetails d, Size area) {
    if (d.pointerCount >= 2) {
      if (_dueDitaDa == null) {
        _dueDitaDa = DateTime.now();
        _dueDitaPunto = d.localFocalPoint;
        _dueDitaMosse = false;
      } else if ((d.localFocalPoint - _dueDitaPunto).distance > 14 || (d.scale - 1).abs() > .06) {
        _dueDitaMosse = true; // zoom o scorrimento: non è un tocco
      }
      _dita = 2;
      if (_trascinoDa != null) _trascinoDa = null;
      if ((d.scale - 1).abs() > .06 || _haZoomato) {
        // zoom attorno alle dita
        _haZoomato = true;
        final z = (_zoomInizio * d.scale).clamp(1.0, 4.0);
        final contenuto = (_focaleInizio - _spostaInizio) / _zoomInizio;
        _zoom = z;
        _sposta = d.localFocalPoint - contenuto * z;
        _limitaVista(area);
      } else if (_zoom > 1) {
        _sposta = _spostaInizio + (d.localFocalPoint - _focaleInizio);
        _limitaVista(area);
      } else {
        // rotella: ogni 24 pixel uno scatto (dito giù = la pagina scende verso l'alto, come sul telefono)
        _rotella += d.focalPointDelta.dy;
        while (_rotella.abs() >= 24) {
          final passo = _rotella > 0 ? 1 : -1;
          s.manda({'t': 'mw', 'dx': 0, 'dy': passo});
          _rotella -= passo * 24;
        }
      }
      setState(() {});
      return;
    }
    if (_dita != 1) return;
    if (touchpad) {
      final r = _rettVideo(area);
      final delta = d.focalPointDelta / _zoom;
      final n = Offset((_puntatore.dx + delta.dx / r.width * 1.4).clamp(0.0, 1.0),
          (_puntatore.dy + delta.dy / r.height * 1.4).clamp(0.0, 1.0));
      _muovi(n);
      _seguiPuntatore(area);
    } else {
      final n = _normalizza(d.localFocalPoint, area);
      if (_trascinoDa != null && (n - _trascinoDa!).distance > .004) {
        // trascinare: tasto premuto dal punto di partenza
        s.manda({'t': 'mb', 'b': 'l', 'd': 1, 'x': _r(_trascinoDa!.dx), 'y': _r(_trascinoDa!.dy)});
        _trascinoDa = const Offset(-1, -1);
      }
      _muovi(n);
    }
    setState(() {});
  }

  void _fine(ScaleEndDetails d) {
    // il gesto si chiude a ogni dito sollevato: si decide solo quando non resta nessun dito
    final da = _dueDitaDa;
    if (d.pointerCount == 0) _dueDitaDa = null;
    if (da != null && d.pointerCount == 0 && !_dueDitaMosse && DateTime.now().difference(da).inMilliseconds < 400) {
      // tocco con due dita: clic destro (touchpad = dove c'è il puntatore, tocco diretto = tra le due dita)
      final size = context.size;
      if (!touchpad && size != null) _muovi(_normalizza(_dueDitaPunto, size));
      HapticFeedback.mediumImpact();
      _clic('r', _puntatore);
      setState(() {});
    }
    if (_trascinoDa == const Offset(-1, -1)) {
      s.manda({'t': 'mb', 'b': 'l', 'd': 0, 'x': _r(_puntatore.dx), 'y': _r(_puntatore.dy)});
    }
    _trascinoDa = null;
    _dita = 0;
  }

  // ───────────────────────── tastiera
  bool get _mac => s.piattaforma == 'macos';

  void _tasto(String nome) {
    for (final m in _modificatori) {
      s.manda({'t': 'k', 'k': m, 'd': 1});
    }
    s.manda({'t': 'k', 'k': nome, 'd': 1});
    s.manda({'t': 'k', 'k': nome, 'd': 0});
    for (final m in _modificatori) {
      s.manda({'t': 'k', 'k': m, 'd': 0});
    }
    if (_modificatori.isNotEmpty) setState(_modificatori.clear);
  }

  void _scritto(String v) {
    if (v.length < _base.length) {
      for (var i = 0; i < _base.length - v.length; i++) {
        _tasto('backspace');
      }
    } else if (v.length > _base.length) {
      for (final ch in v.substring(_base.length).characters) {
        if (ch == '\n') {
          _tasto('enter');
        } else if (_modificatori.isNotEmpty && RegExp(r'^[A-Za-z0-9]$').hasMatch(ch)) {
          _tasto(ch.toLowerCase()); // Ctrl+C, Cmd+V…: si manda il tasto, non il carattere
        } else {
          s.manda({'t': 'c', 'c': ch});
        }
      }
    }
    _campo.value = const TextEditingValue(text: _base, selection: TextSelection.collapsed(offset: _base.length));
  }

  void _apriTastiera() {
    setState(() => tastiera = !tastiera);
    if (tastiera) {
      _fuoco.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    } else {
      _fuoco.unfocus();
    }
  }

  Future<void> _incolla() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text ?? '';
    if (t.isEmpty) {
      if (mounted) avviso(context, 'Negli appunti del telefono non c\'è testo.');
      return;
    }
    s.manda({'t': 'appunti', 's': t});
    await Future<void>.delayed(const Duration(milliseconds: 250));
    s.manda({'t': 'k', 'k': 'ctrl', 'd': 1}); // su Mac «ctrl» diventa Cmd (vedi tkdesk/comandi.py)
    s.manda({'t': 'k', 'k': 'v', 'd': 1});
    s.manda({'t': 'k', 'k': 'v', 'd': 0});
    s.manda({'t': 'k', 'k': 'ctrl', 'd': 0});
  }

  // ───────────────────────── fogli
  void _apriChat() {
    s.chatNuovi = 0;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: bianco,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FoglioChat(sessione: s),
    ).then((_) => setState(() => s.chatNuovi = 0));
  }

  void _scegliSchermo() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: bianco,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(16), child: TitoloSezione('Schermo del computer')),
          for (final (i, sc) in s.schermi.indexed)
            ListTile(
              leading: Icon(Icons.desktop_windows, color: i == s.schermoAttivo ? accento : grigio500),
              title: Text('Schermo ${i + 1}'),
              subtitle: Text('${sc['width']} × ${sc['height']}'),
              trailing: i == s.schermoAttivo ? const Icon(Icons.check, color: accento) : null,
              onTap: () {
                s.manda({'t': 'schermo', 'i': i});
                Navigator.pop(c);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _esci() async {
    if (s.aperta && !await conferma(context, 'Chiudere la sessione?', 'Il collegamento con il computer si chiude.',
        si: 'Chiudi')) {
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  // ───────────────────────── disegno
  @override
  Widget build(BuildContext context) {
    final tasti = <Tasto>[
      const Tasto('Esc', 'esc'),
      const Tasto('Tab', 'tab'),
      Tasto(_mac ? '⌘ Cmd' : 'Ctrl', 'ctrl', modificatore: true),
      Tasto(_mac ? '⌥ Opt' : 'Alt', 'alt', modificatore: true),
      Tasto(_mac ? 'Ctrl' : 'Win', 'meta', modificatore: true),
      const Tasto('⇧', 'shift', modificatore: true),
      const Tasto('←', 'left'),
      const Tasto('↑', 'up'),
      const Tasto('↓', 'down'),
      const Tasto('→', 'right'),
      const Tasto('Canc', 'delete'),
      const Tasto('Home', 'home'),
      const Tasto('Fine', 'end'),
      for (var i = 1; i <= 12; i++) Tasto('F$i', 'f$i'),
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (fatto, _) {
        if (!fatto) _esci();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1220),
        body: Stack(children: [
          // campo invisibile che riceve la tastiera del telefono
          Positioned(
            left: -1000,
            top: 0,
            width: 10,
            height: 10,
            child: TextField(
              controller: _campo,
              focusNode: _fuoco,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.multiline,
              maxLines: null,
              onChanged: _scritto,
            ),
          ),
          Positioned.fill(
            child: LayoutBuilder(builder: (context, c) {
              final area = Size(c.maxWidth, c.maxHeight);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _tocco(d, area),
                onLongPressStart: (d) => _toccoLungo(d, area),
                onScaleStart: (d) => _inizio(d, area),
                onScaleUpdate: (d) => _aggiorna(d, area),
                onScaleEnd: _fine,
                child: ClipRect(
                  child: Stack(children: [
                    Positioned.fill(
                      child: Transform(
                        transform: Matrix4.identity()
                          ..translateByDouble(_sposta.dx, _sposta.dy, 0, 1)
                          ..scaleByDouble(_zoom, _zoom, 1, 1),
                        child: RTCVideoView(s.renderer,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain, filterQuality: FilterQuality.medium),
                      ),
                    ),
                    if (s.aperta)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: _Puntatore(_suSchermo(touchpad ? _puntatore : (s.cursore ?? _puntatore), area))),
                        ),
                      ),
                  ]),
                ),
              );
            }),
          ),
          if (!s.aperta) _attesa(),
          if (s.aperta && barra) _barraSopra(),
          if (s.aperta && !barra)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: _pulsantino(Icons.more_horiz, 'Mostra i comandi', () => setState(() => barra = true)),
            ),
          if (s.aperta && tastiera) _barraTasti(tasti),
        ]),
      ),
    );
  }

  Widget _attesa() => Positioned.fill(
        child: Container(
          color: const Color(0xFF0B1220),
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const LogoTk(lato: 64),
            const SizedBox(height: 22),
            if (s.chiusa == null) ...[
              const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3, color: accento2)),
              const SizedBox(height: 18),
              Text(s.stato, textAlign: TextAlign.center, style: const TextStyle(color: bianco, fontSize: 16)),
              const SizedBox(height: 6),
              Text('ID ${formattaId(s.idRemoto)}', style: const TextStyle(color: grigio400, fontSize: 13)),
            ] else ...[
              Text(s.chiusa!, textAlign: TextAlign.center, style: const TextStyle(color: bianco, fontSize: 16, height: 1.4)),
              if (!_eraAperta && s.registro.isNotEmpty) ...[
                const SizedBox(height: 14),
                // i passi del collegamento: una foto di questo basta per capire dove si è fermato
                Text(s.registro.join('\n'),
                    textAlign: TextAlign.left, style: const TextStyle(color: grigio400, fontSize: 10.5, height: 1.35)),
              ],
              const SizedBox(height: 24),
              SizedBox(width: 240, child: BottoneTk(testo: 'Indietro', icona: Icons.arrow_back, onTap: () => Navigator.of(context).pop())),
            ],
          ]),
        ),
      );

  Widget _pulsantino(IconData icona, String descrizione, VoidCallback onTap, {bool acceso = false, int badge = 0}) =>
      Tooltip(
        message: descrizione,
        child: Material(
          color: acceso ? accento : const Color(0xCC1E293B),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Badge(isLabelVisible: badge > 0, label: Text('$badge'), child: Icon(icona, color: bianco, size: 22)),
            ),
          ),
        ),
      );

  Widget _barraSopra() => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        right: 8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xE60F172A), borderRadius: BorderRadius.circular(18)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _pulsantino(Icons.close, 'Chiudi la sessione', _esci),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(s.nome.isEmpty ? 'Computer' : s.nome,
                      style: const TextStyle(color: bianco, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(formattaId(s.idRemoto), style: const TextStyle(color: grigio400, fontSize: 11)),
                ]),
              ),
              const SizedBox(width: 6),
              _pulsantino(touchpad ? Icons.touch_app_outlined : Icons.ads_click,
                  touchpad ? 'Modalità touchpad (tocca per il tocco diretto)' : 'Tocco diretto (tocca per il touchpad)', () {
                setState(() => touchpad = !touchpad);
                avviso(context, touchpad
                    ? 'Touchpad: un dito sposta il puntatore, tocco = clic, tocco lungo = clic destro.'
                    : 'Tocco diretto: il clic va dove tocchi, trascina per trascinare.');
              }),
              const SizedBox(width: 6),
              _pulsantino(Icons.mouse_outlined, 'Tasto destro: il prossimo tocco è un clic destro', () {
                setState(() => _destro = !_destro);
                if (_destro) avviso(context, 'Tocca dove vuoi il clic destro (o tocca con due dita, o tieni premuto).');
              }, acceso: _destro),
              const SizedBox(width: 6),
              _pulsantino(Icons.keyboard, 'Tastiera', _apriTastiera, acceso: tastiera),
              const SizedBox(width: 6),
              _pulsantino(Icons.content_paste, 'Incolla sul computer il testo copiato sul telefono', _incolla),
              const SizedBox(width: 6),
              _pulsantino(Icons.chat_bubble_outline, 'Chat', _apriChat, badge: s.chatNuovi),
              if (s.schermi.length > 1) ...[
                const SizedBox(width: 6),
                _pulsantino(Icons.desktop_windows_outlined, 'Scegli lo schermo', _scegliSchermo),
              ],
              const SizedBox(width: 6),
              _pulsantino(Icons.fit_screen, 'Adatta lo schermo', () => setState(() {
                    _zoom = 1;
                    _sposta = Offset.zero;
                  })),
              const SizedBox(width: 6),
              _pulsantino(Icons.expand_less, 'Nascondi i comandi', () => setState(() => barra = false)),
            ]),
          ),
        ),
      );

  Widget _barraTasti(List<Tasto> tasti) => Positioned(
        left: 0,
        right: 0,
        bottom: MediaQuery.of(context).viewInsets.bottom,
        child: Container(
          color: navy,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(children: [
              for (final t in tasti)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Material(
                    color: _modificatori.contains(t.nome) ? accento : navy3,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (t.modificatore) {
                          setState(() => _modificatori.contains(t.nome) ? _modificatori.remove(t.nome) : _modificatori.add(t.nome));
                        } else {
                          _tasto(t.nome);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                        child: Text(t.etichetta,
                            style: const TextStyle(color: bianco, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
}

/// Freccia del mouse del computer, disegnata sopra il video (la cattura dello schermo non la contiene).
class _Puntatore extends CustomPainter {
  _Puntatore(this.p);
  final Offset p;

  @override
  void paint(Canvas canvas, Size size) {
    final f = Path()..moveTo(p.dx, p.dy);
    for (final d in const [(0.0, 20.0), (5.3, 15.0), (8.8, 23.0), (12.4, 21.4), (9.0, 13.7), (15.3, 13.7)]) {
      f.lineTo(p.dx + d.$1, p.dy + d.$2);
    }
    f.close();
    canvas.drawShadow(f, Colors.black, 3, false);
    canvas.drawPath(f, Paint()..color = navy);
    canvas.drawPath(
        f,
        Paint()
          ..color = bianco
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _Puntatore old) => old.p != p;
}

class _FoglioChat extends StatefulWidget {
  const _FoglioChat({required this.sessione});
  final SessioneDesk sessione;

  @override
  State<_FoglioChat> createState() => _FoglioChatState();
}

class _FoglioChatState extends State<_FoglioChat> {
  final _testo = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.sessione.addListener(_agg);
  }

  void _agg() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.sessione.removeListener(_agg);
    _testo.dispose();
    super.dispose();
  }

  void _manda() {
    final t = _testo.text.trim();
    if (t.isEmpty) return;
    widget.sessione.scriviChat(t);
    _testo.clear();
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.sessione.chat;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .55,
        child: Column(children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8), child: TitoloSezione('Chat')),
          Expanded(
            child: chat.isEmpty
                ? const Center(child: Text('Scrivi un messaggio a chi è davanti al computer.', style: TextStyle(color: grigio500)))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: chat.length,
                    itemBuilder: (_, i) {
                      final (mio, t) = chat[chat.length - 1 - i];
                      return Align(
                        alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: const BoxConstraints(maxWidth: 300),
                          decoration: BoxDecoration(
                              color: mio ? accento : grigio100, borderRadius: BorderRadius.circular(16)),
                          child: Text(t, style: TextStyle(color: mio ? bianco : navy, fontSize: 15)),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _testo,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Messaggio'),
                    onSubmitted: (_) => _manda(),
                  ),
                ),
                IconButton(onPressed: _manda, icon: const Icon(Icons.send, color: accento)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
