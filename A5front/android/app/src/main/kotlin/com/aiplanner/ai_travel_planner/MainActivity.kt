package com.aiplanner.ai_travel_planner

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var weatherChannel:MethodChannel?=null
    override fun onNewIntent(newIntent:android.content.Intent) {
        super.onNewIntent(newIntent);setIntent(newIntent)
        val plan=newIntent.getLongExtra("weatherPlanId",-1)
        if(plan>0 && weatherChannel!=null){newIntent.removeExtra("weatherPlanId");weatherChannel!!.invokeMethod("notificationTapped",plan)}
    }


    companion object {
        private const val CHANNEL =
            "ai_travel_planner/app_config"
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        weatherChannel=MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"ai_travel_planner/weather")
        weatherChannel!!.setMethodCallHandler { call, result ->
            try {
                when(call.method) {
                    "configure" -> { WeatherNotifications.configure(this,org.json.JSONObject(call.arguments as Map<*,*>));result.success(null) }
                    "getSession" -> result.success(WeatherNotifications.session(this))
                    "clear" -> { WeatherNotifications.clear(this);result.success(null) }
                    "takeTappedPlan" -> { val plan=intent.getLongExtra("weatherPlanId",-1);intent.removeExtra("weatherPlanId");result.success(if(plan>0)plan else null) }
                    else -> result.notImplemented()
                }
            }catch(e:Exception){result.error("WEATHER_SETUP","날씨 알림 설정을 적용하지 못했습니다.",null)}
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "getMapsApiKey" -> {
                    try {
                        val applicationInfo =
                            packageManager.getApplicationInfo(
                                packageName,
                                PackageManager.GET_META_DATA
                            )

                        val apiKey =
                            applicationInfo.metaData
                                ?.getString(
                                    "com.google.android.geo.API_KEY"
                                )

                        if (apiKey.isNullOrBlank()) {
                            result.error(
                                "MISSING_API_KEY",
                                "Google Maps API Key를 찾을 수 없습니다.",
                                null
                            )
                        } else {
                            result.success(apiKey)
                        }
                    } catch (e: Exception) {
                        result.error(
                            "API_KEY_ERROR",
                            e.message,
                            null
                        )
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}