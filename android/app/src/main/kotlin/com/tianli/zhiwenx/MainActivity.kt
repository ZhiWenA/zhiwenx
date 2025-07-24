package com.tianli.zhiwenx

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.widget.Toast
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
