package com.travel.planner.service;

import com.travel.planner.dto.PlanRequest;
import com.travel.planner.entity.*;
import com.travel.planner.repository.*;
import com.travel.planner.util.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import java.util.*;

/** Item replacement with fixed remaining identities, order and dwell durations. */
@Service
@RequiredArgsConstructor
public class PlanItemAdjustmentService {
    private final PlanRepository plans;
    private final PlaceRepository places;
    private final PlanPersistenceService persistence;
    private final PlanService engine;
    private final RemainingDayReflow reflow;
    @org.springframework.beans.factory.annotation.Autowired(required=false) private SupplementalFoodService food;
    @org.springframework.beans.factory.annotation.Autowired(required=false) private LodgingCostService prices;

    private record Target(Plan plan,Itinerary item,List<Itinerary> day,int index,PlanRequest request) {}
    private Target target(String email,Long planId,Long itemId,String theme,String companion) {
        Plan plan=plans.findDetailById(planId).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"일정을 찾을 수 없습니다."));
        if(plan.getUser()==null || !email.equals(plan.getUser().getEmail()))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"본인의 일정만 수정할 수 있습니다.");
        Itinerary item=plan.getItineraries().stream().filter(i->itemId.equals(i.getId())).findFirst().orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"일정 항목을 찾을 수 없습니다."));
        if(item.getPlace()!=null && PlanService.isAirport(item.getPlace()))throw new IllegalArgumentException("공항 일정은 변경할 수 없습니다.");
        if(item.getPlace()!=null && "DUMMY_FIXED_SCHEDULE".equals(item.getPlace().getPlaceId()))throw new IllegalArgumentException("고정 일정은 변경할 수 없습니다.");
        // A hotel departure refers to the previous night's stay.
        if(item.getPlace()!=null && PlanService.isLodging(item.getPlace()) && item.getDayNumber()>1) {
            int priorDay=item.getDayNumber()-1;
            var prior=plan.getItineraries().stream().filter(i->i.getDayNumber()==priorDay)
                .max(Comparator.comparing(Itinerary::getSequence)).orElse(null);
            if(prior!=null && same(prior.getPlace(),item.getPlace()))item=prior;
        }
        final Itinerary selected=item;
        var day=plan.getItineraries().stream().filter(i->i.getDayNumber().equals(selected.getDayNumber())).sorted(Comparator.comparing(Itinerary::getSequence)).toList();
        PlanRequest request=persistence.restoreRequest(plan);
        if(theme!=null && !theme.isBlank()) {
            String normalized=ThemeVocabulary.normalize(theme);
            if(normalized==null)throw new IllegalArgumentException("테마를 다시 선택해주세요.");
            request.setThemes(List.of(normalized));
        }
        if(companion!=null && !companion.isBlank()) {
            var values=Arrays.stream(companion.split(",")).map(String::trim).toList();
            if(values.stream().anyMatch(v->!Set.of("혼자","친구","연인","부모님","어린이","배우자","가족").contains(v)) || (values.contains("혼자") && values.size()>1))throw new IllegalArgumentException("동행인을 다시 선택해주세요.");
            request.setCompanion(companion);
        }
        return new Target(plan,item,day,day.indexOf(item),request);
    }
    private List<PlanService.DayItem> inputs(List<Itinerary> day) {
        if(food==null)return PlanReplaceService.toDayItems(day);
        var overlay=food.load(day);var result=PlanReplaceService.toDayItems(day);
        for(int i=0;i<day.size();i++)if(overlay.containsKey(day.get(i).getId())) {
            var d=result.get(i);d.place=overlay.get(day.get(i).getId());d.type=PlanService.SimulatedItinerary.Type.VISIT;d.title=null;
        }
        return result;
    }
    private List<Place> pool(Target t,String theme) {
        var old=t.item.getPlace();boolean hotel=old!=null && PlanService.isLodging(old);
        Set<String> used=new HashSet<>();for(var i:t.plan.getItineraries())if(i.getPlace()!=null)used.add(i.getPlace().getPlaceId());
        if(t.plan.getRejectedPlaceIds()!=null)used.addAll(Arrays.asList(t.plan.getRejectedPlaceIds().split(",")));
        var cityList=new ArrayList<String>(t.request.getCities()==null?List.of():t.request.getCities());
        if(old!=null && old.getCity()!=null && !cityList.contains(old.getCity()))cityList.add(old.getCity());
        PlaceKind oldKind=old==null?null:PlaceKind.of(old);
        String wanted=ThemeVocabulary.normalize(theme);
        var effective=inputs(t.day);Place anchor=effective.get(t.index).place;
        if(!located(anchor))anchor=effective.subList(0,t.index).reversed().stream().map(d->d.place).filter(PlanItemAdjustmentService::located).findFirst().orElse(null);
        if(!located(anchor))anchor=effective.stream().map(d->d.place).filter(PlanItemAdjustmentService::located).findFirst().orElse(null);
        final Place center=anchor;
        final String targetCity=old!=null && old.getCity()!=null && !old.getCity().isBlank()?old.getCity():center==null?null:center.getCity();
        return places.findByCityIn(cityList).stream().filter(p->p.getPlaceId()!=null && !used.contains(p.getPlaceId()))
            .filter(p->p.getLatitude()!=null && p.getLongitude()!=null && !(p.getLatitude()==0 && p.getLongitude()==0))
            .filter(p->!PlanService.isAirport(p) && !PlanService.isPseudoCategory(p.getCategory()))
            .filter(p->hotel==PlanService.isLodging(p))
            .filter(p->targetCity==null || targetCity.equals(p.getCity()))
            .filter(p->{if(hotel)return true;var k=PlaceKind.of(p);
                if(oldKind==PlaceKind.RESTAURANT || oldKind==PlaceKind.BAR || "DUMMY_MEAL".equals(old==null?null:old.getPlaceId()))return k==PlaceKind.RESTAURANT || k==PlaceKind.BAR;
                if(oldKind==PlaceKind.CAFE)return k==PlaceKind.CAFE;
                if("맛집".equals(wanted))return k==PlaceKind.RESTAURANT;
                if("카페".equals(wanted))return k==PlaceKind.CAFE;
                return k!=PlaceKind.RESTAURANT && k!=PlaceKind.BAR && k!=PlaceKind.CAFE;})
            .filter(p->hotel || wanted==null || PlaceDescriber.themeListOf(p).stream().anyMatch(v->wanted.equals(ThemeVocabulary.normalize(v))))
            .sorted(Comparator.comparingDouble(p->distance(center,p))).limit(30).toList();
    }
    private static boolean located(Place p) {return p!=null && !PlanService.isPseudoCategory(p.getCategory()) && p.getLatitude()!=null && p.getLongitude()!=null && !(p.getLatitude()==0 && p.getLongitude()==0);}
    private static double distance(Place a,Place b) {
        return a==null || a.getLatitude()==null || a.getLongitude()==null?0:DistanceUtil.calculateDistance(a.getLatitude(),a.getLongitude(),b.getLatitude(),b.getLongitude());
    }
    private static boolean same(Place a,Place b){return a!=null && b!=null && Objects.equals(a.getPlaceId(),b.getPlaceId());}
    private PlanService.DayContext context(Target t,int number,List<PlanService.DayItem> day) {
        Place start=day.getFirst().type==PlanService.SimulatedItinerary.Type.START?day.getFirst().place:null;
        Place end=day.getLast().type==PlanService.SimulatedItinerary.Type.END?day.getLast().place:null;
        return engine.buildDayContext(t.request,number,t.plan.totalDays(),start,end);
    }
    private Map<Integer,List<PlanService.SimulatedItinerary>> changed(Target t,Place selected) {
        var day=inputs(t.day);var old=day.get(t.index);boolean hotel=PlanService.isLodging(selected);
        Integer end=hotel?null:old.startMin+engine.calculateDwellTime(selected,t.request);
        var type=hotel?old.type:PlanService.SimulatedItinerary.Type.VISIT;
        day.set(t.index,new PlanService.DayItem(type,selected,null,old.startMin,end));
        Map<Integer,List<PlanService.SimulatedItinerary>> result=new TreeMap<>();
        var updated=reflow.reflow(t.request,context(t,t.item.getDayNumber(),day),day,t.index);
        result.put(t.item.getDayNumber(),updated);
        if(hotel && old.type==PlanService.SimulatedItinerary.Type.END) {
            int next=t.item.getDayNumber()+1;
            var nextRows=t.plan.getItineraries().stream().filter(i->i.getDayNumber()==next).sorted(Comparator.comparing(Itinerary::getSequence)).toList();
            if(!nextRows.isEmpty()) {
                var following=inputs(nextRows);var first=following.getFirst();
                if(!same(first.place,old.place))throw new IllegalArgumentException("다음 날 출발 숙소를 확인할 수 없어 변경할 수 없습니다.");
                int depart=Math.max(first.startMin,updated.getLast().getStartMin()-1440);
                following.set(0,new PlanService.DayItem(first.type,selected,null,depart,null));
                result.put(next,reflow.reflow(t.request,context(t,next,following),following,0));
            }
        }
        return result;
    }
    @Transactional(readOnly=true)
    public List<Map<String,Object>> alternatives(String email,Long planId,Long itemId,String theme,String companion) {
        Target t=target(email,planId,itemId,theme,companion);List<Map<String,Object>> result=new ArrayList<>();
        for(var p:pool(t,theme)) {
            try {changed(t,p);}catch(IllegalArgumentException ex){continue;}
            Map<String,Object> row=new LinkedHashMap<>();row.put("placeId",p.getPlaceId());row.put("placeName",p.shownName());row.put("address",p.getAddress());row.put("category",p.getCategory());result.add(row);
            if(result.size()==8)break;
        }
        return result;
    }
    @Transactional
    public void replace(String email,Long planId,Long itemId,String selectedId,String theme,String companion) {
        Target t=target(email,planId,itemId,theme,companion);
        Place selected=pool(t,theme).stream().filter(p->Objects.equals(p.getPlaceId(),selectedId)).findFirst().orElseThrow(()->new IllegalArgumentException("대체 장소 후보를 다시 확인해주세요."));
        var adjusted=changed(t,selected); // Validate all days before making any persistent changes.
        if(PlanService.isLodging(selected) && t.index==t.day.size()-1)updateStay(t,selected);
        for(var entry:adjusted.entrySet())persistence.replaceDay(t.plan,entry.getKey(),entry.getValue());
        var rejected=new LinkedHashSet<String>();if(t.plan.getRejectedPlaceIds()!=null)rejected.addAll(Arrays.asList(t.plan.getRejectedPlaceIds().split(",")));
        if(t.item.getPlace()!=null)rejected.add(t.item.getPlace().getPlaceId());t.plan.setRejectedPlaceIds(String.join(",",rejected));plans.save(t.plan);
    }
    private void updateStay(Target t,Place hotel) {
        var night=(t.plan.undated()?Plan.UNDATED_BASE:t.plan.getStartDate()).plusDays(t.item.getDayNumber()-1);
        var old=t.plan.getAccommodations().stream().filter(a->!a.getCheckIn().isAfter(night) && a.getCheckOut().isAfter(night)).findFirst().orElse(null);
        if(old==null)throw new IllegalArgumentException("해당 날짜의 숙박 정보를 확인할 수 없습니다.");
        var start=old.getCheckIn();var end=old.getCheckOut();
        if(start.isBefore(night)) t.plan.addAccommodation(copyStay(old,start,night));
        if(end.isAfter(night.plusDays(1))) t.plan.addAccommodation(copyStay(old,night.plusDays(1),end));
        old.setCheckIn(night);old.setCheckOut(night.plusDays(1));old.setPlaceId(hotel.getPlaceId());old.setName(hotel.shownName());old.setAddress(hotel.getAddress());old.setLatitude(hotel.getLatitude());old.setLongitude(hotel.getLongitude());old.setPriceYen(null);
        if(prices!=null)prices.estimate(List.of(old),t.plan.undated()?Plan.UNDATED_BASE:t.plan.getStartDate(),t.plan.undated(),1);
    }
    private Accommodation copyStay(Accommodation old,java.time.LocalDate in,java.time.LocalDate out) {
        var a=new Accommodation();a.setPlaceId(old.getPlaceId());a.setName(old.getName());a.setAddress(old.getAddress());a.setCheckIn(in);a.setCheckOut(out);return a;
    }
}
