package com.travel.planner.service;
import com.travel.planner.util.*;
import com.travel.planner.dto.*;
import com.travel.planner.entity.Place;
import com.travel.planner.repository.PlaceRepository;
import com.travel.planner.transit.*;
import org.junit.jupiter.api.Test;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class IslandTravelTest {
 final TransitLegPlanner.Names names=new TransitLegPlanner.Names(){public String station(String s){return s;}public String line(String s){return s;}public String operator(String s){return s;}};
 @Test void connectedMainIslandsAreNotMarkedAsFlights(){
  assertFalse(IslandTravel.crossesSea(35.68,139.76,43.05,141.35));
  assertFalse(IslandTravel.crossesSea(26.21,127.68,26.59,127.97));
  assertTrue(IslandTravel.crossesSea(43.05,141.35,24.8,125.28));
 }
 @Test void sapporoMiyakoUsesAirSpeedNotMillionYenTaxi(){
  var leg=TransitLegPlanner.plan(null,null,names,43.05,141.35,"삿포로",24.8,125.28,"미야코지마","대중교통",5877,null,null);
  assertEquals("distance-flight",leg.getSource());assertNull(leg.getFareYen());assertTrue(leg.getMinutes()>150 && leg.getMinutes()<500);
  assertEquals(FlightTransferService.minutes(leg.getDistanceKm()),leg.getMinutes());assertTrue(leg.isEstimated());
  assertTrue(leg.getFareRides().isEmpty());assertEquals("비행기",leg.getSteps().getFirst().getCategory());
 }
 @Test void ordinaryWalkingOnMiyakoStillWorks(){
  var leg=TransitLegPlanner.plan(null,null,names,24.8,125.28,"A",24.801,125.281,"B","대중교통",5,null,null);
  assertEquals("walk",leg.getSource());assertTrue(leg.getMinutes()>=3);assertEquals(0,leg.getFareYen());
 }
 @Test void airportAccessFlightAndArrivalAreRepairedWithinTheDay() throws Exception {
  var repository=mock(PlaceRepository.class);var persistence=mock(PlanPersistenceService.class);
  when(repository.findByPlaceId(anyString())).thenReturn(Optional.empty());when(persistence.upsertPlace(any())).thenAnswer(c->c.getArgument(0));
  var flights=new FlightTransferService(repository,persistence);
  var day=new PlanService.DayPlan(15,null,"미야코지마");
  day.getItems().add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.START,null,"삿포로 숙소",540,null,0,43.05,141.35));
  day.getItems().add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.END,null,"미야코지마 숙소",1320,null,5877,24.8,125.28));
  flights.add(List.of(day));assertEquals(5,day.getItems().size());assertTrue(day.getItems().get(1).getDisplayName().contains("신치토세"));
  assertEquals("비행기 이동 필요",day.getItems().get(2).getTitle());assertTrue(day.getItems().get(3).getDisplayName().contains("미야코"));
  var routes=mock(RailRouteService.class);
  when(routes.leg(anyDouble(),anyDouble(),anyString(),anyDouble(),anyDouble(),anyString(),any(),anyInt(),any(),any())).thenAnswer(c->{
    double a=c.getArgument(0),b=c.getArgument(1),x=c.getArgument(3),y=c.getArgument(4);
    if(IslandTravel.crossesSea(a,b,x,y))return TransitLegPlanner.plan(null,null,names,a,b,c.getArgument(2),x,y,c.getArgument(5),"대중교통",0,null,null);
    var leg=new TransitLegDto();leg.setMinutes((int)Math.ceil(DistanceUtil.calculateDistance(a,b,x,y)*2.4));return leg;
  });
  var jobs=new PlanGenerationJobs();try{
    jobs.submit("owner","job","f",()->{TimelineConsistency.repair(List.of(day),routes,new PlanRequest(),new ArrayList<>());var r=new AiRouteResponse();r.setTimeline(List.of(new AiRouteResponse.TimelineItem()));return r;});
    EndTimeApprovalTest.await(()->"SUCCEEDED".equals(jobs.find("owner","job").status()));assertNull(jobs.find("owner","job").approval());
    assertTrue(day.getItems().getLast().getStartMin()<1320);
    for(int i=1;i<day.getItems().size();i++){var prev=day.getItems().get(i-1);var curr=day.getItems().get(i);assertTrue(curr.getStartMin()>=(prev.getEndMin()==null?prev.getStartMin():prev.getEndMin())+curr.getTravelMinutes());}
  }finally{jobs.close();}
 }
 @Test void flightFareIsNotCountedAsFreeTransitOrEligibleForPass(){
   var row=new AiRouteResponse.TimelineItem();row.setDay(1);var leg=new TransitLegDto();leg.setSource("distance-flight");leg.setMode("비행기 이동 필요");row.setTransit(leg);
   var response=new AiRouteResponse();response.setTimeline(List.of(row));MobilePassCosts.apply(response,List.of(),id->null);
   var costs=response.getTransportCosts();assertEquals(1,costs.get("flightLegCount"));assertEquals(1,costs.get("unknownFlightLegCount"));assertNull(costs.get("flightFareYen"));assertEquals(0,costs.get("unknownLegCount"));
 }
}
