// SPAKE2 deve dare gli STESSI numeri del programma per computer (tkdesk/pake.py): vettore calcolato là
// (tests/test_core.py, prova «SPAKE2»). Se cambiano, telefono e computer non si collegano più.
import 'package:flutter_test/flutter_test.dart';
import 'package:tkdesk/pake.dart';

List<int> byte(int n) => List<int>.generate(n, (i) => i);

void main() {
  test('M e N nel sottogruppo giusto', () {
    for (final p in [puntoM, puntoN, g]) {
      expect(codifica(perScalare(ordine, p)).map((x) => x.toRadixString(16).padLeft(2, '0')).join(), identitaHex());
    }
  });

  test('vettore fisso come sul computer', () async {
    final a = Spake2('A', '123456789', '987654321', byte(32), casuale: BigInt.parse('12345678901234567890'));
    final b = Spake2('B', '123456789', '987654321', byte(32), casuale: BigInt.parse('98765432109876543210'));
    expect(a.messaggio(), '36248fd005296495ec44d9654840d38ece44021cea09da2555a25d15fc8709de');
    expect(b.messaggio(), '8449501d946aa2017d41ccb4592503954e71b3d7bbc61f5d64fa16324581ecaf');
    await b.finisci(a.messaggio());
    await a.finisci(b.messaggio());
    expect(a.conferma(), 'e926a04f139cced74a28e3999bb2e582e30dff4dd7f5a7dfed12bebe23a21a61');
    expect(b.conferma(), '3e921e9b95e97770690626bab3f61694f4b4a803ade611af414e8f75c01a751b');
    expect(await a.sigilla('offerta', 'ciao è'), 'a41499441380f89e352e03863404992b0322c6f16c6df4b1020496217137c313');
    expect(a.confermaValida(b.conferma()), isTrue);
    expect(b.confermaValida(a.conferma()), isTrue);
    expect(await b.sigilloValido('offerta', 'ciao è', await a.sigilla('offerta', 'ciao è')), isTrue);
    expect(await b.sigilloValido('offerta', 'ciao e', await a.sigilla('offerta', 'ciao è')), isFalse);
  });

  test('password sbagliata: le conferme non tornano', () async {
    final a = Spake2('A', '1', '2', byte(32));
    final b = Spake2('B', '1', '2', List<int>.filled(32, 7));
    await b.finisci(a.messaggio());
    await a.finisci(b.messaggio());
    expect(a.confermaValida(b.conferma()), isFalse);
    expect(b.confermaValida(a.conferma()), isFalse);
  });

  test('messaggi storti rifiutati', () async {
    for (final storto in ['zz', 'ff' * 32, '00' * 32]) {
      await expectLater(Spake2('A', '1', '2', byte(32)).finisci(storto), throwsA(isA<ErrorePake>()));
    }
    final a = Spake2('A', '1', '2', byte(32));
    await expectLater(a.finisci(a.messaggio()), throwsA(isA<ErrorePake>()));
  });
}
