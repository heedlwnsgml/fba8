package com.travel.planner.service;
import com.travel.planner.dto.*;
import com.travel.planner.entity.*;
import com.travel.planner.repository.*;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
class OvernightLodgingTest {
    private Place hotel(String city,String id,double lat,double lng) {
        Place p=TestPlaces.place(id,id,city,lat,lng,"숙소","숙소",TestPlaces.H_24);p.setId(123L);return p;
    }
    private PlanGenerationService generator(PlaceRepository repository,GoogleMapsService maps,LodgingCatalog catalog) {
        var service=new PlanGenerationService(new PlanService(),mock(PlanValidationService.class),mock(PlanPersistenceService.class),mock(TimelineAssembler.class),repository,mock(UserRepository.class),maps,mock(WeatherService.class),mock(PlaceDescriptionService.class),mock(PlaceNameService.class),mock(RailRouteService.class),mock(PassAdvisorService.class));
        ReflectionTestUtils.setField(service,"lodgingCatalog",catalog);return service;
    }
    @Test void gapsAreFilledWithoutChangingSpecifiedHotelAndConsecutiveDaysShareTheSameHotel() {
        Place first=hotel("오사카","confirmed",34.6687,135.5013),second=hotel("교토","recommended",35.0023,135.7671);
        var maps=mock(GoogleMapsService.class);var catalog=mock(LodgingCatalog.class);when(catalog.recommended("교토")).thenReturn(List.of(second));
        var request=new PlanRequest();request.setStartDate(LocalDate.of(2026,10,20));request.setEndDate(request.getStartDate().plusDays(2));request.setCities(List.of("오사카","교토"));request.setThemes(List.of("관광"));request.setTransportation("대중교통");
        Map<Integer,Place> nights=new HashMap<>();nights.put(1,first);List<Accommodation> entities=new ArrayList<>();
        ReflectionTestUtils.invokeMethod(generator(mock(PlaceRepository.class),maps,catalog),"suggestHotels",request,3,List.of("오사카","교토","교토"),Map.of("교토",new double[]{35.0023,135.7671}),"오사카",nights,entities,new ArrayList<String>());
        assertSame(first,nights.get(1));assertSame(second,nights.get(2));assertEquals(1,entities.size());
        assertEquals(request.getStartDate().plusDays(1),entities.getFirst().getCheckIn());assertEquals(request.getEndDate(),entities.getFirst().getCheckOut());verifyNoInteractions(maps);
        var input=new PlanService.TripInput();input.request=request;input.candidates=new ArrayList<>(TestPlaces.osaka());input.candidates.addAll(TestPlaces.kyoto());input.lodgingByNight=nights;input.dayCities=List.of("오사카","교토","교토");
        var trip=new PlanService().planTrip(input);PlanGenerationService.validateOvernightAnchors(trip);
        assertSame(first,trip.getDays().get(0).getItems().getLast().getPlace());assertSame(first,trip.getDays().get(1).getItems().getFirst().getPlace());
        assertSame(second,trip.getDays().get(1).getItems().getLast().getPlace());assertSame(second,trip.getDays().get(2).getItems().getFirst().getPlace());
        assertNotEquals(PlanService.SimulatedItinerary.Type.END,trip.getDays().get(2).getItems().getLast().getType());
    }
    @Test void primaryHotelsWinWithoutReadingOlderHotels() {
        var repo=mock(PlaceRepository.class);var jdbc=mock(org.springframework.jdbc.core.JdbcTemplate.class);Place primary=hotel("오사카","primary",34.6687,135.5013);when(repo.findByCity("오사카")).thenReturn(List.of(primary));
        assertEquals(List.of(primary),new LodgingCatalog(repo,jdbc).recommended("오사카"));verifyNoInteractions(jdbc);
    }
    @Test void missingHotelsFailInsteadOfSavingAnUnanchoredTrip() {
        var maps=mock(GoogleMapsService.class);var catalog=mock(LodgingCatalog.class);when(catalog.recommended("없는도시")).thenReturn(List.of());when(maps.searchRecommendedHotels("없는도시")).thenReturn(List.of());
        var request=new PlanRequest();request.setStartDate(LocalDate.of(2026,10,20));request.setEndDate(request.getStartDate().plusDays(1));
        assertThrows(PlanGenerationException.class,()->ReflectionTestUtils.invokeMethod(generator(mock(PlaceRepository.class),maps,catalog),"suggestHotels",request,2,List.of("없는도시","없는도시"),Map.of(),"없는도시",new HashMap<Integer,Place>(),new ArrayList<Accommodation>(),new ArrayList<String>()));
    }
    @Test void lastDayEndsAtAirportWhenSpecified() {
        var input=PlanServiceTest.osakaTrip(3,"오전","오후","관광");var trip=new PlanService().planTrip(input);
        PlanGenerationService.validateOvernightAnchors(trip);var last=trip.getDays().getLast().getItems().getLast();
        assertEquals(PlanService.SimulatedItinerary.Type.END,last.getType());assertTrue(PlanService.isAirport(last.getPlace()));
    }
}
