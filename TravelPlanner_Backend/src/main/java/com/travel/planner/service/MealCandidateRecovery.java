package com.travel.planner.service;

import com.travel.planner.entity.Place;
import com.travel.planner.util.*;
import org.springframework.stereotype.Service;
import lombok.RequiredArgsConstructor;
import java.util.*;

/** Bounded local recovery: retain real places and validate their opening/travel windows. */
@Service
@RequiredArgsConstructor
public class MealCandidateRecovery {
    private final GoogleMapsService google;
    private final SupplementalFoodService food;
    static final int MAX_SEARCHES=12;
    @org.springframework.beans.factory.annotation.Autowired(required=false)
    private RailRouteService routes;
    static boolean missing(PlanService.SimulatedItinerary item){
        return item.getType()==PlanService.SimulatedItinerary.Type.MEAL && item.getPlace()==null;
    }
    private static boolean located(Place p){return p!=null && p.getLatitude()!=null && p.getLongitude()!=null && !(p.getLatitude()==0 && p.getLongitude()==0);}
    public PlanService.TripPlan complete(PlanService.TripInput input,PlanService.TripPlan initial,PlanService engine){
        var plan=initial;
        var searched=new ArrayList<double[]>();
        Set<String> known=new HashSet<>();for(var p:input.candidates)known.add(p.getPlaceId());
        for(int round=0;round<2;round++){
            int added=0;double radius=round==0?1500:4000;
            for(var day:plan.getDays()){
                Place previous=null;
                for(int index=0;index<day.getItems().size();index++){
                    var item=day.getItems().get(index);
                    if(located(item.getPlace()))previous=item.getPlace();
                    if(!missing(item))continue;
                    var anchors=new ArrayList<Place>();
                    Double ownLat=item.getLatitude(),ownLng=item.getLongitude();
                    if(ownLat!=null && ownLng!=null && !(ownLat==0 && ownLng==0)){
                        var own=new Place();own.setLatitude(ownLat);own.setLongitude(ownLng);own.setCity(previous!=null?previous.getCity():day.getCity());anchors.add(own);
                    }
                    if(previous!=null)anchors.add(previous);
                    for(int next=index+1;next<day.getItems().size();next++)if(located(day.getItems().get(next).getPlace())){anchors.add(day.getItems().get(next).getPlace());break;}
                    var lodging=input.lodgingByNight.get(day.getDayNumber());if(located(lodging))anchors.add(lodging);
                    if(anchors.isEmpty())for(var candidate:day.getItems())if(located(candidate.getPlace())){anchors.add(candidate.getPlace());break;}
                    for(var anchor:anchors){
                        if(searched.size()>=(round==0?MAX_SEARCHES/2:MAX_SEARCHES))break;
                        double lat=anchor.getLatitude(),lng=anchor.getLongitude();
                        if(searched.stream().anyMatch(at->at[2]>=radius && DistanceUtil.calculateDistance(at[0],at[1],lat,lng)<0.8))continue;
                        searched.add(new double[]{lat,lng,radius});
                        String city=anchor.getCity()!=null?anchor.getCity():day.getCity();
                        PlanGenerationJobs.progress(day.getDayNumber()+"일차 식사 장소 주변의 실제 식당을 확인하고 있습니다.");
                        var found=(round==0?google.findNearbyRestaurants(city,lat,lng):google.searchRestaurantsNear(lat,lng,radius,city)).stream()
                            .filter(MealCandidateRecovery::located)
                            .filter(p->DistanceUtil.calculateDistance(lat,lng,p.getLatitude(),p.getLongitude())<=radius/1000)
                            .filter(p->PlaceKind.of(p)==PlaceKind.RESTAURANT || PlaceKind.of(p)==PlaceKind.BAR)
                            .filter(p->!known.contains(p.getPlaceId())).toList();
                        for(var restaurant:food.cacheSearchResults(city,found))if(known.add(restaurant.getPlaceId())){input.candidates.add(restaurant);added++;}
                    }
                }
            }
            if(added>0)plan=engine.planTrip(input);
            if(plan.getDays().stream().flatMap(d->d.getItems().stream()).noneMatch(MealCandidateRecovery::missing))return plan;
        }
        fillExistingSlots(input,plan);
        for(var day:plan.getDays())for(var item:day.getItems())if(missing(item))
            throw new PlanGenerationException(day.getDayNumber()+"일차 "+item.getTime()+"에 이동·영업시간 조건을 만족하는 식당을 찾지 못했습니다. 식사 장소를 확정하지 못한 일정은 저장하지 않았습니다.");
        return plan;
    }

    /** A whole-day rerun may miss a short valid meal window. Fill only that window with a real nearby restaurant. */
    void fillExistingSlots(PlanService.TripInput input,PlanService.TripPlan plan){
        if(input.request==null)return;
        Set<String> used=new HashSet<>();for(var day:plan.getDays())for(var item:day.getItems())if(item.getPlace()!=null)used.add(item.getPlace().getPlaceId());
        var excluded=ThemeVocabulary.normalizeAll(input.request.getExcludedThemes());
        for(var day:plan.getDays())for(int index=0;index<day.getItems().size();index++){
            var item=day.getItems().get(index);if(!missing(item))continue;
            PlanService.SimulatedItinerary previous=null,next=null;
            for(int before=index-1;before>=0;before--)if(located(day.getItems().get(before).getPlace())){previous=day.getItems().get(before);break;}
            for(int after=index+1;after<day.getItems().size();after++)if(located(day.getItems().get(after).getPlace())){next=day.getItems().get(after);break;}
            if(previous==null)continue;
            Place origin=previous.getPlace();int departure=previous.getEndMin()==null?previous.getStartMin():previous.getEndMin();
            var candidates=new ArrayList<>(input.candidates);
            candidates.removeIf(p->!located(p) || used.contains(p.getPlaceId()) || (PlaceKind.of(p)!=PlaceKind.RESTAURANT && PlaceKind.of(p)!=PlaceKind.BAR)
                || ThemeVocabulary.explicitThemes(p).stream().anyMatch(excluded::contains)
                || ThemeVocabulary.inferredThemes(p).stream().anyMatch(excluded::contains));
            candidates.sort(Comparator.comparingDouble(p->DistanceUtil.calculateDistance(origin.getLatitude(),origin.getLongitude(),p.getLatitude(),p.getLongitude())));
            for(var place:candidates.subList(0,Math.min(20,candidates.size()))){
                if(DistanceUtil.calculateDistance(origin.getLatitude(),origin.getLongitude(),place.getLatitude(),place.getLongitude())>4)continue;
                // Preserve companion restrictions in the scheduling engine by using restaurants only for this fallback.
                if(PlaceKind.of(place)==PlaceKind.BAR)continue;
                int travel=TravelTimeEstimator.minutes(origin.getLatitude(),origin.getLongitude(),place.getLatitude(),place.getLongitude(),input.request.legTransport());
                if(routes!=null){var leg=routes.leg(origin.getLatitude(),origin.getLongitude(),origin.shownName(),place.getLatitude(),place.getLongitude(),place.shownName(),input.request.legTransport(),travel,day.getDate(),departure);if(leg!=null)travel=leg.getMinutes();}
                int earliest=Math.max(item.getStartMin(),departure+travel);
                int latest=item.getEndMin()==null?earliest+60:item.getEndMin();
                if(next!=null)latest=Math.min(latest,next.getStartMin()-TravelTimeEstimator.minutes(place.getLatitude(),place.getLongitude(),next.getLatitude(),next.getLongitude(),input.request.legTransport()));
                if(next!=null && routes!=null){int back=TravelTimeEstimator.minutes(place.getLatitude(),place.getLongitude(),next.getLatitude(),next.getLongitude(),input.request.legTransport());var leg=routes.leg(place.getLatitude(),place.getLongitude(),place.shownName(),next.getLatitude(),next.getLongitude(),next.getDisplayName(),input.request.legTransport(),back,day.getDate(),earliest+30);if(leg!=null)latest=Math.min(latest,next.getStartMin()-leg.getMinutes());}
                var intervals=OpeningHours.intervalsOn(place,day.getDate());
                if(intervals==null)continue;
                for(int[] opening:intervals){
                    int start=Math.max(earliest,opening[0]);int end=Math.min(Math.min(start+60,opening[1]),latest);
                    if(end-start<30)continue;
                    day.getItems().set(index,new PlanService.SimulatedItinerary(PlanService.SimulatedItinerary.Type.VISIT,place,null,start,end,travel,place.getLatitude(),place.getLongitude()));
                    used.add(place.getPlaceId());break;
                }
                if(!missing(day.getItems().get(index)))break;
            }
        }
    }
}
