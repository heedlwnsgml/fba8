package com.travel.planner.service;
import com.travel.planner.entity.*;
import com.travel.planner.repository.*;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;
import java.time.LocalDate;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class SavedPlanQueryServiceTest {
    private final PlanRepository plans=mock(PlanRepository.class);
    private final TrafficRepository traffic=mock(TrafficRepository.class);
    private final RailRouteService routes=mock(RailRouteService.class);
    private final SavedPlanQueryService service=new SavedPlanQueryService(plans,traffic,routes);
    private Plan plan(long id,String email) {
        Plan p=new Plan();p.setId(id);p.setTitle("여행");p.setStartDate(LocalDate.of(2026,10,11));p.setEndDate(p.getStartDate());
        User u=new User();u.setEmail(email);p.setUser(u);return p;
    }
    @Test void emptyUserHasNoTrips() {
        when(plans.findAllByUserEmail("new")).thenReturn(List.of());
        assertEquals(List.of(),service.list("new"));verifyNoInteractions(traffic);
    }
    @Test void newestFirstAndNoEntitySerialization() {
        when(plans.findAllByUserEmail("me")).thenReturn(List.of(plan(1,"me"),plan(3,"me")));
        var result=service.list("me");assertEquals(3L,result.get(0).get("id"));assertFalse(result.get(0).containsKey("user"));
    }
    @Test void cannotReadAnotherUsersTrip() {
        when(plans.findDetailById(1L)).thenReturn(Optional.of(plan(1,"other")));
        var error=assertThrows(ResponseStatusException.class,()->service.detail("me",1L));
        assertEquals(403,error.getStatusCode().value());verifyNoInteractions(traffic);
    }
    @Test void returnsStoredTimelineAndTransportWithoutWrites() {
        Plan p=plan(1,"me");Place place=new Place();place.setName("장소");place.setLatitude(35.0);place.setLongitude(139.0);
        Itinerary i=new Itinerary();i.setId(5L);i.setDayNumber(1);i.setSequence(1);i.setTime("09:00");i.setPlace(place);p.getItineraries().add(i);
        Traffic t=new Traffic();t.setItinerary(i);t.setDurationMinutes(12);t.setEstimatedCost(220);t.setTransportType("버스");
        when(plans.findDetailById(1L)).thenReturn(Optional.of(p));when(traffic.findByItineraryIn(p.getItineraries())).thenReturn(List.of(t));
        var detail=service.detail("me",1L);assertTrue(detail.containsKey("request"));
        var response=(Map<?,?>)detail.get("response");var row=(Map<?,?>)((List<?>)response.get("timeline")).get(0);
        assertEquals("장소",row.get("placeName"));assertEquals(12,row.get("travelMinutes"));
        verify(plans).findDetailById(1L);verify(traffic).findByItineraryIn(p.getItineraries());verifyNoMoreInteractions(plans,traffic);
    }
    @Test void resolvesStoredTripsUsingDatabaseRoutesAndDoesNotConnectDifferentDays() {
        Plan p=plan(2,"me");p.setTransportation("도보 및 대중교통");
        Place from=new Place();from.setName("숙소");from.setLatitude(35.68);from.setLongitude(139.76);
        Place to=new Place();to.setName("공원");to.setLatitude(35.69);to.setLongitude(139.77);
        Itinerary a=new Itinerary();a.setId(10L);a.setDayNumber(1);a.setSequence(1);a.setTime("09:00");a.setEndTime("09:30");a.setPlace(from);
        Itinerary b=new Itinerary();b.setId(11L);b.setDayNumber(1);b.setSequence(2);b.setTime("10:00");b.setPlace(to);
        Itinerary c=new Itinerary();c.setId(12L);c.setDayNumber(2);c.setSequence(1);c.setTime("09:00");c.setPlace(to);
        p.getItineraries().addAll(List.of(a,b,c));
        var route=new com.travel.planner.dto.TransitLegDto();route.setSource("gtfs");route.setMinutes(30);
        var step=new com.travel.planner.dto.TransitLegDto.Step();step.setType("승차");step.setCategory("버스");step.setMinutes(30);route.getSteps().add(step);
        when(plans.findDetailById(2L)).thenReturn(Optional.of(p));when(traffic.findByItineraryIn(p.getItineraries())).thenReturn(List.of());
        when(routes.leg(from,to,"도보 및 대중교통",0,p.getStartDate(),570)).thenReturn(route);
        var detail=service.detail("me",2L);
        var rows=(List<?>)((Map<?,?>)detail.get("response")).get("timeline");
        assertSame(route,((Map<?,?>)rows.get(1)).get("transit"));
        assertFalse(((Map<?,?>)rows.get(2)).containsKey("transit"));
        verify(routes).leg(from,to,"도보 및 대중교통",0,p.getStartDate(),570);
        verifyNoMoreInteractions(routes);verify(traffic,never()).save(any());verify(plans,never()).save(any());
    }

}
