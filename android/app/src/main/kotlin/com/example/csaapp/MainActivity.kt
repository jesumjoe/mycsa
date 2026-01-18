package com.example.csaapp

import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.MifareClassic
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
// import io.flutter.plugin.common.EventChannel
import java.io.IOException
import kotlin.experimental.and


class MainActivity : FlutterActivity() {
    // This channel is for transmitting NFC data
    private val CHANNEL = "com.example.csaapp/nfc_events"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Setup the MethodChannel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // If activity was launched with an NFC intent while app was closed
        intent?.let { handleNfcIntent(it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Called when an NFC tag is discovered while app is in foreground (singleTop)
        handleNfcIntent(intent)
    }

    private fun handleNfcIntent(intent: Intent) {
        val action = intent.action ?: return
        if (action == NfcAdapter.ACTION_TAG_DISCOVERED ||
                action == NfcAdapter.ACTION_TECH_DISCOVERED ||
                action == NfcAdapter.ACTION_NDEF_DISCOVERED
        ) {
            val tag: Tag? = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
            tag?.let { readMifareClassic(it) }
        }
    }

    private fun readMifareClassic(tag: Tag) {
        var mifare: MifareClassic? = null
        try {
            mifare = MifareClassic.get(tag)
            if (mifare == null) {
                invokeDart("ERR: Not Mifare")
                return
            }

            mifare.connect()
            val sectors = mifare.sectorCount
            val sbRaw = StringBuilder()
            var found7Digit: String? = null

            // Keys to try
            val keyFFF = byteArrayOf(0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte())
            val keyDefault = MifareClassic.KEY_DEFAULT
            
            // Iterate all sectors
            for (i in 0 until sectors) {
                // Try auth with F...F
                var auth = false
                try { 
                    auth = mifare.authenticateSectorWithKeyA(i, keyFFF) 
                } catch (e: Exception) {}

                // If failed, try Default
                if (!auth) {
                    try { 
                        auth = mifare.authenticateSectorWithKeyA(i, keyDefault) 
                    } catch (e: Exception) {}
                }

                if (auth) {
                    val firstBlock = mifare.sectorToBlock(i)
                    val blockCount = mifare.getBlockCountInSector(i)
                    for (j in 0 until blockCount) {
                        try {
                            val data = mifare.readBlock(firstBlock + j)
                            val s = bytesToPrintableString(data)
                            if (s.isNotBlank()) {
                                sbRaw.append(s).append(" ") // Collect raw data
                                
                                // Check for 7 digits
                                val match = Regex("""\d{7}""").find(s)
                                if (match != null) {
                                    found7Digit = match.value
                                    // Don't break immediately, might be noise. But 7 digits is specific enough.
                                    break 
                                }
                            }
                        } catch (e: Exception) {}
                    }
                }
                if (found7Digit != null) break
            }

            if (found7Digit != null) {
                invokeDart(found7Digit)
            } else {
                // If we found ANY text, show it for debugging
                val raw = sbRaw.toString().trim()
                if (raw.isNotEmpty()) {
                     // Limit length to avoid crashing Channel
                    val safeRaw = if (raw.length > 200) raw.take(200) + "..." else raw
                    invokeDart("RAW: $safeRaw")
                } else {
                    // Fallback to UID
                    invokeDart("UID: ${bytesToHex(tag.id)}")
                }
            }
        } catch (e: Exception) {
            invokeDart("ERR: ${e.message}")
        } finally {
            try { mifare?.close() } catch (_: Exception) {}
        }
    }

    private fun invokeDart(value: String) {
        // --- 5. MODIFIED this function ---
        // Send the scanned string back to Flutter via MethodChannel
        methodChannel?.invokeMethod("nfcData", value)
    }

    private fun bytesToHex(bytes: ByteArray?): String {
        if (bytes == null) return ""
        val sb = StringBuilder()
        for (b in bytes) {
            sb.append(String.format("%02X", b))
        }
        return sb.toString()
    }

    private fun bytesToPrintableString(bytes: ByteArray): String {
        // convert bytes to ASCII where possible, replace non-printable with '.'
        val sb = StringBuilder()
        for (b in bytes) {
            val ch = b.toInt() and 0xFF
            if (ch in 32..126) { // printable ASCII range
                sb.append(ch.toChar())
            } else {
                // try to treat as BCD-like digits: if 0x30..0x39 (ASCII digits) handled above.
                // else append placeholder
                sb.append('.')
            }
        }
        return sb.toString()
    }
}