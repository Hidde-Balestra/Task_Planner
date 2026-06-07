package nl.hidde.taskplanner.task_planner

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "nl.hidde.taskplanner/widget"
        ).setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                TaskWidgetProvider.updateAllWidgets(this)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
