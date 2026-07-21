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
import java.io.InputStream
import java.security.MessageDigest

/**
 * A narrow, local-only Gemma adapter for the proof of concept.
 *
 * The model is allowed to classify a spoken request only. Dart validates the
 * returned values again before it offers a user-confirmed app action.
 */
class GemmaCommandEngine(private val context: Context) : Closeable {
    companion object {
        const val defaultModelId = "e2b"

        private val modelSpecs = mapOf(
            "e2b" to GemmaModelSpec(
                id = "e2b",
                displayName = "Gemma 4 E2B",
                fileName = "gemma-4-E2B-it.litertlm",
                downloadUrl = "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm?download=true",
                expectedBytes = 2588147712L,
                sha256 = "181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c",
                requiredFreeBytes = 6L * 1024 * 1024 * 1024,
            ),
            "e4b" to GemmaModelSpec(
                id = "e4b",
                displayName = "Gemma 4 E4B",
                fileName = "gemma-4-E4B-it.litertlm",
                downloadUrl = "https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm?download=true",
                expectedBytes = 3659530240L,
                sha256 = "0b2a8980ce155fd97673d8e820b4d29d9c7d99b8fa6806f425d969b145bd52e0",
                requiredFreeBytes = 10L * 1024 * 1024 * 1024,
            ),
        )

        fun expectedFileName(modelId: String): String? = modelSpecs[modelId]?.fileName

        fun modelSpec(modelId: String): GemmaModelSpec? = modelSpecs[modelId]

        private const val systemInstruction = """
            You interpret spoken commands for a local household app.
            Return exactly one JSON object and nothing else. Never include markdown.
            Allowed actions: add_grocery, open_grocery, add_contact, open_stores, open_contacts, add_store, update_store_whatsapp, unknown.
            For add_grocery use action, store, item, quantity, unit.
            Quantity is an optional number. Unit must be count, dozen, kg, or litre.
            Put only the grocery name in item; do not include its quantity or unit.
            For open_grocery use action, store (or an empty string for all lists).
            For open_contacts and open_stores, action alone is enough.
            Example: "show me contacts" must return {"action":"open_contacts"}.
            For add_contact use action, name, phoneNumber.
            For add_store use action, name, whatsAppNumber.
            For updating an existing store's WhatsApp number use action update_store_whatsapp, store, whatsAppNumber.
            For unknown, action alone is enough.
            Do not propose payment, messaging, deletion, or any action outside this list.
        """
    }

    private val lock = Any()
    private var engine: Engine? = null
    private var loadedModelPath: String? = null

    fun status(): Map<String, Any> {
        val activeSpec = activeModelSpec()
        val displaySpec = activeSpec ?: modelSpecs.getValue(defaultModelId)
        val file = modelFile(displaySpec)
        return mapOf(
            "ready" to (activeSpec != null),
            "modelPath" to file.absolutePath,
            "modelId" to displaySpec.id,
            "modelDisplayName" to displaySpec.displayName,
            "modelFileName" to displaySpec.fileName,
            "sizeBytes" to if (file.isFile) file.length() else 0L,
        )
    }

    /** Copies the selected LiteRT-LM file into the app-owned model directory. */
    fun installModel(modelId: String, sourceName: String, source: InputStream): Map<String, Any> {
        val selectedSpec = modelSpecs[modelId]
            ?: throw IllegalArgumentException("Choose a supported Gemma model.")
        require(sourceName == selectedSpec.fileName) {
            "Choose the ${selectedSpec.fileName} model file."
        }

        val target = modelFile(selectedSpec)
        val temporary = File(target.parentFile, "${target.name}.part")
        temporary.delete()
        try {
            temporary.outputStream().use { output -> source.copyTo(output) }
            require(temporary.length() >= 100L * 1024 * 1024) {
                "That file is too small to be the Gemma model. Download it again and choose ${selectedSpec.fileName}."
            }

            synchronized(lock) {
                engine?.close()
                engine = null
                loadedModelPath = null
            }
            replaceModelFile(temporary, target)
            modelSpecs.values
                .filter { it.id != selectedSpec.id }
                .forEach { modelFile(it).delete() }
            preferences().edit().putString("active_model_id", selectedSpec.id).apply()
            return status()
        } catch (exception: Exception) {
            temporary.delete()
            throw exception
        }
    }

    fun installDownloadedModel(modelId: String, downloadedFile: File): Map<String, Any> {
        val selectedSpec = modelSpecs[modelId]
            ?: throw IllegalArgumentException("Choose a supported Gemma model.")
        require(downloadedFile.isFile) { "The Gemma download could not be found. Download it again." }
        require(downloadedFile.length() == selectedSpec.expectedBytes) {
            "The Gemma download is incomplete. Download it again."
        }
        require(sha256(downloadedFile).equals(selectedSpec.sha256, ignoreCase = true)) {
            "The downloaded Gemma file could not be verified. Download it again."
        }
        return downloadedFile.inputStream().use { input ->
            installModel(modelId, selectedSpec.fileName, input)
        }
    }

    fun interpret(transcript: String, storeNames: List<String>): Map<String, Any> {
        require(transcript.isNotBlank()) { "Say or type a command first." }
        val selectedSpec = activeModelSpec()
            ?: throw ModelUnavailableException("A Gemma model has not been installed on this device.")
        val model = modelFile(selectedSpec)

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
        if (action !in setOf("add_grocery", "open_grocery", "add_contact", "open_stores", "open_contacts", "add_store", "update_store_whatsapp", "unknown")) {
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

    private fun activeModelSpec(): GemmaModelSpec? {
        val selectedId = preferences().getString("active_model_id", null)
        modelSpecs[selectedId]?.let { selected ->
            if (modelFile(selected).isFile) return selected
        }
        // Existing E2B installs pre-date the active-model preference.
        return modelSpecs.values.firstOrNull { modelFile(it).isFile }
    }

    private fun preferences() = context.getSharedPreferences("gemma_model", Context.MODE_PRIVATE)

    private fun modelFile(spec: GemmaModelSpec): File {
        val directory = context.getExternalFilesDir("models") ?: File(context.filesDir, "models")
        directory.mkdirs()
        return File(directory, spec.fileName)
    }

    private fun replaceModelFile(temporary: File, target: File) {
        val backup = File(target.parentFile, "${target.name}.previous")
        backup.delete()
        val hadExistingModel = target.exists()
        if (hadExistingModel && !target.renameTo(backup)) {
            throw IllegalStateException("Gruhasthi could not replace the existing Gemma model.")
        }
        if (!temporary.renameTo(target)) {
            if (hadExistingModel) backup.renameTo(target)
            throw IllegalStateException("Gruhasthi could not save the selected Gemma model.")
        }
        backup.delete()
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().buffered().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString(separator = "") { "%02x".format(it.toInt() and 0xff) }
    }

    private fun extractJson(value: String): String {
        val first = value.indexOf('{')
        val last = value.lastIndexOf('}')
        if (first < 0 || last <= first) throw IllegalArgumentException("Gemma did not return a command.")
        return value.substring(first, last + 1)
    }
}

data class GemmaModelSpec(
    val id: String,
    val displayName: String,
    val fileName: String,
    val downloadUrl: String,
    val expectedBytes: Long,
    val sha256: String,
    val requiredFreeBytes: Long,
)

class ModelUnavailableException(message: String) : IllegalStateException(message)
