"""Icone dell'app, identiche al programma per computer (tkdesk.kit.render_icon).
Uso (col Python del progetto per computer, che ha PySide6):
  C:\\dev\\venv-tkdesk\\Scripts\\python.exe tools/genera_icona.py
Crea assets/icona.png (1024, completa) e assets/icona-adattiva.png (schermo e freccia al centro, fondo trasparente)."""
import os
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
QUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.expanduser("~"), "Dropbox", "CLAUDE", "dev", "tk-desk"))

from PySide6.QtCore import QRectF, Qt  # noqa: E402
from PySide6.QtGui import QImage, QPainter  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402

app = QApplication(sys.argv)
from tkdesk.kit import render_icon  # noqa: E402

render_icon(1024).save(os.path.join(QUI, "assets", "icona.png"))

# adattiva: Android ritaglia un cerchio/ovale al centro (zona sicura ~66%) e mette lui il fondo navy:
# si disegna l'icona intera ridotta al 66% e si toglie il quadrato navy (resta solo schermo e freccia)
size = 1024
piccola = render_icon(int(size * .66)).toImage()
img = QImage(size, size, QImage.Format.Format_ARGB32)
img.fill(Qt.GlobalColor.transparent)
p = QPainter(img)
p.drawImage(QRectF(size * .17, size * .17, size * .66, size * .66), piccola)
p.end()
# il fondo navy dell'icona (#0F172A/#1E293B) diventa trasparente: resta il disegno bianco e verde
for y in range(size):
    for x in range(size):
        c = img.pixelColor(x, y)
        if c.alpha() and c.red() < 45 and c.green() < 55 and c.blue() < 70 and abs(c.blue() - c.red()) > 20:
            c.setAlpha(0)
            img.setPixelColor(x, y, c)
img.save(os.path.join(QUI, "assets", "icona-adattiva.png"))
print("icone generate")
