package com.travel.planner.service;
import com.travel.planner.entity.Place;
import org.junit.jupiter.api.Test;
import java.time.LocalDate;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class MealCandidateRecoveryTest {
    Place restaurant(String id,double latitude){var p=new Place();p.setPlaceId(id);p.setName("실제 식당");p.setCategory("식음");p.setCity("도쿄");p.setLatitude(latitude);p.setLongitude(139.7968);return p;}
    PlanService.TripPlan trip(Place meal){
        var trip=new PlanService.TripPlan();var day=new PlanService.DayPlan(1,LocalDate.of(2026,10,19),"도쿄");trip.getDays().add(day);
        var before=restaurant("before",35.711);before.setCategory("관광지");before.setName("아사쿠사");
        day.getItems().add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.VISIT,before,null,750,780,0,35.711,139.7968));
        day.getItems().add(new PlanService.SimulatedItinerary(meal==null?PlanService.SimulatedItinerary.Type.MEAL:PlanService.SimulatedItinerary.Type.VISIT,meal,meal==null?"점심 식사 (주변 자유 식사)":null,786,846,0,35.711,139.7968));return trip;
    }
    @Test void existingRestaurantDoesNotTriggerMoreSearches(){
        var google=mock(GoogleMapsService.class);var food=mock(SupplementalFoodService.class);var engine=mock(PlanService.class);var plan=trip(restaurant("meal",35.711));
        assertSame(plan,new MealCandidateRecovery(google,food).complete(new PlanService.TripInput(),plan,engine));verifyNoInteractions(google,food,engine);
    }
    @Test void nearbyRestaurantsAreAddedAndTheWholeScheduleIsRevalidated(){
        var google=mock(GoogleMapsService.class);var food=mock(SupplementalFoodService.class);var engine=mock(PlanService.class);var meal=restaurant("meal",35.712);
        when(google.findNearbyRestaurants(anyString(),anyDouble(),anyDouble())).thenReturn(List.of(meal));
        when(food.cacheSearchResults(eq("도쿄"),anyList())).thenReturn(List.of(meal));var valid=trip(meal);when(engine.planTrip(any())).thenReturn(valid);
        var input=new PlanService.TripInput();assertSame(valid,new MealCandidateRecovery(google,food).complete(input,trip(null),engine));assertTrue(input.candidates.contains(meal));verify(engine).planTrip(input);
    }
    @Test void distantSearchResultsNeverBecomeFakeLocalMeals(){
        var google=mock(GoogleMapsService.class);var food=mock(SupplementalFoodService.class);var engine=mock(PlanService.class);
        when(google.findNearbyRestaurants(anyString(),anyDouble(),anyDouble())).thenReturn(List.of(restaurant("distant",36.5)));
        when(food.cacheSearchResults(anyString(),anyList())).thenAnswer(inv->inv.getArgument(1));
        assertThrows(PlanGenerationException.class,()->new MealCandidateRecovery(google,food).complete(new PlanService.TripInput(),trip(null),engine));verifyNoInteractions(engine);
    }
}
