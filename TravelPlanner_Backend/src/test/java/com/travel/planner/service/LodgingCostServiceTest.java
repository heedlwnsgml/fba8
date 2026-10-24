package com.travel.planner.service;

import com.travel.planner.dto.AiRouteResponse;
import com.travel.planner.dto.LodgingCostDto;
import com.travel.planner.entity.Accommodation;
import com.travel.planner.entity.Plan;
import com.travel.planner.lodging.RakutenHotels;
import com.travel.planner.lodging.RakutenTravelApi;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** 숙박비: 직접 입력 / 라쿠텐 빈방 최저가 / 날짜 미정이면 표시 최저가 / 못 찾으면 비움 */
class LodgingCostServiceTest {

    // 라쿠텐 응답 모양 (formatVersion=2: hotels 가 배열의 배열)
    static final String NEAR = "{\"hotels\":[" +
            "[{\"hotelBasicInfo\":{\"hotelNo\":111,\"hotelName\":\"ホテルアソシア静岡\",\"latitude\":34.9717,\"longitude\":138.3891,\"hotelMinCharge\":9800,\"hotelInformationUrl\":\"https://travel.rakuten.co.jp/HOTEL/111/\"}}]," +
            "[{\"hotelBasicInfo\":{\"hotelNo\":222,\"hotelName\":\"静岡ステーションホテル\",\"latitude\":34.9740,\"longitude\":138.3900,\"hotelMinCharge\":5500}}]]}";
    // 빈방 검색: 방마다 dailyCharge (formatVersion=1 모양: hotel 안에 roomInfo 배열)
    static final String VACANT = "{\"hotels\":[{\"hotel\":[{\"hotelBasicInfo\":{\"hotelNo\":111,\"hotelName\":\"ホテルアソシア静岡\",\"hotelMinCharge\":9800}}," +
            "{\"roomInfo\":[{\"roomBasicInfo\":{\"roomName\":\"ツイン\"}},{\"dailyCharge\":{\"stayDate\":\"2026-10-17\",\"rakutenCharge\":12000,\"total\":24000,\"chargeFlag\":0}}]}," +
            "{\"roomInfo\":[{\"roomBasicInfo\":{\"roomName\":\"ダブル\"}},{\"dailyCharge\":{\"stayDate\":\"2026-10-17\",\"rakutenCharge\":19000,\"total\":19000,\"chargeFlag\":1}}]}," +
            "{\"roomInfo\":[{\"roomBasicInfo\":{\"roomName\":\"スイート\"}},{\"dailyCharge\":{\"stayDate\":\"2026-10-17\",\"rakutenCharge\":80000,\"total\":80000,\"chargeFlag\":1}}]}]}]}";

    static class FakeRakuten implements RakutenTravelApi {
        boolean configured = true;
        String near = NEAR;
        String vacant = VACANT;
        final List<String> calls = new ArrayList<>();
        public boolean configured() { return configured; }
        public String simpleSearch(double lat, double lng, double radiusKm) { calls.add("simple"); return near; }
        public String vacantSearch(long hotelNo, LocalDate in, LocalDate out, int adults, int rooms) {
            calls.add("vacant " + hotelNo + " " + in + "~" + out + " " + adults + "명 " + rooms + "실");
            return vacant;
        }
    }

    private static final LocalDate BASE = LocalDate.of(2026, 10, 17);

    @Test
    void parsesBothResponseShapes() {
        List<RakutenHotels.Hotel> near = RakutenHotels.parse(NEAR);
        assertEquals(2, near.size());
        assertEquals(111, near.get(0).hotelNo);
        assertEquals(9800, near.get(0).minCharge);
        assertEquals("https://travel.rakuten.co.jp/HOTEL/111/", near.get(0).url);
        List<RakutenHotels.Hotel> vacant = RakutenHotels.parse(VACANT);
        assertEquals(1, vacant.size());
        assertEquals(19000, vacant.get(0).lowestNightTotal, "방 가운데 1박 합계가 가장 싼 값");
        assertTrue(RakutenHotels.parse("{\"hotels\":[]}").isEmpty());
        assertTrue(RakutenHotels.parse("not json").isEmpty());
        assertTrue(RakutenHotels.parse(null).isEmpty());
        assertEquals("wrong_parameter: specify valid applicationId",
                RakutenHotels.error("{\"error\":\"wrong_parameter\",\"error_description\":\"specify valid applicationId\"}"));
    }

    @Test
    void requestValuesAreEncodedOneByOne() {
        java.util.Map<String, Object> q = new java.util.LinkedHashMap<>();
        q.put("accessKey", "a+b/c=");
        q.put("sort", "+roomCharge");
        q.put("hotelNo", 111);
        assertEquals("https://example.com/api?accessKey=a%2Bb%2Fc%3D&sort=%2BroomCharge&hotelNo=111",
                com.travel.planner.lodging.RakutenTravelClient.uri("https://example.com/api", q).toString(), "'+' 가 공백으로 읽히지 않게");
    }

    @Test
    void datedTripUsesListedMinimumWithoutVacancySearch() {
        FakeRakuten api = new FakeRakuten();
        LodgingCostService service = new LodgingCostService(api);
        Accommodation hotel = stay("호텔 아소시아 시즈오카", BASE, BASE.plusDays(3), 34.97165, 138.38905, "P_ASSOCIA");

        LodgingCostService.Result r = service.estimate(List.of(hotel), BASE, false, 2);

        LodgingCostDto dto = r.lodgings.get(0);
        assertEquals("rakuten-estimate", dto.getSource());
        assertEquals(3, dto.getNights());
        assertEquals(9800, dto.getPerNightYen());
        assertEquals(9800, dto.getLowestNightPerRoomYen());
        assertEquals(29400, dto.getTotalYen(), "표시 1박 최저가 × 3박");
        assertEquals("ホテルアソシア静岡", dto.getMatchedHotelName());
        assertEquals(1, dto.getCheckInDay());
        assertEquals(4, dto.getCheckOutDay());
        assertEquals("2026-10-17", dto.getCheckIn());
        assertEquals(29400, r.totalYen);
        assertTrue(r.complete);
        assertEquals(29400, hotel.getPriceYen(), "응답용 숙소에도 남긴다");
        assertEquals("rakuten-estimate", hotel.getPriceSource());
        assertEquals(List.of("simple"), api.calls);

        // The service delegates every search to the provider client, whose persistent cache owns expiry.
        api.calls.clear();
        service.estimate(List.of(stay("호텔 아소시아 시즈오카", BASE, BASE.plusDays(1), 34.97165, 138.38905, "P_ASSOCIA")), BASE, false, 3);
        assertEquals(List.of("simple"), api.calls);
    }

    @Test
    void longStayStillUsesPublishedMinimumWithoutVacancyOrRoomEstimation() {
        FakeRakuten api = new FakeRakuten();
        Accommodation month = stay("호텔 아소시아 시즈오카", BASE, BASE.plusDays(30), 34.97165, 138.38905, "P_ASSOCIA");
        LodgingCostService.Result r = new LodgingCostService(api).estimate(List.of(month), BASE, false, 1);
        assertEquals(List.of("simple"), api.calls, "사용자 요청에 따라 장기도 숙소 표시 최저가만 조회");
        assertEquals(9800 * 30, r.lodgings.get(0).getTotalYen());
        assertEquals(9800,r.lodgings.get(0).getLowestNightPerRoomYen());
    }

    @Test
    void userEnteredPriceWinsAndIsNeverLookedUp() {
        FakeRakuten api = new FakeRakuten();
        Accommodation own = stay("직접 예약한 료칸", BASE, BASE.plusDays(2), 34.97165, 138.38905, "P_OWN");
        own.setPriceYen(64000);
        LodgingCostService.Result r = new LodgingCostService(api).estimate(List.of(own), BASE, false, 2);
        assertEquals("user", r.lodgings.get(0).getSource());
        assertEquals(64000, r.lodgings.get(0).getTotalYen());
        assertEquals(32000, r.lodgings.get(0).getPerNightYen());
        assertTrue(api.calls.isEmpty());
    }

    @Test
    void undatedTripUsesTheListedMinimum() {
        FakeRakuten api = new FakeRakuten();
        Accommodation hotel = stay("호텔 아소시아 시즈오카", Plan.UNDATED_BASE, Plan.UNDATED_BASE.plusDays(2), 34.97165, 138.38905, "P1");
        LodgingCostService.Result r = new LodgingCostService(api).estimate(List.of(hotel), Plan.UNDATED_BASE, true, 4);
        LodgingCostDto dto = r.lodgings.get(0);
        assertEquals("rakuten-estimate", dto.getSource());
        assertEquals(9800 * 2, dto.getTotalYen(), "인원수로 객실 수를 추정하지 않고 숙박일 수만 곱한다");
        assertNull(dto.getCheckIn(), "날짜 미정이면 날짜를 내보내지 않는다");
        assertEquals(1, dto.getCheckInDay());
        assertEquals(3, dto.getCheckOutDay());
        assertEquals(List.of("simple"), api.calls, "날짜가 없으면 빈방 검색을 하지 않는다");
        assertTrue(r.note.contains("표시 최저가"));
    }

    @Test
    void unknownStaysAreLeftEmptyNotGuessed() {
        FakeRakuten api = new FakeRakuten();
        api.vacant = "{\"hotels\":[]}";                                    // 그 날짜 만실
        Accommodation full = stay("만실 호텔", BASE, BASE.plusDays(1), 34.97165, 138.38905, "P_FULL");
        Accommodation far = stay("멀리 있는 호텔", BASE.plusDays(1), BASE.plusDays(2), 35.10, 138.50, "P_FAR");   // 라쿠텐 숙소가 100m 안에 없음
        Accommodation noCoords = stay("위치 모르는 호텔", BASE.plusDays(2), BASE.plusDays(3), null, null, null);
        LodgingCostService.Result r = new LodgingCostService(api).estimate(List.of(full, far, noCoords), BASE, false, 1);

        assertEquals("rakuten-estimate", r.lodgings.get(0).getSource(), "만실이면 표시 최저가로 어림하고 그렇게 적는다");
        assertEquals(9800, r.lodgings.get(0).getTotalYen());
        assertTrue(r.lodgings.get(0).getBasis().contains("표시 최저가"));
        assertTrue(api.calls.stream().noneMatch(call -> call.startsWith("vacant")));
        assertNull(r.lodgings.get(1).getTotalYen());
        assertNull(r.lodgings.get(1).getSource());
        assertNull(r.lodgings.get(2).getTotalYen());
        assertEquals(9800, r.totalYen);
        assertFalse(r.complete);
        assertTrue(r.note.contains("2곳은 숙박비를 알 수 없어"));

        // 키가 없으면 아무것도 부르지 않는다
        FakeRakuten off = new FakeRakuten();
        off.configured = false;
        LodgingCostService.Result none = new LodgingCostService(off).estimate(List.of(stay("A", BASE, BASE.plusDays(1), 34.97, 138.38, "PA")), BASE, false, 1);
        assertNull(none.totalYen);
        assertTrue(off.calls.isEmpty());
        assertTrue(none.lodgings.get(0).getBasis().contains("설정"));

        // 숙소가 없으면 빈 결과
        LodgingCostService.Result empty = new LodgingCostService(api).estimate(new ArrayList<>(), BASE, false, 1);
        assertTrue(empty.lodgings.isEmpty());
        assertNull(empty.totalYen);
    }

    @Test
    void lookupsPerPlanAreCapped() {
        FakeRakuten api = new FakeRakuten();
        List<Accommodation> stays = new ArrayList<>();
        for (int i = 0; i < LodgingCostService.MAX_LOOKUPS + 2; i++) {
            stays.add(stay("호텔 " + i, BASE.plusDays(i), BASE.plusDays(i + 1), 34.97165, 138.38905, "P" + i));
        }
        LodgingCostService.Result r = new LodgingCostService(api).estimate(stays, BASE, false, 1);
        assertEquals(LodgingCostService.MAX_LOOKUPS, api.calls.size());
        assertNull(r.lodgings.get(r.lodgings.size() - 1).getTotalYen());
    }

    @Test
    void tripCostPerPersonAddsTransitAndLodgingShare() {
        LodgingCostService.Result r = new LodgingCostService(new FakeRakuten())
                .estimate(List.of(stay("A", BASE, BASE.plusDays(3), 34.97165, 138.38905, "PA")), BASE, false, 2);
        AiRouteResponse response = new AiRouteResponse();
        response.setTransitFareYen(3310);
        response.setTransitFareWithPassesYen(2300);
        LodgingCostService.apply(response, r, 2);
        assertEquals(29400, response.getLodgingCostYen());
        assertEquals(2300 + 14700, response.getTripCostPerPersonYen(), "패스를 쓴 교통비 + 숙박비 ÷ 2명");
        assertTrue(response.isLodgingCostComplete());
        assertEquals(2, response.getAdults());
        assertTrue(response.getCostNote().contains("추천 패스"));

        AiRouteResponse noPass = new AiRouteResponse();
        noPass.setTransitFareYen(3310);
        LodgingCostService.apply(noPass, new LodgingCostService.Result(), 1);
        assertEquals(3310, noPass.getTripCostPerPersonYen());
        assertNull(noPass.getLodgingCostYen());

    }

    @Test
    void missingListedMinimumDoesNotTriggerDatedVacancySearch() {
        FakeRakuten api = new FakeRakuten();
        api.near = NEAR.replace("9800", "0");
        var result = new LodgingCostService(api).estimate(
            List.of(stay("A", BASE, BASE.plusDays(1), 34.97165, 138.38905, "PA")), BASE, false, 2);
        assertNull(result.totalYen);
        assertNull(result.lodgings.get(0).getLowestNightPerRoomYen());
        assertEquals(List.of("simple"), api.calls);
    }

    @Test
    void savedHotelDisplayUsesOnlyLiveCacheAndLeavesUnknownEmpty() {
        class CachedApi extends FakeRakuten {
            String cached = NEAR;
            @Override public String cachedSimpleSearch(double latitude,double longitude,double radius) { return cached; }
        }
        CachedApi api=new CachedApi();
        LodgingCostService service=new LodgingCostService(api);
        com.travel.planner.entity.Place place=new com.travel.planner.entity.Place();
        place.setCategory("숙소");place.setLatitude(34.97165);place.setLongitude(138.38905);
        assertEquals(9800,service.cachedMinimum(place));
        api.cached=null;
        assertNull(service.cachedMinimum(place));
        assertTrue(service.cachedDisplayPrice(place).isEmpty(),"Unknown lodging prices must stay empty in saved itineraries");
        assertTrue(api.calls.isEmpty(),"Saved itinerary display must not block on external calls");
    }

    private static Accommodation stay(String name, LocalDate in, LocalDate out, Double lat, Double lng, String placeId) {
        Accommodation a = new Accommodation();
        a.setName(name);
        a.setCheckIn(in);
        a.setCheckOut(out);
        a.setLatitude(lat);
        a.setLongitude(lng);
        a.setPlaceId(placeId);
        return a;
    }

    @Test void undatedWebFallbackCoversMoreThanTwoHotelsAndUsesTodayInsteadOfPlaceholderDate() {
        var api=new FakeRakuten();api.near="{\"hotels\":[]}";
        var web=org.mockito.Mockito.mock(HotelWebPriceService.class);
        org.mockito.Mockito.when(web.cached(org.mockito.ArgumentMatchers.anyString())).thenReturn(List.of());
        org.mockito.Mockito.when(web.search(org.mockito.ArgumentMatchers.anyString(),org.mockito.ArgumentMatchers.anyString(),org.mockito.ArgumentMatchers.isNull()))
            .thenReturn(List.of(java.util.Map.of("yen",9000,"url","https://hotel.example")));
        var service=new LodgingCostService(api);
        org.springframework.test.util.ReflectionTestUtils.setField(service,"webPrices",web);
        var hotels=new ArrayList<Accommodation>();
        for(int i=0;i<4;i++)hotels.add(stay("Hotel "+i,Plan.UNDATED_BASE.plusDays(i),Plan.UNDATED_BASE.plusDays(i+1),35.0,139.0,"hotel"+i));
        var result=service.estimate(hotels,Plan.UNDATED_BASE,true,2);
        assertTrue(result.complete);assertEquals(36000,result.totalYen);
        for(var dto:result.lodgings) {
            assertEquals(LocalDate.now(java.time.ZoneId.of("Asia/Tokyo")).toString(),dto.getPriceAsOfDate());
            assertNull(dto.getCheckIn());assertEquals(9000,dto.getLowestNightPerRoomYen());
        }
        org.mockito.Mockito.verify(web,org.mockito.Mockito.times(4)).search(org.mockito.ArgumentMatchers.anyString(),org.mockito.ArgumentMatchers.anyString(),org.mockito.ArgumentMatchers.isNull());
    }

    @Test void storedVerifiedPriceIsUsedImmediatelyAndLiveQuoteAlwaysWins(@org.junit.jupiter.api.io.TempDir java.nio.file.Path dir) {
        var api=new FakeRakuten();api.near="{\"hotels\":[]}";
        var web=new HotelWebPriceService(dir.resolve("prices.sqlite"),java.time.Clock.systemUTC());
        var service=new LodgingCostService(api);org.springframework.test.util.ReflectionTestUtils.setField(service,"webPrices",web);
        web.recordLivePrice("reserve-hotel",9000,"https://hotel.example","2026-10-25");
        for(int i=0;i<4;i++)web.recordPriceFailure("reserve-hotel");
        var before=service.estimateCached(List.of(stay("Hotel",BASE,BASE.plusDays(2),34.97165,138.38905,"reserve-hotel")),BASE,false,2);
        assertEquals(18000,before.totalYen,"저장 요금은 조회 실패 때 즉시 사용한다");
        assertTrue(web.hotelsNeedingPrices().isEmpty(),"단순 일정 조회는 실패 횟수를 올리지 않는다");
        web.recordPriceFailure("reserve-hotel");
        var fallback=service.estimateCached(List.of(stay("Hotel",BASE,BASE.plusDays(2),34.97165,138.38905,"reserve-hotel")),BASE,false,2);
        assertEquals(18000,fallback.totalYen);assertEquals("stored-minimum",fallback.lodgings.getFirst().getSource());
        api.near=NEAR;
        var fresh=service.estimate(List.of(stay("Hotel",BASE,BASE.plusDays(2),34.97165,138.38905,"reserve-hotel")),BASE,false,2);
        assertEquals(19600,fresh.totalYen);assertEquals("rakuten-estimate",fresh.lodgings.getFirst().getSource());
        assertEquals(9800,web.reservedPrice("reserve-hotel").get("yen"));
    }
}
