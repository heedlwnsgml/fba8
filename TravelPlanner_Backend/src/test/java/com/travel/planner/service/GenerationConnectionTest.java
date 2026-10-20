package com.travel.planner.service;
import com.travel.planner.dto.*;
import com.travel.planner.controller.PlanGenerationController;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;
import tools.jackson.databind.json.JsonMapper;
import java.util.*;
import java.time.LocalDate;
import java.util.concurrent.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class GenerationConnectionTest {
    private AiRouteResponse result() {var r=new AiRouteResponse();r.setTimeline(List.of(new AiRouteResponse.TimelineItem()));return r;}
    @Test void newEngineWithoutAirportsStillCreatesVisits() {
        PlanRequest req=new PlanRequest();req.setStartDate(LocalDate.of(2026,10,11));req.setEndDate(req.getStartDate());req.setCities(List.of("오사카"));req.setThemes(List.of("관광"));
        PlanService.TripInput input=new PlanService.TripInput();input.request=req;input.candidates=TestPlaces.osaka();
        var result=new PlanService().planTrip(input);
        assertFalse(result.getDays().get(0).getItems().isEmpty());
        assertTrue(result.getDays().get(0).getItems().stream().noneMatch(i -> i.getPlace()!=null && PlanService.isAirport(i.getPlace())));
    }
    @Test void backgroundCallsNewEngineAndSupportsSnacks() throws Exception {
        try(PlanGenerationJobsClose jobs=new PlanGenerationJobsClose()) {
            var generator=mock(PlanGenerationService.class);when(generator.createPlan(eq("me"),any())).thenReturn(result());
            var mapper=JsonMapper.builder().build();var controller=new PlanGenerationController(jobs.value,generator,mapper);
            var auth=mock(org.springframework.security.core.Authentication.class);when(auth.getName()).thenReturn("me"); var request=new PlanRequest();request.setClientRequestId("request-1");request.setStartDate(LocalDate.of(2026,10,11));request.setIncludeSnacks(true);
            controller.submit(auth,request);
            long end=System.nanoTime()+TimeUnit.SECONDS.toNanos(3);
            while(!"SUCCEEDED".equals(jobs.value.find("me","request-1").status()) && System.nanoTime()<end) Thread.sleep(10);
            assertEquals("SUCCEEDED",jobs.value.find("me","request-1").status());
            verify(generator).createPlan(eq("me"),argThat(r -> Boolean.FALSE.equals(r.getExcludeCafe()) && request.getStartDate().equals(r.getStartDate())));
            assertNull(jobs.value.find("other","request-1"));
            controller.submit(auth,request);verifyNoMoreInteractions(generator);
        }
    }
    @Test void atMostTwoAndCancellationDoesNotCommit() throws Exception {
        try(PlanGenerationJobsClose jobs=new PlanGenerationJobsClose()) {
            CountDownLatch entered=new CountDownLatch(2),release=new CountDownLatch(1);
            java.util.function.Supplier<AiRouteResponse> blocked=()->{entered.countDown();try {release.await();}catch(InterruptedException e){Thread.currentThread().interrupt();}PlanGenerationJobs.checkCancellation();return result();};
            jobs.value.submit("me","1","a",blocked);jobs.value.submit("me","2","b",blocked);assertTrue(entered.await(2,TimeUnit.SECONDS));
            assertEquals(429,assertThrows(ResponseStatusException.class,()->jobs.value.submit("me","3","c",blocked)).getStatusCode().value());
            assertEquals("CANCELLED",jobs.value.cancel("me","1").status());release.countDown();
        }
    }
    @Test void omittedAirportsDoNotTriggerGeocodingOrRoundTripPenalty() {
        var maps=mock(GoogleMapsService.class);when(maps.getFormalizedJapanCity("도쿄")).thenReturn("일본 도쿄도");
        var service=new PlanValidationService(maps);service.validateMultiCityPlan(List.of("도쿄"),null,null,2);
        verifyNoInteractions(maps);verifyNoMoreInteractions(maps);
    }
    private static class PlanGenerationJobsClose implements AutoCloseable {
        final PlanGenerationJobs value=new PlanGenerationJobs();public void close(){value.close();}
    }
}
