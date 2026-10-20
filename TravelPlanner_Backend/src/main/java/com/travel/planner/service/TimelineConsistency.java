package com.travel.planner.service;
import com.travel.planner.dto.TransitLegDto;
import com.travel.planner.dto.PlanRequest;
import com.travel.planner.util.TimeUtil;
import com.travel.planner.util.OpeningHours;
import java.util.*;

/** A displayed transit duration must fit between consecutive stops, before saving as well as on legacy reads. */
public final class TimelineConsistency {
    private TimelineConsistency(){}
    static int ceiling(int minute){return ((minute+4)/5)*5;}
    public static void repair(List<PlanService.DayPlan> days,RailRouteService routes,PlanRequest request,List<String> warnings){
        for(var day:days){
            var originals=new ArrayList<>(day.getItems());
            int deadline=request.getPreferredEndTime()==null?22*60:TimeUtil.toMinutes(request.getPreferredEndTime());
            if(day.getDayNumber()==days.size() && request.getOutCity()!=null && !request.getOutCity().isBlank()) {
                Integer flight=TimeUtil.parseFlightTime(request.getOutTime());if(flight!=null)deadline=Math.min(deadline,flight-120);
            }
            for(int attempt=0;attempt<100;attempt++) {
                var adjusted=new ArrayList<PlanService.SimulatedItinerary>();
                PlanService.SimulatedItinerary previous=null;
                for(var item:originals){
                    int travel=item.getTravelMinutes();int start=item.getStartMin();Integer end=item.getEndMin();
                    if(previous!=null){
                        if(previous.getLatitude()!=null && item.getLatitude()!=null){
                            var leg=routes.leg(previous.getLatitude(),previous.getLongitude(),previous.getDisplayName(),item.getLatitude(),item.getLongitude(),item.getDisplayName(),request.getTransportation(),travel,day.getDate(),previous.getEndMin()==null?previous.getStartMin():previous.getEndMin());
                            if(leg!=null)travel=leg.getMinutes();
                        }
                        int departure=previous.getEndMin()==null?previous.getStartMin():previous.getEndMin();
                        int earliest=ceiling(departure+travel);
                        if(item.getType()==PlanService.SimulatedItinerary.Type.END)start=earliest;
                        if(start<earliest){
                            if(item.getType()==PlanService.SimulatedItinerary.Type.FIXED)throw new PlanGenerationException("고정 일정 '"+item.getDisplayName()+"'에 이동 시간상 도착할 수 없습니다. 시작 시간을 조정해주세요.");
                            int dwell=end==null?0:Math.max(0,end-start);start=earliest;if(end!=null)end=start+dwell;
                        }
                    }
                    if(item.getType()==PlanService.SimulatedItinerary.Type.VISIT && item.getPlace()!=null && !"교통".equals(item.getCategory())) {
                        var intervals=OpeningHours.intervalsOn(item.getPlace(),day.getDate());
                        final int visitStart=start,visitEnd=end==null?start:end;
                        if(intervals!=null && intervals.stream().noneMatch(iv->visitStart>=iv[0] && visitEnd<=iv[1]))continue;
                    }
                    var copy=new PlanService.SimulatedItinerary(item.getType(),item.getPlace(),item.getTitle(),start,end,travel,item.getLatitude(),item.getLongitude());
                    adjusted.add(copy);previous=copy;
                }
                if(adjusted.isEmpty())throw new PlanGenerationException("이동 시간을 만족하는 방문 일정을 만들 수 없습니다.");
                var last=adjusted.getLast();int finish=last.getEndMin()==null?last.getStartMin():last.getEndMin();
                if(finish<=deadline || originals.size()<=1){day.getItems().clear();day.getItems().addAll(adjusted);break;}
                int remove=-1;
                for(int i=originals.size()-1;i>=0;i--)if(originals.get(i).getType()==PlanService.SimulatedItinerary.Type.VISIT && !"교통".equals(originals.get(i).getCategory())){remove=i;break;}
                if(remove<0)throw new PlanGenerationException("이동 시간과 숙소·공항 도착 시간을 동시에 만족할 수 없습니다. 기간 또는 지역을 조정해주세요.");
                originals.remove(remove);
                if(!warnings.contains("이동 시간을 확보하기 위해 일부 방문지를 조정했습니다."))warnings.add("이동 시간을 확보하기 위해 일부 방문지를 조정했습니다.");
            }
        }
    }
    public static void repairSaved(List<Map<String,Object>> timeline) {
        Map<Integer,Integer> ends=new HashMap<>();
        for(var item:timeline){
            int day=((Number)item.get("day")).intValue();Integer start=TimeUtil.parseClock((String)item.get("time"));if(start==null)continue;
            Integer end=TimeUtil.parseClock((String)item.get("endTime"));int duration=end==null?0:Math.max(0,end-start);
            int travel=item.get("transit") instanceof TransitLegDto leg?leg.getMinutes():item.get("travelMinutes") instanceof Number n?n.intValue():0;
            if(ends.containsKey(day))start=Math.max(start,ceiling(ends.get(day)+travel));
            item.put("time",TimeUtil.format(start));if(end!=null)item.put("endTime",TimeUtil.format(start+duration));
            ends.put(day,start+duration);
        }
    }
}
