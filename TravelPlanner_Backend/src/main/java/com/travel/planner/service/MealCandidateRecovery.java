package com.travel.planner.service;

import com.travel.planner.entity.Place;
import com.travel.planner.util.DistanceUtil;
import com.travel.planner.util.PlaceKind;
import org.springframework.stereotype.Service;
import lombok.RequiredArgsConstructor;
import java.util.*;

/** Reuse the existing Places search only at meal gaps, then rerun all scheduling constraints. */
@Service
@RequiredArgsConstructor
public class MealCandidateRecovery {
    private final GoogleMapsService google;
    private final SupplementalFoodService food;
    static final int MAX_SEARCHES=8;
    static boolean missing(PlanService.SimulatedItinerary item){
        return item.getType()==PlanService.SimulatedItinerary.Type.MEAL && item.getPlace()==null;
    }
    public PlanService.TripPlan complete(PlanService.TripInput input,PlanService.TripPlan initial,PlanService engine){
        var plan=initial;
        var searched=new ArrayList<double[]>();
        Set<String> known=new HashSet<>();for(var p:input.candidates)known.add(p.getPlaceId());
        for(int round=0;round<2;round++){
            int added=0;
            for(var day:plan.getDays()){
                Place previous=null;
                for(var item:day.getItems()){
                    if(item.getPlace()!=null)previous=item.getPlace();
                    if(!missing(item) || searched.size()>=MAX_SEARCHES)continue;
                    Double lat=item.getLatitude(),lng=item.getLongitude();
                    if(lat==null || lng==null || lat==0 && lng==0)continue;
                    if(searched.stream().anyMatch(at->DistanceUtil.calculateDistance(at[0],at[1],lat,lng)<0.8))continue;
                    searched.add(new double[]{lat,lng});
                    String city=previous!=null && previous.getCity()!=null?previous.getCity():day.getCity();
                    PlanGenerationJobs.progress("식사 장소 주변의 실제 식당을 확인하고 있습니다.");
                    var found=google.findNearbyRestaurants(city,lat,lng).stream()
                        .filter(p->p.getLatitude()!=null && p.getLongitude()!=null)
                        .filter(p->DistanceUtil.calculateDistance(lat,lng,p.getLatitude(),p.getLongitude())<=1.5)
                        .filter(p->PlaceKind.of(p)==PlaceKind.RESTAURANT || PlaceKind.of(p)==PlaceKind.BAR)
                        .filter(p->!known.contains(p.getPlaceId())).toList();
                    for(var restaurant:food.cacheSearchResults(city,found)){
                        if(known.add(restaurant.getPlaceId())){input.candidates.add(restaurant);added++;}
                    }
                }
            }
            if(added==0)break;
            plan=engine.planTrip(input);
        }
        for(var day:plan.getDays())for(var item:day.getItems())if(missing(item))
            throw new PlanGenerationException(day.getDayNumber()+"일차 "+item.getTime()+"에 이동·영업시간 조건을 만족하는 식당을 찾지 못했습니다. 식사 장소를 확정하지 못한 일정은 저장하지 않았습니다.");
        return plan;
    }
}
