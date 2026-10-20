package com.travel.planner.service;

import com.travel.planner.entity.*;
import com.travel.planner.repository.*;
import com.travel.planner.dto.*;
import com.travel.planner.transit.*;
import java.nio.file.*;
import java.sql.*;
import java.time.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.test.util.ReflectionTestUtils;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class LongTripPerformanceTest {
    @Test void seedSearchStopsAfterSameFortyFeasibleCandidates() throws Exception {
        var input=new PlanService.TripInput();
        var req=new PlanRequest();req.setCities(List.of("오사카"));req.setThemes(List.of("관광"));req.setTripDays(1);req.setTransportation("대중교통");input.request=req;
        for(int i=0;i<1000;i++) {
            var p=TestPlaces.place("performance-"+i,"관광 장소 "+i,"오사카",34.668+i*.000001,135.501+i*.000001,"관광지","관광",TestPlaces.H_9_17);
            p.setRecommendedDuration(60);p.setRating(4.5);p.setUserRatingCount(100);input.candidates.add(p);
        }
        var hotel=TestPlaces.place("hotel","숙소","오사카",34.65,135.5,"숙박",null,TestPlaces.H_24);
        var engine=new PlanService();var routes=mock(RailRouteService.class);ReflectionTestUtils.setField(engine,"routeTimes",routes);
        var build=PlanService.class.getDeclaredMethod("buildState",PlanService.TripInput.class);build.setAccessible(true);var state=build.invoke(engine,input);
        var ctx=engine.buildDayContext(req,1,1,hotel,null);ctx.city="오사카";
        var choose=PlanService.class.getDeclaredMethod("chooseSeed",PlanService.DayContext.class,state.getClass());choose.setAccessible(true);
        assertNotNull(choose.invoke(engine,ctx,state));
        long searches=mockingDetails(routes).getInvocations().stream().filter(i->i.getMethod().getName().equals("leg")).count();
        assertEquals(40,searches,"1000 eligible seeds must not all explore the national network");
        System.out.println("SEED_ROUTE_SEARCHES candidates=1000 actual="+searches+" previous=1000");
    }

    @Test @EnabledIfEnvironmentVariable(named="PLANNER_PERFORMANCE_DB",matches="1")
    @Timeout(value=120,unit=TimeUnit.SECONDS,threadMode=Timeout.ThreadMode.SEPARATE_THREAD)
    void realCatalogueThirtyDayBenchmarkWithoutWritesOrExternalApis() throws Exception {
        var properties=new Properties();try(var reader=Files.newBufferedReader(Path.of("config/database-local.properties"))){properties.load(reader);}
        try(var connection=DriverManager.getConnection(properties.getProperty("spring.datasource.url"),properties.getProperty("spring.datasource.username"),properties.getProperty("spring.datasource.password"))) {
            connection.setReadOnly(true);
            var stations=mock(TransitStationRepository.class);when(stations.findAll()).thenReturn(rows(connection,"transit_station",TransitStation.class));
            var links=mock(TransitLinkRepository.class);when(links.findAll()).thenReturn(rows(connection,"transit_link",TransitLink.class));
            var stops=mock(TransitStopRepository.class);when(stops.findAll()).thenReturn(rows(connection,"transit_stop",TransitStop.class));
            var patterns=mock(TransitPatternRepository.class);when(patterns.findAll()).thenReturn(rows(connection,"transit_pattern",TransitPattern.class));
            var feeds=mock(TransitFeedRepository.class);when(feeds.findAll()).thenReturn(rows(connection,"transit_feed",TransitFeed.class));
            var names=mock(TransitNameService.class);when(names.station(anyString())).thenAnswer(i->i.getArgument(0));when(names.line(anyString())).thenAnswer(i->i.getArgument(0));when(names.operator(anyString())).thenAnswer(i->i.getArgument(0));
            var fares=mock(FareDataService.class);when(fares.fareBook()).thenReturn(FareBook.EMPTY);
            var buses=new BusStopService();buses.use(BusStopParser.read(Path.of("data/P11-22_SHP.zip")));
            var routes=new RailRouteService(stations,links,stops,patterns,feeds,names,fares,buses);
            var engine=new PlanService();ReflectionTestUtils.setField(engine,"routeTimes",routes);
            var input=new PlanService.TripInput();var req=new PlanRequest();req.setStartDate(LocalDate.of(2026,10,21));req.setEndDate(req.getStartDate().plusDays(29));req.setCities(List.of("도쿄","요코하마","가마쿠라"));req.setThemes(List.of("관광","힐링","야경"));req.setTransportation("대중교통");req.setMealCount(2);input.request=req;
            input.candidates=rows(connection,"place",Place.class).stream().filter(p->p.getCity()!=null && req.getCities().contains(p.getCity())).toList();
            input.dayCities=new ArrayList<>();var hotels=new HashMap<String,Place>();var centers=engine.cityCenters(input.candidates,req.getCities());
            for(String city:req.getCities()) {var point=centers.get(city);hotels.put(city,TestPlaces.place("performance-hotel-"+city,"숙소 "+city,city,point[0],point[1],"숙박",null,TestPlaces.H_24));}
            for(int day=1;day<=30;day++) {String city=req.getCities().get((day-1)/10);input.dayCities.add(city);if(day<30)input.lodgingByNight.put(day,hotels.get(city));}
            long started=System.nanoTime();var result=engine.planTrip(input);
            long engineMs=TimeUnit.NANOSECONDS.toMillis(System.nanoTime()-started);
            TimelineConsistency.repair(result.getDays(),routes,req,new ArrayList<>());
            System.out.println("THIRTY_DAY_REAL_DATA candidates="+input.candidates.size()+" engineMs="+engineMs+" totalMs="+TimeUnit.NANOSECONDS.toMillis(System.nanoTime()-started));
            assertEquals(30,result.getDays().size());
            assertTrue(result.getDays().stream().allMatch(d->!d.getItems().isEmpty()));
        }
    }
    private static <T> List<T> rows(Connection c,String table,Class<T> type) throws Exception {
        var result=new ArrayList<T>();
        try(var query=c.createStatement();var rows=query.executeQuery("SELECT * FROM "+table)) {
            var columns=new HashSet<String>();for(int n=1;n<=rows.getMetaData().getColumnCount();n++)columns.add(rows.getMetaData().getColumnName(n));
            while(rows.next()) {
                T item=type.getDeclaredConstructor().newInstance();
                for(var field:type.getDeclaredFields()) {
                    if(java.lang.reflect.Modifier.isStatic(field.getModifiers()))continue;
                    String column=field.getName().replaceAll("([a-z])([A-Z])","$1_$2").toLowerCase();var mapping=field.getAnnotation(jakarta.persistence.Column.class);if(mapping!=null && !mapping.name().isEmpty())column=mapping.name();if(!columns.contains(column))continue;
                    Object value=rows.getObject(column);if(value==null)continue;
                    Class<?> kind=field.getType();
                    if(kind==Long.class)value=((Number)value).longValue();else if(kind==Integer.class)value=((Number)value).intValue();else if(kind==Double.class)value=((Number)value).doubleValue();
                    else if(kind==Boolean.class)value=value instanceof Boolean?value:((Number)value).intValue()!=0;
                    else if(kind==LocalDate.class)value=rows.getDate(column).toLocalDate();else if(kind==LocalDateTime.class)value=rows.getTimestamp(column).toLocalDateTime();else if(kind==String.class)value=rows.getString(column);else continue;
                    field.setAccessible(true);field.set(item,value);
                }
                result.add(item);
            }
        }
        return result;
    }
}
