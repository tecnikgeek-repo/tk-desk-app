# tk-desk per Android e iPhone

Controlla PC e Mac dal telefono: scrivi l'ID e la password che vedi in tk-desk sul computer e lo comandi con
touchpad o tocco diretto, tastiera, più schermi, chat e incolla dal telefono. Tutte le funzioni sono gratis, per tutti
(anche l'accesso non presidiato con la password fissa).

- **Piattaforme:** Android (APK); iPhone in arrivo. Sul computer serve tk-desk per Windows o Mac:
  [tk-desk per computer](https://pietrodefilippis.it/software/).
- **Licenza:** software libero sotto [GNU AGPL-3.0](COPYING), fornito così com'è, senza alcuna garanzia.
- **Sicurezza:** non dare mai ID e password a chi ti chiama o ti scrive dicendo di essere un tecnico, la banca o la
  polizia. Usa tk-desk solo con persone che conosci.
- **Privacy:** i computer recenti restano sul telefono. Per collegarsi il telefono usa il centralino di
  pietrodefilippis.it (ID e nome del telefono, messaggi firmati), i server STUN di Google e, se il collegamento
  diretto non riesce, un ponte TURN di Cloudflare; schermo e comandi passano cifrati e il centralino non li vede.
  Le statistiche anonime (una volta al giorno: nome, versione, sistema e un codice casuale) partono solo se dici sì
  nel benvenuto o in Informazioni.

## Compilare dal sorgente

Serve [Flutter](https://flutter.dev) (versione indicata in `.github/workflows/android.yml`):

```
flutter pub get
flutter test
flutter build apk --release
```

Senza la variabile `ANDROID_KEYSTORE` l'APK si firma con la chiave di debug di Flutter.

Il nome «tk-desk» e il logo non sono coperti dalla licenza (AGPL sez. 7): una versione modificata deve avere un
nome diverso.

© 2026 Pietro De Filippis (TecnikGeek) — [pietrodefilippis.it](https://pietrodefilippis.it)
