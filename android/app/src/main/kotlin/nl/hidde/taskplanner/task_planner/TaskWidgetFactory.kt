package nl.hidde.taskplanner.task_planner

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

private data class WidgetTask(val id: String, val title: String, val completed: Boolean)

class TaskWidgetFactory(
    private val context: Context,
    private val intent: Intent,
) : RemoteViewsService.RemoteViewsFactory {

    private val tasks = mutableListOf<WidgetTask>()

    override fun onCreate() { loadTasks() }
    override fun onDataSetChanged() { loadTasks() }
    override fun onDestroy() {}

    private fun loadTasks() {
        tasks.clear()
        try {
            val json = HomeWidgetPlugin.getData(context).getString("today_tasks", "[]") ?: "[]"
            val arr = JSONArray(json)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                tasks.add(
                    WidgetTask(
                        id = obj.optString("id"),
                        title = obj.optString("title"),
                        completed = obj.optBoolean("completed", false),
                    )
                )
            }
        } catch (_: Exception) {}
    }

    override fun getCount(): Int = tasks.size
    override fun getViewTypeCount(): Int = 1
    override fun hasStableIds(): Boolean = true
    override fun getItemId(position: Int): Long = position.toLong()
    override fun getLoadingView(): RemoteViews? = null

    override fun getViewAt(position: Int): RemoteViews {
        if (position >= tasks.size) return RemoteViews(context.packageName, R.layout.task_widget_item)
        val task = tasks[position]
        val rv = RemoteViews(context.packageName, R.layout.task_widget_item)

        rv.setTextViewText(R.id.task_title, task.title)

        if (task.completed) {
            rv.setImageViewResource(R.id.task_checkbox, R.drawable.widget_check_on)
            rv.setInt(R.id.task_title, "setTextColor", 0xFF9E9E9E.toInt())
        } else {
            rv.setImageViewResource(R.id.task_checkbox, R.drawable.widget_check_off)
            rv.setInt(R.id.task_title, "setTextColor", 0xFF212121.toInt())
        }

        // Fill-in intent merges with the template PendingIntent set on the ListView
        val fillIn = Intent().apply { putExtra("task_id", task.id) }
        rv.setOnClickFillInIntent(R.id.task_item_root, fillIn)

        return rv
    }
}
