package com.aiplanner.ai_travel_planner

import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.os.*
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URI
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** A user-started status sync: the actual itinerary calculation runs on the PC server. */
class GenerationNotificationService : Service() {
    companion object {
        private const val PROGRESS = "generation_progress"
        private const val COMPLETE = "generation_complete"
        private const val ONGOING_ID = 8300
        private var running: GenerationNotificationService? = null
        fun watch(c: Context, data: JSONObject) {
            val url = URI(data.getString("baseUrl"))
            require(url.scheme in listOf("http", "https") && url.host != null && url.userInfo == null)
            require(data.getString("id").matches(Regex("[a-f0-9]{32}")))
            val intent = Intent(c, GenerationNotificationService::class.java).putExtra("job", data.toString())
            if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(intent) else c.startService(intent)
        }
        fun finish(c: Context, data: JSONObject) { running?.terminal(data, data.optString("token")) }
        fun clear(c: Context) {
            running?.apply { jobs.clear(); token = ""; stopSelf() }
            c.getSystemService(NotificationManager::class.java).cancelAllGeneration()
        }
        private fun NotificationManager.cancelAllGeneration() {
            activeNotifications.filter { it.tag == "generation" || it.id == ONGOING_ID }.forEach { cancel(it.tag, it.id) }
        }
    }
    private val jobs = linkedMapOf<String, JSONObject>()
    private val delivered = mutableSetOf<String>()
    private var token = ""
    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadScheduledExecutor()
    override fun onBind(intent: Intent?) = null
    override fun onCreate() {
        super.onCreate(); running = this
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(PROGRESS, "일정 생성 진행", NotificationManager.IMPORTANCE_LOW))
        manager.createNotificationChannel(NotificationChannel(COMPLETE, "일정 생성 완료", NotificationManager.IMPORTANCE_DEFAULT))
        executor.scheduleWithFixedDelay({ poll() }, 1, 10, TimeUnit.SECONDS)
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val data = intent?.getStringExtra("job")?.let { JSONObject(it) }
        if (data == null) { stopSelf(); return START_NOT_STICKY }
        val next = data.getString("token")
        if (token != next) { jobs.clear(); delivered.clear(); getSystemService(NotificationManager::class.java).cancelAllGeneration() }
        token = next
        if (!delivered.contains(data.getString("id"))) jobs[data.getString("id")] = data
        startForeground(ONGOING_ID, Notification.Builder(this, PROGRESS)
            .setSmallIcon(android.R.drawable.ic_menu_compass).setContentTitle("일정을 만들고 있습니다")
            .setContentText("완성되면 알림으로 알려드립니다.").setOngoing(true).setOnlyAlertOnce(true)
            .setContentIntent(open(-1, ONGOING_ID)).build())
        return START_NOT_STICKY
    }
    private fun open(plan: Long, id: Int) = PendingIntent.getActivity(this, id,
        Intent(this, MainActivity::class.java).putExtra("generationPlanId", plan)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun poll() {
        // Snapshot and finish on the main thread, including account/logout checks.
        val snapshot = java.util.concurrent.CompletableFuture<Pair<String, List<JSONObject>>>()
        main.post { snapshot.complete(token to jobs.values.toList()) }
        val (session, work) = try { snapshot.get(2, TimeUnit.SECONDS) } catch (_: Exception) { return }
        for (job in work) {
            try {
                val url = job.getString("baseUrl").trimEnd('/') + "/api/v1/plans/generation-jobs/" + job.getString("id")
                val connection = URI(url).toURL().openConnection() as HttpURLConnection
                connection.connectTimeout = 5000; connection.readTimeout = 10000; connection.instanceFollowRedirects = false
                connection.setRequestProperty("Authorization", "Bearer $session")
                try {
                    if (connection.responseCode in listOf(401, 403)) {
                        main.post { if (token == session) clear(this) }; return
                    }
                    if (connection.responseCode != 200) continue
                    val result = connection.inputStream.bufferedReader().use { JSONObject(it.readText()) }
                    result.put("id", job.getString("id")).put("title", job.optString("title", "여행 일정"))
                    main.post { terminal(result, session) }
                } finally { connection.disconnect() }
            } catch (_: Exception) { /* USB/network reconnects must not cancel the server job. */ }
        }
    }
    private fun terminal(data: JSONObject, session: String) {
        if (token != session) return
        val status = data.optString("status")
        if (status !in listOf("SUCCEEDED", "FAILED", "CANCELLED")) return
        if (status == "CANCELLED" && data.optBoolean("cancellationPending")) return
        val id = data.getString("id")
        if (!jobs.containsKey(id) || !delivered.add(id)) return
        jobs.remove(id)
        val allowed = Build.VERSION.SDK_INT < 33 || checkSelfPermission("android.permission.POST_NOTIFICATIONS") == PackageManager.PERMISSION_GRANTED
        if (allowed && status != "CANCELLED") {
            val plan = data.optJSONObject("response")?.optLong("planId", -1) ?: data.optLong("planId", -1)
            val notificationId = 8400 + (id.hashCode() and 0x00ffffff)
            getSystemService(NotificationManager::class.java).notify("generation", notificationId,
                Notification.Builder(this, COMPLETE).setSmallIcon(android.R.drawable.ic_menu_compass)
                    .setContentTitle(if (status == "SUCCEEDED") "일정 생성 완료" else "일정 생성 확인 필요")
                    .setContentText(if (status == "SUCCEEDED") "${data.optString("title", "여행 일정")} 일정이 완성되어 저장되었습니다." else "앱에서 생성 결과를 확인해 주세요.")
                    .setAutoCancel(true).setContentIntent(open(plan, notificationId)).build())
        }
        if (jobs.isEmpty()) { stopForeground(STOP_FOREGROUND_REMOVE); stopSelf() }
    }
    override fun onTimeout(startId: Int, fgsType: Int) { stopForeground(STOP_FOREGROUND_REMOVE); stopSelf() }
    override fun onDestroy() {
        if (running === this) running = null
        token = ""; jobs.clear(); executor.shutdownNow(); main.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
}
