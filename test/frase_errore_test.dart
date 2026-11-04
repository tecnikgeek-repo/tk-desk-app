// Mai il testo tecnico degli errori a schermo: solo frasi in italiano.
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:tkdesk/kit_tk.dart";

void main() {
  test("il testo tecnico non arriva mai alla frase", () {
    final frase = fraseErrore("Salvataggio non riuscito.", ArgumentError("object is unsendable"));
    expect(frase, startsWith("Salvataggio non riuscito."));
    expect(frase, isNot(contains("unsendable")));
    expect(frase, isNot(contains("Invalid")));
  });

  test("i messaggi scritti da noi passano, la rete ha la sua frase", () {
    expect(fraseErrore("Lista non caricata.", "link non valido"), "Lista non caricata. Link non valido");
    expect(motivoErrore(const SocketException("Failed host lookup")), contains("connessione"));
    expect(motivoErrore(const SocketException("Failed host lookup")), isNot(contains("host")));
  });
}
