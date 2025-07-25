package com.tianli.zhiwenx

import android.app.AlertDialog
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.widget.Toast
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    private val FLOATING_WINDOW_CHANNEL = "com.tianli.zhiwenx/floating_window"
    private val ACTION_RECORDING_CHANNEL = "com.tianli.zhiwenx/action_recording"
    private val FLOATING_WINDOW_EVENT_CHANNEL = "com.tianli.zhiwenx/floating_window_events"
    private val ACTION_RECORDING_EVENT_CHANNEL = "com.tianli.zhiwenx/action_recording_events"
    private val AUTOMATION_ENGINE_CHANNEL = "com.tianli.zhiwenx/automation_engine"
    private val GLOBAL_CAPTURE_CHANNEL = "com.tianli.zhiwenx/global_capture"
    private val OVERLAY_PERMISSION_CHANNEL = "com.tianli.zhiwenx/overlay_permission"
    
    private val OVERLAY_PERMISSION_REQUEST_CODE = 1001
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 悬浮窗方法通道
        val floatingWindowMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLOATING_WINDOW_CHANNEL)
        floatingWindowMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkOverlayPermission" -> {
                    val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(hasPermission)
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(null)
                }
                "showFloatingWindow" -> {
                    showFloatingWindow()
                    result.success(null)
                }
                "hideFloatingWindow" -> {
                    hideFloatingWindow()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        
        // 操作录制方法通道
        val actionRecordingMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACTION_RECORDING_CHANNEL)
        actionRecordingMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startRecording" -> {
                    startActionRecording()
                    result.success(null)
                }
                "stopRecording" -> {
                    stopActionRecording()
                    result.success(null)
                }
                "pauseResumeRecording" -> {
                    pauseResumeActionRecording()
                    result.success(null)
                }
                "saveRecording" -> {
                    val filename = call.argument<String>("filename")
                    saveActionRecording(filename)
                    result.success(null)
                }
                "loadRecording" -> {
                    val filename = call.argument<String>("filename")
                    loadActionRecording(filename)
                    result.success(null)
                }
                "executeRecording" -> {
                    val filename = call.argument<String>("filename")
                    executeActionRecording(filename)
                    result.success(null)
                }
                "recordAction" -> {
                    val actionJson = call.argument<String>("action")
                    recordAction(actionJson)
                    result.success(null)
                }
                "getRecordingsList" -> {
                    val recordings = getRecordingsList()
                    result.success(recordings)
                }
                else -> result.notImplemented()
            }
        }
        
        // 智能录制方法通道
        val smartRecordingMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.tianli.zhiwenx/smart_recording")
        smartRecordingMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isServiceEnabled" -> {
                    result.success(SmartAccessibilityService.instance != null)
                }
                "requestAccessibilityPermission" -> {
                    requestSmartAccessibilityPermission()
                    result.success(null)
                }
                "startRecording" -> {
                    SmartAccessibilityService.instance?.startRecording()
                    result.success(null)
                }
                "stopRecording" -> {
                    val filename = SmartAccessibilityService.instance?.stopRecording()
                    result.success(filename)
                }
                "pauseResumeRecording" -> {
                    SmartAccessibilityService.instance?.pauseResumeRecording()
                    result.success(null)
                }
                "saveRecording" -> {
                    val filename = call.argument<String>("filename")
                    val savedFilename = SmartAccessibilityService.instance?.saveRecording(filename)
                    result.success(savedFilename)
                }
                "executeRecording" -> {
                    val filename = call.argument<String>("filename")
                    if (filename != null) {
                        SmartAccessibilityService.instance?.executeRecording(filename)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Filename is required", null)
                    }
                }
                "getRecordingsList" -> {
                    val recordings = SmartAccessibilityService.instance?.getRecordingsList() ?: emptyList()
                    result.success(recordings)
                }
                "showOverlay" -> {
                    SmartAccessibilityService.instance?.showOverlay()
                    result.success(null)
                }
                "hideOverlay" -> {
                    SmartAccessibilityService.instance?.hideOverlay()
                    result.success(null)
                }
                "getRecordingStatus" -> {
                    val status = SmartAccessibilityService.instance?.getRecordingStatus() ?: mapOf(
                        "isRecording" to false,
                        "isPaused" to false,
                        "actionsCount" to 0,
                        "isOverlayShowing" to false,
                        "excludeOwnApp" to true,
                        "excludedPackages" to emptyList<String>()
                    )
                    result.success(status)
                }
                "setExcludeOwnApp" -> {
                    val exclude = call.argument<Boolean>("exclude") ?: true
                    SmartAccessibilityService.instance?.setExcludeOwnApp(exclude)
                    result.success(null)
                }
                "addExcludedPackage" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        SmartAccessibilityService.instance?.addExcludedPackage(packageName)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is required", null)
                    }
                }
                "removeExcludedPackage" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        SmartAccessibilityService.instance?.removeExcludedPackage(packageName)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // 悬浮窗事件通道
        val floatingWindowEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, FLOATING_WINDOW_EVENT_CHANNEL)
        floatingWindowEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                FloatingWindowService.eventSink = events
            }
            
            override fun onCancel(arguments: Any?) {
                FloatingWindowService.eventSink = null
            }
        })
        
        // 操作录制事件通道
        val actionRecordingEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, ACTION_RECORDING_EVENT_CHANNEL)
        actionRecordingEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                ActionRecordingService.eventSink = events
            }
            
            override fun onCancel(arguments: Any?) {
                ActionRecordingService.eventSink = null
            }
        })
        
        // 智能录制事件通道
        val smartRecordingEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.tianli.zhiwenx/smart_recording_events")
        smartRecordingEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                SmartAccessibilityService.eventSink = events
            }
            
            override fun onCancel(arguments: Any?) {
                SmartAccessibilityService.eventSink = null
            }
        })
        
        // 自动化引擎方法通道
        val automationEngineMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUTOMATION_ENGINE_CHANNEL)
        automationEngineMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "executeRule" -> {
                    val ruleJson = call.argument<Map<String, Any>>("rule")
                    if (ruleJson != null) {
                        SmartAccessibilityService.instance?.executeAutomationRule(ruleJson)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Rule is required", null)
                    }
                }
                "validateRule" -> {
                    val ruleJson = call.argument<Map<String, Any>>("rule")
                    if (ruleJson != null) {
                        val isValid = SmartAccessibilityService.instance?.validateAutomationRule(ruleJson) ?: false
                        result.success(isValid)
                    } else {
                        result.success(false)
                    }
                }
                "getScreenWidgets" -> {
                    val widgets = SmartAccessibilityService.instance?.getScreenWidgets() ?: emptyList()
                    result.success(widgets)
                }
                "findWidget" -> {
                    val selectorJson = call.argument<Map<String, Any>>("selector")
                    if (selectorJson != null) {
                        val widget = SmartAccessibilityService.instance?.findWidget(selectorJson)
                        result.success(widget)
                    } else {
                        result.error("INVALID_ARGUMENT", "Selector is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // 存储通道引用
        FloatingWindowService.methodChannel = floatingWindowMethodChannel
        ActionRecordingService.methodChannel = actionRecordingMethodChannel
        
        // 全局控件抓取方法通道
        val globalCaptureMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GLOBAL_CAPTURE_CHANNEL)
        globalCaptureMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkAccessibilityPermission" -> {
                    val hasPermission = SmartAccessibilityService.instance != null
                    result.success(hasPermission)
                }
                "showGlobalOverlay" -> {
                    showFloatingWindow()
                    result.success(null)
                }
                "hideGlobalOverlay" -> {
                    hideFloatingWindow()
                    result.success(null)
                }
                "captureScreenWidgets" -> {
                    val widgets = SmartAccessibilityService.instance?.getScreenWidgets() ?: emptyList()
                    result.success(widgets)
                }
                "highlightWidget" -> {
                    val bounds = call.argument<Map<String, Any>>("bounds")
                    val color = call.argument<Long>("color")
                    val duration = call.argument<Int>("duration")
                    if (bounds != null) {
                        SmartAccessibilityService.instance?.highlightWidget(bounds, color, duration)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Bounds is required", null)
                    }
                }
                "showWidgetDetails" -> {
                    val widget = call.argument<Map<String, Any>>("widget")
                    if (widget != null) {
                        SmartAccessibilityService.instance?.showWidgetDetails(widget)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Widget is required", null)
                    }
                }
                "toggleSelectionMode" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    SmartAccessibilityService.instance?.toggleSelectionMode(enabled)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        
        // 悬浮窗权限方法通道
        val overlayPermissionMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_PERMISSION_CHANNEL)
        overlayPermissionMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasOverlayPermission" -> {
                    val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(hasPermission)
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    // 返回当前权限状态
                    val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(hasPermission)
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = Uri.parse("package:$packageName")
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("FAILED", "无法打开应用设置", e.message)
                    }
                }
                "showFloatingWindow" -> {
                    val title = call.argument<String>("title") ?: "悬浮窗"
                    val content = call.argument<String>("content") ?: ""
                    val x = call.argument<Int>("x")
                    val y = call.argument<Int>("y")
                    val width = call.argument<Int>("width")
                    val height = call.argument<Int>("height")
                    
                    showCustomFloatingWindow(title, content, x, y, width, height)
                    result.success(true)
                }
                "hideFloatingWindow" -> {
                    hideFloatingWindow()
                    result.success(null)
                }
                "updateFloatingWindow" -> {
                    val title = call.argument<String>("title")
                    val content = call.argument<String>("content")
                    updateFloatingWindow(title, content)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
            }
        }
    }
    
    private fun showFloatingWindow() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            Toast.makeText(this, "需要悬浮窗权限", Toast.LENGTH_SHORT).show()
            requestOverlayPermission()
            return
        }
        
        val intent = Intent(this, FloatingWindowService::class.java)
        intent.action = "SHOW_FLOATING_WINDOW"
        startService(intent)
    }
    
    private fun hideFloatingWindow() {
        val intent = Intent(this, FloatingWindowService::class.java)
        intent.action = "HIDE_FLOATING_WINDOW"
        startService(intent)
    }
    
    private fun showCustomFloatingWindow(title: String, content: String, x: Int?, y: Int?, width: Int?, height: Int?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            Toast.makeText(this, "需要悬浮窗权限", Toast.LENGTH_SHORT).show()
            requestOverlayPermission()
            return
        }
        
        val intent = Intent(this, FloatingWindowService::class.java)
        intent.action = "SHOW_CUSTOM_FLOATING_WINDOW"
        intent.putExtra("title", title)
        intent.putExtra("content", content)
        x?.let { intent.putExtra("x", it) }
        y?.let { intent.putExtra("y", it) }
        width?.let { intent.putExtra("width", it) }
        height?.let { intent.putExtra("height", it) }
        startService(intent)
    }
    
    private fun updateFloatingWindow(title: String?, content: String?) {
        val intent = Intent(this, FloatingWindowService::class.java)
        intent.action = "UPDATE_FLOATING_WINDOW"
        title?.let { intent.putExtra("title", it) }
        content?.let { intent.putExtra("content", it) }
        startService(intent)
    }
    
    private fun requestSmartAccessibilityPermission() {
        // 直接跳转到无障碍设置，Flutter端会处理UI提示
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        
        try {
            startActivity(intent)
        } catch (e: Exception) {
            Toast.makeText(this, "无法打开无障碍设置，请手动前往：设置 > 无障碍", Toast.LENGTH_LONG).show()
        }
    }
    
    private fun startActionRecording() {
        val intent = Intent(this, ActionRecordingService::class.java)
        intent.action = "START_RECORDING"
        startService(intent)
    }
    
    private fun stopActionRecording() {
        val intent = Intent(this, ActionRecordingService::class.java)
        intent.action = "STOP_RECORDING"
        startService(intent)
    }
    
    private fun pauseResumeActionRecording() {
        val intent = Intent(this, ActionRecordingService::class.java)
        intent.action = "PAUSE_RESUME_RECORDING"
        startService(intent)
    }
    
    private fun saveActionRecording(filename: String?) {
        val intent = Intent(this, ActionRecordingService::class.java)
        intent.action = "SAVE_RECORDING"
        filename?.let { intent.putExtra("filename", it) }
        startService(intent)
    }
    
    private fun loadActionRecording(filename: String?) {
        val intent = Intent(this, ActionRecordingService::class.java)
        intent.action = "LOAD_RECORDING"
        filename?.let { intent.putExtra("filename", it) }
        startService(intent)
    }
    
    private fun executeActionRecording(filename: String?) {
        val intent = Intent(this, ActionRecordingService::class.java)
        intent.action = "EXECUTE_RECORDING"
        filename?.let { intent.putExtra("filename", it) }
        startService(intent)
    }
    
    private fun recordAction(actionJson: String?) {
        val intent = Intent(this, ActionRecordingService::class.java)
        intent.action = "RECORD_ACTION"
        actionJson?.let { intent.putExtra("action", it) }
        startService(intent)
    }
    
    private fun getRecordingsList(): List<String> {
        val recordingsDir = java.io.File(filesDir, "recordings")
        if (!recordingsDir.exists()) {
            return emptyList()
        }
        
        return recordingsDir.listFiles()
            ?.filter { it.name.endsWith(".json") }
            ?.map { it.name }
            ?: emptyList()
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == OVERLAY_PERMISSION_REQUEST_CODE) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (Settings.canDrawOverlays(this)) {
                    Toast.makeText(this, "悬浮窗权限已获取", Toast.LENGTH_SHORT).show()
                } else {
                    Toast.makeText(this, "需要悬浮窗权限才能使用此功能", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }
}
