package nl.hidde.taskplanner.task_planner

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class TaskWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    companion object {
        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, TaskWidgetProvider::class.java)
            )
            for (id in ids) {
                updateWidget(context, manager, id)
            }
            if (ids.isNotEmpty()) {
                manager.notifyAppWidgetViewDataChanged(ids, R.id.widget_list)
            }
        }

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val tasksJson = widgetData.getString("today_tasks", "[]") ?: "[]"
            val dateLabel = widgetData.getString("date_label", "Vandaag") ?: "Vandaag"

            val views = RemoteViews(context.packageName, R.layout.task_widget)
            views.setTextViewText(R.id.widget_date, dateLabel)

            val taskCount = try { JSONArray(tasksJson).length() } catch (_: Exception) { 0 }

            if (taskCount > 0) {
                views.setViewVisibility(R.id.widget_list, View.VISIBLE)
                views.setViewVisibility(R.id.widget_empty, View.GONE)

                // Set up RemoteViewsService as list adapter
                val serviceIntent = Intent(context, TaskWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    // Unique URI so Android treats each widget instance as distinct
                    data = Uri.fromParts("content", appWidgetId.toString(), null)
                }
                views.setRemoteAdapter(R.id.widget_list, serviceIntent)

                // Template PendingIntent for task row clicks (toggle)
                val toggleIntent = Intent(context, TaskToggleReceiver::class.java).apply {
                    action = TaskToggleReceiver.ACTION_TOGGLE
                }
                val toggleFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                val togglePendingIntent = PendingIntent.getBroadcast(
                    context, appWidgetId, toggleIntent, toggleFlags
                )
                views.setPendingIntentTemplate(R.id.widget_list, togglePendingIntent)
            } else {
                views.setViewVisibility(R.id.widget_list, View.GONE)
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            }

            // Open app button
            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val openPendingIntent = PendingIntent.getActivity(context, 0, openIntent, openFlags)
            views.setOnClickPendingIntent(R.id.widget_open_app, openPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
