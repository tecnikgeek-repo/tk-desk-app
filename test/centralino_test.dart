// La chiave dalla password e la firma devono essere IDENTICHE al programma per computer (tkdesk/centralino.py):
// valori calcolati là con ce.chiave() e ce.firma(). Se cambiano, telefono e computer non si capiscono più.
import 'package:flutter_test/flutter_test.dart';
import 'package:tkdesk/centralino.dart';
import 'package:tkdesk/tema.dart';

String hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('chiave dalla monouso «123 456» come sul computer', () async {
    final k = await chiaveDa('123 456', '987654321');
    expect(hex(k), '784acf6ecf317f3ed1df5f9d68452f83e524398d5532acee41e2cba84a0bbcec');
    expect(hex(await chiaveDa('123456', '987654321')), hex(k));
  });

  test('chiave dalla password fissa come sul computer', () async {
    final k = await chiaveDa('Ufficio-2026!', '987654321');
    expect(hex(k), '9957290d0ee60136f836ed0465c649aa4dde8c02eecc25c414cad36100a360d1');
  });

  test('firma della chiamata come sul computer', () async {
    final k = await chiaveDa('123 456', '987654321');
    final f = await firma(k, 'chiamata', '111222333', '987654321', 'abcd', 'v=0\r\nsdp');
    expect(f, '8c326c54664a6174a52ad30b0d983c2b039b4f38cc27493adc2d6576f12ad055');
    expect(await firmaValida(k, 'chiamata', '111222333', '987654321', 'abcd', 'v=0\r\nsdp', f), isTrue);
    expect(await firmaValida(k, 'chiamata', '111222333', '987654321', 'abcd', 'v=0\r\nsdp-cambiato', f), isFalse);
  });

  test('chiave nuova (600.000 giri) e firma come tk-desk 1.1.0 per computer', () async {
    final k = await chiaveDa2('123 456', '987654321');
    expect(hex(k), '6dcb77b4f6cc2c5d2b116537ae500cbb07700c0b7a340114017a3006f0b099f8');
    expect(await firma(k, 'chiamata', '111222333', '987654321', 'abcd', 'v=0\r\nsdp'),
        'd1622c1a70922a8aff2d76341e43236a25487bd2e01903780da5e1416a28363d');
  });

  test('ID a gruppi di tre', () {
    expect(formattaId('123456789'), '123 456 789');
    expect(pulisciId('123 456 789'), '123456789');
    expect(pulisciId('12345'), '');
  });
}
