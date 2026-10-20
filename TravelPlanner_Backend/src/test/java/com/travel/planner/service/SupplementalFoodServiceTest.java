package com.travel.planner.service;
import com.travel.planner.entity.*;
import com.travel.planner.dto.*;
import com.travel.planner.repository.*;
import com.travel.planner.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.test.util.ReflectionTestUtils;
import java.time.LocalDate;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
@SpringBootTest
@Transactional
class SupplementalFoodServiceTest {
    @Autowired SupplementalFoodService food;
    @Autowired PlaceRepository places;
    @Autowired PlanRepository plans;
    @Autowired TrafficRepository traffic;
    @Test void primaryPlaceIdentityWinsOverOldSupplement() {
        Place old=food.candidates("닛코").getFirst();Place primary=new Place();primary.setPlaceId(old.getPlaceId());primary.setName("Primary entry");
        List<Place> candidates=new ArrayList<>(List.of(primary));food.supplement(candidates,List.of("닛코"));
        assertSame(primary,candidates.stream().filter(p->old.getPlaceId().equals(p.getPlaceId())).findFirst().orElseThrow());
        assertEquals(1,candidates.stream().filter(p->old.getPlaceId().equals(p.getPlaceId())).count());
    }
    @Test void wednesdayLunchAndDinnerFindOpenRestaurantsAndFitExistingWindows() {
        Plan plan=new Plan();plan.setStartDate(LocalDate.of(2026,10,12));plan.setTransportation("도보 및 대중교통");
        Place previous=new Place();previous.setCity("닛코");previous.setLatitude(36.7544652);previous.setLongitude(139.6009041);
        Set<String> used=new HashSet<>();
        for(String clock:List.of("11:50","18:25")) {
            Itinerary item=new Itinerary();item.setDayNumber(3);item.setTime(clock);item.setEndTime(TimeUtil.format(TimeUtil.parseClock(clock)+60));
            Place meal=food.mealAt(plan,item,previous,previous,used,List.of());assertNotNull(meal,clock);
            assertTrue(PlaceKind.of(meal).isFood());
            int[] window=food.mealWindow(plan,item,previous,meal,previous);assertTrue(window[1]-window[0]>=30);
            assertTrue(window[0]>=TimeUtil.parseClock(clock));assertTrue(window[1]<=TimeUtil.parseClock(item.getEndTime()));used.add(meal.getPlaceId());
        }
    }
    @Test void saveAndReplaceKeepSupplementalDetailsWithoutChangingPrimaryPlaces() {
        long originalCount=places.count();Place restaurant=food.candidates("닛코").getFirst();
        restaurant.setLastUpdated(java.time.LocalDateTime.of(2026,10,12,12,30));
        var routes=mock(RailRouteService.class);when(routes.legsFor(anyList(),anyString(),any())).thenAnswer(inv->new ArrayList<>(Collections.nCopies(((List<?>)inv.getArgument(0)).size(),null)));
        var persistence=new PlanPersistenceService(plans,places,traffic,routes);ReflectionTestUtils.setField(persistence,"supplementalFood",food);
        var request=new PlanRequest();request.setCities(List.of("닛코"));request.setStartDate(LocalDate.of(2026,10,14));request.setEndDate(request.getStartDate());request.setTransportation("대중교통");
        var day=new PlanService.DayPlan(1,request.getStartDate(),"닛코");
        day.getItems().add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.VISIT,restaurant,null,720,780,5,restaurant.getLatitude(),restaurant.getLongitude()));
        Plan saved=persistence.saveNewPlan(null,request,List.of(day),List.of(),"test");
        Itinerary item=saved.getItineraries().getFirst();assertNotNull(item.getPlace());
        assertEquals(restaurant.getPlaceId(),food.load(List.of(item)).get(item.getId()).getPlaceId());
        assertEquals(restaurant.getLastUpdated(),food.load(List.of(item)).get(item.getId()).getLastUpdated());
        persistence.replaceDay(saved,1,day.getItems());
        Itinerary replaced=saved.getItineraries().getFirst();assertEquals(restaurant.getAddress(),food.load(List.of(replaced)).get(replaced.getId()).getAddress());
        assertEquals(originalCount,places.count());
    }
}
