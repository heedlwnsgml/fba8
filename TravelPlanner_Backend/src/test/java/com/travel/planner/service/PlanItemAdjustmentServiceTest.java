package com.travel.planner.service;
import com.travel.planner.dto.PlanRequest;
import com.travel.planner.entity.*;
import com.travel.planner.repository.*;
import org.junit.jupiter.api.*;
import org.mockito.ArgumentCaptor;
import java.util.*;
import java.time.*;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;

class PlanItemAdjustmentServiceTest {
    PlanRepository plans=mock(PlanRepository.class);PlaceRepository places=mock(PlaceRepository.class);
    PlanPersistenceService persistence=mock(PlanPersistenceService.class);PlanService engine=new PlanService();
    PlanItemAdjustmentService service=new PlanItemAdjustmentService(plans,places,persistence,engine,new RemainingDayReflow(engine));
    Plan plan;PlanRequest request;Place hotel,otherHotel,sight;
    Place p(String id,String category,double lat){var p=RemainingDayReflowTest.place(id,lat);p.setCategory(category);p.setCity("도쿄");return p;}
    Itinerary row(long id,int day,int sequence,Place place,String time,String end){var i=new Itinerary();i.setId(id);i.setDayNumber(day);i.setSequence(sequence);i.setPlace(place);i.setTime(time);i.setEndTime(end);plan.addItinerary(i);return i;}
    @BeforeEach void setup(){
        plan=new Plan();plan.setId(1L);var u=new User();u.setEmail("owner@example.com");plan.setUser(u);plan.setStartDate(LocalDate.of(2026,10,20));plan.setEndDate(LocalDate.of(2026,10,21));
        request=new PlanRequest();request.setStartDate(plan.getStartDate());request.setEndDate(plan.getEndDate());request.setCities(List.of("도쿄"));request.setTransportation("자동차");request.setPreferredStartTime(LocalTime.of(9,0));request.setPreferredEndTime(LocalTime.of(22,0));
        when(plans.findDetailById(1L)).thenReturn(Optional.of(plan));when(persistence.restoreRequest(plan)).thenReturn(request);
        hotel=p("old hotel","숙소",35.6);otherHotel=p("new hotel","숙소",35.605);sight=p("keep attraction","관광지",35.61);
        when(places.findByCityIn(anyList())).thenReturn(List.of(hotel,otherHotel,sight));
    }
    @Test void hotelReplacementUpdatesFollowingDepartureButKeepsFollowingPlaces(){
        row(1,1,1,sight,"09:00","10:00");row(2,1,2,hotel,"20:00",null);
        row(3,2,1,hotel,"09:00",null);row(4,2,2,sight,"10:00","11:00");
        var stay=new Accommodation();stay.setName(hotel.getName());stay.setPlaceId(hotel.getPlaceId());stay.setCheckIn(plan.getStartDate());stay.setCheckOut(plan.getEndDate());plan.addAccommodation(stay);
        service.replace("owner@example.com",1L,2L,otherHotel.getPlaceId(),null,"친구");
        var cap=ArgumentCaptor.forClass(List.class);
        verify(persistence).replaceDay(eq(plan),eq(2),cap.capture());
        var next=(List<PlanService.SimulatedItinerary>)cap.getValue();
        assertSame(otherHotel,next.get(0).getPlace());assertSame(sight,next.get(1).getPlace());assertEquals(60,next.get(1).getEndMin()-next.get(1).getStartMin());
        assertEquals(otherHotel.getPlaceId(),stay.getPlaceId());verify(persistence).replaceDay(eq(plan),eq(1),anyList());
    }
    @Test void airportCannotBeEditedAndUnauthorizedUserCannotWrite(){
        var airport=p("AIRPORT_NRT","공항",35.7);row(1,1,1,airport,"09:00",null);
        assertThrows(IllegalArgumentException.class,()->service.alternatives("owner@example.com",1L,1L,null,null));
        assertThrows(org.springframework.web.server.ResponseStatusException.class,()->service.replace("intruder@example.com",1L,1L,otherHotel.getPlaceId(),null,null));
        verify(persistence,never()).replaceDay(any(),anyInt(),anyList());
    }

    @Test void editingNextMorningHotelChangesOnlyItsPreviousNightAndKeepsLaterStays() {
        plan.setEndDate(plan.getStartDate().plusDays(2));request.setEndDate(plan.getEndDate());
        row(1,1,1,sight,"09:00","10:00");row(2,1,2,hotel,"20:00",null);
        row(3,2,1,hotel,"09:00",null);row(4,2,2,sight,"10:00","11:00");row(5,2,3,hotel,"20:00",null);
        row(6,3,1,hotel,"09:00",null);
        var stay=new Accommodation();stay.setName(hotel.getName());stay.setPlaceId(hotel.getPlaceId());stay.setCheckIn(plan.getStartDate());stay.setCheckOut(plan.getEndDate());plan.addAccommodation(stay);
        service.replace("owner@example.com",1L,3L,otherHotel.getPlaceId(),null,"친구");
        assertEquals(2,plan.getAccommodations().size());
        assertEquals(otherHotel.getPlaceId(),stay.getPlaceId());assertEquals(plan.getStartDate().plusDays(1),stay.getCheckOut());
        var later=plan.getAccommodations().stream().filter(a->a!=stay).findFirst().orElseThrow();
        assertEquals(hotel.getPlaceId(),later.getPlaceId());assertEquals(plan.getStartDate().plusDays(1),later.getCheckIn());
        verify(persistence,never()).replaceDay(eq(plan),eq(3),anyList());
    }
    @Test void failureOnFollowingDayDoesNotPersistEitherDayOrAccommodation() {
        otherHotel.setLatitude(36.6);
        row(1,1,1,sight,"09:00","10:00");row(2,1,2,hotel,"20:00",null);
        row(3,2,1,hotel,"09:00",null);var fixed=p("DUMMY_FIXED_SCHEDULE","고정 일정",35.6);row(4,2,2,fixed,"09:05","10:00");
        var appointment=new PlanRequest.FixedScheduleInput();appointment.setName("DUMMY_FIXED_SCHEDULE");appointment.setDayNumber(2);appointment.setStartTime(LocalTime.of(9,5));appointment.setEndTime(LocalTime.of(10,0));appointment.setLatitude(35.6);appointment.setLongitude(139.7);request.setFixedSchedules(List.of(appointment));
        var stay=new Accommodation();stay.setName(hotel.getName());stay.setPlaceId(hotel.getPlaceId());stay.setCheckIn(plan.getStartDate());stay.setCheckOut(plan.getEndDate());plan.addAccommodation(stay);
        assertThrows(IllegalArgumentException.class,()->service.replace("owner@example.com",1L,2L,otherHotel.getPlaceId(),null,null));
        verify(persistence,never()).replaceDay(any(),anyInt(),anyList());assertEquals(hotel.getPlaceId(),stay.getPlaceId());
    }

    @Test void genericSightseeingThemeIncludesAttractionsWithSpecificStoredThemes(){
        row(1,1,1,sight,"09:00","10:00");row(2,1,2,hotel,"20:00",null);
        var park=p("자연 공원","관광지",35.612);park.setTheme("자연");
        when(places.findByCityIn(anyList())).thenReturn(List.of(hotel,otherHotel,sight,park));
        var choices=service.alternatives("owner@example.com",1L,1L,"관광","친구");
        assertTrue(choices.stream().anyMatch(c->park.getPlaceId().equals(c.get("placeId"))));
    }
    @Test void hotelOverlaysRemainAnchorsInsteadOfBeingTreatedAsFreeMeals(){
        var dummy=p("DUMMY_MEAL","식사",0);
        var first=row(1,1,1,sight,"09:00","10:00");var night=row(2,1,2,dummy,"20:00",null);
        var morning=row(3,2,1,dummy,"09:00",null);row(4,2,2,sight,"10:00","11:00");
        var food=mock(SupplementalFoodService.class);
        when(food.load(anyList())).thenAnswer(call->{
            Map<Long,Place> m=new HashMap<>();
            for(Itinerary it:(List<Itinerary>)call.getArgument(0))if(it.getId()==2L || it.getId()==3L)m.put(it.getId(),hotel);
            return m;
        });
        org.springframework.test.util.ReflectionTestUtils.setField(service,"food",food);
        var stay=new Accommodation();stay.setName(hotel.getName());stay.setPlaceId(hotel.getPlaceId());stay.setCheckIn(plan.getStartDate());stay.setCheckOut(plan.getEndDate());plan.addAccommodation(stay);
        service.replace("owner@example.com",1L,2L,otherHotel.getPlaceId(),null,"친구");
        var cap=ArgumentCaptor.forClass(List.class);verify(persistence).replaceDay(eq(plan),eq(2),cap.capture());
        var next=(List<PlanService.SimulatedItinerary>)cap.getValue();
        assertEquals(PlanService.SimulatedItinerary.Type.START,next.getFirst().getType());
        assertSame(otherHotel,next.getFirst().getPlace());assertSame(sight,next.get(1).getPlace());
    }

    @Test void changingOneThemeDoesNotResetFoodTripMealSpacing(){
        row(1,1,1,sight,"09:00","10:00");row(2,1,2,hotel,"20:00",null);
        var park=p("자연 공원","관광지",35.612);park.setTheme("자연");
        when(places.findByCityIn(anyList())).thenReturn(List.of(hotel,otherHotel,sight,park));
        request.setThemes(List.of("맛집"));request.setMealCount(5);
        service.alternatives("owner@example.com",1L,1L,"관광","친구");
        assertEquals(List.of("맛집"),request.getThemes());assertEquals(5,PlanService.mealCount(request));
    }
}
