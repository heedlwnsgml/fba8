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
            PlanGenerationJobs.progress(day.getDayNumber()+"/"+days.size()+"일차 이동 시간과 도착 시각을 확인하고 있습니다.");
            var originals=new ArrayList<>(day.getItems());
            int deadline=request.getPreferredEndTime()==null?22*60:TimeUtil.toMinutes(request.getPreferredEndTime());
            int hardLimit=Integer.MAX_VALUE;
            // Consent applies only to this day's end. Never carry an overrun into tomorrow.
            if(day.getDayNumber()<days.size())hardLimit=1440+9*60-1;
            if(day.getDayNumber()==days.size() && request.getOutCity()!=null && !request.getOutCity().isBlank()) {
                Integer flight=TimeUtil.parseFlightTime(request.getOutTime());if(flight!=null){hardLimit=Math.min(hardLimit,flight-120);deadline=Math.min(deadline,flight-120);}
            }
            while(true) {
                PlanGenerationJobs.checkCancellation();
                var adjusted=new ArrayList<PlanService.SimulatedItinerary>();
                PlanService.SimulatedItinerary previous=null;
                for(var item:originals){
                    int travel=item.getTravelMinutes();int start=item.getStartMin();Integer end=item.getEndMin();
                    if(previous==null && day.getDayNumber()>1 && item.getType()==PlanService.SimulatedItinerary.Type.START && PlanService.isLodging(item.getPlace())){
                        if(end!=null)end+=9*60-start;
                        start=9*60;
                    }
                    if(previous!=null){
                        if(previous.getLatitude()!=null && item.getLatitude()!=null){
                            var leg=routes.leg(previous.getLatitude(),previous.getLongitude(),previous.getDisplayName(),item.getLatitude(),item.getLongitude(),item.getDisplayName(),request.legTransport(),travel,day.getDate(),previous.getEndMin()==null?previous.getStartMin():previous.getEndMin());
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
                if(finish<=deadline){day.getItems().clear();day.getItems().addAll(adjusted);break;}
                PlanGenerationJobs.progress(day.getDayNumber()+"일차 종료 시각 안에 맞는 대안을 찾고 있습니다.");
                int remove=-1;
                // Remove discretionary free time first, then optional visits; fixed appointments,
                // transport, meals and overnight anchors are retained.
                for(int i=originals.size()-1;i>=0;i--)if(originals.get(i).getType()==PlanService.SimulatedItinerary.Type.FREE){remove=i;break;}
                if(remove<0)for(int i=originals.size()-1;i>=0;i--)if(originals.get(i).getType()==PlanService.SimulatedItinerary.Type.VISIT && !"교통".equals(originals.get(i).getCategory())){remove=i;break;}
                if(remove<0){
                    System.getLogger(TimelineConsistency.class.getName()).log(System.Logger.Level.INFO,
                        "Day {0}: no removable stops remain; finish={1}, preferredLimit={2}, flightLimit={3}",day.getDayNumber(),finish,deadline,hardLimit);
                    if(day.getDayNumber()<days.size() && finish>=1440+9*60)
                        throw new PlanGenerationException(day.getDayNumber()+"일차 이동이 다음 날 오전 9시 이후까지 이어져 다음 날 일정과 겹칩니다. 다음 날 시작은 오전 9시로 유지하므로 이동 구간·방문 지역 또는 숙소를 조정해야 합니다.");
                    // Ask only after trying the within-limit alternatives. Departure flights are
                    // immutable; a previous day's consent cannot answer for this day.
                    if(finish<=hardLimit && PlanGenerationJobs.requestEndTimeExtension(day.getDayNumber(),day.getDate(),deadline,finish,adjusted.getFirst().getDisplayName(),last.getDisplayName())){
                        day.getItems().clear();day.getItems().addAll(adjusted);
                        warnings.add(day.getDayNumber()+"일차는 사용자 허용에 따라 설정한 종료 시각 "+TimeUtil.format(deadline)+"을 넘겨 "+(finish>=1440?"다음날 ":"")+TimeUtil.format(finish)+"에 종료합니다.");
                        break;
                    }
                    throw new PlanGenerationException(day.getDayNumber()+"일차는 "+adjusted.getFirst().getDisplayName()+"에서 "+last.getDisplayName()+"까지 이동하면 "+(finish>=1440?"다음날 ":"")+TimeUtil.format(finish)+"에 도착하여 종료 시각 "+TimeUtil.format(deadline)+"을 넘습니다. 해당 일차의 숙소·지역 또는 종료 시각을 조정해주세요.");
                }
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
