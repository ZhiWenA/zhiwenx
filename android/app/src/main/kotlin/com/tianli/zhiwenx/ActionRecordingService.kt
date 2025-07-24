package com.tianli.zhiwenx

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.*

class ActionRecordingService : Service() {
    
    private var isRecording = false
    private var isPaused = false
    private val recordedActions = mutableListOf<RecordedAction>()
    private val gson = Gson()
    private var startTime = 0L
    
    companion object {
        const val CHANNEL_ID = "ActionRecordingChannel"
        const val NOTIFICATION_ID = 1002
        var methodChannel: MethodChannel? = null
        var eventChannel: EventChannel? = null
        var eventSink: EventChannel.EventSink? = null
        const val TAG = "ActionRecordingService"
    }
    
    data class RecordedAction(
        val type: String, // "click", "scroll", "input", "swipe", "wait"
        val timestamp: Long,
        val x: Int? = null,
        val y: Int? = null,
        val text: String? = null,
        val scrollDirection: String? = null, // "up", "down", "left", "right"
        val scrollDistance: Int? = null,
        val swipeStartX: Int? = null,
        val swipeStartY: Int? = null,
        val swipeEndX: Int? = null,
        val swipeEndY: Int? = null,
        val waitDuration: Long? = null,
        val description: String? = null
    )
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START_RECORDING" -> startRecording()
            "STOP_RECORDING" -> stopRecording()
            "PAUSE_RESUME_RECORDING" -> pauseResumeRecording()
            "SAVE_RECORDING" -> saveRecording(intent.getStringExtra("filename"))
            "LOAD_RECORDING" -> loadRecording(intent.getStringExtra("filename"))
            "EXECUTE_RECORDING" -> executeRecording(intent.getStringExtra("filename"))
            "RECORD_ACTION" -> {
                val actionJson = intent.getStringExtra("action")
                actionJson?.let { recordAction(it) }
            }
        }
        
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "操作录制服务",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "用户操作录制和回放服务"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val statusText = when {
            !isRecording -> "待机中"
            isPaused -> "已暂停"
            else -> "录制中"
        }
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("操作录制")
            .setContentText("状态: $statusText (已录制 ${recordedActions.size} 个操作)")
            .setSmallIcon(android.R.drawable.ic_menu_save)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }
    
    private fun startRecording() {
        isRecording = true
        isPaused = false
        recordedActions.clear()
        startTime = System.currentTimeMillis()
        
        Log.d(TAG, "开始录制操作")
        
        // 发送状态更新到Flutter
        val data = mapOf(
            "action" to "recording_started",
            "timestamp" to startTime
        )
        eventSink?.success(data)
        
        updateNotification()
    }
    
    private fun stopRecording() {
        isRecording = false
        isPaused = false
        
        Log.d(TAG, "停止录制，共录制 ${recordedActions.size} 个操作")
        
        // 自动保存录制
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val filename = "recording_$timestamp.json"
        saveRecording(filename)
        
        // 发送状态更新到Flutter
        val data = mapOf(
            "action" to "recording_stopped",
            "actionsCount" to recordedActions.size,
            "filename" to filename
        )
        eventSink?.success(data)
        
        updateNotification()
    }
    
    private fun pauseResumeRecording() {
        if (!isRecording) return
        
        isPaused = !isPaused
        
        Log.d(TAG, if (isPaused) "暂停录制" else "继续录制")
        
        // 添加暂停/继续标记
        if (isPaused) {
            recordedActions.add(
                RecordedAction(
                    type = "wait",
                    timestamp = System.currentTimeMillis() - startTime,
                    waitDuration = 0L,
                    description = "录制暂停"
                )
            )
        } else {
            recordedActions.add(
                RecordedAction(
                    type = "wait",
                    timestamp = System.currentTimeMillis() - startTime,
                    waitDuration = 0L,
                    description = "录制继续"
                )
            )
        }
        
        // 发送状态更新到Flutter
        val data = mapOf(
            "action" to "recording_paused",
            "isPaused" to isPaused
        )
        eventSink?.success(data)
        
        updateNotification()
    }
    
    private fun recordAction(actionJson: String) {
        if (!isRecording || isPaused) return
        
        try {
            val actionMap = gson.fromJson<Map<String, Any>>(actionJson, object : TypeToken<Map<String, Any>>() {}.type)
            
            val action = RecordedAction(
                type = actionMap["type"] as String,
                timestamp = System.currentTimeMillis() - startTime,
                x = (actionMap["x"] as? Double)?.toInt(),
                y = (actionMap["y"] as? Double)?.toInt(),
                text = actionMap["text"] as? String,
                scrollDirection = actionMap["scrollDirection"] as? String,
                scrollDistance = (actionMap["scrollDistance"] as? Double)?.toInt(),
                swipeStartX = (actionMap["swipeStartX"] as? Double)?.toInt(),
                swipeStartY = (actionMap["swipeStartY"] as? Double)?.toInt(),
                swipeEndX = (actionMap["swipeEndX"] as? Double)?.toInt(),
                swipeEndY = (actionMap["swipeEndY"] as? Double)?.toInt(),
                waitDuration = (actionMap["waitDuration"] as? Double)?.toLong(),
                description = actionMap["description"] as? String
            )
            
            recordedActions.add(action)
            
            Log.d(TAG, "录制操作: ${action.type} at (${action.x}, ${action.y})")
            
            // 发送操作录制事件到Flutter
            val data = mapOf(
                "action" to "action_recorded",
                "actionType" to action.type,
                "actionsCount" to recordedActions.size
            )
            eventSink?.success(data)
            
            updateNotification()
            
        } catch (e: Exception) {
            Log.e(TAG, "录制操作时出错", e)
        }
    }
    
    private fun saveRecording(filename: String?) {
        if (recordedActions.isEmpty()) return
        
        val actualFilename = filename ?: "recording_${System.currentTimeMillis()}.json"
        
        try {
            val recordingsDir = File(filesDir, "recordings")
            if (!recordingsDir.exists()) {
                recordingsDir.mkdirs()
            }
            
            val file = File(recordingsDir, actualFilename)
            val json = gson.toJson(recordedActions)
            
            FileWriter(file).use { writer ->
                writer.write(json)
            }
            
            Log.d(TAG, "录制已保存到: ${file.absolutePath}")
            
            // 发送保存完成事件到Flutter
            val data = mapOf(
                "action" to "recording_saved",
                "filename" to actualFilename,
                "path" to file.absolutePath,
                "actionsCount" to recordedActions.size
            )
            eventSink?.success(data)
            
        } catch (e: Exception) {
            Log.e(TAG, "保存录制时出错", e)
            
            val data = mapOf(
                "action" to "recording_save_error",
                "error" to e.message
            )
            eventSink?.success(data)
        }
    }
    
    private fun loadRecording(filename: String?) {
        if (filename == null) return
        
        try {
            val recordingsDir = File(filesDir, "recordings")
            val file = File(recordingsDir, filename)
            
            if (!file.exists()) {
                Log.e(TAG, "录制文件不存在: $filename")
                return
            }
            
            val json = file.readText()
            val type = object : TypeToken<List<RecordedAction>>() {}.type
            val loadedActions = gson.fromJson<List<RecordedAction>>(json, type)
            
            recordedActions.clear()
            recordedActions.addAll(loadedActions)
            
            Log.d(TAG, "录制已加载: $filename，共 ${recordedActions.size} 个操作")
            
            // 发送加载完成事件到Flutter
            val data = mapOf(
                "action" to "recording_loaded",
                "filename" to filename,
                "actionsCount" to recordedActions.size
            )
            eventSink?.success(data)
            
        } catch (e: Exception) {
            Log.e(TAG, "加载录制时出错", e)
            
            val data = mapOf(
                "action" to "recording_load_error",
                "error" to e.message
            )
            eventSink?.success(data)
        }
    }
    
    private fun executeRecording(filename: String?) {
        if (filename != null) {
            loadRecording(filename)
        }
        
        if (recordedActions.isEmpty()) {
            Log.w(TAG, "没有可执行的录制操作")
            return
        }
        
        Log.d(TAG, "开始执行录制，共 ${recordedActions.size} 个操作")
        
        // 发送执行开始事件到Flutter
        val data = mapOf(
            "action" to "recording_execution_started",
            "actionsCount" to recordedActions.size
        )
        eventSink?.success(data)
        
        // 在新线程中执行录制
        Thread {
            executeActionsSequentially()
        }.start()
    }
    
    private fun executeActionsSequentially() {
        var lastTimestamp = 0L
        
        for ((index, action) in recordedActions.withIndex()) {
            try {
                // 计算等待时间
                val waitTime = action.timestamp - lastTimestamp
                if (waitTime > 0) {
                    Thread.sleep(waitTime)
                }
                
                // 执行操作
                when (action.type) {
                    "click" -> {
                        if (action.x != null && action.y != null) {
                            // 发送点击事件到Flutter进行执行
                            val clickData = mapOf(
                                "action" to "execute_click",
                                "x" to action.x,
                                "y" to action.y
                            )
                            eventSink?.success(clickData)
                        }
                    }
                    "input" -> {
                        if (!action.text.isNullOrEmpty()) {
                            val inputData = mapOf(
                                "action" to "execute_input",
                                "text" to action.text
                            )
                            eventSink?.success(inputData)
                        }
                    }
                    "scroll" -> {
                        val scrollData = mapOf(
                            "action" to "execute_scroll",
                            "direction" to action.scrollDirection,
                            "distance" to action.scrollDistance
                        )
                        eventSink?.success(scrollData)
                    }
                    "swipe" -> {
                        if (action.swipeStartX != null && action.swipeStartY != null &&
                            action.swipeEndX != null && action.swipeEndY != null) {
                            val swipeData = mapOf(
                                "action" to "execute_swipe",
                                "startX" to action.swipeStartX,
                                "startY" to action.swipeStartY,
                                "endX" to action.swipeEndX,
                                "endY" to action.swipeEndY
                            )
                            eventSink?.success(swipeData)
                        }
                    }
                    "wait" -> {
                        action.waitDuration?.let { Thread.sleep(it) }
                    }
                }
                
                // 发送执行进度
                val progressData = mapOf(
                    "action" to "recording_execution_progress",
                    "currentIndex" to index,
                    "totalCount" to recordedActions.size,
                    "currentAction" to action.type
                )
                eventSink?.success(progressData)
                
                lastTimestamp = action.timestamp
                
                Log.d(TAG, "执行操作 ${index + 1}/${recordedActions.size}: ${action.type}")
                
            } catch (e: Exception) {
                Log.e(TAG, "执行操作时出错", e)
            }
        }
        
        // 发送执行完成事件
        val completeData = mapOf(
            "action" to "recording_execution_completed",
            "actionsCount" to recordedActions.size
        )
        eventSink?.success(completeData)
        
        Log.d(TAG, "录制执行完成")
    }
    
    private fun updateNotification() {
        val notification = createNotification()
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "ActionRecordingService destroyed")
    }
}
