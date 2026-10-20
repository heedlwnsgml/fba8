package com.travel.planner.service;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import java.nio.file.Path;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
class HotelWebPriceServiceTest {
 @TempDir Path temp;
 final ObjectMapper json=new ObjectMapper();
 @Test @SuppressWarnings("unchecked") void missingPriceSearchActuallyCallsGeminiWithGoogleSearch() throws Exception {
  var service=new HotelWebPriceService(temp.resolve("search.sqlite"),Clock.systemUTC());
  var http=org.mockito.Mockito.mock(java.net.http.HttpClient.class);
  var response=org.mockito.Mockito.mock(java.net.http.HttpResponse.class);
  org.springframework.test.util.ReflectionTestUtils.setField(service,"http",http);
  org.springframework.test.util.ReflectionTestUtils.setField(service,"apiKey","test-key");
  org.springframework.test.util.ReflectionTestUtils.setField(service,"model","gemini-test");
  org.mockito.Mockito.when(http.send(org.mockito.ArgumentMatchers.any(java.net.http.HttpRequest.class),org.mockito.ArgumentMatchers.any(java.net.http.HttpResponse.BodyHandler.class))).thenReturn(response);
  org.mockito.Mockito.when(response.statusCode()).thenReturn(200);
  org.mockito.Mockito.when(response.body()).thenReturn(response("1 Hotel Tokyo",80000,"room-night","Room JPY 80,000 per night","https://hotel.example/rates",true));
  assertEquals(1,service.search("hotel-id","1 Hotel Tokyo","Tokyo").size());
  var request=org.mockito.ArgumentCaptor.forClass(java.net.http.HttpRequest.class);
  org.mockito.Mockito.verify(http).send(request.capture(),org.mockito.ArgumentMatchers.any(java.net.http.HttpResponse.BodyHandler.class));
  assertEquals("generativelanguage.googleapis.com",request.getValue().uri().getHost());
  assertTrue(request.getValue().uri().getPath().endsWith("gemini-test:generateContent"));
  assertEquals("test-key",request.getValue().headers().firstValue("x-goog-api-key").orElseThrow());
 }

 String response(String hotel,int yen,String unit,String evidence,String url,boolean cited) throws Exception {
  var quote=Map.of("provider","Official","yen",yen,"currency","JPY","unit",unit,"evidence",evidence,"url",url);
  var text=json.writeValueAsString(Map.of("hotelName",hotel,"offers",List.of(quote)));
  return json.writeValueAsString(Map.of("candidates",List.of(Map.of("content",Map.of("parts",List.of(Map.of("text",text))),"groundingMetadata",Map.of("webSearchQueries",List.of(hotel),"groundingChunks",cited?List.of(Map.of("web",Map.of("uri",url))):List.of(),"groundingSupports",cited?List.of(Map.of("groundingChunkIndices",List.of(0))):List.of())))));

 }
 @Test void admitsOnlyIdentityMatchedCitedRoomNightPrices() throws Exception {
  var service=new HotelWebPriceService(temp.resolve("cache.sqlite"),Clock.systemUTC());
  assertEquals(1,service.parse(response("１ Hotel Tokyo",80000,"room-night","Room JPY 80,000 per night","https://hotel.example/rates",true),"1 Hotel Tokyo").size());
  assertTrue(service.parse(response("Other Hotel",80000,"room-night","Room JPY 80,000 per night","https://hotel.example/rates",true),"1 Hotel Tokyo").isEmpty());
  assertTrue(service.parse(response("1 Hotel Tokyo",80000,"room-night","Room JPY 80,000 per night","https://hotel.example/rates",false),"1 Hotel Tokyo").isEmpty());
  assertTrue(service.parse(response("1 Hotel Tokyo",80000,"person-night","Room JPY 80,000 per night","https://hotel.example/rates",true),"1 Hotel Tokyo").isEmpty());
  assertTrue(service.parse(response("1 Hotel Tokyo",3000,"room-night","Parking JPY 3,000 per night","https://hotel.example/rates",true),"1 Hotel Tokyo").isEmpty());
 }
 @Test void cacheExpiresExactlyAtOneDayWithoutTouchingPrimaryDatabase() {
  var file=temp.resolve("cache.sqlite");var now=Instant.parse("2026-10-18T00:00:00Z");
  var service=new HotelWebPriceService(file,Clock.fixed(now,ZoneOffset.UTC));
  service.save("p1",List.of(Map.of("yen",80000,"url","https://hotel.example/rates")));
  assertEquals(1,new HotelWebPriceService(file,Clock.fixed(now.plusSeconds(86399),ZoneOffset.UTC)).cached("p1").size());
  assertTrue(new HotelWebPriceService(file,Clock.fixed(now.plusSeconds(86400),ZoneOffset.UTC)).cached("p1").isEmpty());
 }
}
