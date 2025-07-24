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
        
        // 存储通道引用
        FloatingWindowService.methodChannel = floatingWindowMethodChannel
        ActionRecordingService.methodChannel = actionRecordingMethodChannel
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
    
    private fun requestSmartAccessibilityPermission() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        
        // 创建现代化的 Material Design 对话框
        val builder = AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog)
        builder.setIcon(android.R.drawable.ic_dialog_info)
        builder.setTitle("开启智能录制服务")
        
        // 使用结构化的消息布局
        val message = buildString {
            append("📱 请按照以下步骤开启智能录制服务：\n\n")
            append("1️⃣ 在无障碍设置页面中找到\n")
            append("   「智问X - 智能操作录制服务」\n\n")
            append("2️⃣ 点击进入该服务设置页面\n\n")
            append("3️⃣ 打开服务开关（切换到开启状态）\n\n")
            append("4️⃣ 在弹出的权限对话框中点击「确定」\n\n")
            append("⚠️ 重要提示：\n")
            append("• 如果只看到「无障碍快捷按钮」选项，请查找服务开关\n")
            append("• 确保开关处于「开启」状态\n")
            append("• 如果问题持续，请重新安装应用")
        }
        
        builder.setMessage(message)
        
        // 使用 Material Design 按钮样式
        builder.setPositiveButton("前往设置 🚀") { _, _ ->
            try {
                startActivity(intent)
            } catch (e: Exception) {
                Toast.makeText(this, "⚠️ 无法打开无障碍设置，请手动前往：\n设置 > 无障碍", Toast.LENGTH_LONG).show()
            }
        }
        
        builder.setNegativeButton("暂不设置", null)
        
        // 添加中性按钮提供帮助
        builder.setNeutralButton("帮助 ℹ️") { _, _ ->
            showAccessibilityHelp()
        }
        
        val dialog = builder.create()
        dialog.show()
        
        // 设置按钮颜色和样式
        dialog.getButton(AlertDialog.BUTTON_POSITIVE)?.let { button ->
            button.setTextColor(ContextCompat.getColor(this, android.R.color.holo_green_dark))
            button.textSize = 16f
        }
        
        dialog.getButton(AlertDialog.BUTTON_NEGATIVE)?.let { button ->
            button.setTextColor(ContextCompat.getColor(this, android.R.color.darker_gray))
        }
        
        dialog.getButton(AlertDialog.BUTTON_NEUTRAL)?.let { button ->
            button.setTextColor(ContextCompat.getColor(this, android.R.color.holo_blue_light))
        }
    }
    
    private fun showAccessibilityHelp() {
        val builder = AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog)
        builder.setIcon(android.R.drawable.ic_dialog_info)
        builder.setTitle("无障碍服务帮助")
        
        val helpMessage = buildString {
            append("🔧 如果无法找到服务或开关：\n\n")
            append("方法一：\n")
            append("• 完全卸载应用\n")
            append("• 重新安装最新版本\n")
            append("• 重启设备后重试\n\n")
            append("方法二：\n")
            append("• 设置 > 应用管理 > 智问X\n")
            append("• 清除应用数据\n")
            append("• 重新打开应用\n\n")
            append("方法三：\n")
            append("• 设置 > 无障碍 > 下载的服务\n")
            append("• 查找「智问X」相关服务\n\n")
            append("⭐ 服务开启后，您将看到：\n")
            append("• 服务开关（可切换开启/关闭）\n")
            append("• 服务说明和权限描述\n")
            append("• 快捷方式设置（可选）")
        }
        
        builder.setMessage(helpMessage)
        builder.setPositiveButton("我知道了", null)
        builder.show()
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
