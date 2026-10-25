// tk_pro — benvenuto, statistiche col consenso e «Offrimi un caffè» delle app TK (Flutter),
// gemello di tk_licenza_qt.py dei software per computer.
//
// Copia IDENTICA in ogni app TK (lib/tk_pro.dart), accanto a tk_licenza.dart e kit_tk.dart. Originale in
// Dropbox\CLAUDE\tk-software\librerie\tk_pro.dart.
//
// Dal 2026-10-25 le app TK sono software libero (AGPL-3.0): tutte le funzioni per tutti, niente Pro.
// Il nome del file resta per non cambiare gli import delle app.
//
// Uso (in main, prima di runApp):
//   final lic = Licenza(slug: 'tk-pdf-app', versione: info.version);
//   await lic.carica();
//   proTk = ProTk(lic);
//   lic.avvia();                                   // il segnale parte solo col consenso
// Poi, dopo l'apertura della schermata principale:
//   await benvenutoTk(context);                    // una volta sola: AGPL, nessuna garanzia, privacy, statistiche
//   invitoCaffe(context);                          // discreto: al massimo una volta al mese
// Nelle Impostazioni (se l'app le ha): const InterruttoreStatistiche()
//
// Restano per compatibilità (non fanno più nulla): chiediPro (sempre vero), BottonePro e ProInformazioni
// (vuoti), apriPro, FunzionePro, ProTk(funzioni:, gratis:).
// Copyright (C) 2026 Pietro De Filippis (TecnikGeek) — AGPL-3.0-or-later, vedi COPYING

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'kit_tk.dart';
import 'tk_licenza.dart';

const proBlu = Color(0xFF3B82F6);
const proBluScuro = Color(0xFF2563EB);
const caffe = Color(0xFFF59E0B);
const caffeChiaro = Color(0xFFFBBF24);

const _primaVolta = Duration(seconds: 8);
const _ogni = Duration(days: 30); // non più di una volta al mese…
const _avviiMinimi = 10; // …e solo dopo almeno 10 aperture dall'ultima volta
const _dopoDono = Duration(days: 90); // chi ha premuto «Offrimi un caffè» non lo rivede per 3 mesi

/// Resta per compatibilità: le app non hanno più funzioni Pro.
class FunzionePro {
  const FunzionePro(this.icona, this.titolo, this.testo);
  final IconData icona;
  final String titolo;
  final String testo;
}

class ProTk {
  /// [funzioni] e [gratis] non contano più (restano per compatibilità).
  ProTk(this.lic, {this.funzioni = const [], this.gratis = const []});
  final Licenza lic;
  final List<FunzionePro> funzioni;
  final List<String> gratis;
}

/// Impostato in main dopo `lic.carica()`. Null = app senza licenza: niente benvenuto, statistiche né caffè.
ProTk? proTk;

/// Sempre falso: non c'è più il Pro.
bool get proVisibile => false;

/// Sempre falso: non ci sono più chiavi Pro.
bool get haDonato => false;

/// Testo secondario: grigio sul fondo chiaro, più chiaro sul fondo scuro (tk-tv, tk-foto) così si legge.
Color get testoTenue => configTk.scuro ? grigio300 : grigio500;

void _apri(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Resta per compatibilità: non apre più nulla.
Future<void> apriPro(BuildContext context) async {}

/// Resta per compatibilità: tutte le funzioni sono per tutti, risponde sempre sì.
Future<bool> chiediPro(BuildContext context, String funzione) async => true;

// ───────────────────────── pulsanti ─────────────────────────

class _BottoneColorato extends StatelessWidget {
  const _BottoneColorato({required this.testo, required this.fondo, this.onTap, this.icona, this.testoColore = bianco});
  final String testo;
  final Color fondo;
  final Color testoColore;
  final IconData? icona;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
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

/// Resta per compatibilità: vuoto (non c'è più il Pro).
class BottonePro extends StatelessWidget {
  const BottonePro({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// «Offrimi un caffè» ambra, uguale in tutte le app e in tutti i software.
class PulsanteCaffe extends StatelessWidget {
  const PulsanteCaffe({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = proTk;
    if (p == null) return const SizedBox.shrink();
    return _BottoneColorato(
      testo: 'Offrimi un caffè',
      icona: Icons.coffee,
      fondo: caffe,
      testoColore: const Color(0xFF1F2937),
      onTap: () {
        _apri(p.lic.donazione);
        onTap?.call();
      },
    );
  }
}

/// Resta per compatibilità: vuoto. Il caffè ora lo mette da sé la schermata Informazioni del kit.
class ProInformazioni extends StatelessWidget {
  const ProInformazioni({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ───────────────────────── statistiche (col consenso) ─────────────────────────

/// Interruttore con titolo e spiegazione, per la scheda Privacy di Informazioni e per le Impostazioni.
/// [scuro] = su fondo navy (di serie quello del tema dell'app).
class RigaInterruttore extends StatelessWidget {
  const RigaInterruttore(
      {super.key, required this.titolo, required this.valore, required this.onChanged, this.spiegazione, this.scuro});

  final String titolo;
  final String? spiegazione;
  final bool valore;
  final ValueChanged<bool>? onChanged;
  final bool? scuro;

  @override
  Widget build(BuildContext context) {
    final suScuro = scuro ?? configTk.scuro;
    final acc = configTk.accento;
    return Selezionabile(
      raggio: 10,
      onTap: onChanged == null ? null : () => onChanged!(!valore),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 6),
              Text(titolo,
                  style: TextStyle(color: suScuro ? bianco : navy, fontSize: 14.5, fontWeight: FontWeight.w700)),
              if (spiegazione != null && spiegazione!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(spiegazione!,
                    style: TextStyle(color: suScuro ? grigio300 : grigio500, fontSize: 12.5, height: 1.4)),
              ],
            ]),
          ),
          const SizedBox(width: 10),
          Switch(
            value: valore,
            onChanged: onChanged,
            thumbColor: const WidgetStatePropertyAll(bianco),
            trackColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected) ? acc : (suScuro ? navy3 : grigio300)),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ]),
      ),
    );
  }
}

/// «Invia statistiche anonime di utilizzo»: accende o spegne il segnale giornaliero (gemello di casella_statistiche).
class InterruttoreStatistiche extends StatefulWidget {
  const InterruttoreStatistiche({super.key, this.spiegazione = testoStatisticheBreve, this.scuro});

  final String spiegazione;
  final bool? scuro;

  @override
  State<InterruttoreStatistiche> createState() => _InterruttoreStatisticheState();
}

class _InterruttoreStatisticheState extends State<InterruttoreStatistiche> {
  @override
  Widget build(BuildContext context) {
    final lic = proTk?.lic;
    if (lic == null) return const SizedBox.shrink();
    return RigaInterruttore(
      titolo: 'Invia statistiche anonime di utilizzo',
      spiegazione: widget.spiegazione,
      valore: lic.consensoStatistiche == true,
      scuro: widget.scuro,
      onChanged: (v) async {
        await lic.impostaStatistiche(v);
        if (mounted) setState(() {});
      },
    );
  }
}

// ───────────────────────── benvenuto (primo avvio) ─────────────────────────

/// Da chiamare una volta dopo l'apertura della schermata principale, PRIMA di [invitoCaffe] e di ogni altra
/// chiamata in rete: la mostra solo al primo avvio. [righeExtra] = frasi in più dell'app (stessa scrittura di
/// [TestoConLink]: **grassetto** e [testo](indirizzo)).
Future<void> benvenutoTk(BuildContext context, {List<String> righeExtra = const []}) async {
  final lic = proTk?.lic;
  if (lic == null || lic.benvenutoVisto) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true, builder: (_) => SchermataBenvenuto(lic: lic, righeExtra: righeExtra)));
}

/// Prima apertura: software libero, nessuna garanzia, privacy e consenso alle statistiche (spento di default).
/// Uguale a BenvenutoDialog dei software. Anche uscendo col tasto indietro la scelta vale.
class SchermataBenvenuto extends StatefulWidget {
  const SchermataBenvenuto({super.key, required this.lic, this.righeExtra = const []});

  final Licenza lic;
  final List<String> righeExtra;

  @override
  State<SchermataBenvenuto> createState() => _SchermataBenvenutoState();
}

class _SchermataBenvenutoState extends State<SchermataBenvenuto> {
  bool _statistiche = false;
  bool _salvato = false;

  Future<void> _salva() async {
    if (_salvato) return;
    _salvato = true;
    await widget.lic.impostaStatistiche(_statistiche);
    await widget.lic.ricorda('benvenuto_agpl', true);
  }

  @override
  Widget build(BuildContext context) {
    final c = configTk;
    final sorgente = urlSorgente(widget.lic.versione);
    final righe = [
      '${c.nome} è **software libero e gratuito**, con tutte le funzioni, sotto licenza [GNU AGPL-3.0]($urlAgpl): '
          'puoi usarlo, studiarlo, modificarlo e condividerlo ([codice sorgente]($sorgente)).',
      "È fornito **così com'è, senza alcuna garanzia** (licenza, sezioni 15 e 16): tieni una copia dei tuoi file "
          'importanti.',
      ...widget.righeExtra,
      'I tuoi file e i tuoi dati restano su questo telefono. [Privacy]($urlPrivacy) · [Termini]($urlTermini)',
    ];
    final basso = MediaQuery.of(context).padding.bottom;
    return PopScope(
      onPopInvokedWithResult: (fatto, _) {
        if (fatto) _salva();
      },
      child: Scaffold(
        backgroundColor: navy,
        body: Column(children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(22, MediaQuery.of(context).padding.top + 28, 22, 16),
              children: [
                Row(children: [
                  const LogoTk(lato: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text('Benvenuto in ${c.nome}',
                        style: const TextStyle(color: bianco, fontSize: 23, fontWeight: FontWeight.w800, height: 1.2)),
                  ),
                ]),
                const SizedBox(height: 22),
                for (final r in righe) ...[
                  TestoConLink(r, stile: const TextStyle(color: grigio300, fontSize: 14.5, height: 1.5)),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 10, 14),
                  decoration: BoxDecoration(
                      color: navy2, borderRadius: BorderRadius.circular(14), border: Border.all(color: navy3)),
                  child: RigaInterruttore(
                    titolo: 'Invia statistiche anonime di utilizzo',
                    spiegazione: testoStatistiche,
                    valore: _statistiche,
                    scuro: true,
                    onChanged: (v) => setState(() => _statistiche = v),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(22, 4, 22, 18 + basso),
            child: BottoneTk(
                testo: 'Inizia', icona: Icons.arrow_forward, scuro: true, onTap: () => Navigator.of(context).pop()),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── invito al caffè ─────────────────────────

/// Da chiamare una volta dopo l'apertura della schermata principale (dopo [benvenutoTk]): l'invito compare al
/// primo avvio e poi al massimo una volta al mese (dopo almeno 10 aperture), mai dopo «Non mostrarlo più».
Future<void> invitoCaffe(BuildContext context, {bool Function()? puoMostrare}) async {
  final p = proTk;
  if (p == null) return;
  final lic = p.lic;
  final avvii = ((lic.ricordo('caffe_avvii', 0) as num?) ?? 0).toInt() + 1;
  await lic.ricorda('caffe_avvii', avvii);
  if (lic.ricordo('caffe_mai', false) == true || haDonato) return;
  final ora = DateTime.now().millisecondsSinceEpoch;
  final ultimo = ((lic.ricordo('caffe_ultimo', 0) as num?) ?? 0).toInt();
  final offerto = ((lic.ricordo('caffe_offerto', 0) as num?) ?? 0).toInt();
  if (ora - offerto < _dopoDono.inMilliseconds) return;
  if (ultimo > 0 && (ora - ultimo < _ogni.inMilliseconds || avvii < _avviiMinimi)) return;
  for (var tentativo = 0; tentativo < 20; tentativo++) {
    await Future<void>.delayed(tentativo == 0 ? _primaVolta : const Duration(minutes: 1));
    if (!context.mounted) return;
    final libero = ModalRoute.of(context)?.isCurrent ?? true;
    if (libero && (puoMostrare?.call() ?? true)) break;
    if (tentativo == 19) return;
  }
  if (!context.mounted) return;
  await lic.ricorda('caffe_ultimo', DateTime.now().millisecondsSinceEpoch);
  await lic.ricorda('caffe_avvii', 0);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (f) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: caffe.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.coffee, color: caffe, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Ti piace ${configTk.nome}?', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${configTk.nome} è gratis. Se ti è utile, offrimi un caffè: mi aiuta a migliorarlo e a crearne altri.',
                    style: TextStyle(color: testoTenue)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          PulsanteCaffe(onTap: () {
            lic.ricorda('caffe_offerto', DateTime.now().millisecondsSinceEpoch);
            Navigator.pop(f);
          }),
          const SizedBox(height: 8),
          Row(children: [
            TextButton(
                onPressed: () {
                  lic.ricorda('caffe_mai', true);
                  Navigator.pop(f);
                },
                child: Text('Non mostrarlo più', style: TextStyle(color: testoTenue))),
            const Spacer(),
            TextButton(
                onPressed: () => Navigator.pop(f),
                child: Text('Più tardi',
                    style: TextStyle(color: configTk.scuro ? bianco : navy, fontWeight: FontWeight.w600))),
          ]),
        ]),
      ),
    ),
  );
}
