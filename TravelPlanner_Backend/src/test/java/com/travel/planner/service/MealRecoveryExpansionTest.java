package com.travel.planner.service;
import com.travel.planner.dto.PlanRequest;
import com.travel.planner.entity.Place;
import org.junit.jupiter.api.Test;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
class MealRecoveryExpansionTest {
 Place place(String id,double lng){var p=new Place();p.setPlaceId(id);p.setName(id);p.setCategory("식음");p.setTheme("맛집");p.setCity("도쿄");p.setLatitude(35.68);p.setLongitude(lng);p.setOpeningHours("월요일: 오전 11:00 ~ 오후 10:00");return p;}
 PlanService.TripPlan gap(Place origin){var plan=new PlanService.TripPlan();var day=new PlanService.DayPlan(1,null,"도쿄");plan.getDays().add(day);day.getItems().add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.VISIT,origin,null,1020,1080,0,origin.getLatitude(),origin.getLongitude()));day.getItems().add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.MEAL,null,"저녁",1080,1140,0,origin.getLatitude(),origin.getLongitude()));return plan;}
 @Test void expandsEvenWhenTheFirstSearchAddsNothing(){
  var google=mock(GoogleMapsService.class);var food=mock(SupplementalFoodService.class);var engine=mock(PlanService.class);
  var origin=place("origin",139.76);var restaurant=place("real-restaurant",139.79);var input=new PlanService.TripInput();input.request=new PlanRequest();
  when(google.findNearbyRestaurants("도쿄",35.68,139.76)).thenReturn(List.of());
  when(google.searchRestaurantsNear(35.68,139.76,4000,"도쿄")).thenReturn(List.of(restaurant));
  when(food.cacheSearchResults(eq("도쿄"),anyList())).thenAnswer(c->c.getArgument(1));
  var complete=new PlanService.TripPlan();when(engine.planTrip(input)).thenReturn(complete);
  assertSame(complete,new MealCandidateRecovery(google,food).complete(input,gap(origin),engine));
  verify(google).searchRestaurantsNear(35.68,139.76,4000,"도쿄");assertTrue(input.candidates.contains(restaurant));
 }
 @Test void usesExistingNearbyRestaurantInShortOpenWindowWithoutMovingNextStop(){
  var origin=place("origin",139.76);var restaurant=place("restaurant",139.761);var plan=gap(origin);var day=plan.getDays().getFirst();
  day.getItems().add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.END,origin,null,1140,null,0,35.68,139.76));
  var input=new PlanService.TripInput();input.request=new PlanRequest();input.request.setTransportation("대중교통");input.candidates.add(restaurant);
  new MealCandidateRecovery(mock(GoogleMapsService.class),mock(SupplementalFoodService.class)).fillExistingSlots(input,plan);
  var meal=day.getItems().get(1);assertSame(restaurant,meal.getPlace());assertTrue(meal.getEndMin()-meal.getStartMin()>=30);assertTrue(meal.getEndMin()<1140);assertEquals(1140,day.getItems().getLast().getStartMin());
 }
 @Test void closedAndForbiddenRestaurantsNeverReplaceMeal(){
  var origin=place("origin",139.76);var forbidden=place("forbidden",139.761);forbidden.setTheme("사진");
  var plan=gap(origin);var input=new PlanService.TripInput();input.request=new PlanRequest();input.request.setExcludedThemes(List.of("사진"));input.candidates.add(forbidden);
  new MealCandidateRecovery(mock(GoogleMapsService.class),mock(SupplementalFoodService.class)).fillExistingSlots(input,plan);
  assertTrue(MealCandidateRecovery.missing(plan.getDays().getFirst().getItems().get(1)));
 }
}
