package nl.hidde.taskplanner.task_planner

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class TaskWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            try {
                updateWidget(context, appWidgetManager, id)
            } catch (e: Throwable) {
                android.util.Log.e("TaskWidget", "onUpdate failed for id=$id", e)
                // Always push a valid RemoteViews so Android never shows "Can't load widget"
                try {
                    appWidgetManager.updateAppWidget(
                        id, RemoteViews(context.packageName, R.layout.task_widget)
                    )
                } catch (_: Throwable) {}
            }
        }
    }

    companion object {
        private const val MAX_VISIBLE = 5

        private val ROW_IDS = intArrayOf(
            R.id.task_row_0, R.id.task_row_1, R.id.task_row_2,
            R.id.task_row_3, R.id.task_row_4
        )
        private val CHECK_IDS = intArrayOf(
            R.id.task_check_0, R.id.task_check_1, R.id.task_check_2,
            R.id.task_check_3, R.id.task_check_4
        )
        private val TITLE_IDS = intArrayOf(
            R.id.task_title_0, R.id.task_title_1, R.id.task_title_2,
            R.id.task_title_3, R.id.task_title_4
        )

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, TaskWidgetProvider::class.java)
            )
            for (id in ids) {
                try {
                    updateWidget(context, manager, id)
                } catch (e: Throwable) {
                    android.util.Log.e("TaskWidget", "updateAllWidgets failed for id=$id", e)
                }
            }
        }

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val today = Calendar.getInstance()
            val tasks = loadTodayTasks(context, today)
            val dateLabel = SimpleDateFormat("d MMM", Locale("nl", "NL")).format(today.time)

            val views = RemoteViews(context.packageName, R.layout.task_widget)
            views.setTextViewText(R.id.widget_date, dateLabel)

            val taskCount = tasks.size
            val visibleCount = minOf(taskCount, MAX_VISIBLE)

            val toggleFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            else
                PendingIntent.FLAG_UPDATE_CURRENT

            for (i in 0 until MAX_VISIBLE) {
                if (i < visibleCount) {
                    val task = tasks[i]
                    views.setViewVisibility(ROW_IDS[i], View.VISIBLE)
                    views.setTextViewText(TITLE_IDS[i], task.getString("title"))

                    if (task.optBoolean("completed", false)) {
                        views.setImageViewResource(CHECK_IDS[i], R.drawable.widget_check_on)
                        views.setInt(TITLE_IDS[i], "setTextColor", 0xFFBDBDBD.toInt())
                    } else {
                        views.setImageViewResource(CHECK_IDS[i], R.drawable.widget_check_off)
                        views.setInt(TITLE_IDS[i], "setTextColor", 0xFF212121.toInt())
                    }

                    val toggleIntent = Intent(context, TaskToggleReceiver::class.java).apply {
                        action = TaskToggleReceiver.ACTION_TOGGLE
                        putExtra("task_id", task.optString("id"))
                    }
                    val pi = PendingIntent.getBroadcast(
                        context, appWidgetId * 10 + i, toggleIntent, toggleFlags
                    )
                    views.setOnClickPendingIntent(ROW_IDS[i], pi)
                } else {
                    views.setViewVisibility(ROW_IDS[i], View.GONE)
                }
            }

            views.setViewVisibility(
                R.id.widget_empty,
                if (visibleCount > 0) View.GONE else View.VISIBLE
            )

            if (taskCount > MAX_VISIBLE) {
                views.setViewVisibility(R.id.widget_more, View.VISIBLE)
                views.setTextViewText(R.id.widget_more, "+${taskCount - MAX_VISIBLE} meer taken")
            } else {
                views.setViewVisibility(R.id.widget_more, View.GONE)
            }

            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            else
                PendingIntent.FLAG_UPDATE_CURRENT
            val openPi = PendingIntent.getActivity(context, appWidgetId, openIntent, openFlags)
            views.setOnClickPendingIntent(R.id.widget_open_app, openPi)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        // Reads today's tasks straight from Flutter's SharedPreferences.
        // This works without the app ever having called HomeWidget.saveWidgetData().
        private fun loadTodayTasks(context: Context, today: Calendar): List<JSONObject> {
            val year = today.get(Calendar.YEAR)
            val month = today.get(Calendar.MONTH) + 1   // Calendar is 0-based
            val day = today.get(Calendar.DAY_OF_MONTH)
            val dateKey = "$year-$month-$day"

            // Dart: Mon=1..Sat=6, Sun=0  (DateTime.weekday % 7)
            // Java Calendar: Sun=1, Mon=2..Sat=7  → (javaDay - 1) % 7
            val dartWeekday = (today.get(Calendar.DAY_OF_WEEK) - 1) % 7

            val flutterPrefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE
            )
            val rawSet = flutterPrefs.getStringSet("flutter.tasks", null) ?: return emptyList()

            val result = mutableListOf<JSONObject>()
            for (jsonStr in rawSet) {
                try {
                    val obj = JSONObject(jsonStr)
                    val repeatDays = obj.optJSONArray("repeatDays")
                    val showToday = if (repeatDays != null && repeatDays.length() > 0) {
                        (0 until repeatDays.length()).any { repeatDays.getInt(it) == dartWeekday }
                    } else {
                        // One-time task: compare creation date
                        val iso = obj.optString("creationDate")
                        val datePart = iso.substringBefore("T")
                        val parts = datePart.split("-")
                        parts.size == 3 &&
                            parts[0].toIntOrNull() == year &&
                            parts[1].toIntOrNull() == month &&
                            parts[2].toIntOrNull() == day
                    }

                    if (showToday) {
                        val completed = obj.optJSONObject("completedByDate")
                            ?.optBoolean(dateKey, false) ?: false
                        result.add(
                            JSONObject().apply {
                                put("id", obj.optString("id"))
                                put("title", obj.optString("title"))
                                put("completed", completed)
                            }
                        )
                    }
                } catch (_: Exception) {}
            }
            return result
        }
    }
}
