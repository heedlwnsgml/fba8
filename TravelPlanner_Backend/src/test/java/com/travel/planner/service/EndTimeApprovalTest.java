package com.travel.planner.service;
import com.travel.planner.dto.*;
import com.travel.planner.entity.Place;
import java.time.*;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.BooleanSupplier;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class EndTimeApprovalTest {
    final RailRouteService routes=mock(RailRouteService.class);
    EndTimeApprovalTest(){when(routes.leg(anyDouble(),anyDouble(),anyString(),anyDouble(),anyDouble(),anyString(),any(),anyInt(),any(),any())).thenAnswer(call->{var leg=new TransitLegDto();leg.setMinutes(20);return leg;});}
    static void await(BooleanSupplier test) throws Exception {long end=System.nanoTime()+3_000_000_000L;while(!test.getAsBoolean()&&System.nanoTime()<end)Thread.sleep(5);assertTrue(test.getAsBoolean());}
    PlanRequest request(){var r=new PlanRequest();r.setPreferredEndTime(LocalTime.of(22,0));r.setTransportation("대중교통");return r;}
    Place place(String id,String name,String category,double lat){var p=new Place();p.setPlaceId(id);p.setName(name);p.setCategory(category);p.setCity("도쿄");p.setLatitude(lat);p.setLongitude(139.7);p.setOpeningHours(TestPlaces.H_24);return p;}
    PlanService.DayPlan day(int number){var d=new PlanService.DayPlan(number,LocalDate.of(2026,10,21).plusDays(number-1),"도쿄");var start=place("a"+number,"출발 숙소","숙소",35.6);var visit=place("v"+number,"야경 관광지","관광지",35.61);var end=place("b"+number,"도착 숙소","숙소",35.62);
        d.getItems().add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.START,start,null,1260,null,0,35.6,139.7));
        d.getItems().add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.VISIT,visit,null,1270,1300,10,35.61,139.7));
        d.getItems().add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.END,end,null,1320,null,10,35.62,139.7));return d;}
    AiRouteResponse response(){var r=new AiRouteResponse();r.setTimeline(List.of(new AiRouteResponse.TimelineItem()));return r;}
    PlanService.DayPlan unavoidableDay(int number,int start){var d=day(number);d.getItems().remove(1);var old=d.getItems().getFirst();d.getItems().set(0,new PlanService.SimulatedItinerary(old.getType(),old.getPlace(),old.getTitle(),start,null,0,old.getLatitude(),old.getLongitude()));return d;}
    PlanService.DayPlan lateFixedDay(int number){
        var d=unavoidableDay(number,630);
        d.getItems().add(1,new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.FIXED,null,"필수 일정",1260,1260,0,35.61,139.7));return d;
    }
    void routeMinutes(int minutes){when(routes.leg(anyDouble(),anyDouble(),anyString(),anyDouble(),anyDouble(),anyString(),any(),anyInt(),any(),any())).thenAnswer(call->{var leg=new TransitLegDto();leg.setMinutes(minutes);return leg;});}
    @Test void repairableDayFinishesWithinLimitWithoutAsking() throws Exception {
        var jobs=new PlanGenerationJobs();try{
            var d=day(1);var req=request();
            jobs.submit("owner","job","f",()->{TimelineConsistency.repair(List.of(d),routes,req,new ArrayList<>());return response();});
            await(()->"SUCCEEDED".equals(jobs.find("owner","job").status()));
            assertNull(jobs.find("owner","job").approval());assertEquals(1280,d.getItems().getLast().getStartMin());
            assertEquals(LocalTime.of(22,0),req.getPreferredEndTime());
        }finally{jobs.close();}
    }
    @Test void firstDayConsentDoesNotSkipThirdDayAndDecliningDoesNotSave() throws Exception {
        var jobs=new PlanGenerationJobs();try {
            routeMinutes(90);
            var days=List.of(unavoidableDay(1,1260),unavoidableDay(2,540),lateFixedDay(3));
            var req=request();var warnings=new ArrayList<String>();var committed=new AtomicBoolean();
            jobs.submit("owner","job","fingerprint",()->{TimelineConsistency.repair(days,routes,req,warnings);committed.set(true);return response();});
            await(()->jobs.find("owner","job").approval()!=null);
            var first=jobs.find("owner","job").approval();assertEquals(1,first.day());assertEquals(30,first.overtimeMinutes());
            assertEquals(404,assertThrows(ResponseStatusException.class,()->jobs.decideEndTime("other","job",first.decisionId(),true)).getStatusCode().value());
            jobs.decideEndTime("owner","job",first.decisionId(),true);
            await(()->jobs.find("owner","job").approval()!=null&&jobs.find("owner","job").approval().day()==3);
            assertFalse(committed.get());var third=jobs.find("owner","job").approval();
            assertNotEquals(first.decisionId(),third.decisionId());jobs.decideEndTime("owner","job",third.decisionId(),false);
            await(()->"FAILED".equals(jobs.find("owner","job").status()));assertFalse(committed.get());
            assertEquals(1350,days.get(0).getItems().getLast().getStartMin());assertEquals(630,days.get(1).getItems().getLast().getStartMin());
            assertEquals(LocalTime.of(22,0),req.getPreferredEndTime());assertTrue(warnings.stream().anyMatch(w->w.contains("1일차는 사용자 허용")));
            assertTrue(warnings.stream().noneMatch(w->w.contains("3일차는 사용자 허용")));
            assertEquals("FAILED",jobs.decideEndTime("owner","job",first.decisionId(),true).status());
            assertEquals(409,assertThrows(ResponseStatusException.class,()->jobs.decideEndTime("owner","job",first.decisionId(),false)).getStatusCode().value());
        }finally{jobs.close();}
    }
    @Test void approvedLateFinishNeverDelaysTheNextMorning() throws Exception {
        var jobs=new PlanGenerationJobs();try{
            routeMinutes(150);var days=List.of(unavoidableDay(1,1380),unavoidableDay(2,795));
            jobs.submit("owner","job","f",()->{TimelineConsistency.repair(days,routes,request(),new ArrayList<>());return response();});
            await(()->jobs.find("owner","job").approval()!=null);
            var approval=jobs.find("owner","job").approval();assertEquals(1,approval.day());assertEquals("다음날 01:30",approval.expectedEndTime());
            jobs.decideEndTime("owner","job",approval.decisionId(),true);
            await(()->"SUCCEEDED".equals(jobs.find("owner","job").status()));
            assertEquals(1530,days.get(0).getItems().getLast().getStartMin());
            assertEquals(540,days.get(1).getItems().getFirst().getStartMin());assertEquals(690,days.get(1).getItems().getLast().getStartMin());
        }finally{jobs.close();}
    }
    @Test void transferOverlappingNextNineAmCannotBeApprovedOrCommitted() throws Exception {
        var jobs=new PlanGenerationJobs();try{
            routeMinutes(601);var days=List.of(unavoidableDay(1,1380),unavoidableDay(2,540));var committed=new AtomicBoolean();
            jobs.submit("owner","job","f",()->{TimelineConsistency.repair(days,routes,request(),new ArrayList<>());committed.set(true);return response();});
            await(()->"FAILED".equals(jobs.find("owner","job").status()));
            var result=jobs.find("owner","job");assertNull(result.approval());assertFalse(committed.get());assertTrue(result.error().contains("다음 날 오전 9시"));
            assertEquals(540,days.get(1).getItems().getFirst().getStartMin());
        }finally{jobs.close();}
    }
    @Test void decliningAnImpossibleTransferFailsAfterAttemptAndDoesNotSave() throws Exception {
        var jobs=new PlanGenerationJobs();try {
            var d=day(1);d.getItems().remove(1);
            when(routes.leg(anyDouble(),anyDouble(),anyString(),anyDouble(),anyDouble(),anyString(),any(),anyInt(),any(),any())).thenAnswer(call->{var leg=new TransitLegDto();leg.setMinutes(90);return leg;});
            AtomicBoolean committed=new AtomicBoolean();jobs.submit("owner","job","f",()->{TimelineConsistency.repair(List.of(d),routes,request(),new ArrayList<>());committed.set(true);return response();});
            await(()->jobs.find("owner","job").approval()!=null);var decision=jobs.find("owner","job").approval();
            jobs.decideEndTime("owner","job",decision.decisionId(),false);await(()->"FAILED".equals(jobs.find("owner","job").status()));
            assertFalse(committed.get());assertNull(jobs.find("owner","job").response());assertTrue(jobs.find("owner","job").error().contains("1일차"));
        }finally{jobs.close();}
    }
    @Test void waitingCanBeCancelledAndStillCountsTowardTwoJobLimit() throws Exception {
        var jobs=new PlanGenerationJobs();try {
            AtomicBoolean committed=new AtomicBoolean();
            for(String id:List.of("a","b"))jobs.submit("owner",id,id,()->{TimelineConsistency.repair(List.of(unavoidableDay(1,1310)),routes,request(),new ArrayList<>());committed.set(true);return response();});
            await(()->jobs.list("owner").stream().allMatch(j->j.approval()!=null));
            assertEquals(429,assertThrows(ResponseStatusException.class,()->jobs.submit("owner","c","c",this::response)).getStatusCode().value());
            jobs.cancel("owner","a");jobs.cancel("owner","b");await(()->jobs.list("owner").stream().allMatch(j->!j.cancellationPending()));assertFalse(committed.get());
        }finally{jobs.close();}
    }
    @Test void flightDeadlineCannotBeOverridden() throws Exception {
        var jobs=new PlanGenerationJobs();try {
            var req=request();req.setOutCity("하네다공항");req.setOutTime("23:00");
            jobs.submit("owner","job","f",()->{TimelineConsistency.repair(List.of(day(1)),routes,req,new ArrayList<>());return response();});
            await(()->"FAILED".equals(jobs.find("owner","job").status()));assertNull(jobs.find("owner","job").approval());
        }finally{jobs.close();}
    }
}
