package com.travel.planner.service;
import com.travel.planner.entity.Place;
import com.travel.planner.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.web.client.RestTemplate;
import org.springframework.http.HttpEntity;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
class CandidateRecoveryRevisionTest {
 @Test void longLandTransferUsesSpareNightsWithoutRemovingDestination(){
  Map<String,Integer> times=Map.of("삿포로→다카마쓰",1101,"삿포로→센다이",450,"센다이→다카마쓰",650,"센다이→도쿄",200,"도쿄→다카마쓰",450);
  var result=LandStopoverPlanner.split(List.of("삿포로","다카마쓰","다카마쓰","다카마쓰"),Set.of(),List.of("센다이","도쿄"),(a,z)->times.getOrDefault(a+"→"+z,Integer.MAX_VALUE),480);
  assertEquals(List.of("삿포로","센다이","도쿄","다카마쓰"),result);
 }
 @Test void fixedHotelsAndLastDestinationStayCannotBeReplaced(){
  var original=List.of("삿포로","다카마쓰","다카마쓰");
  assertEquals(original,LandStopoverPlanner.split(original,Set.of(2),List.of("도쿄"),(a,z)->a.equals("삿포로")&&z.equals("다카마쓰")?1100:400,480));
  assertEquals(List.of("삿포로","다카마쓰"),LandStopoverPlanner.split(List.of("삿포로","다카마쓰"),Set.of(),List.of("도쿄"),(a,z)->1100,480));
 }
 @Test void coordinateLessMealSearchesFromPreviousStopAndUsesSupplementalCatalogue(){
  var google=mock(GoogleMapsService.class);var food=mock(SupplementalFoodService.class);var engine=mock(PlanService.class);
  var before=new Place();before.setLatitude(35.68);before.setLongitude(139.76);before.setCity("도쿄");before.setName("공원");before.setCategory("관광지");
  var restaurant=new Place();restaurant.setName("현지 식당");restaurant.setPlaceId("real-meal");restaurant.setCategory("식음");restaurant.setLatitude(35.681);restaurant.setLongitude(139.76);
  var initial=new PlanService.TripPlan();var day=new PlanService.DayPlan(1,null,"도쿄");initial.getDays().add(day);
  day.getItems().add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.VISIT,before,null,600,660,0,35.68,139.76));
  day.getItems().add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.MEAL,null,"식사",690,750,0,null,null));
  when(google.findNearbyRestaurants("도쿄",35.68,139.76)).thenReturn(List.of(restaurant));when(food.cacheSearchResults(eq("도쿄"),anyList())).thenReturn(List.of(restaurant));
  var complete=new PlanService.TripPlan();when(engine.planTrip(any())).thenReturn(complete);var input=new PlanService.TripInput();
  assertSame(complete,new MealCandidateRecovery(google,food).complete(input,initial,engine));assertTrue(input.candidates.contains(restaurant));verify(engine).planTrip(input);
 }
 @Test void nearbyHotelsNeedLocationButNotInventedOpeningHours(){
  var rest=mock(RestTemplate.class);var google=new GoogleMapsService(rest);
  when(rest.postForObject(anyString(),any(HttpEntity.class),eq(String.class))).thenReturn("{\"places\":[{\"id\":\"hotel\",\"displayName\":{\"text\":\"실제 호텔\"},\"location\":{\"latitude\":36.75,\"longitude\":139.6},\"primaryType\":\"lodging\"}]}");
  var found=google.searchHotelsNear(36.75,139.6,2500,"닛코");assertEquals(1,found.size());assertNull(found.getFirst().getOpeningHours());assertEquals("숙소",found.getFirst().getCategory());
 }
 @Test void newAttractionsReduceFreeTimeOnlyAfterEngineValidation(){
  var google=mock(GoogleMapsService.class);var engine=mock(PlanService.class);var persistence=mock(PlanPersistenceService.class);
  var initial=new PlanService.TripPlan();var day=new PlanService.DayPlan(1,null,"도쿄");initial.getDays().add(day);
  var anchor=new Place();anchor.setName("숙소");anchor.setLatitude(35.68);anchor.setLongitude(139.76);
  day.getItems().add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.START,anchor,null,540,null,0,35.68,139.76));
  day.getItems().add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.FREE,null,"자유",600,900,0,null,null));
  var sight=new Place();sight.setPlaceId("real-sight");when(google.searchAttractionsNear(35.68,139.76,4000,"도쿄")).thenReturn(List.of(sight));when(persistence.upsertPlace(sight)).thenReturn(sight);
  var better=new PlanService.TripPlan();when(engine.planTrip(any())).thenReturn(better);
  var service=new PlanGenerationService(engine,null,persistence,null,null,null,google,null,null,null,null,null);var input=new PlanService.TripInput();
  assertSame(better,service.fillAttractionGaps(input,initial));assertTrue(input.candidates.contains(sight));verify(engine).planTrip(input);
 }
}
