// Schermata principale: ID e password del computer da controllare, recenti con il punto acceso/spento.
// Copyright (C) 2026 Pietro De Filippis (TecnikGeek) — AGPL-3.0-or-later, vedi COPYING
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'centralino.dart';
import 'schermo.dart';
import 'sessione.dart';
import 'tema.dart';
import 'tk_pro.dart';

class Recente {
  Recente(this.id, this.nome, this.quando);
  final String id, nome;
  final int quando;
  Map<String, dynamic> toJson() => {'id': id, 'nome': nome, 'quando': quando};
  static Recente da(Map<String, dynamic> j) =>
      Recente(j['id'].toString(), (j['nome'] ?? '').toString(), (j['quando'] as num?)?.toInt() ?? 0);
}

class SchermataHome extends StatefulWidget {
  const SchermataHome({super.key, required this.centralino});
  final Centralino centralino;

  @override
  State<SchermataHome> createState() => _SchermataHomeState();
}

class _SchermataHomeState extends State<SchermataHome> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  final _fuocoPw = FocusNode();
  String _errore = '';
  bool _numerico = true; // tastiera numerica per la monouso; «ABC» per una password fissa con lettere
  List<Recente> _recenti = [];
  Map<String, bool> _accesi = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // primo avvio: benvenuto (software libero, privacy, statistiche, avviso antitruffa) PRIMA di qualunque
      // chiamata in rete: lo stato acceso/spento dei recenti chiede al centralino, quindi parte dopo
      if (mounted) await benvenutoTk(context, righeExtra: righeBenvenutoDesk);
      if (!mounted) return;
      await _carica();
      // controllo discreto: parla solo se c'è una versione nuova
      if (mounted) proponiAggiornamento(context, avvisaSeAggiornata: false);
      // invito al caffè: al primo avvio e poi al massimo una volta al mese, mai sopra un'altra finestra
      if (mounted) invitoCaffe(context);
    });
  }

  Future<void> _carica() async {
    final p = await SharedPreferences.getInstance();
    try {
      _recenti = (jsonDecode(p.getString('desk_recenti') ?? '[]') as List)
          .map((e) => Recente.da(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      _recenti = [];
    }
    if (mounted) setState(() {});
    _controllaAccesi();
  }

  Future<void> _controllaAccesi() async {
    if (_recenti.isEmpty) return;
    try {
      if (widget.centralino.id.isEmpty) await widget.centralino.registra();
      final s = await widget.centralino.stato(_recenti.map((r) => r.id).toList());
      if (mounted) setState(() => _accesi = s);
    } catch (_) {}
  }

  Future<void> _ricorda(SessioneDesk s) async {
    _recenti.removeWhere((r) => r.id == s.idRemoto);
    _recenti.insert(0, Recente(s.idRemoto, s.nome, DateTime.now().millisecondsSinceEpoch ~/ 1000));
    if (_recenti.length > 12) _recenti = _recenti.sublist(0, 12);
    final p = await SharedPreferences.getInstance();
    await p.setString('desk_recenti', jsonEncode(_recenti.map((r) => r.toJson()).toList()));
    if (mounted) setState(() {});
  }

  void _formattaId(String t) {
    final n = formattaId(t.replaceAll(RegExp(r'\D'), '').substring(0, t.replaceAll(RegExp(r'\D'), '').length.clamp(0, 9)));
    if (n != t) _id.value = TextEditingValue(text: n, selection: TextSelection.collapsed(offset: n.length));
  }

  /// La monouso a gruppi come sul computer («123 456»); una password fissa resta com'è.
  void _formattaPw(String t) {
    final cifre = t.replaceAll(' ', '');
    String nuovo;
    if (RegExp(r'^\d{0,6}$').hasMatch(cifre)) {
      nuovo = cifre.length <= 3 ? cifre : '${cifre.substring(0, 3)} ${cifre.substring(3)}';
    } else if (t.length > 3 && t[3] == ' ' && RegExp(r'^\d{3}$').hasMatch(t.substring(0, 3)) && !t.substring(4).contains(' ')) {
      nuovo = t.substring(0, 3) + t.substring(4);
    } else {
      return;
    }
    if (nuovo != t) _pw.value = TextEditingValue(text: nuovo, selection: TextSelection.collapsed(offset: nuovo.length));
  }

  Future<void> _collegati() async {
    final id = pulisciId(_id.text);
    final pw = _pw.text.trim();
    if (id.isEmpty) return setState(() => _errore = "L'ID ha 9 cifre: controlla di averlo scritto tutto.");
    if (pw.isEmpty) {
      _fuocoPw.requestFocus();
      return setState(() => _errore = "Scrivi la password che vedi sull'altro computer.");
    }
    setState(() => _errore = '');
    FocusScope.of(context).unfocus();
    final sessione = SessioneDesk(widget.centralino, id, pw);
    _pw.clear();
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SchermataSessione(sessione: sessione, suAperta: _ricorda), fullscreenDialog: true));
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _controllaAccesi();
  }

  Future<void> _togli(Recente r) async {
    if (!await conferma(context, 'Togliere ${r.nome.isEmpty ? formattaId(r.id) : r.nome}?', 'Sparisce solo da questo elenco.',
        si: 'Togli')) {
      return;
    }
    _recenti.removeWhere((x) => x.id == r.id);
    final p = await SharedPreferences.getInstance();
    await p.setString('desk_recenti', jsonEncode(_recenti.map((r) => r.toJson()).toList()));
    if (mounted) setState(() {});
  }

  Future<List<(String, String)>> _righeInfo() async => [
        ('ID di questo telefono', widget.centralino.id.isEmpty ? '—' : formattaId(widget.centralino.id)),
        ('Computer recenti', '${_recenti.length}'),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: sfondo,
      body: Column(children: [
        Testata(
          sottotitolo: 'Controlla PC e Mac dal telefono',
          azioni: [
            AzioneTk(Icons.info, 'Informazioni',
                () => apriInformazioni(context, righe: _righeInfo, notaDati: notaDatiDesk)),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _controllaAccesi,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              CardTk(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const TitoloSezione('Controlla un computer'),
                  const SizedBox(height: 6),
                  Text("Scrivi l'ID e la password che vedi in tk-desk sul computer.",
                      style: TextStyle(color: testoTenue, fontSize: 13)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _id,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onChanged: _formattaId,
                    onSubmitted: (_) => _fuocoPw.requestFocus(),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1),
                    decoration: const InputDecoration(hintText: 'ID del computer (9 cifre)', prefixIcon: Icon(Icons.computer)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pw,
                    focusNode: _fuocoPw,
                    keyboardType: _numerico ? TextInputType.number : TextInputType.visiblePassword,
                    // in chiaro, come sul computer: è la monouso che ti dettano
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: _formattaPw,
                    onSubmitted: (_) => _collegati(),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2),
                    decoration: InputDecoration(
                      hintText: 'Password (6 cifre)',
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: TextButton(
                        onPressed: () {
                          setState(() => _numerico = !_numerico);
                          // la tastiera cambia solo se il campo si riapre
                          _fuocoPw.unfocus();
                          Future<void>.delayed(const Duration(milliseconds: 120), _fuocoPw.requestFocus);
                        },
                        child: Text(_numerico ? 'ABC' : '123', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  if (_errore.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(_errore, style: const TextStyle(color: rosso, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 14),
                  BottoneTk(testo: 'Collegati', icona: Icons.link, onTap: _collegati),
                ]),
              ),
              const SizedBox(height: 18),
              const TitoloSezione('Recenti'),
              const SizedBox(height: 8),
              if (_recenti.isEmpty)
                CardTk(
                  child: Text('I computer che controlli compariranno qui, con un punto verde quando sono accesi.',
                      style: TextStyle(color: testoTenue)),
                ),
              for (final r in _recenti)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CardTk(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    onTap: () {
                      _id.text = formattaId(r.id);
                      _fuocoPw.requestFocus();
                    },
                    onLongPress: () => _togli(r),
                    child: Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: accentoChiaro, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.desktop_windows, color: accentoScuro),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.nome.isEmpty ? 'Computer' : r.nome,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(formattaId(r.id), style: TextStyle(color: testoTenue, fontSize: 13)),
                        ]),
                      ),
                      Pilla(_accesi[r.id] == true ? 'Acceso' : 'Spento', _accesi[r.id] == true ? verde : grigio400),
                    ]),
                  ),
                ),
              const SizedBox(height: 12),
              Text('Per farti aiutare, o per controllare questo computer da qui, apri tk-desk sul computer: '
                  'c\'è per Windows e Mac.', textAlign: TextAlign.center, style: TextStyle(color: testoTenue, fontSize: 12)),
            ]),
          ),
        ),
      ]),
    );
  }
}
