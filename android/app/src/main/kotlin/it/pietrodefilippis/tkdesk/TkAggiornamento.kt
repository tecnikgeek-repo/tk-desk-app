package it.pietrodefilippis.tkdesk

// Controllo dell'aggiornamento scaricato da kit_tk.dart (canale «tk/aggiornamento»). FILE IDENTICO IN TUTTE LE
// APP TK, cambia solo la riga «package» (originale in Dropbox\CLAUDE\tk-software\librerie\TkAggiornamento.kt).
// Si installa solo un APK di QUESTA app (stesso pacchetto) firmato con lo stesso certificato: chi cambiasse il
// manifest sul sito o su Dropbox non può far proporre al telefono l'installazione di un'altra app.
// Copyright (C) 2026 Pietro De Filippis (TecnikGeek) — AGPL-3.0-or-later, vedi COPYING
import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

object TkAggiornamento {
    fun registra(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "tk/aggiornamento").setMethodCallHandler { call, result ->
            if (call.method == "verificaApk") {
                val percorso = call.argument<String>("percorso")
                result.success(percorso != null && try {
                    apkNostro(context, percorso)
                } catch (e: Exception) {
                    false
                })
            } else {
                result.notImplemented()
            }
        }
    }

    private fun apkNostro(context: Context, percorso: String): Boolean {
        val pm = context.packageManager
        val nuovo = archivio(pm, percorso) ?: return false
        if (nuovo.packageName != context.packageName) return false
        val attuali = impronte(installato(pm, context.packageName))
        val scaricato = impronte(nuovo)
        // certificati non leggibili su qualche telefono: decide Android, che non installa sopra
        // un aggiornamento dello stesso pacchetto con un'altra firma
        if (attuali.isEmpty() || scaricato.isEmpty()) return true
        return scaricato.any { it in attuali }
    }

    @Suppress("DEPRECATION")
    private fun opzioni() =
        if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES

    @Suppress("DEPRECATION")
    private fun archivio(pm: PackageManager, percorso: String): PackageInfo? = pm.getPackageArchiveInfo(percorso, opzioni())

    @Suppress("DEPRECATION")
    private fun installato(pm: PackageManager, nome: String): PackageInfo = pm.getPackageInfo(nome, opzioni())

    @Suppress("DEPRECATION")
    private fun impronte(p: PackageInfo): Set<String> {
        val firme: Array<Signature>? = if (Build.VERSION.SDK_INT >= 28) {
            p.signingInfo?.let { if (it.hasMultipleSigners()) it.apkContentsSigners else it.signingCertificateHistory }
        } else {
            p.signatures
        }
        return firme.orEmpty().map { firma ->
            MessageDigest.getInstance("SHA-256").digest(firma.toByteArray()).joinToString("") { "%02x".format(it) }
        }.toSet()
    }
}
