package com.example.focus_guard

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.CountDownTimer
import android.os.Handler
import android.os.Looper
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import org.json.JSONArray
import java.util.Calendar

class AppBlockerService : AccessibilityService() {

    private var windowManager: WindowManager? = null
    private var overlayView: LinearLayout? = null
    private var currentPackage: String = ""
    private val handler = Handler(Looper.getMainLooper())

    private val usageSecondsMap = mutableMapOf<String, Int>()
    private val cooldownUntilMap = mutableMapOf<String, Long>()

    private var emergencyBypassUntil: Long = 0L
    private var activeCountDown: CountDownTimer? = null

    private val tickerRunnable = object : Runnable {
        override fun run() {
            checkRulesAndTick()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        handler.post(tickerRunnable)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val pkg = event.packageName?.toString() ?: return
            if (pkg == "com.android.systemui" || pkg == packageName) {
                removeOverlay()
                currentPackage = ""
                return
            }
            currentPackage = pkg
            checkRulesAndTick()
        }
    }

    private fun checkRulesAndTick() {
        val nowMillis = System.currentTimeMillis()

        if (nowMillis < emergencyBypassUntil) {
            removeOverlay()
            return
        }

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val cal = Calendar.getInstance()
        val currentMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

        val routinesJson = prefs.getString("flutter.routines", "[]") ?: "[]"
        val routines = JSONArray(routinesJson)
        for (i in 0 until routines.length()) {
            val item = routines.getJSONObject(i)
            if (!item.optBoolean("isEnabled", true)) continue
            val start = item.getInt("startMinutes")
            val end = item.getInt("endMinutes")
            val title = item.getString("title")

            val isActive = if (start <= end) {
                currentMinutes in start until end
            } else {
                currentMinutes >= start || currentMinutes < end
            }

            if (isActive && currentPackage.isNotEmpty()) {
                val endHour = end / 60
                val endMin = end % 60
                showOverlay(
                    title = "ROUTINE LOCK ACTIVE",
                    subtitle = "Task: $title\nPhone locked until %02d:%02d".format(endHour, endMin),
                    allowExitHome = false
                )
                return
            }
        }

        val limitsJson = prefs.getString("flutter.app_limits", "[]") ?: "[]"
        val limits = JSONArray(limitsJson)
        for (i in 0 until limits.length()) {
            val item = limits.getJSONObject(i)
            val targetPkg = item.getString("packageName")
            if (targetPkg != currentPackage) continue

            val maxSeconds = item.getInt("limitMinutes") * 60
            val cooldownMillis = item.getInt("cooldownMinutes") * 60 * 1000L
            val appName = item.getString("appName")

            val cooldownEnd = cooldownUntilMap[targetPkg] ?: 0L
            if (nowMillis < cooldownEnd) {
                val remainingSec = ((cooldownEnd - nowMillis) / 1000).toInt()
                val min = remainingSec / 60
                val sec = remainingSec % 60
                showOverlay(
                    title = "$appName LIMIT REACHED",
                    subtitle = "Take a break. Resets in %02d:%02d".format(min, sec),
                    allowExitHome = true
                )
                return
            } else if (cooldownEnd != 0L && nowMillis >= cooldownEnd) {
                cooldownUntilMap.remove(targetPkg)
                usageSecondsMap[targetPkg] = 0
            }

            val used = (usageSecondsMap[targetPkg] ?: 0) + 1
            usageSecondsMap[targetPkg] = used

            if (used >= maxSeconds) {
                cooldownUntilMap[targetPkg] = nowMillis + cooldownMillis
                showOverlay(
                    title = "$appName LIMIT REACHED",
                    subtitle = "Time's up! Locked for ${item.getInt("cooldownMinutes")} minutes.",
                    allowExitHome = true
                )
                return
            }
        }

        removeOverlay()
    }

    private fun showOverlay(title: String, subtitle: String, allowExitHome: Boolean) {
        if (overlayView != null) {
            val subText = overlayView?.findViewWithTag<TextView>("subtitle")
            subText?.text = subtitle
            return
        }

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val savedPin = prefs.getString("flutter.emergency_pin", "1234") ?: "1234"
        val bypassMinutes = prefs.getInt("flutter.emergency_duration", 10)

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#FA0A0A0A"))
            setPadding(64, 64, 64, 64)
        }

        val titleView = TextView(this).apply {
            text = title
            textSize = 22f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 20)
        }

        val subtitleView = TextView(this).apply {
            tag = "subtitle"
            text = subtitle
            textSize = 16f
            setTextColor(Color.parseColor("#B0B0B0"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 48)
        }

        layout.addView(titleView)
        layout.addView(subtitleView)

        if (allowExitHome) {
            val homeBtn = Button(this).apply {
                text = "Go to Home Screen"
                setBackgroundColor(Color.WHITE)
                setTextColor(Color.BLACK)
                setOnClickListener {
                    performGlobalAction(GLOBAL_ACTION_HOME)
                    removeOverlay()
                }
            }
            layout.addView(homeBtn)
        }

        val overrideContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            visibility = View.GONE
            setPadding(0, 32, 0, 0)
        }

        val countdownText = TextView(this).apply {
            textSize = 14f
            setTextColor(Color.parseColor("#FFCC00"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 16)
        }

        val pinInput = EditText(this).apply {
            hint = "Enter Emergency PIN"
            setHintTextColor(Color.GRAY)
            setTextColor(Color.WHITE)
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
            gravity = Gravity.CENTER
            visibility = View.GONE
        }

        val confirmUnlockBtn = Button(this).apply {
            text = "Unlock for $bypassMinutes mins"
            setBackgroundColor(Color.parseColor("#D32F2F"))
            setTextColor(Color.WHITE)
            visibility = View.GONE
            setOnClickListener {
                if (pinInput.text.toString() == savedPin) {
                    emergencyBypassUntil = System.currentTimeMillis() + (bypassMinutes * 60 * 1000L)
                    Toast.makeText(
                        this@AppBlockerService,
                        "Emergency unlock active for $bypassMinutes minutes",
                        Toast.LENGTH_LONG
                    ).show()
                    removeOverlay()
                } else {
                    Toast.makeText(this@AppBlockerService, "Incorrect PIN", Toast.LENGTH_SHORT).show()
                }
            }
        }

        overrideContainer.addView(countdownText)
        overrideContainer.addView(pinInput)
        overrideContainer.addView(confirmUnlockBtn)

        val emergencyTriggerBtn = Button(this).apply {
            text = "Emergency Work Unlock"
            setBackgroundColor(Color.TRANSPARENT)
            setTextColor(Color.parseColor("#888888"))
            textSize = 13f
            setPadding(0, 48, 0, 0)
            setOnClickListener {
                visibility = View.GONE
                overrideContainer.visibility = View.VISIBLE

                activeCountDown?.cancel()
                activeCountDown = object : CountDownTimer(30000, 1000) {
                    override fun onTick(millisUntilFinished: Long) {
                        val sec = millisUntilFinished / 1000
                        countdownText.text = "Wait ${sec}s to confirm this is an urgent work need..."
                    }

                    override fun onFinish() {
                        countdownText.text = "Enter your Emergency PIN below:"
                        pinInput.visibility = View.VISIBLE
                        confirmUnlockBtn.visibility = View.VISIBLE
                    }
                }.start()
            }
        }

        layout.addView(emergencyTriggerBtn)
        layout.addView(overrideContainer)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )

        overlayView = layout
        windowManager?.addView(layout, params)
    }

    private fun removeOverlay() {
        activeCountDown?.cancel()
        activeCountDown = null
        if (overlayView != null) {
            windowManager?.removeView(overlayView)
            overlayView = null
        }
    }

    override fun onInterrupt() {
        removeOverlay()
    }

    override fun onDestroy() {
        handler.removeCallbacks(tickerRunnable)
        removeOverlay()
        super.onDestroy()
    }
}
