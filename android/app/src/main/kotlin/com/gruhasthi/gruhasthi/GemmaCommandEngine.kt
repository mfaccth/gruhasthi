package com.gruhasthi.gruhasthi

import android.content.Context
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.SamplerConfig
import org.json.JSONObject
import java.io.Closeable
import java.io.File

/**
 * A narrow, local-only Gemma adapter for the proof of concept.
 *
 * The model is allowed to classify a spoken request only. Dart validates the
 * returned values again before it offers a user-confirmed app action.
 */
class GemmaCommandEngine(private val context: Context) : Closeable {
    companion object {
        const val modelFileName = "gemma-4-E2B-it.litertlm"

        private const val systemInstruction = """
            You interpret spoken commands for a local household app.
            Return exactly one JSON object and nothing else. Never include markdown.
            Allowed actions: add_grocery, open_grocery, add_contact, open_stores, add_store, unknown.
            For add_grocery use action, store, item, quantity, unit.
            Quantity is an optional number. Unit must be count, dozen, kg, or litre.
            Put only the grocery name in item; do not include its quantity or unit.
            For open_grocery use action, store (or an empty string for all lists).
            For add_contact use action, name, phoneNumber.
            For add_store use action, name, whatsAppNumber.
            For open_stores and unknown, action alone is enough.
            Do not propose payment, messaging, deletion, or any action outside this list.
        """
    }

    private val lock = Any()
    private var engine: Engine? = null
    private var loadedModelPath: String? = null

    fun status(): Map<String, Any> {
        val file = modelFile()
        return mapOf(
            "ready" to file.isFile,
            "modelPath" to file.absolutePath,
            "modelFileName" to modelFileName,
            "sizeBytes" to if (file.isFile) file.length() else 0L,
        )
    }

    fun interpret(transcript: String, storeNames: List<String>): Map<String, Any> {
        require(transcript.isNotBlank()) { "Say or type a command first." }
        val model = modelFile()
        if (!model.isFile) {
            throw ModelUnavailableException("Gemma 4 E2B has not been installed on this device.")
        }

        val prompt = buildString {
            appendLine("Known stores: ${storeNames.joinToString(", ")}")
            appendLine("Transcript: $transcript")
        }
        val startedAt = System.nanoTime()
        val response = engineFor(model).createConversation(
            ConversationConfig(
                systemInstruction = Contents.of(systemInstruction.trimIndent()),
                samplerConfig = SamplerConfig(
                    topK = 1,
                    topP = 1.0,
                    temperature = 0.0,
                    seed = 42,
                ),
            ),
        ).use { conversation ->
            conversation.sendMessage(prompt)
        }
        val responseText = response.contents.contents
            .filterIsInstance<Content.Text>()
            .joinToString(separator = "") { it.text }
        val parsed = JSONObject(extractJson(responseText))
        val action = parsed.optString("action").trim()
        if (action !in setOf("add_grocery", "open_grocery", "add_contact", "open_stores", "add_store", "unknown")) {
            throw IllegalArgumentException("Gemma returned an unsupported action.")
        }

        return mapOf(
            "action" to action,
            "store" to parsed.optString("store").trim(),
            "item" to parsed.optString("item").trim(),
            "quantity" to parsed.optString("quantity").trim(),
            "unit" to parsed.optString("unit").trim(),
            "name" to parsed.optString("name").trim(),
            "phoneNumber" to parsed.optString("phoneNumber").trim(),
            "whatsAppNumber" to parsed.optString("whatsAppNumber").trim(),
            "elapsedMs" to ((System.nanoTime() - startedAt) / 1_000_000),
        )
    }

    override fun close() {
        synchronized(lock) {
            engine?.close()
            engine = null
            loadedModelPath = null
        }
    }

    private fun engineFor(model: File): Engine = synchronized(lock) {
        if (engine != null && loadedModelPath == model.absolutePath) return@synchronized engine!!
        engine?.close()
        return@synchronized Engine(
            EngineConfig(
                modelPath = model.absolutePath,
                backend = Backend.CPU(),
                cacheDir = context.cacheDir.absolutePath,
            ),
        ).also {
            it.initialize()
            engine = it
            loadedModelPath = model.absolutePath
        }
    }

    private fun modelFile(): File {
        val directory = context.getExternalFilesDir("models") ?: File(context.filesDir, "models")
        directory.mkdirs()
        return File(directory, modelFileName)
    }

    private fun extractJson(value: String): String {
        val first = value.indexOf('{')
        val last = value.lastIndexOf('}')
        if (first < 0 || last <= first) throw IllegalArgumentException("Gemma did not return a command.")
        return value.substring(first, last + 1)
    }
}

class ModelUnavailableException(message: String) : IllegalStateException(message)
