// La chiave dalla password deve essere IDENTICA al programma per computer (tkdesk/centralino.py): valori calcolati là
// con ce.chiave2(). Se cambiano, telefono e computer non si capiscono più. SPAKE2: test/pake_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:tkdesk/centralino.dart';
import 'package:tkdesk/tema.dart';

String hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('chiave dalla monouso «123 456» come sul computer', () async {
    final k = await chiaveDa2('123 456', '987654321');
    expect(hex(k), '6dcb77b4f6cc2c5d2b116537ae500cbb07700c0b7a340114017a3006f0b099f8');
    expect(hex(await chiaveDa2('123456', '987654321')), hex(k));
  });

  test('chiave dalla password fissa come sul computer', () async {
    final k = await chiaveDa2('Ufficio-2026!', '987654321');
    expect(hex(k), 'c4a5038171ebfa5d732dfce5d8239e51e7716676989a9abf22f353fedc74c767');
  });

  test('monouso o fissa', () {
    expect(eFissa('123 456'), isFalse);
    expect(eFissa('Ufficio-2026!'), isTrue);
  });

  test('ID a gruppi di tre', () {
    expect(formattaId('123456789'), '123 456 789');
    expect(pulisciId('123 456 789'), '123456789');
    expect(pulisciId('12345'), '');
  });
}
