package com.tianli.zhiwenx

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.Toast
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class FloatingWindowService : Service() {
    
    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var isRecording = false
    private var isDragging = false
    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    
    companion object {
        const val CHANNEL_ID = "FloatingWindowChannel"
        const val NOTIFICATION_ID = 1001
        var methodChannel: MethodChannel? = null
        var eventChannel: EventChannel? = null
        var eventSink: EventChannel.EventSink? = null
    }
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "SHOW_FLOATING_WINDOW" -> showFloatingWindow()
            "HIDE_FLOATING_WINDOW" -> hideFloatingWindow()
            "TOGGLE_RECORDING" -> toggleRecording()
        }
        
        // 启动前台通知
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "悬浮窗服务",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "操作录制悬浮窗服务"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("智问X")
            .setContentText("悬浮窗服务运行中")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }
    
    private fun showFloatingWindow() {
        if (floatingView != null) return
        
        // 创建悬浮窗布局
        floatingView = createFloatingWindowLayout()
        
        // 设置悬浮窗参数
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or 
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 100
            y = 100
        }
        
        // 添加到窗口管理器
        try {
            windowManager?.addView(floatingView, params)
        } catch (e: Exception) {
            e.printStackTrace()
            Toast.makeText(this, "无法显示悬浮窗，请检查权限", Toast.LENGTH_SHORT).show()
        }
    }
    
    private fun createFloatingWindowLayout(): View {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(16, 16, 16, 16)
        }
        
        // 创建圆角背景
        val background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = 24f
            setColor(ContextCompat.getColor(this@FloatingWindowService, android.R.color.holo_blue_light))
            alpha = 220
        }
        layout.background = background
        
        // 录制按钮
        val recordButton = ImageView(this).apply {
            layoutParams = LinearLayout.LayoutParams(120, 120).apply {
                gravity = Gravity.CENTER
                setMargins(0, 0, 0, 16)
            }
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            setPadding(20, 20, 20, 20)
            setImageResource(android.R.drawable.ic_media_play)
            
            setOnClickListener {
                toggleRecording()
            }
        }
        
        // 暂停/继续按钮
        val pauseButton = ImageView(this).apply {
            layoutParams = LinearLayout.LayoutParams(100, 100).apply {
                gravity = Gravity.CENTER
                setMargins(0, 0, 0, 16)
            }
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            setPadding(16, 16, 16, 16)
            setImageResource(android.R.drawable.ic_media_pause)
            
            setOnClickListener {
                pauseResumeRecording()
            }
        }
        
        // 关闭按钮
        val closeButton = ImageView(this).apply {
            layoutParams = LinearLayout.LayoutParams(80, 80).apply {
                gravity = Gravity.CENTER
            }
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            setPadding(12, 12, 12, 12)
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            
            setOnClickListener {
                hideFloatingWindow()
            }
        }
        
        layout.addView(recordButton)
        layout.addView(pauseButton)
        layout.addView(closeButton)
        
        // 添加拖拽功能
        layout.setOnTouchListener(createDragTouchListener())
        
        return layout
    }
    
    private fun createDragTouchListener(): View.OnTouchListener {
        return View.OnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    isDragging = false
                    val params = floatingView?.layoutParams as? WindowManager.LayoutParams
                    initialX = params?.x ?: 0
                    initialY = params?.y ?: 0
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = event.rawX - initialTouchX
                    val deltaY = event.rawY - initialTouchY
                    
                    if (kotlin.math.abs(deltaX) > 10 || kotlin.math.abs(deltaY) > 10) {
                        isDragging = true
                        val params = floatingView?.layoutParams as? WindowManager.LayoutParams
                        params?.x = initialX + deltaX.toInt()
                        params?.y = initialY + deltaY.toInt()
                        
                        windowManager?.updateViewLayout(floatingView, params)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDragging) {
                        view.performClick()
                    }
                    isDragging = false
                    true
                }
                else -> false
            }
        }
    }
    
    private fun updateRecordButtonIcon(button: ImageView) {
        if (isRecording) {
            button.setImageResource(android.R.drawable.ic_media_pause)
            // 更改背景颜色为红色表示正在录制
            val background = button.parent as? LinearLayout
            val drawable = background?.background as? GradientDrawable
            drawable?.setColor(ContextCompat.getColor(this, android.R.color.holo_red_light))
        } else {
            button.setImageResource(android.R.drawable.ic_media_play)
            // 更改背景颜色为蓝色表示待录制
            val background = button.parent as? LinearLayout
            val drawable = background?.background as? GradientDrawable
            drawable?.setColor(ContextCompat.getColor(this, android.R.color.holo_blue_light))
        }
    }
    
    private fun toggleRecording() {
        isRecording = !isRecording
        
        // 更新按钮图标
        val recordButton = (floatingView as? LinearLayout)?.getChildAt(0) as? ImageView
        recordButton?.let { updateRecordButtonIcon(it) }
        
        // 发送状态到Flutter
        val data = mapOf(
            "action" to "recording_state_changed",
            "isRecording" to isRecording
        )
        eventSink?.success(data)
        
        // 启动或停止录制服务
        val intent = Intent(this, ActionRecordingService::class.java)
        if (isRecording) {
            intent.action = "START_RECORDING"
            startService(intent)
        } else {
            intent.action = "STOP_RECORDING"
            startService(intent)
        }
        
        Toast.makeText(this, if (isRecording) "开始录制" else "停止录制", Toast.LENGTH_SHORT).show()
    }
    
    private fun pauseResumeRecording() {
        val intent = Intent(this, ActionRecordingService::class.java)
        intent.action = "PAUSE_RESUME_RECORDING"
        startService(intent)
        
        Toast.makeText(this, "切换录制状态", Toast.LENGTH_SHORT).show()
    }
    
    private fun hideFloatingWindow() {
        floatingView?.let {
            windowManager?.removeView(it)
            floatingView = null
        }
        
        // 发送隐藏事件到Flutter
        val data = mapOf("action" to "floating_window_hidden")
        eventSink?.success(data)
        
        stopSelf()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        hideFloatingWindow()
        
        // 停止录制服务
        val intent = Intent(this, ActionRecordingService::class.java)
        stopService(intent)
    }
}
