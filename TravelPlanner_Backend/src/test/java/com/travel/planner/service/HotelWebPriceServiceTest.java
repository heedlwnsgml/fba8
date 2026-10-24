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
  var file=temp.resolve("cache.sqlite");var now=Instant.parse("2026-10-17T15:00:00Z");
  var service=new HotelWebPriceService(file,Clock.fixed(now,ZoneOffset.UTC));
  service.save("p1",List.of(Map.of("yen",80000,"url","https://hotel.example/rates")));
  assertEquals(1,new HotelWebPriceService(file,Clock.fixed(now.plusSeconds(86399),ZoneOffset.UTC)).cached("p1").size());
  assertTrue(new HotelWebPriceService(file,Clock.fixed(now.plusSeconds(86400),ZoneOffset.UTC)).cached("p1").isEmpty());
 }

 @Test @SuppressWarnings("unchecked") void geminiRateLimitFallsBackToGroundedOpenAiAndKeepsOnlyLowest() throws Exception {
  var service=new HotelWebPriceService(temp.resolve("fallback.sqlite"),Clock.systemUTC());
  var http=org.mockito.Mockito.mock(java.net.http.HttpClient.class);
  var limited=org.mockito.Mockito.mock(java.net.http.HttpResponse.class);
  var success=org.mockito.Mockito.mock(java.net.http.HttpResponse.class);
  org.springframework.test.util.ReflectionTestUtils.setField(service,"http",http);
  org.springframework.test.util.ReflectionTestUtils.setField(service,"apiKey","gemini-test");
  org.springframework.test.util.ReflectionTestUtils.setField(service,"model","gemini-test");
  org.springframework.test.util.ReflectionTestUtils.setField(service,"openAiApiKey","openai-test");
  org.springframework.test.util.ReflectionTestUtils.setField(service,"openAiModel","configured-test-model");
  org.mockito.Mockito.when(limited.statusCode()).thenReturn(429);
  org.mockito.Mockito.when(success.statusCode()).thenReturn(200);
  org.mockito.Mockito.when(success.body()).thenReturn(openAiResponse("JPY 12,000 per night",12000));
  org.mockito.Mockito.when(http.send(org.mockito.ArgumentMatchers.any(java.net.http.HttpRequest.class),org.mockito.ArgumentMatchers.any(java.net.http.HttpResponse.BodyHandler.class))).thenReturn(limited,success);
  assertEquals(12000,service.search("hotel","1 Hotel Tokyo","Tokyo").getFirst().get("yen"));
  var requests=org.mockito.ArgumentCaptor.forClass(java.net.http.HttpRequest.class);
  org.mockito.Mockito.verify(http,org.mockito.Mockito.times(2)).send(requests.capture(),org.mockito.ArgumentMatchers.any(java.net.http.HttpResponse.BodyHandler.class));
  assertEquals("/v1/responses",requests.getAllValues().get(1).uri().getPath());
  assertEquals("Bearer openai-test",requests.getAllValues().get(1).headers().firstValue("Authorization").orElseThrow());
 }
 String openAiResponse(String evidence,int yen) throws Exception {
  var answer=Map.of("hotelName","1 Hotel Tokyo","offers",List.of(Map.of("provider","Official","currency","JPY","unit","room-night","yen",yen,"evidence",evidence,"url","https://hotel.example/rates")));
  return json.writeValueAsString(Map.of("status","completed","output",List.of(
   Map.of("type","web_search_call","status","completed","action",Map.of("sources",List.of(Map.of("url","https://hotel.example/rates")))),
   Map.of("type","message","content",List.of(Map.of("type","output_text","text",json.writeValueAsString(answer)))))));
 }
 @Test void openAiRejectsMultiNightTotalsEvenWhenModelLabelsThemNightly() throws Exception {
  var service=new HotelWebPriceService(temp.resolve("invalid.sqlite"),Clock.systemUTC());
  assertTrue(service.parseOpenAi(openAiResponse("JPY 126,438 for 3泊, per night",126438),"1 Hotel Tokyo").isEmpty());
  assertTrue(service.parseOpenAi(openAiResponse("JPY 12,000 per night",12000).replace("https://hotel.example/rates","https://fake.example/rates").replace("\"sources\":[{\"url\":\"https://fake.example/rates\"}]","\"sources\":[]"),"1 Hotel Tokyo").isEmpty());
 }
 @Test void previousDayPricesAreNotReusedAndPlanSnapshotSurvivesCacheExpiry() {
  var file=temp.resolve("day.sqlite");var now=Instant.parse("2026-10-18T14:59:00Z");
  var service=new HotelWebPriceService(file,Clock.fixed(now,ZoneOffset.UTC));
  service.save("hotel",List.of(Map.of("yen",9000)));
  var dto=new com.travel.planner.dto.LodgingCostDto();dto.setPlaceId("hotel");dto.setLowestNightPerRoomYen(9000);dto.setPriceAsOfDate("2026-10-18");
  service.savePlanPrices(1,List.of(dto));
  var tomorrow=new HotelWebPriceService(file,Clock.fixed(now.plusSeconds(120),ZoneOffset.UTC));
  assertTrue(tomorrow.cached("hotel").isEmpty());
  tomorrow.purgeExpired();
  assertEquals("2026-10-18",tomorrow.planPrices(1).getFirst().getPriceAsOfDate());
  assertEquals(9000,tomorrow.planPrices(1).getFirst().getLowestNightPerRoomYen());
 }

 @Test void everyVerifiedPriceIsAvailableImmediatelyAndFailuresAreListedAfterFive() {
  var file=temp.resolve("reserve.sqlite");var service=new HotelWebPriceService(file,Clock.systemUTC());
  service.recordLivePrice("hotel",9000,"https://hotel.example","2026-10-25");
  service.registerHotel("hotel","Example Hotel");
  for(int i=0;i<4;i++)service.recordPriceFailure("hotel");
  assertEquals(9000,service.reservedPrice("hotel").get("yen"));
  assertTrue(service.hotelsNeedingPrices().isEmpty());
  service.recordPriceFailure("hotel");assertEquals(9000,service.reservedPrice("hotel").get("yen"));
  assertEquals(List.of("Example Hotel"),service.hotelsNeedingPrices());
  service.recordLivePrice("hotel",8000,"https://new.example","2026-10-26");
  assertTrue(service.hotelsNeedingPrices().isEmpty());
  service.recordPriceFailure("hotel");assertEquals(8000,service.reservedPrice("hotel").get("yen"));
  var afterRestart=new HotelWebPriceService(file,Clock.fixed(Instant.parse("2026-11-01T00:00:00Z"),ZoneOffset.UTC));
  afterRestart.purgeExpired();assertEquals(8000,afterRestart.reservedPrice("hotel").get("yen"));
 }
 @Test void fiveFailuresNeverInventAPriceWithoutVerifiedHistory() {
  var service=new HotelWebPriceService(temp.resolve("empty-reserve.sqlite"),Clock.systemUTC());
  for(int i=0;i<5;i++)service.recordPriceFailure("missing");
  assertTrue(service.reservedPrice("missing").isEmpty());
 }
}
