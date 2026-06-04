package nl.hidde.taskplanner.task_planner

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

class TaskToggleReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_TOGGLE = "nl.hidde.taskplanner.task_planner.TOGGLE_TASK"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_TOGGLE) return
        val taskId = intent.getStringExtra("task_id") ?: return

        toggleInWidgetPrefs(context, taskId)
        toggleInFlutterPrefs(context, taskId)
        refreshWidget(context)
    }

    private fun toggleInWidgetPrefs(context: Context, taskId: String) {
        val prefs = HomeWidgetPlugin.getData(context)
        val json = prefs.getString("today_tasks", "[]") ?: "[]"
        try {
            val arr = JSONArray(json)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                if (obj.optString("id") == taskId) {
                    obj.put("completed", !obj.optBoolean("completed", false))
                    break
                }
            }
            prefs.edit().putString("today_tasks", arr.toString()).apply()
        } catch (_: Exception) {}
    }

    private fun toggleInFlutterPrefs(context: Context, taskId: String) {
        val cal = Calendar.getInstance()
        // Date key format matches Task._dateKey() in Dart: "yyyy-M-d" (no zero padding)
        val dateKey =
            "${cal.get(Calendar.YEAR)}-${cal.get(Calendar.MONTH) + 1}-${cal.get(Calendar.DAY_OF_MONTH)}"

        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val tasksSet = flutterPrefs.getStringSet("flutter.tasks", null) ?: return

        val updated = mutableSetOf<String>()
        for (taskJson in tasksSet) {
            try {
                val obj = JSONObject(taskJson)
                if (obj.optString("id") == taskId) {
                    val completedByDate = obj.optJSONObject("completedByDate") ?: JSONObject()
                    completedByDate.put(dateKey, !completedByDate.optBoolean(dateKey, false))
                    obj.put("completedByDate", completedByDate)
                    updated.add(obj.toString())
                } else {
                    updated.add(taskJson)
                }
            } catch (_: Exception) {
                updated.add(taskJson)
            }
        }
        // New HashSet reference to avoid the Android SharedPreferences StringSet mutation bug
        flutterPrefs.edit().putStringSet("flutter.tasks", HashSet(updated)).apply()
    }

    private fun refreshWidget(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        TaskWidgetProvider.updateAllWidgets(context)
        val ids = manager.getAppWidgetIds(
            android.content.ComponentName(context, TaskWidgetProvider::class.java)
        )
        if (ids.isNotEmpty()) {
            manager.notifyAppWidgetViewDataChanged(ids, R.id.widget_list)
        }
    }
}
