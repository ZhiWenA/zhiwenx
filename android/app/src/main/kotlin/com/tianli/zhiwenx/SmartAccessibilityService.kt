package com.tianli.zhiwenx

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.Rect
import android.os.Build
import android.util.DisplayMetrics
import android.util.Log
import android.view.*
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.Toast
import androidx.core.content.ContextCompat
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.text.SimpleDateFormat
import java.util.*

class SmartAccessibilityService : AccessibilityService() {
    
    private var isRecording = false
    private var isPaused = false
    private var isExcludeOwnApp = true
    private val recordedActions = mutableListOf<SmartAction>()
    private val gson = Gson()
    private var startTime = 0L
    
    // 浮层相关
    private var overlayView: LinearLayout? = null
    private var windowManager: WindowManager? = null
    private var isOverlayShowing = false
    
    // 排除的包名列表
    private val excludedPackages = mutableSetOf<String>()
    private var ownPackageName: String = ""
    
    // 记录上一次的目标应用
    private var lastTargetPackage: String? = null
    private var currentSessionStartTime: Long = 0
    
    companion object {
        const val TAG = "SmartAccessibilityService"
        var eventSink: EventChannel.EventSink? = null
        var instance: SmartAccessibilityService? = null
        
        // 手势识别相关
        private const val GESTURE_TIMEOUT = 300L
        private const val CLICK_THRESHOLD = 10
        private const val LONG_CLICK_THRESHOLD = 500L
    }
    
    data class SmartAction(
        val type: String, // "app_launch", "click", "long_click", "input", "scroll", "swipe", "wait", "key_event"
        val timestamp: Long,
        val packageName: String? = null,
        val activityName: String? = null,
        val nodeInfo: ActionNodeInfo? = null,
        val gesture: GestureInfo? = null,
        val text: String? = null,
        val description: String? = null,
        val metadata: Map<String, Any>? = null
    )
    
    data class ActionNodeInfo(
        val className: String? = null,
        val text: String? = null,
        val contentDescription: String? = null,
        val resourceId: String? = null,
        val bounds: ActionRect? = null,
        val isClickable: Boolean = false,
        val isLongClickable: Boolean = false,
        val isEditable: Boolean = false,
        val isScrollable: Boolean = false
    )
    
    data class GestureInfo(
        val startX: Int,
        val startY: Int,
        val endX: Int? = null,
        val endY: Int? = null,
        val duration: Long? = null,
        val pressure: Float? = null
    )
    
    data class ActionRect(
        val left: Int,
        val top: Int,
        val right: Int,
        val bottom: Int
    ) {
        val centerX: Int get() = (left + right) / 2
        val centerY: Int get() = (top + bottom) / 2
        val width: Int get() = right - left
        val height: Int get() = bottom - top
    }
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        ownPackageName = packageName
        excludedPackages.add(ownPackageName)
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        
        Log.d(TAG, "SmartAccessibilityService created, own package: $ownPackageName")
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || !isRecording || isPaused) return
        
        val sourcePackage = event.packageName?.toString()
        
        // 排除自己的应用和系统应用
        if (isExcludeOwnApp && (sourcePackage == null || shouldExcludePackage(sourcePackage))) {
            return
        }
        
        try {
            when (event.eventType) {
                AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                    handleClickEvent(event)
                }
                AccessibilityEvent.TYPE_VIEW_LONG_CLICKED -> {
                    handleLongClickEvent(event)
                }
                AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                    handleTextChangeEvent(event)
                }
                AccessibilityEvent.TYPE_VIEW_SCROLLED -> {
                    handleScrollEvent(event)
                }
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                    handleWindowStateChange(event)
                }
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                    // 处理界面内容变化，可能包含滑动等手势
                    handleContentChangeEvent(event)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling accessibility event", e)
        }
    }
    
    private fun shouldExcludePackage(packageName: String): Boolean {
        // 排除系统应用和已知的系统包
        val systemPackages = setOf(
            "com.android.systemui",
            "android",
            "com.android.system",
            "com.android.settings",
            "com.android.launcher",
            "com.android.inputmethod"
        )
        
        return excludedPackages.contains(packageName) || 
               systemPackages.any { packageName.contains(it) } ||
               packageName.startsWith("com.android.") ||
               packageName.startsWith("com.google.android.") ||
               packageName == "android"
    }
    
    private fun handleWindowStateChange(event: AccessibilityEvent) {
        val packageName = event.packageName?.toString() ?: return
        val className = event.className?.toString()
        
        // 检测应用启动
        if (lastTargetPackage != packageName && !shouldExcludePackage(packageName)) {
            recordAction(SmartAction(
                type = "app_launch",
                timestamp = System.currentTimeMillis() - startTime,
                packageName = packageName,
                activityName = className,
                description = "启动应用: ${getAppName(packageName)}"
            ))
            
            lastTargetPackage = packageName
            currentSessionStartTime = System.currentTimeMillis()
            
            Log.d(TAG, "应用启动: $packageName")
        }
    }
    
    private fun handleClickEvent(event: AccessibilityEvent) {
        val nodeInfo = extractNodeInfo(event.source)
        val packageName = event.packageName?.toString()
        
        recordAction(SmartAction(
            type = "click",
            timestamp = System.currentTimeMillis() - startTime,
            packageName = packageName,
            nodeInfo = nodeInfo,
            description = "点击: ${nodeInfo?.text ?: nodeInfo?.contentDescription ?: "未知元素"}"
        ))
        
        Log.d(TAG, "点击事件: ${nodeInfo?.text}")
    }
    
    private fun handleLongClickEvent(event: AccessibilityEvent) {
        val nodeInfo = extractNodeInfo(event.source)
        val packageName = event.packageName?.toString()
        
        recordAction(SmartAction(
            type = "long_click",
            timestamp = System.currentTimeMillis() - startTime,
            packageName = packageName,
            nodeInfo = nodeInfo,
            description = "长按: ${nodeInfo?.text ?: nodeInfo?.contentDescription ?: "未知元素"}"
        ))
        
        Log.d(TAG, "长按事件: ${nodeInfo?.text}")
    }
    
    private fun handleTextChangeEvent(event: AccessibilityEvent) {
        val text = event.text?.joinToString("") ?: return
        if (text.isEmpty()) return
        
        val nodeInfo = extractNodeInfo(event.source)
        val packageName = event.packageName?.toString()
        
        recordAction(SmartAction(
            type = "input",
            timestamp = System.currentTimeMillis() - startTime,
            packageName = packageName,
            nodeInfo = nodeInfo,
            text = text,
            description = "输入文本: $text"
        ))
        
        Log.d(TAG, "文本输入: $text")
    }
    
    private fun handleScrollEvent(event: AccessibilityEvent) {
        val nodeInfo = extractNodeInfo(event.source)
        val packageName = event.packageName?.toString()
        
        // 尝试检测滚动方向
        val scrollX = event.scrollX
        val scrollY = event.scrollY
        val maxScrollX = event.maxScrollX
        val maxScrollY = event.maxScrollY
        
        val direction = when {
            scrollY > 0 && maxScrollY > 0 -> "up"
            scrollY == 0 && maxScrollY > 0 -> "down"
            scrollX > 0 && maxScrollX > 0 -> "left"
            scrollX == 0 && maxScrollX > 0 -> "right"
            else -> "unknown"
        }
        
        recordAction(SmartAction(
            type = "scroll",
            timestamp = System.currentTimeMillis() - startTime,
            packageName = packageName,
            nodeInfo = nodeInfo,
            metadata = mapOf(
                "direction" to direction,
                "scrollX" to scrollX,
                "scrollY" to scrollY,
                "maxScrollX" to maxScrollX,
                "maxScrollY" to maxScrollY
            ),
            description = "滚动: $direction"
        ))
        
        Log.d(TAG, "滚动事件: $direction")
    }
    
    private fun handleContentChangeEvent(event: AccessibilityEvent) {
        // 这里可以处理一些界面变化，例如页面滑动等
        // 暂时不录制，避免过多噪音
    }
    
    private fun extractNodeInfo(node: AccessibilityNodeInfo?): ActionNodeInfo? {
        if (node == null) return null
        
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        
        return ActionNodeInfo(
            className = node.className?.toString(),
            text = node.text?.toString(),
            contentDescription = node.contentDescription?.toString(),
            resourceId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                node.viewIdResourceName
            } else null,
            bounds = ActionRect(bounds.left, bounds.top, bounds.right, bounds.bottom),
            isClickable = node.isClickable,
            isLongClickable = node.isLongClickable,
            isEditable = node.isEditable,
            isScrollable = node.isScrollable
        )
    }
    
    private fun recordAction(action: SmartAction) {
        recordedActions.add(action)
        
        // 发送事件到Flutter
        val data = mapOf(
            "action" to "action_recorded",
            "actionType" to action.type,
            "actionsCount" to recordedActions.size,
            "packageName" to action.packageName,
            "description" to action.description
        )
        eventSink?.success(data)
        
        Log.d(TAG, "录制操作 #${recordedActions.size}: ${action.type} - ${action.description}")
    }
    
    private fun getAppName(packageName: String): String {
        return try {
            val packageManager = this.packageManager
            val applicationInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(applicationInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }
    
    // ========== 录制控制方法 ==========
    
    fun startRecording() {
        isRecording = true
        isPaused = false
        recordedActions.clear()
        startTime = System.currentTimeMillis()
        lastTargetPackage = null
        currentSessionStartTime = System.currentTimeMillis()
        
        // 添加会话开始标记
        recordAction(SmartAction(
            type = "session_start",
            timestamp = 0L,
            description = "录制会话开始",
            metadata = mapOf(
                "startTime" to startTime,
                "deviceInfo" to getDeviceInfo()
            )
        ))
        
        showToast("开始录制操作")
        updateOverlayStatus()
        
        Log.d(TAG, "开始录制操作")
    }
    
    fun stopRecording(): String? {
        if (!isRecording) return null
        
        isRecording = false
        isPaused = false
        
        // 添加会话结束标记
        recordAction(SmartAction(
            type = "session_end",
            timestamp = System.currentTimeMillis() - startTime,
            description = "录制会话结束",
            metadata = mapOf(
                "endTime" to System.currentTimeMillis(),
                "totalActions" to recordedActions.size,
                "duration" to (System.currentTimeMillis() - startTime)
            )
        ))
        
        // 自动保存
        val filename = saveRecording(null)
        showToast("录制停止，共录制 ${recordedActions.size} 个操作")
        updateOverlayStatus()
        
        Log.d(TAG, "停止录制，共录制 ${recordedActions.size} 个操作")
        return filename
    }
    
    fun pauseResumeRecording() {
        if (!isRecording) return
        
        isPaused = !isPaused
        
        // 添加暂停/继续标记
        recordAction(SmartAction(
            type = "session_pause",
            timestamp = System.currentTimeMillis() - startTime,
            description = if (isPaused) "录制暂停" else "录制继续"
        ))
        
        showToast(if (isPaused) "录制已暂停" else "录制已继续")
        updateOverlayStatus()
        
        Log.d(TAG, if (isPaused) "暂停录制" else "继续录制")
    }
    
    fun saveRecording(filename: String?): String {
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val actualFilename = filename ?: "smart_recording_$timestamp.json"
        
        try {
            val recordingsDir = getExternalFilesDir("recordings") ?: filesDir.resolve("recordings")
            if (!recordingsDir.exists()) {
                recordingsDir.mkdirs()
            }
            
            val file = recordingsDir.resolve(actualFilename)
            val recordingData = mapOf(
                "version" to "1.0",
                "createdAt" to System.currentTimeMillis(),
                "deviceInfo" to getDeviceInfo(),
                "totalActions" to recordedActions.size,
                "actions" to recordedActions
            )
            
            file.writeText(gson.toJson(recordingData))
            
            Log.d(TAG, "录制已保存到: ${file.absolutePath}")
            showToast("录制已保存: $actualFilename")
            
            return actualFilename
        } catch (e: Exception) {
            Log.e(TAG, "保存录制失败", e)
            showToast("保存失败: ${e.message}")
            return ""
        }
    }
    
    private fun getDeviceInfo(): Map<String, Any> {
        val displayMetrics = resources.displayMetrics
        return mapOf(
            "model" to Build.MODEL,
            "manufacturer" to Build.MANUFACTURER,
            "androidVersion" to Build.VERSION.RELEASE,
            "sdkVersion" to Build.VERSION.SDK_INT,
            "screenWidth" to displayMetrics.widthPixels,
            "screenHeight" to displayMetrics.heightPixels,
            "density" to displayMetrics.density
        )
    }
    
    // ========== 录制回放方法 ==========
    
    fun executeRecording(filename: String) {
        CoroutineScope(Dispatchers.Main).launch {
            try {
                val recordingsDir = getExternalFilesDir("recordings") ?: filesDir.resolve("recordings")
                val file = recordingsDir.resolve(filename)
                
                if (!file.exists()) {
                    showToast("录制文件不存在: $filename")
                    return@launch
                }
                
                val json = file.readText()
                val recordingData = gson.fromJson<Map<String, Any>>(json, object : TypeToken<Map<String, Any>>() {}.type)
                val actionsJson = gson.toJson(recordingData["actions"])
                val actions = gson.fromJson<List<SmartAction>>(actionsJson, object : TypeToken<List<SmartAction>>() {}.type)
                
                showToast("开始执行录制，共 ${actions.size} 个操作")
                
                executeActionsSequentially(actions)
                
            } catch (e: Exception) {
                Log.e(TAG, "执行录制失败", e)
                showToast("执行录制失败: ${e.message}")
            }
        }
    }
    
    private suspend fun executeActionsSequentially(actions: List<SmartAction>) {
        withContext(Dispatchers.Main) {
            var lastTimestamp = 0L
            
            for ((index, action) in actions.withIndex()) {
                try {
                    // 计算等待时间
                    val waitTime = action.timestamp - lastTimestamp
                    if (waitTime > 0) {
                        delay(waitTime)
                    }
                    
                    // 执行操作
                    when (action.type) {
                        "app_launch" -> {
                            action.packageName?.let { packageName ->
                                launchApp(packageName)
                            }
                        }
                        "click" -> {
                            action.nodeInfo?.bounds?.let { bounds ->
                                performClick(bounds.centerX, bounds.centerY)
                            }
                        }
                        "long_click" -> {
                            action.nodeInfo?.bounds?.let { bounds ->
                                performLongClick(bounds.centerX, bounds.centerY)
                            }
                        }
                        "input" -> {
                            action.text?.let { text ->
                                performTextInput(text)
                            }
                        }
                        "scroll" -> {
                            performScroll(action)
                        }
                        "swipe" -> {
                            performSwipe(action)
                        }
                        "session_start", "session_end", "session_pause" -> {
                            // 跳过会话控制操作
                        }
                    }
                    
                    // 发送进度更新
                    val progressData = mapOf(
                        "action" to "execution_progress",
                        "currentIndex" to index,
                        "totalCount" to actions.size,
                        "currentAction" to action.type,
                        "description" to action.description
                    )
                    eventSink?.success(progressData)
                    
                    lastTimestamp = action.timestamp
                    
                    Log.d(TAG, "执行操作 ${index + 1}/${actions.size}: ${action.type}")
                    
                } catch (e: Exception) {
                    Log.e(TAG, "执行操作时出错: ${action.type}", e)
                }
            }
            
            showToast("录制执行完成")
            val completeData = mapOf(
                "action" to "execution_completed",
                "actionsCount" to actions.size
            )
            eventSink?.success(completeData)
        }
    }
    
    private fun launchApp(packageName: String) {
        try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
                Log.d(TAG, "启动应用: $packageName")
            } else {
                Log.w(TAG, "无法启动应用: $packageName")
            }
        } catch (e: Exception) {
            Log.e(TAG, "启动应用失败: $packageName", e)
        }
    }
    
    private fun performClick(x: Int, y: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val path = Path().apply { moveTo(x.toFloat(), y.toFloat()) }
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 100))
                .build()
            
            dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    Log.d(TAG, "点击完成: ($x, $y)")
                }
                
                override fun onCancelled(gestureDescription: GestureDescription?) {
                    Log.w(TAG, "点击取消: ($x, $y)")
                }
            }, null)
        }
    }
    
    private fun performLongClick(x: Int, y: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val path = Path().apply { moveTo(x.toFloat(), y.toFloat()) }
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 1000))  // 长按1秒
                .build()
            
            dispatchGesture(gesture, null, null)
        }
    }
    
    private fun performTextInput(text: String) {
        // 查找当前聚焦的输入框
        val rootNode = rootInActiveWindow
        val editableNode = findEditableNode(rootNode)
        
        if (editableNode != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val arguments = android.os.Bundle().apply {
                putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
            }
            editableNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
            Log.d(TAG, "输入文本: $text")
        }
    }
    
    private fun findEditableNode(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (node == null) return null
        
        if (node.isEditable && node.isFocused) {
            return node
        }
        
        for (i in 0 until node.childCount) {
            val childNode = node.getChild(i)
            val result = findEditableNode(childNode)
            if (result != null) return result
        }
        
        return null
    }
    
    private fun performScroll(action: SmartAction) {
        val direction = action.metadata?.get("direction") as? String ?: "down"
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val displayMetrics = resources.displayMetrics
            val centerX = displayMetrics.widthPixels / 2
            val centerY = displayMetrics.heightPixels / 2
            val scrollDistance = 500
            
            val (startX, startY, endX, endY) = when (direction) {
                "up" -> arrayOf(centerX, centerY + scrollDistance, centerX, centerY - scrollDistance)
                "down" -> arrayOf(centerX, centerY - scrollDistance, centerX, centerY + scrollDistance)
                "left" -> arrayOf(centerX + scrollDistance, centerY, centerX - scrollDistance, centerY)
                "right" -> arrayOf(centerX - scrollDistance, centerY, centerX + scrollDistance, centerY)
                else -> arrayOf(centerX, centerY - scrollDistance, centerX, centerY + scrollDistance)
            }
            
            val path = Path().apply {
                moveTo(startX.toFloat(), startY.toFloat())
                lineTo(endX.toFloat(), endY.toFloat())
            }
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 300))
                .build()
            
            dispatchGesture(gesture, null, null)
        }
    }
    
    private fun performSwipe(action: SmartAction) {
        val gesture = action.gesture ?: return
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && gesture.endX != null && gesture.endY != null) {
            val path = Path().apply {
                moveTo(gesture.startX.toFloat(), gesture.startY.toFloat())
                lineTo(gesture.endX.toFloat(), gesture.endY.toFloat())
            }
            val gestureBuilder = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, gesture.duration ?: 300))
                .build()
            
            dispatchGesture(gestureBuilder, null, null)
        }
    }
    
    // ========== 浮层控制 ==========
    
    fun showOverlay() {
        if (isOverlayShowing || !checkOverlayPermission()) return
        
        try {
            overlayView = createOverlayView()
            val params = createOverlayLayoutParams()
            
            windowManager?.addView(overlayView, params)
            isOverlayShowing = true
            
            Log.d(TAG, "显示录制控制浮层")
        } catch (e: Exception) {
            Log.e(TAG, "显示浮层失败", e)
        }
    }
    
    fun hideOverlay() {
        if (!isOverlayShowing || overlayView == null) return
        
        try {
            windowManager?.removeView(overlayView)
            overlayView = null
            isOverlayShowing = false
            
            Log.d(TAG, "隐藏录制控制浮层")
        } catch (e: Exception) {
            Log.e(TAG, "隐藏浮层失败", e)
        }
    }
    
    private fun createOverlayView(): LinearLayout {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(24, 16, 24, 16)
            
            // 使用现代的圆角背景
            background = createRoundedBackground(
                ContextCompat.getColor(this@SmartAccessibilityService, android.R.color.white),
                24f
            )
            
            // 添加阴影效果
            elevation = 16f
        }
        
        // 主录制按钮 - 更大更现代
        val recordButton = ImageView(this).apply {
            layoutParams = LinearLayout.LayoutParams(140, 140).apply {
                setMargins(8, 8, 8, 8)
            }
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            background = createCircularBackground(
                ContextCompat.getColor(this@SmartAccessibilityService, android.R.color.holo_green_light)
            )
            elevation = 8f
            setOnClickListener { toggleRecording() }
        }
        
        // 暂停按钮 - 圆形设计
        val pauseButton = ImageView(this).apply {
            layoutParams = LinearLayout.LayoutParams(100, 100).apply {
                setMargins(4, 16, 4, 16)
            }
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            background = createCircularBackground(
                ContextCompat.getColor(this@SmartAccessibilityService, android.R.color.holo_orange_light)
            )
            elevation = 6f
            setOnClickListener { pauseResumeRecording() }
        }
        
        // 关闭按钮 - 现代化设计
        val closeButton = ImageView(this).apply {
            layoutParams = LinearLayout.LayoutParams(80, 80).apply {
                setMargins(4, 20, 4, 20)
            }
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            background = createCircularBackground(
                ContextCompat.getColor(this@SmartAccessibilityService, android.R.color.darker_gray)
            )
            elevation = 4f
            setOnClickListener { hideOverlay() }
        }
        
        layout.addView(recordButton)
        layout.addView(pauseButton)
        layout.addView(closeButton)
        
        updateOverlayStatus()
        return layout
    }
    
    private fun createCircularBackground(color: Int): android.graphics.drawable.GradientDrawable {
        return android.graphics.drawable.GradientDrawable().apply {
            shape = android.graphics.drawable.GradientDrawable.OVAL
            setColor(color)
        }
    }
    
    private fun createRoundedBackground(color: Int, cornerRadius: Float): android.graphics.drawable.GradientDrawable {
        return android.graphics.drawable.GradientDrawable().apply {
            shape = android.graphics.drawable.GradientDrawable.RECTANGLE
            setColor(color)
            setCornerRadius(cornerRadius)
        }
    }
    
    private fun createOverlayLayoutParams(): WindowManager.LayoutParams {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = 32  // 距离右边缘32dp
            y = 200 // 距离顶部200dp
            
            // 添加圆角窗口效果（如果支持）
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
    }
    
    private fun checkOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            android.provider.Settings.canDrawOverlays(this)
        } else {
            true
        }
    }
    
    private fun toggleRecording() {
        if (isRecording) {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private fun updateOverlayStatus() {
        overlayView?.let { layout ->
            val recordButton = layout.getChildAt(0) as? ImageView
            val pauseButton = layout.getChildAt(1) as? ImageView
            
            recordButton?.let { button ->
                when {
                    !isRecording -> {
                        // 使用播放图标和绿色背景
                        button.setImageResource(android.R.drawable.ic_media_play)
                        button.background = createCircularBackground(
                            ContextCompat.getColor(this, android.R.color.holo_green_light)
                        )
                        button.setColorFilter(ContextCompat.getColor(this, android.R.color.white))
                    }
                    isPaused -> {
                        // 使用播放图标和橙色背景
                        button.setImageResource(android.R.drawable.ic_media_play)
                        button.background = createCircularBackground(
                            ContextCompat.getColor(this, android.R.color.holo_orange_light)
                        )
                        button.setColorFilter(ContextCompat.getColor(this, android.R.color.white))
                    }
                    else -> {
                        // 使用停止图标和红色背景
                        button.setImageResource(android.R.drawable.ic_media_pause)
                        button.background = createCircularBackground(
                            ContextCompat.getColor(this, android.R.color.holo_red_light)
                        )
                        button.setColorFilter(ContextCompat.getColor(this, android.R.color.white))
                    }
                }
            }
            
            pauseButton?.let { button ->
                // 暂停按钮根据录制状态显示不同图标
                if (isRecording) {
                    if (isPaused) {
                        button.setImageResource(android.R.drawable.ic_media_play)
                        button.background = createCircularBackground(
                            ContextCompat.getColor(this, android.R.color.holo_green_light)
                        )
                    } else {
                        button.setImageResource(android.R.drawable.ic_media_pause)
                        button.background = createCircularBackground(
                            ContextCompat.getColor(this, android.R.color.holo_orange_light)
                        )
                    }
                    button.setColorFilter(ContextCompat.getColor(this, android.R.color.white))
                } else {
                    button.setImageResource(android.R.drawable.ic_media_pause)
                    button.background = createCircularBackground(
                        ContextCompat.getColor(this, android.R.color.darker_gray)
                    )
                    button.setColorFilter(ContextCompat.getColor(this, android.R.color.white))
                }
            }
            
            // 关闭按钮设置图标
            val closeButton = layout.getChildAt(2) as? ImageView
            closeButton?.let { button ->
                button.setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
                button.setColorFilter(ContextCompat.getColor(this, android.R.color.white))
            }
        }
    }
    
    private fun showToast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }
    
    override fun onInterrupt() {
        Log.d(TAG, "Accessibility service interrupted")
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "SmartAccessibilityService connected")
        showToast("智能录制服务已连接，可以开始使用")
        
        // 发送服务连接事件到Flutter
        val data = mapOf(
            "action" to "service_connected",
            "timestamp" to System.currentTimeMillis()
        )
        eventSink?.success(data)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        hideOverlay()
        instance = null
        Log.d(TAG, "SmartAccessibilityService destroyed")
    }
    
    // ========== 公共接口方法 ==========
    
    fun getRecordingsList(): List<String> {
        return try {
            val recordingsDir = getExternalFilesDir("recordings") ?: filesDir.resolve("recordings")
            if (!recordingsDir.exists()) {
                emptyList()
            } else {
                recordingsDir.listFiles()
                    ?.filter { it.name.endsWith(".json") }
                    ?.map { it.name }
                    ?.sorted()
                    ?: emptyList()
            }
        } catch (e: Exception) {
            Log.e(TAG, "获取录制文件列表失败", e)
            emptyList()
        }
    }
    
    fun setExcludeOwnApp(exclude: Boolean) {
        isExcludeOwnApp = exclude
        Log.d(TAG, "设置排除自身应用: $exclude")
    }
    
    fun addExcludedPackage(packageName: String) {
        excludedPackages.add(packageName)
        Log.d(TAG, "添加排除包名: $packageName")
    }
    
    fun removeExcludedPackage(packageName: String) {
        excludedPackages.remove(packageName)
        Log.d(TAG, "移除排除包名: $packageName")
    }
    
    fun getRecordingStatus(): Map<String, Any> {
        return mapOf(
            "isRecording" to isRecording,
            "isPaused" to isPaused,
            "actionsCount" to recordedActions.size,
            "isOverlayShowing" to isOverlayShowing,
            "excludeOwnApp" to isExcludeOwnApp,
            "excludedPackages" to excludedPackages.toList()
        )
    }
}
