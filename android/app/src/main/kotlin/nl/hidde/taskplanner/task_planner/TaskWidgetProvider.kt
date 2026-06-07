package nl.hidde.taskplanner.task_planner

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StrikethroughSpan
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class TaskWidgetProvider : HomeWidgetProvider() {

    private val rowIds = listOf(
        Triple(R.id.task_row_0, R.id.task_check_0, R.id.task_title_0),
        Triple(R.id.task_row_1, R.id.task_check_1, R.id.task_title_1),
        Triple(R.id.task_row_2, R.id.task_check_2, R.id.task_title_2),
        Triple(R.id.task_row_3, R.id.task_check_3, R.id.task_title_3),
        Triple(R.id.task_row_4, R.id.task_check_4, R.id.task_title_4),
    )

    private fun priorityColor(priority: String): Int = when (priority) {
        "medium" -> 0xFFFF9800.toInt()
        "high" -> 0xFFF44336.toInt()
        else -> 0xFF4CAF50.toInt()
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val dateLabel = widgetData.getString("date_label", "") ?: ""
        val tasksJson = widgetData.getString("tasks_json", "[]") ?: "[]"
        val tasks = JSONArray(tasksJson)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.task_widget)
            views.setTextViewText(R.id.widget_date, dateLabel)

            rowIds.forEachIndexed { index, (rowId, checkId, titleId) ->
                if (index < tasks.length()) {
                    val task = tasks.getJSONObject(index)
                    val taskId = task.getString("id")
                    val title = task.getString("title")
                    val done = task.getBoolean("done")
                    val priority = task.optString("priority", "low")
                    val color = priorityColor(priority)

                    views.setViewVisibility(rowId, View.VISIBLE)
                    val titleText = SpannableString(title)
                    if (done) {
                        titleText.setSpan(
                            StrikethroughSpan(),
                            0,
                            title.length,
                            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
                        )
                    }
                    views.setTextViewText(titleId, titleText)
                    views.setImageViewResource(
                        checkId,
                        if (done) R.drawable.widget_check_done else R.drawable.widget_check_todo,
                    )
                    views.setInt(checkId, "setColorFilter", color)

                    val toggleUri = Uri.parse("taskplanner://toggle?id=$taskId&date=$today")
                    val pendingIntent = HomeWidgetBackgroundIntent.getBroadcast(context, toggleUri)
                    views.setOnClickPendingIntent(rowId, pendingIntent)
                } else {
                    views.setViewVisibility(rowId, View.GONE)
                }
            }

            val hasTasks = tasks.length() > 0
            views.setViewVisibility(R.id.widget_empty, if (hasTasks) View.GONE else View.VISIBLE)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
