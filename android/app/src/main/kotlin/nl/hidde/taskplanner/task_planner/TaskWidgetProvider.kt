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
                // Prevent "Can't load widget" by always pushing a valid RemoteViews
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
            // Access SharedPreferences directly — same file home_widget uses internally.
            val widgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val tasksJson = widgetData.getString("today_tasks", "[]") ?: "[]"
            val dateLabel = widgetData.getString("date_label", "Vandaag") ?: "Vandaag"

            val views = RemoteViews(context.packageName, R.layout.task_widget)
            views.setTextViewText(R.id.widget_date, dateLabel)

            val allTasks = try { JSONArray(tasksJson) } catch (_: Exception) { JSONArray() }
            val taskCount = allTasks.length()
            val visibleCount = minOf(taskCount, MAX_VISIBLE)

            val toggleFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            else
                PendingIntent.FLAG_UPDATE_CURRENT

            for (i in 0 until MAX_VISIBLE) {
                if (i < visibleCount) {
                    val task = allTasks.getJSONObject(i)
                    val taskId = task.optString("id")
                    val taskTitle = task.optString("title")
                    val completed = task.optBoolean("completed", false)

                    views.setViewVisibility(ROW_IDS[i], View.VISIBLE)
                    views.setTextViewText(TITLE_IDS[i], taskTitle)

                    if (completed) {
                        views.setImageViewResource(CHECK_IDS[i], R.drawable.widget_check_on)
                        views.setInt(TITLE_IDS[i], "setTextColor", 0xFFBDBDBD.toInt())
                    } else {
                        views.setImageViewResource(CHECK_IDS[i], R.drawable.widget_check_off)
                        views.setInt(TITLE_IDS[i], "setTextColor", 0xFF212121.toInt())
                    }

                    val toggleIntent = Intent(context, TaskToggleReceiver::class.java).apply {
                        action = TaskToggleReceiver.ACTION_TOGGLE
                        putExtra("task_id", taskId)
                    }
                    val pi = PendingIntent.getBroadcast(
                        context, appWidgetId * 10 + i, toggleIntent, toggleFlags
                    )
                    views.setOnClickPendingIntent(ROW_IDS[i], pi)
                } else {
                    views.setViewVisibility(ROW_IDS[i], View.GONE)
                }
            }

            if (visibleCount > 0) {
                views.setViewVisibility(R.id.widget_empty, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            }

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
    }
}
