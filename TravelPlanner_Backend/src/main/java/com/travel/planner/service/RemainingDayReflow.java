package com.travel.planner.service;

import com.travel.planner.dto.PlanRequest;
import com.travel.planner.entity.Place;
import com.travel.planner.util.OpeningHours;
import java.util.*;
import org.springframework.stereotype.Service;
import lombok.RequiredArgsConstructor;

/** Retains every stop and its order; recomputes only the changed stop and its suffix. */
@Service
@RequiredArgsConstructor
public class RemainingDayReflow {
    private final PlanService engine;

    public List<PlanService.SimulatedItinerary> reflow(PlanRequest request, PlanService.DayContext ctx,
            List<PlanService.DayItem> day, int from) {
        List<PlanService.SimulatedItinerary> result = new ArrayList<>();
        Place previous = null;
        int cursor = ctx.startMin;
        Integer lastMealStart = null;
        int buffer = engine.calculateBufferTime(request);
        for (int i=0;i<day.size();i++) {
            var item=day.get(i);
            Place location=item.hasLocation()?item.place:null;
            if(item.type==PlanService.SimulatedItinerary.Type.FIXED) {
                var block=ctx.blocks.stream().filter(b->b.start==item.startMin && b.hasLocation()).findFirst().orElse(null);
                if(block!=null) {location=new Place();location.setLatitude(block.lat);location.setLongitude(block.lng);}
            }
            boolean located=location!=null;
            int travel=located && previous!=null ? engine.travel(ctx,previous.getLatitude(),previous.getLongitude(),location.getLatitude(),location.getLongitude()) : 0;
            int start=item.startMin;
            Integer end=item.endMin;
            if(i>=from) {
                int earliest=i==0 ? item.startMin : ceil(cursor+travel);
                int dwell=end==null?0:Math.max(0,end-start);
                boolean meal=item.place!=null && (com.travel.planner.util.PlaceKind.of(item.place)==com.travel.planner.util.PlaceKind.RESTAURANT || com.travel.planner.util.PlaceKind.of(item.place)==com.travel.planner.util.PlaceKind.BAR);
                if(meal && lastMealStart!=null) earliest=Math.max(earliest,lastMealStart+(PlanService.mealCount(request)>3?150:300));
                if(item.type==PlanService.SimulatedItinerary.Type.FIXED || (item.place!=null && PlanService.isAirport(item.place))) {
                    if(earliest>start) throw new IllegalArgumentException("고정 일정 또는 공항 도착 시간을 지킬 수 없어 변경할 수 없습니다.");
                } else {
                    start=earliest;
                    if(located && item.type==PlanService.SimulatedItinerary.Type.VISIT && !PlanService.isLodging(item.place)) {
                        var intervals=OpeningHours.intervalsOn(item.place,ctx.date);
                        if(intervals!=null) {
                            boolean fits=false;
                            for(var range:intervals) {
                                int candidate=Math.max(start,range[0]);
                                if(candidate+dwell<=range[1]) {start=candidate;fits=true;break;}
                            }
                            if(!fits)throw new IllegalArgumentException("남은 방문지의 영업시간을 지킬 수 없어 변경할 수 없습니다.");
                        }
                    }
                    if(end!=null)end=start+dwell;
                }
                int finish=end==null?start:end;
                int deadline=ctx.hardDeadlineMin==null?ctx.endMin:Math.min(ctx.endMin,ctx.hardDeadlineMin);
                if(finish>deadline)throw new IllegalArgumentException("남은 장소를 유지하면 하루 종료 시간을 넘기므로 다른 장소를 선택해주세요.");
            }
            result.add(new PlanService.SimulatedItinerary(item.type,item.place,item.title,start,end,travel,
                located?location.getLatitude():null,located?location.getLongitude():null));
            cursor=(end==null?start:end)+(item.type==PlanService.SimulatedItinerary.Type.VISIT?buffer:0);
            if(located) {
                previous=location;
                if(item.place!=null) {
                    var kind=com.travel.planner.util.PlaceKind.of(item.place);
                    if(kind==com.travel.planner.util.PlaceKind.RESTAURANT || kind==com.travel.planner.util.PlaceKind.BAR)lastMealStart=start;
                }
            }
        }
        return result;
    }
    static int ceil(int value) {return ((value+4)/5)*5;}
}
