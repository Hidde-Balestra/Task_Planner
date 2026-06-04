package nl.hidde.taskplanner.task_planner

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONObject
import java.util.Calendar

class TaskToggleReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_TOGGLE = "nl.hidde.taskplanner.task_planner.TOGGLE_TASK"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_TOGGLE) return
        val taskId = intent.getStringExtra("task_id") ?: return

        try {
            toggleInFlutterPrefs(context, taskId)
        } catch (_: Exception) {}
        refreshWidget(context)
    }

    private fun toggleInFlutterPrefs(context: Context, taskId: String) {
        val cal = Calendar.getInstance()
        val dateKey =
            "${cal.get(Calendar.YEAR)}-${cal.get(Calendar.MONTH) + 1}-${cal.get(Calendar.DAY_OF_MONTH)}"

        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val taskStrings = FlutterPrefsHelper.readStringList(flutterPrefs, "flutter.tasks")
        if (taskStrings.isEmpty()) return

        val updated = taskStrings.map { jsonStr ->
            try {
                val obj = JSONObject(jsonStr)
                if (obj.optString("id") == taskId) {
                    val completedByDate = obj.optJSONObject("completedByDate") ?: JSONObject()
                    completedByDate.put(dateKey, !completedByDate.optBoolean(dateKey, false))
                    obj.put("completedByDate", completedByDate)
                    obj.toString()
                } else {
                    jsonStr
                }
            } catch (_: Exception) { jsonStr }
        }

        val editor = flutterPrefs.edit()
        FlutterPrefsHelper.writeStringList(editor, "flutter.tasks", updated)
        editor.apply()
    }

    private fun refreshWidget(context: Context) {
        TaskWidgetProvider.updateAllWidgets(context)
    }
}
