package com.aiplanner.ai_travel_planner

import android.app.Instrumentation
import android.app.NotificationManager
import android.content.Intent
import android.os.Bundle
import org.json.JSONObject
import java.net.ServerSocket
import java.util.concurrent.atomic.AtomicBoolean

/** Runs only in the test APK, against a local fake job endpoint (no production credentials). */
class GenerationNotificationInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); start() }
    override fun onStart() {
        val output = Bundle()
        val server = ServerSocket(0)
        val complete = AtomicBoolean(false)
        val alive = AtomicBoolean(true)
        val endpoint = Thread {
            while (alive.get()) {
                try { server.accept().use { socket ->
                    socket.soTimeout = 3000
                    val reader = socket.getInputStream().bufferedReader()
                    while (true) { val line = reader.readLine() ?: break; if (line.isEmpty()) break }
                    val body = if (complete.get()) """{"status":"SUCCEEDED","response":{"planId":42}}""" else """{"status":"RUNNING"}"""
                    val bytes = body.toByteArray()
                    socket.getOutputStream().apply {
                        write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: ${bytes.size}\r\nConnection: close\r\n\r\n".toByteArray()); write(bytes); flush()
                    }
                }} catch (_: Exception) {}
            }
        }.apply { isDaemon = true; start() }
        try {
            val c = targetContext
            c.startActivity(Intent(c, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            Thread.sleep(3000)
            val data = JSONObject().put("id", "a".repeat(32)).put("title", "백그라운드 알림 검증")
                .put("token", "local-test-session").put("baseUrl", "http://127.0.0.1:${server.localPort}")
            runOnMainSync { GenerationNotificationService.watch(c, data) }
            Thread.sleep(1500)
            c.startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            complete.set(true)
            val manager = c.getSystemService(NotificationManager::class.java)
            val end = System.currentTimeMillis() + 25000
            while (System.currentTimeMillis() < end && manager.activeNotifications.none { it.tag == "generation" }) Thread.sleep(200)
            val posted = manager.activeNotifications.filter { it.tag == "generation" }
            check(posted.size == 1) { "Expected one completion notification after Home" }
            check(posted.single().notification.extras.getString("android.title") == "일정 생성 완료")
            check(manager.activeNotifications.none { it.id == 8300 }) { "Progress notification should stop on completion" }
            runOnMainSync { GenerationNotificationService.clear(c) }
            check(manager.activeNotifications.none { it.tag == "generation" }) { "Logout must clear generation notifications" }
            output.putString("result", "PASS: Home background completion notification, stopped progress, session cleanup")
            finish(-1, output)
        } catch (failure: Throwable) {
            output.putString("error", failure.toString()); finish(0, output)
        } finally { alive.set(false); server.close(); endpoint.interrupt() }
    }
}
