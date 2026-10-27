"""Controlla che le librerie native arm64 di un .aab siano allineate a pagine di memoria da 16 kB
(Play lo richiede per Android 15 e successivi). Uso: python3 tools/controlla_16kb.py app-release.aab"""
import struct
import sys
import zipfile

male = []
with zipfile.ZipFile(sys.argv[1]) as z:
    for nome in z.namelist():
        if not nome.endswith(".so") or "arm64" not in nome:
            continue
        d = z.read(nome)
        inizio = struct.unpack_from("<Q", d, 0x20)[0]
        passo, quanti = struct.unpack_from("<HH", d, 0x36)
        allineamenti = [struct.unpack_from("<Q", d, inizio + i * passo + 0x30)[0]
                        for i in range(quanti) if struct.unpack_from("<I", d, inizio + i * passo)[0] == 1]
        if min(allineamenti) < 0x4000:
            male.append(nome)
if male:
    sys.exit("::error::Librerie non allineate a 16 kB: " + ", ".join(male))
print("Librerie native allineate a 16 kB")
