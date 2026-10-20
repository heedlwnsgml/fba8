package com.travel.planner.service;
import com.travel.planner.entity.Place;
import org.junit.jupiter.api.Test;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class HotelRecommendationTest {
 Place hotel(String id,double latitude,boolean detailed){
  Place p=new Place();p.setName(id);p.setPlaceId(id);p.setCategory("숙소");p.setLatitude(latitude);p.setLongitude(139.75);
  p.setAddress("실제 호텔 주소");p.setPhone("실제 전화번호");if(detailed)p.setSummary("강변 전망과 실내 수영장을 갖춘 호텔");return p;
 }
 @Test void closeAlternativesAvoidRepeatedRecommendationButDoNotSendTravelersAcrossTheCity(){
  Place previous=hotel("previous",35.68,true),alternative=hotel("alternative",35.685,true),far=hotel("far",35.73,true);
  var candidates=List.of(previous,alternative,far);double[] center={35.68,139.75};
  assertSame(previous,HotelRecommendation.selectNearby(candidates,center,Set.of(),null));
  assertSame(alternative,HotelRecommendation.selectNearby(candidates,center,Set.of("previous"),null));
  assertSame(previous,HotelRecommendation.selectNearby(List.of(previous,far),center,Set.of("previous"),null));
 }
 @Test void individualFeaturesWinAmongNearbyCandidatesWithoutInventingOpeningHours(){
  Place empty=hotel("empty",35.68,false),known=hotel("known",35.681,true);
  assertSame(known,HotelRecommendation.selectNearby(List.of(empty,known),new double[]{35.68,139.75},Set.of(),null));
  assertNull(known.getOpeningHours());
 }
 @Test void officialStayTimesAreShownSeparatelyFromGuessedOpeningHours(){
  var jdbc=mock(org.springframework.jdbc.core.JdbcTemplate.class);
  when(jdbc.queryForList(anyString(),eq("tokyo1"))).thenReturn(List.of(Map.of("check_in","15:00","check_out","12:00")));
  var descriptions=new KoreanPlaceDescriptions(jdbc);Place hotel=hotel("tokyo1",35.68,false);
  assertEquals("체크인 15:00 · 체크아웃 12:00",descriptions.hours(hotel,java.time.LocalDate.of(2026,10,12)));
  assertEquals("체크인 15:00 · 체크아웃 12:00",descriptions.hours(hotel,java.time.LocalDate.of(2026,10,13)));
  verify(jdbc,times(1)).queryForList(anyString(),eq("tokyo1"));assertNull(hotel.getOpeningHours());
 }
}
