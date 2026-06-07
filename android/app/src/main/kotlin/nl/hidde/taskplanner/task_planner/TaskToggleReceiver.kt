package nl.hidde.taskplanner.task_planner

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

class TaskToggleReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_TOGGLE = "nl.hidde.taskplanner.task_planner.TOGGLE_TASK"

        // Flutter's shared_preferences_android 2.x stores StringList as a String
        // prefixed with the base64 of "This is the prefix for a list."
        private const val FLUTTER_LIST_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_TOGGLE) return
        val taskId = intent.getStringExtra("task_id") ?: return

        try { toggleInWidgetPrefs(context, taskId) } catch (_: Exception) {}
        try { syncToFlutterTasks(context, taskId) } catch (_: Exception) {}
        TaskWidgetProvider.updateAllWidgets(context)
    }

    // Toggle the completed flag in flutter.today_tasks so the widget immediately reflects the change.
    private fun toggleInWidgetPrefs(context: Context, taskId: String) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val json = prefs.getString("flutter.today_tasks", "[]") ?: "[]"
        val arr = JSONArray(json)
        for (i in 0 until arr.length()) {
            val obj = arr.getJSONObject(i)
            if (obj.optString("id") == taskId) {
                obj.put("completed", !obj.optBoolean("completed", false))
                break
            }
        }
        prefs.edit().putString("flutter.today_tasks", arr.toString()).apply()
    }

    // Mirror the toggle into flutter.tasks so the app sees the change on resume (prefs.reload()).
    private fun syncToFlutterTasks(context: Context, taskId: String) {
        val cal = Calendar.getInstance()
        val dateKey = "${cal.get(Calendar.YEAR)}-${cal.get(Calendar.MONTH) + 1}-${cal.get(Calendar.DAY_OF_MONTH)}"

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        val raw = prefs.all["flutter.tasks"]
        val taskStrings: List<String> = when (raw) {
            is Set<*> -> raw.filterIsInstance<String>()
            is String -> {
                val jsonPart = if (raw.startsWith(FLUTTER_LIST_PREFIX))
                    raw.removePrefix(FLUTTER_LIST_PREFIX) else raw
                try {
                    JSONArray(jsonPart).let { arr -> (0 until arr.length()).map { arr.getString(it) } }
                } catch (_: Exception) { emptyList() }
            }
            else -> return
        }
        if (taskStrings.isEmpty()) return

        val updated = taskStrings.map { jsonStr ->
            try {
                val obj = JSONObject(jsonStr)
                if (obj.optString("id") == taskId) {
                    val cbd = obj.optJSONObject("completedByDate") ?: JSONObject()
                    cbd.put(dateKey, !cbd.optBoolean(dateKey, false))
                    obj.put("completedByDate", cbd)
                    obj.toString()
                } else jsonStr
            } catch (_: Exception) { jsonStr }
        }

        prefs.edit()
            .putString("flutter.tasks", FLUTTER_LIST_PREFIX + JSONArray(updated).toString())
            .apply()
    }
}
