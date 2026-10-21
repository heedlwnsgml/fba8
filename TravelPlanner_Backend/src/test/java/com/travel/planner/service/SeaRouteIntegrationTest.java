package com.travel.planner.service;
import com.travel.planner.dto.*;
import com.travel.planner.entity.*;
import com.travel.planner.repository.*;
import com.travel.planner.transit.SeaRoutes;
import org.junit.jupiter.api.Test;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
class SeaRouteIntegrationTest {
 @Test void preferenceSurvivesExistingTransportColumnAndRequestRestore() throws Exception {
  var request=new tools.jackson.databind.ObjectMapper().readValue("{\"transportation\":\"대중교통\",\"interIslandTransport\":\"배\"}",PlanRequest.class);
  assertEquals("배",request.getIslandTransport());
  var plan=new Plan();plan.setTransportation(request.legTransport());
  var persistence=new PlanPersistenceService(mock(PlanRepository.class),mock(PlaceRepository.class),mock(TrafficRepository.class),mock(RailRouteService.class));
  var restored=persistence.restoreRequest(plan);
  assertEquals("대중교통",restored.getTransportation());assertEquals("배",restored.getIslandTransport());
  assertEquals(SeaRoutes.Pref.SHIP,SeaRoutes.prefOf(restored.legTransport()));
  assertTrue(Plan.class.getDeclaredField("islandTransport").isAnnotationPresent(jakarta.persistence.Transient.class));
 }
 @Test void seaFlightsKeepGroundFareInPassComparisonAndNeverTreatItAsAirfare() {
  var leg=new TransitLegDto();leg.setSource("sea");leg.setMode("비행기");leg.setFareYen(1200);
  var row=new AiRouteResponse.TimelineItem();row.setDay(1);row.setTransit(leg);
  var response=new AiRouteResponse();response.setTimeline(List.of(row));
  MobilePassCosts.apply(response,List.of(),id->null);
  assertEquals(1200,response.getTransportCosts().get("totalFareYen"));
  assertEquals(1,response.getTransportCosts().get("unknownFlightLegCount"));
  assertNull(response.getTransportCosts().get("flightFareYen"));
 }
}
