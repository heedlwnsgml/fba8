package com.travel.planner.service;
import com.travel.planner.dto.*;
import com.travel.planner.entity.Place;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class ProductRevisionTest {
    Place place(String id,String name,String category,double lat) {var p=new Place();p.setPlaceId(id);p.setName(name);p.setCategory(category);p.setLatitude(lat);p.setLongitude(139.7);return p;}
    TransitLegDto leg(int minutes) {var l=new TransitLegDto();l.setMinutes(minutes);l.setMode("지하철");var step=new TransitLegDto.Step();step.setType("승차");step.setMinutes(minutes);step.setFrom("空港駅");step.setLine("공항선");l.getSteps().add(step);return l;}
    @Test void walkingOrRailMarginIsAppliedOnceAndStepsSumToTotal(){var l=RailRouteService.padded(leg(35));assertEquals(42,l.getMinutes());assertEquals(42,l.getSteps().stream().mapToInt(TransitLegDto.Step::getMinutes).sum());}
    @Test void distanceFallbackIsNotPaddedTwice(){var l=leg(35);l.setSource("distance");assertEquals(35,RailRouteService.padded(l).getMinutes());}
    @Test void legacyReadCannotArriveBeforeDeparturePlusTravel(){var rows=new ArrayList<Map<String,Object>>();var first=new HashMap<String,Object>();first.put("day",1);first.put("time","09:00");first.put("endTime","09:40");rows.add(first);var next=new HashMap<String,Object>();next.put("day",1);next.put("time","10:00");next.put("endTime","11:00");next.put("transit",leg(35));rows.add(next);TimelineConsistency.repairSaved(rows);assertEquals("10:15",next.get("time"));assertEquals("11:15",next.get("endTime"));}
    @Test void generatedScheduleIsRepairedBeforePersistence(){var routes=mock(RailRouteService.class);when(routes.leg(anyDouble(),anyDouble(),anyString(),anyDouble(),anyDouble(),anyString(),anyString(),anyInt(),isNull(),any())).thenReturn(leg(35));var day=new PlanService.DayPlan(1,null,"도쿄");var p=place("a","출발 호텔","숙소",35.6);var q=place("b","관광지","관광지",35.61);day.getItems().add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.START,p,null,580,null,0,35.6,139.7));day.getItems().add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.VISIT,q,null,600,660,20,35.61,139.7));var request=new PlanRequest();request.setTransportation("대중교통");TimelineConsistency.repair(List.of(day),routes,request,new ArrayList<>());assertEquals("10:15",day.getItems().get(1).getTime());}
    @Test void areaRecommendationsExplainVendorsAndSpecialties(){var area=place("x","삿포로 라멘 골목","식음",43);assertEquals("식당가",DiningInformation.type(area));assertTrue(DiningInformation.guide(area).contains("점포별 메뉴"));var single=place("y","개별 라멘점","식음",43);assertEquals("식당",DiningInformation.type(single));assertNull(DiningInformation.guide(single));}
    @Test void totalBudgetIsOnlyTheRoomCostAndDividesByNights(){var request=new PlanRequest();request.setHotelBudgetYen(30000L);request.setHotelBudgetMode("total");assertEquals(10000,HotelBudgetService.nightlyLimit(request,3));request.setHotelBudgetMode("perNight");assertEquals(30000,HotelBudgetService.nightlyLimit(request,3));}
    @Test void knownExpensiveHotelsAreNeverSaidToFitTheBudget(){var service=spy(new HotelBudgetService(mock(JdbcTemplate.class)));var cheap=place("a","A","숙소",35.6);var expensive=place("b","B","숙소",35.6);doReturn(9000L).when(service).price(cheap);doReturn(15000L).when(service).price(expensive);var request=new PlanRequest();request.setHotelBudgetYen(10000L);assertEquals(List.of(cheap),service.eligible(List.of(expensive,cheap),request,2,new ArrayList<>()));assertThrows(PlanGenerationException.class,()->service.eligible(List.of(expensive),request,2,new ArrayList<>()));}
    @Test void airportBoardingPointMustBeOnTheCalculatedRoute(){var jdbc=mock(JdbcTemplate.class);when(jdbc.queryForList(anyString(),eq("空港駅"))).thenReturn(List.of(Map.of("name","空港駅","latitude",35.6001,"longitude",139.7)));var planned=leg(35);var walk=new TransitLegDto.Step();walk.setType("도보");walk.setMinutes(4);var wait=new TransitLegDto.Step();wait.setType("대기");wait.setMinutes(6);planned.getSteps().add(0,wait);planned.getSteps().add(0,walk);planned.setMinutes(45);var routes=mock(RailRouteService.class);when(routes.leg(anyDouble(),anyDouble(),anyString(),anyDouble(),anyDouble(),anyString(),anyString(),anyInt(),isNull(),any())).thenReturn(planned);var day=new PlanService.DayPlan(1,null,"도쿄");var airport=place("airport","입국 공항","교통",35.6);day.getItems().add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.START,airport,null,540,null,0,35.6,139.7));var sight=place("sight","관광지","관광지",35.7);day.getItems().add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.VISIT,sight,null,600,660,35,35.7,139.7));new AirportAccessService(jdbc,routes).add(List.of(day),"대중교통",new ArrayList<>());assertEquals(2,day.getItems().size(),"승차 지점은 공항 카드 안에서 안내하며 시간표에 별도 방문을 넣지 않는다");var access=new AirportAccessService(jdbc,routes).details("입국 공항",35.6,139.7,planned);assertEquals(4,access.get("walkMinutes"),"대기 시간은 공항 내부 도보 시간에 중복해서 넣지 않는다");assertEquals("空港駅",access.get("boardingName"));}
    @Test void hotelArrivalIsRecomputedInsteadOfRetainingAnImpossibleOldTime(){
        var routes=mock(RailRouteService.class);when(routes.leg(anyDouble(),anyDouble(),anyString(),anyDouble(),anyDouble(),anyString(),anyString(),anyInt(),isNull(),any())).thenReturn(leg(15));
        var day=new PlanService.DayPlan(1,null,"도쿄");var sight=place("sight","관광지","관광지",35.6);var hotel=place("hotel","숙소","숙소",35.61);
        day.getItems().add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.VISIT,sight,null,1260,1290,0,35.6,139.7));
        day.getItems().add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.END,hotel,null,1335,null,15,35.61,139.7));
        var request=new PlanRequest();request.setTransportation("대중교통");TimelineConsistency.repair(List.of(day),routes,request,new ArrayList<>());
        assertEquals(2,day.getItems().size());assertEquals("21:45",day.getItems().getLast().getTime());
    }

}
