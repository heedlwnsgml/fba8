package com.travel.planner.service;
import com.travel.planner.dto.AiRouteResponse;
import com.travel.planner.entity.TransportPass;
import com.travel.planner.transit.PassAdvisor;
import java.util.*;
import java.time.LocalDate;
import java.util.function.Function;
/** Expose the same fare blocks and chosen passes to the existing mobile UI, without changing persisted plans. */
public final class MobilePassCosts {
    public static void apply(AiRouteResponse response,List<PassAdvisor.Pass> passes,Function<String,TransportPass> rows) {
        if(response==null || response.getTimeline()==null)return;
        Map<Integer,LocalDate> dates=new HashMap<>();TreeSet<Integer> days=new TreeSet<>();
        if(response.getDays()!=null)for(var d:response.getDays()) {days.add(d.getDay());try{dates.put(d.getDay(),LocalDate.parse(d.getDate()));}catch(Exception ignored){}}
        Map<Integer,Integer> regular=new HashMap<>(),covered=new HashMap<>(),purchase=new HashMap<>(),unknown=new HashMap<>();
        int estimated=0,flightCount=0,unknownFlights=0,flightFare=0;
        for(var item:response.getTimeline()) {
            int day=item.getDay();days.add(day);var leg=item.getTransit();if(leg==null)continue;
            if("distance-flight".equals(leg.getSource()) || (leg.getMode()!=null && leg.getMode().contains("비행기"))){
                flightCount++;if(leg.getFareYen()==null)unknownFlights++;else flightFare+=leg.getFareYen();continue;
            }
            if(leg.getFareYen()==null)unknown.merge(day,1,Integer::sum);
            else regular.merge(day,leg.getFareYen(),Integer::sum);
            if(leg.getFareRides()!=null && leg.getFareRides().stream().anyMatch(r->r.estimated))estimated++;
        }
        var rides=PassAdvice.collectRides(response.getTimeline(),dates);
        var suggestions=PassAdvisor.advise(passes,rides);
        List<Map<String,Object>> recommendations=new ArrayList<>();Map<Integer,List<Map<String,Object>>> dailyPasses=new HashMap<>();
        for(var s:suggestions) {
            int first=s.days.getFirst(),last=s.days.getLast();var row=new LinkedHashMap<String,Object>();
            row.put("id",s.pass.key);row.put("name",s.pass.name);row.put("day",first);row.put("validUntilDay",last);
            row.put("regularFareYen",s.coveredFareYen);row.put("passFareYen",s.pass.priceYen);row.put("savingYen",s.savingYen);
            var source=rows.apply(s.pass.key);row.put("conditions",source==null?"":source.getConditions());
            recommendations.add(row);purchase.merge(first,s.pass.priceYen,Integer::sum);
            for(var ride:s.rides)covered.merge(ride.day,ride.fareYen,Integer::sum);
            for(int d:s.days)dailyPasses.computeIfAbsent(d,k->new ArrayList<>()).add(row);
        }
        List<Map<String,Object>> daily=new ArrayList<>();int total=0,optimal=0,missing=0;
        for(int day:days) {
            int normal=regular.getOrDefault(day,0),paid=purchase.getOrDefault(day,0),discount=covered.getOrDefault(day,0);
            int after=normal-discount+paid;total+=normal;optimal+=after;missing+=unknown.getOrDefault(day,0);
            var d=new LinkedHashMap<String,Object>();d.put("day",day);d.put("regularFareYen",normal);d.put("optimalFareYen",after);
            d.put("passPurchaseFareYen",paid);d.put("unknownLegCount",unknown.getOrDefault(day,0));d.put("passes",dailyPasses.getOrDefault(day,List.of()));daily.add(d);
        }
        Map<String,Object> costs=new LinkedHashMap<>();costs.put("knownFareYen",total);costs.put("totalFareYen",total);costs.put("knownOptimalFareYen",optimal);
        costs.put("unknownLegCount",missing);costs.put("estimatedLegCount",estimated);costs.put("dailyCosts",daily);
        costs.put("recommendations",recommendations);costs.put("passComparisons",recommendations);costs.put("flightLegCount",flightCount);costs.put("unknownFlightLegCount",unknownFlights);costs.put("knownFlightFareYen",flightFare);costs.put("flightFareYen",unknownFlights>0?null:flightFare);
        response.setTransportCosts(costs);
    }
    private MobilePassCosts(){}
}
