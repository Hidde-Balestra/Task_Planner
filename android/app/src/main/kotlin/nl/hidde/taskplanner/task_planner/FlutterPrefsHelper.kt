package nl.hidde.taskplanner.task_planner

import android.content.SharedPreferences
import org.json.JSONArray

/**
 * Flutter's shared_preferences_android 2.x stores StringList as a single String
 * prefixed with a base64-encoded marker ("This is the prefix for a list.").
 * Older versions used StringSet. Both formats are handled here.
 */
object FlutterPrefsHelper {

    private const val LIST_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu"

    fun readStringList(prefs: SharedPreferences, key: String): List<String> {
        return when (val raw = prefs.all[key]) {
            is Set<*> -> raw.filterIsInstance<String>()          // pre-2.x fallback
            is String -> decodeFlutterList(raw)
            else -> emptyList()
        }
    }

    fun writeStringList(editor: SharedPreferences.Editor, key: String, list: List<String>) {
        editor.putString(key, LIST_PREFIX + JSONArray(list).toString())
    }

    private fun decodeFlutterList(encoded: String): List<String> {
        val jsonStr = if (encoded.startsWith(LIST_PREFIX))
            encoded.removePrefix(LIST_PREFIX) else encoded
        return try {
            val arr = JSONArray(jsonStr)
            (0 until arr.length()).map { arr.getString(it) }
        } catch (_: Exception) { emptyList() }
    }
}
