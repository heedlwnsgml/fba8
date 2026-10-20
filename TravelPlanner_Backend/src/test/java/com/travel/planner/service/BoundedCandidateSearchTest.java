package com.travel.planner.service;
import com.travel.planner.dto.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class BoundedCandidateSearchTest {
    static Object field(Object value,String name){return ReflectionTestUtils.getField(value,name);}
    static double number(Object value,String name){return ((Number)field(value,name)).doubleValue();}
    @Test void boundAndWinnerMatchExhaustiveEvaluationAcrossMealWeatherAndEveningCases() throws Exception {
        var engine=new PlanService();var routes=mock(RailRouteService.class);ReflectionTestUtils.setField(engine,"routeTimes",routes);
        when(routes.leg(anyDouble(),anyDouble(),anyString(),anyDouble(),anyDouble(),anyString(),anyString(),anyInt(),any(),any()))
            .thenAnswer(call->{var leg=new TransitLegDto();leg.setMinutes(call.<Integer>getArgument(7)+7);return leg;});
        for(boolean rainy:new boolean[]{false,true})for(String themes:List.of("관광,사진","힐링,온천","맛집,카페","야경,문화"))for(int hour:new int[]{9,11,14,17,20}) {
            var input=new PlanService.TripInput();var req=new PlanRequest();req.setTripDays(3);req.setCities(List.of("오사카","교토"));req.setThemes(Arrays.asList(themes.split(",")));req.setTransportation("대중교통");input.request=req;
            input.candidates.addAll(TestPlaces.osaka());input.candidates.addAll(TestPlaces.kyoto());
            Object st=ReflectionTestUtils.invokeMethod(engine,"buildState",input);
            var hotel=TestPlaces.place("hotel","숙소","오사카",34.6687,135.5013,"숙박",null,TestPlaces.H_24);
            var ctx=engine.buildDayContext(req,1,3,hotel,hotel);ctx.city="오사카";ctx.badWeather=rainy;
            var type=Class.forName(PlanService.class.getName()+"$DayState");var constructor=type.getDeclaredConstructor();constructor.setAccessible(true);Object ds=constructor.newInstance();
            ReflectionTestUtils.setField(ds,"cur",hour*60);ReflectionTestUtils.setField(ds,"locLat",hotel.getLatitude());ReflectionTestUtils.setField(ds,"locLng",hotel.getLongitude());
            ReflectionTestUtils.invokeMethod(engine,"initMeals",ctx,ds,st,ctx.endMin);
            ReflectionTestUtils.setField(ds,"seed",ReflectionTestUtils.invokeMethod(engine,"chooseSeed",ctx,st));
            var feasible=new ArrayList<Object>();int min=Integer.MAX_VALUE;
            for(Object candidate:(List<?>)field(st,"pool")) {
                Object eval=ReflectionTestUtils.invokeMethod(engine,"evaluate",candidate,ctx,ds,st,false);if(eval==null)continue;
                double upper=ReflectionTestUtils.invokeMethod(engine,"utilityUpperBound",candidate,ctx,ds,st);
                assertTrue(upper+1e-8>=number(eval,"utility"),"Upper bound must never exclude a better route");
                feasible.add(eval);min=Math.min(min,((Number)field(eval,"travel")).intValue());
            }
            Object expected=null;
            for(Object eval:feasible) {
                if(field(eval,"fills")==null && number(eval,"utility")+number(eval,"waitPenalty")+PlanService.TRAVEL_WEIGHT*min<PlanService.MIN_NET_UTILITY)continue;
                if(expected==null || number(eval,"utility")>number(expected,"utility"))expected=eval;
            }
            Object actual=ReflectionTestUtils.invokeMethod(engine,"pickBest",ctx,ds,st,false);
            assertSame(expected==null?null:field(expected,"cand"),actual==null?null:field(actual,"cand"),"Winner must match exhaustive search: "+themes+" hour="+hour+" rain="+rainy);
            if(expected!=null)assertEquals(number(expected,"utility"),number(actual,"utility"),1e-8);
        }
    }
}
