package com.travel.planner.service;

import com.travel.planner.entity.*;
import com.travel.planner.repository.PlanRepository;
import com.travel.planner.repository.TrafficRepository;
import com.travel.planner.util.OpeningHours;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import java.util.*;
import java.util.stream.Collectors;

/** Read-only adapter. Movement routes are calculated from the current transit DB; no enrichment or writes. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class SavedPlanQueryService {
    @org.springframework.beans.factory.annotation.Autowired
    private KoreanPlaceDescriptions koreanDescriptions;
    @org.springframework.beans.factory.annotation.Autowired
    private HotelBudgetService hotelBudget;
    @org.springframework.beans.factory.annotation.Autowired
    private LodgingCostService lodgingPrices;
    @org.springframework.beans.factory.annotation.Autowired
    private AirportAccessService airportAccess;
    private final PlanRepository plans;
    private final TrafficRepository traffic;
    private final RailRouteService routes;
    @org.springframework.beans.factory.annotation.Autowired
    private PassAdvisorService passAdvisor;
    @org.springframework.beans.factory.annotation.Autowired
    private SupplementalFoodService supplementalFood;
    @org.springframework.beans.factory.annotation.Autowired
    private com.travel.planner.repository.PlaceRepository placeRepository;

    public List<Map<String, Object>> list(String email) {
        return plans.findAllByUserEmail(email).stream()
                .sorted(Comparator.comparing(Plan::getId).reversed())
                .map(p -> {
                    Map<String,Object> m = new LinkedHashMap<>();
                    m.put("id",p.getId()); m.put("title",p.getTitle());
                    m.put("startDate",p.undated()?null:p.getStartDate()); m.put("endDate",p.undated()?null:p.getEndDate()); m.put("tripDays",p.totalDays());
                    return m;
                }).toList();
    }

    public Map<String,Object> detail(String email, Long id) {
        Plan p=plans.findDetailById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,"일정을 찾을 수 없습니다."));
        if(p.getUser()==null || !email.equals(p.getUser().getEmail()))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,"본인의 일정만 조회할 수 있습니다.");
        Map<Long,Traffic> legs=p.getItineraries().isEmpty() ? Map.of() : traffic.findByItineraryIn(p.getItineraries()).stream()
                .collect(Collectors.toMap(t -> t.getItinerary().getId(),t -> t,(a,b) -> a));
        List<Map<String,Object>> timeline=new ArrayList<>();
        List<Itinerary> items=new ArrayList<>(p.getItineraries());
        items.sort(Comparator.comparing(Itinerary::getDayNumber).thenComparing(Itinerary::getSequence));
        Map<Integer,Itinerary> previousByDay=new HashMap<>();
        Map<Long,Place> displayed=supplementalFood==null?new HashMap<>():new HashMap<>(supplementalFood.load(items));
        Set<String> usedFood=new HashSet<>();for(var item:items)if(item.getPlace()!=null)usedFood.add(item.getPlace().getPlaceId());
        List<Place> primaryFood=placeRepository==null?List.of():placeRepository.findByCityIn(p.getCities()==null?List.of():Arrays.stream(p.getCities().split(",")).map(String::trim).toList());

        for(Itinerary i:items) {
            int[] mealWindow=null;
            Place place=displayed.getOrDefault(i.getId(),i.getPlace());
            if(supplementalFood!=null && place!=null && "식사".equals(place.getCategory()) && i.getCustomTitle()!=null && (i.getCustomTitle().contains("주변 자유 식사") || i.getCustomTitle().contains("식사 (숙소 근처)"))) {
                Itinerary prev=previousByDay.get(i.getDayNumber());Place previous=prev==null?null:displayed.getOrDefault(prev.getId(),prev.getPlace());
                Place next=items.stream().filter(n->n.getDayNumber().equals(i.getDayNumber()) && n.getSequence()>i.getSequence() && validLocation(n.getPlace())).map(Itinerary::getPlace).findFirst().orElse(null);
                Place meal=supplementalFood.mealAt(p,i,previous,next,usedFood,primaryFood);
                if(meal!=null){mealWindow=supplementalFood.mealWindow(p,i,previous,meal,next);place=meal;displayed.put(i.getId(),meal);usedFood.add(meal.getPlaceId());}
            }

            Map<String,Object> item=new LinkedHashMap<>();
            item.put("id",i.getId()); item.put("day",i.getDayNumber()); item.put("time",i.getTime()); item.put("endTime",i.getEndTime());
            item.put("placeName",SupplementalFoodService.supplemental(place) ? place.shownName() : i.getCustomTitle()!=null && !displayed.containsKey(i.getId()) ? i.getCustomTitle() : place==null ? "일정" : place.shownName());
            item.put("description",mealWindow==null?i.getAiComment():place.getSummary());
            if(mealWindow!=null){item.put("time",com.travel.planner.util.TimeUtil.format(mealWindow[0]));item.put("endTime",com.travel.planner.util.TimeUtil.format(mealWindow[1]));}
            if(place!=null) {
                if(koreanDescriptions!=null && PlanService.isLodging(place)) item.put("description",koreanDescriptions.summary(place));
                item.put("diningType",DiningInformation.type(place));item.put("diningGuide",DiningInformation.guide(place));
                if(hotelBudget!=null)item.put("averageHotelPriceYen",hotelBudget.price(place));
                if(lodgingPrices!=null) {item.putAll(lodgingPrices.cachedDisplayPrice(place));item.put("hotelPriceComparisons",lodgingPrices.cachedComparisons(place));}
                item.put("placeId",place.getPlaceId()); item.put("category",place.getCategory());
                item.put("latitude",place.getLatitude()); item.put("longitude",place.getLongitude());
                item.put("formattedAddress",place.getAddress()); item.put("phoneNumber",place.getPhone());
                item.put("openingDays","");item.put("weeklyOpeningHours",place.getOpeningHours());
                item.put("openingHours",koreanDescriptions==null?OpeningHours.describe(place,p.dateOfDay(i.getDayNumber())):koreanDescriptions.hours(place,p.dateOfDay(i.getDayNumber())));
                item.put("subType",place.getSubType()); item.put("summary",koreanDescriptions==null?place.getSummary():koreanDescriptions.summary(place));
                item.put("theme",place.getTheme()); item.put("themes",com.travel.planner.util.PlaceDescriber.themeListOf(place));
            }
            Traffic leg=legs.get(i.getId());
            if(leg!=null) {
                item.put("travelMinutes",leg.getDurationMinutes());
                Map<String,Object> transit=new LinkedHashMap<>();
                transit.put("mode",leg.getTransportType()); transit.put("summary",leg.getPathDetails());
                transit.put("fareYen",leg.getEstimatedCost()); transit.put("minutes",leg.getDurationMinutes());
                item.put("transit",transit);
            }
            // Stored Traffic summaries omit ride steps. Resolve them against the user's transit DB.
            if(place!=null && "비행기".equals(place.getCategory())){
                Itinerary prev=previousByDay.get(i.getDayNumber());
                Itinerary next=items.stream().filter(n->n.getDayNumber().equals(i.getDayNumber()) && n.getSequence()>i.getSequence() && validLocation(n.getPlace())).findFirst().orElse(null);
                if(prev!=null && next!=null){
                    var from=displayed.getOrDefault(prev.getId(),prev.getPlace());var to=next.getPlace();
                    var route=routes.leg(from,to,p.getTransportation(),0,p.dateOfDay(i.getDayNumber()),parseMinute(prev.getEndTime()));
                    if(route!=null){item.put("transit",route);item.put("travelMinutes",route.getMinutes());}
                    previousByDay.put(i.getDayNumber(),next);
                }
            }
            if(validLocation(place)) {
                Itinerary previous=previousByDay.put(i.getDayNumber(),i);
                if(previous!=null && validLocation(displayed.getOrDefault(previous.getId(),previous.getPlace()))) {
                    Place from=displayed.getOrDefault(previous.getId(),previous.getPlace());
                    int schedule=leg==null || leg.getDurationMinutes()==null ? 0 : leg.getDurationMinutes();
                    Integer depart=parseMinute(previous.getEndTime());
                    if(depart==null) {
                        Integer arrival=parseMinute(i.getTime());
                        if(arrival!=null) depart=Math.max(0,arrival-schedule);
                    }
                    var route=routes.leg(from,place,p.getTransportation(),schedule,
                            p.dateOfDay(i.getDayNumber()),depart);
                    if(route!=null) {
                        item.put("transit",route);
                        item.put("travelMinutes",route.getMinutes());
                    }
                    if(route!=null && airportAccess!=null && PlanService.isAirport(from)) {
                        for(var prior:timeline)if(java.util.Objects.equals(prior.get("id"),previous.getId()))prior.put("airportAccess",airportAccess.details(from.getName(),from.getLatitude(),from.getLongitude(),route));
                    }
                }
            }
            if(validLocation(place))displayed.put(i.getId(),place);
            if(PlanService.isAirport(place)){item.put("description", "");item.put("summary", "");}
            timeline.add(item);
        }
        TimelineConsistency.repairSaved(timeline);
        Map<String,Object> request=new LinkedHashMap<>();
        request.put("title",p.getTitle()); request.put("startDate",p.undated()?null:p.getStartDate()); request.put("endDate",p.undated()?null:p.getEndDate()); request.put("tripDays",p.totalDays());
        request.put("cities",p.getCities()==null ? List.of() : Arrays.stream(p.getCities().split(",")).map(String::trim).filter(x -> !x.isEmpty()).toList());
        request.put("inCity",p.getInCity()); request.put("outCity",p.getOutCity());
        request.put("inTime",p.getInTime()); request.put("outTime",p.getOutTime());
        request.put("transportation",p.getTransportation());
        if(hotelBudget!=null)request.putAll(hotelBudget.settings(p.getId()));
        request.put("themes",p.getTheme()==null?List.of():Arrays.stream(p.getTheme().split(",")).map(String::trim).toList());
        request.put("preferredStartTime",p.getPreferredStartTime());request.put("preferredEndTime",p.getPreferredEndTime());
        Map<String,Object> response=new LinkedHashMap<>();
        response.put("planId",p.getId()); response.put("title",p.getTitle()); response.put("reason",p.getAiReason()); response.put("timeline",timeline);
        if (passAdvisor != null) {
            var computed=new com.travel.planner.dto.AiRouteResponse();
            List<com.travel.planner.dto.AiRouteResponse.TimelineItem> costItems=new ArrayList<>();
            for(var item:timeline) {
                var row=new com.travel.planner.dto.AiRouteResponse.TimelineItem();row.setDay((Integer)item.get("day"));row.setTime((String)item.get("time"));
                if(item.get("transit") instanceof com.travel.planner.dto.TransitLegDto leg)row.setTransit(leg);
                else if(item.get("transit") instanceof Map<?,?> old) {
                    var leg=new com.travel.planner.dto.TransitLegDto();
                    if(old.get("fareYen") instanceof Number n)leg.setFareYen(n.intValue());
                    if(old.get("minutes") instanceof Number n)leg.setMinutes(n.intValue());row.setTransit(leg);
                }
                costItems.add(row);
            }
            List<com.travel.planner.dto.AiRouteResponse.DaySummary> summaries=new ArrayList<>();
            for(int day=1;day<=p.totalDays();day++) {
                var date=p.dateOfDay(day);List<PlanService.SimulatedItinerary> simulated=new ArrayList<>();Map<String,Integer> cityCounts=new LinkedHashMap<>();
                for(var original:items)if(original.getDayNumber()==day) {
                    Place loc=displayed.getOrDefault(original.getId(),original.getPlace());
                    var type=loc!=null && "식사".equals(loc.getCategory())?PlanService.SimulatedItinerary.Type.MEAL:loc!=null && "자유시간".equals(loc.getCategory())?PlanService.SimulatedItinerary.Type.FREE:PlanService.SimulatedItinerary.Type.VISIT;
                    if(PlanService.isLodging(loc) || PlanService.isAirport(loc)) {
                        if(original.getSequence()==1)type=PlanService.SimulatedItinerary.Type.START;
                        else if(items.stream().noneMatch(n->n.getDayNumber().equals(original.getDayNumber()) && n.getSequence()>original.getSequence()))type=PlanService.SimulatedItinerary.Type.END;
                    }
                    if(type==PlanService.SimulatedItinerary.Type.VISIT && loc!=null && loc.getCity()!=null)cityCounts.merge(loc.getCity(),1,Integer::sum);
                    if(type==PlanService.SimulatedItinerary.Type.MEAL || type==PlanService.SimulatedItinerary.Type.FREE)loc=null;
                    var shown=timeline.stream().filter(t->original.getId().equals(t.get("id"))).findFirst().orElseThrow();
                    Integer end=shown.get("endTime")==null?null:com.travel.planner.util.TimeUtil.parseClock((String)shown.get("endTime"));
                    int movement=shown.get("transit") instanceof com.travel.planner.dto.TransitLegDto leg?leg.getMinutes():shown.get("travelMinutes") instanceof Number n?n.intValue():0;
                    simulated.add(new PlanService.SimulatedItinerary(type,loc,(String)shown.get("placeName"),com.travel.planner.util.TimeUtil.parseClock((String)shown.get("time")),end,movement,loc==null?null:loc.getLatitude(),loc==null?null:loc.getLongitude()));
                }
                String city=cityCounts.entrySet().stream().max(Map.Entry.comparingByValue()).map(Map.Entry::getKey).orElse(null);
                summaries.add(PlanSummarizer.summarizeDay(day,date,city,simulated,null,null));
            }
            computed.setTimeline(costItems);computed.setDays(summaries);TransitTotals.apply(computed,true);passAdvisor.apply(computed);
            if(computed.getTransitFareYen()!=null && response.get("reason") instanceof String reason)
                response.put("reason",reason.replaceAll("교통비는 합계 약 [0-9,]+엔\\(성인 1인, 추정\\)입니다\\.", "교통비는 합계 약 "+TransitTotals.yen(computed.getTransitFareYen())+"(성인 1인, 추정)입니다."));
            response.put("days",computed.getDays());response.put("passes",computed.getPasses());response.put("transportCosts",computed.getTransportCosts());
            response.put("transitFareYen",computed.getTransitFareYen());response.put("transitFareWithPassesYen",computed.getTransitFareWithPassesYen());
        }
        if(lodgingPrices!=null && !p.getAccommodations().isEmpty()) {
            List<Accommodation> stays=new ArrayList<>();
            for(var original:p.getAccommodations()) {
                var copy=new Accommodation();copy.setName(original.getName());copy.setPlaceId(original.getPlaceId());copy.setCheckIn(original.getCheckIn());copy.setCheckOut(original.getCheckOut());
                var loc=displayed.values().stream().filter(v->java.util.Objects.equals(v.getPlaceId(),original.getPlaceId())).findFirst().orElse(null);
                if(loc==null)loc=items.stream().map(Itinerary::getPlace).filter(java.util.Objects::nonNull).filter(v->java.util.Objects.equals(v.getPlaceId(),original.getPlaceId())).findFirst().orElse(null);
                if(loc!=null){copy.setLatitude(loc.getLatitude());copy.setLongitude(loc.getLongitude());}
                stays.add(copy);
            }
            var costs=lodgingPrices.estimateCached(stays,p.undated()?Plan.UNDATED_BASE:p.getStartDate(),p.undated(),2);
            response.put("lodgings",costs.lodgings);
        }
        return Map.of("request",request,"response",response);
    }
    private static boolean validLocation(Place place) {
        return place!=null && place.getLatitude()!=null && place.getLongitude()!=null
                && !(place.getLatitude()==0 && place.getLongitude()==0);
    }
    private static Integer parseMinute(String value) {
        if(value==null || !value.matches("\\d{2}:\\d{2}")) return null;
        int hour=Integer.parseInt(value.substring(0,2)),minute=Integer.parseInt(value.substring(3,5));
        return hour<24 && minute<60 ? hour*60+minute : null;
    }

}
