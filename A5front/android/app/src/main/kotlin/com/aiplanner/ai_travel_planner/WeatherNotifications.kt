package com.aiplanner.ai_travel_planner
import android.app.*
import android.content.*
import android.os.Build
import android.content.pm.PackageManager
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.*
import java.net.HttpURLConnection
import java.net.URI
import java.time.*
import java.util.Calendar
import java.security.KeyStore
import javax.crypto.*
import javax.crypto.spec.GCMParameterSpec

object WeatherNotifications {
 private const val PREFS="weather_notifications"
 private const val KEY="travel_weather_session"
 private const val CHANNEL="travel_weather"
 private fun preferences(c:Context)=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE)
 private fun key():javax.crypto.SecretKey {
  val store=KeyStore.getInstance("AndroidKeyStore");store.load(null)
  (store.getKey(KEY,null) as? javax.crypto.SecretKey)?.let{return it}
  val generator=KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore")
  generator.init(KeyGenParameterSpec.Builder(KEY,KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());return generator.generateKey()
 }
 private fun encrypt(value:String):String {
  val cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.ENCRYPT_MODE,key())
  return Base64.encodeToString(cipher.iv,Base64.NO_WRAP)+":"+Base64.encodeToString(cipher.doFinal(value.toByteArray()),Base64.NO_WRAP)
 }
 private fun token(c:Context):String?=try {
  val parts=preferences(c).getString("token",null)?.split(":")
  if(parts==null||parts.size!=2)null else {
   val cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.DECRYPT_MODE,key(),GCMParameterSpec(128,Base64.decode(parts[0],Base64.NO_WRAP)));String(cipher.doFinal(Base64.decode(parts[1],Base64.NO_WRAP)))
  }
 }catch(e:Exception){null}
 private fun pending(c:Context,slot:Int):PendingIntent=PendingIntent.getBroadcast(c,8200+slot,Intent(c,WeatherAlarmReceiver::class.java).putExtra("slot",slot),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
 fun session(c:Context):Map<String,String?> = mapOf("token" to token(c),"baseUrl" to preferences(c).getString("baseUrl",null))
 fun clear(c:Context) {
  val manager=c.getSystemService(AlarmManager::class.java);for(slot in 0..1)manager.cancel(pending(c,slot))
  preferences(c).edit().clear().apply()
  c.getSystemService(NotificationManager::class.java).cancel("weather",8200)
 }
 fun configure(c:Context,data:JSONObject) {
  val session=data.optString("token");val enabled=data.optBoolean("enabled")
  if(session.isEmpty()){clear(c);return}
  val endpoint=URI(data.getString("baseUrl"));require(endpoint.scheme in listOf("http","https")&&endpoint.host!=null&&endpoint.userInfo==null)
  val prefs=preferences(c)
  if(token(c)!=session){clear(c)}
  prefs.edit().putString("token",encrypt(session)).putString("baseUrl",endpoint.toString()).putBoolean("enabled",enabled)
   .putString("frequency",data.optString("frequency","both")).putString("morningTime",data.optString("morningTime","08:00"))
   .putString("afternoonTime",data.optString("afternoonTime","18:00")).putString("alerts",data.optJSONArray("alerts")?.toString()?:"[]").apply()
  c.getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel(CHANNEL,"여행 날씨 알림",NotificationManager.IMPORTANCE_DEFAULT).apply{description="여행 시간대 강수확률과 일정 변경 안내"})
  schedule(c)
 }
 fun schedule(c:Context) {
  val prefs=preferences(c);val manager=c.getSystemService(AlarmManager::class.java)
  for(slot in 0..1) {
   val intent=pending(c,slot);manager.cancel(intent)
   val frequency=prefs.getString("frequency","both")
   if(!prefs.getBoolean("enabled",false)||(slot==0&&frequency=="afternoon")||(slot==1&&frequency=="morning"))continue
   val time=prefs.getString(if(slot==0)"morningTime" else "afternoonTime",if(slot==0)"08:00" else "18:00")!!.split(":")
   val date=Calendar.getInstance().apply{set(Calendar.HOUR_OF_DAY,time[0].toInt());set(Calendar.MINUTE,time[1].toInt());set(Calendar.SECOND,0);set(Calendar.MILLISECOND,0);if(timeInMillis<=System.currentTimeMillis())add(Calendar.DATE,1)}
   // No exact-alarm permission is required. Android may defer this under power saving.
   manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,date.timeInMillis,intent)
  }
 }
 private fun load(c:Context):JSONArray {
  val prefs=preferences(c);val session=token(c)?:return JSONArray()
  try {
   val conn=(java.net.URL(prefs.getString("baseUrl","")+"/api/v1/weather/alerts").openConnection() as HttpURLConnection)
   conn.connectTimeout=3000;conn.readTimeout=4000;conn.instanceFollowRedirects=false;conn.setRequestProperty("Authorization","Bearer "+session)
   try {
    if(conn.responseCode==401||conn.responseCode==403){clear(c);return JSONArray()}
    if(conn.responseCode==200) {
     val text=conn.inputStream.bufferedReader().use{it.readText()};val alerts=JSONArray(text);prefs.edit().putString("alerts",alerts.toString()).apply();return alerts
    }
   }finally{conn.disconnect()}
  }catch(e:Exception){}
  return try{JSONArray(prefs.getString("alerts","[]"))}catch(e:Exception){JSONArray()}
 }
 fun deliver(c:Context,slot:Int) {
  val prefs=preferences(c);if(!prefs.getBoolean("enabled",false))return
  if(Build.VERSION.SDK_INT>=33&&c.checkSelfPermission("android.permission.POST_NOTIFICATIONS")!=PackageManager.PERMISSION_GRANTED)return
  val today=LocalDate.now();val stamp=today.toString()+":"+slot
  if(prefs.getString("last","")==stamp)return
  val alerts=load(c);val candidates=mutableListOf<JSONObject>()
  for(i in 0 until alerts.length()) {
   val a=alerts.getJSONObject(i)
   try {
    val date=LocalDate.parse(a.getString("date"));val fetched=Instant.parse(a.getString("fetchedAt"));val valid=Instant.parse(a.getString("validUntil"))
    if(!date.isBefore(today)&&!date.isAfter(today.plusDays(5))&&valid.isAfter(Instant.now())&&fetched.isAfter(Instant.now().minusSeconds(129600)))candidates.add(a)
   }catch(e:Exception){}
  }
  val alert=candidates.minByOrNull{it.optString("date")}?:return
  val plan=alert.getLong("planId")
  val open=PendingIntent.getActivity(c,8200,Intent(c,MainActivity::class.java).putExtra("weatherPlanId",plan).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
  val body="${alert.optString("date")} ${alert.optString("city")} 강수확률 ${alert.optInt("precipitationProbability")}% · ${alert.optString("description")}\n일정을 변경하시겠습니까?"
  val notification=Notification.Builder(c,CHANNEL).setSmallIcon(android.R.drawable.ic_menu_compass).setContentTitle(alert.optString("title")+" 날씨 안내").setContentText(body)
   .setStyle(Notification.BigTextStyle().bigText(body)).setContentIntent(open).setAutoCancel(true)
   .addAction(Notification.Action.Builder(android.R.drawable.ic_menu_edit,"일정 확인·변경",open).build()).build()
  c.getSystemService(NotificationManager::class.java).notify("weather",8200,notification)
  prefs.edit().putString("last",stamp).apply()
 }
}

class WeatherAlarmReceiver:BroadcastReceiver() {
 override fun onReceive(context:Context,intent:Intent) {
  if(intent.action==Intent.ACTION_BOOT_COMPLETED){WeatherNotifications.schedule(context);return}
  val pending=goAsync()
  Thread {
   try{WeatherNotifications.deliver(context,intent.getIntExtra("slot",0))}finally{WeatherNotifications.schedule(context);pending.finish()}
  }.start()
 }
}
