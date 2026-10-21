package com.travel.planner.service;

import com.travel.planner.entity.Place;
import com.travel.planner.repository.PlaceRepository;
import com.travel.planner.util.*;
import org.springframework.stereotype.Service;
import lombok.RequiredArgsConstructor;
import java.util.*;

/** An explicit, unbooked air-transfer placeholder with airport access on both ends. */
@Service
@RequiredArgsConstructor
public class FlightTransferService {
    private final PlaceRepository places;
    private final PlanPersistenceService persistence;
    public static final String SOURCE="distance-flight";
    public static final double AVERAGE_KMH=750;
    /** Same 20% travel margin as other movement. No fare or live timetable is inferred. */
    public static int minutes(double km){return Math.max(30,(int)Math.ceil(km/AVERAGE_KMH*60*1.2));}

    public static AirportDirectory.Airport airport(double lat,double lng){
        String island=IslandTravel.island(lat,lng);
        return AirportDirectory.all().stream().filter(a->IslandTravel.island(a.latitude,a.longitude).equals(island))
            .min(Comparator.comparingDouble(a->DistanceUtil.calculateDistance(lat,lng,a.latitude,a.longitude)))
            .orElseThrow(()->new PlanGenerationException("출발·도착 공항을 확인할 수 없습니다. 공항을 직접 지정해주세요."));
    }
    private Place place(AirportDirectory.Airport airport){
        return places.findByPlaceId(airport.placeId()).orElseGet(()->{
            var p=new Place();p.setPlaceId(airport.placeId());p.setName(airport.name);p.setCategory("교통");
            p.setLatitude(airport.latitude);p.setLongitude(airport.longitude);p.setCity(airport.cities.length>0?airport.cities[0]:airport.name);
            return persistence.upsertPlace(p);
        });
    }
    public void add(List<PlanService.DayPlan> days){
        for(var day:days){
            var rebuilt=new ArrayList<PlanService.SimulatedItinerary>();
            PlanService.SimulatedItinerary previous=null;
            for(var item:day.getItems()){
                PlanGenerationJobs.checkCancellation();
                if(previous!=null && located(item) && IslandTravel.crossesSea(previous.getLatitude(),previous.getLongitude(),item.getLatitude(),item.getLongitude())){
                    var departure=airport(previous.getLatitude(),previous.getLongitude());var arrival=airport(item.getLatitude(),item.getLongitude());
                    var origin=place(departure);var destination=place(arrival);
                    int start=previous.getEndMin()==null?previous.getStartMin():previous.getEndMin();
                    // TimelineConsistency resolves terrestrial airport access using the transit DB.
                    rebuilt.add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.VISIT,origin,null,start,start+60,0,origin.getLatitude(),origin.getLongitude()));
                    int flying=minutes(DistanceUtil.calculateDistance(departure.latitude,departure.longitude,arrival.latitude,arrival.longitude));
                    int landing=start+60+flying;
                    rebuilt.add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.TRANSFER,null,"비행기 이동 필요",landing,null,flying,destination.getLatitude(),destination.getLongitude()));
                    rebuilt.add(new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.VISIT,destination,null,landing,landing+30,0,destination.getLatitude(),destination.getLongitude()));
                }
                rebuilt.add(item);
                if(located(item))previous=item;
            }
            day.getItems().clear();day.getItems().addAll(rebuilt);
        }
    }
    private static boolean located(PlanService.SimulatedItinerary item){return item.getLatitude()!=null && item.getLongitude()!=null && !(item.getLatitude()==0 && item.getLongitude()==0);}
}
