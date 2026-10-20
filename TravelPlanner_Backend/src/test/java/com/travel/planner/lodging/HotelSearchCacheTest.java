package com.travel.planner.lodging;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import java.nio.file.Path;
import java.sql.*;
import java.time.*;
import java.util.Map;
import static org.junit.jupiter.api.Assertions.*;

class HotelSearchCacheTest {
    @TempDir Path dir;
    static final String HOTEL = "{\"hotels\":[[{\"hotelBasicInfo\":{\"hotelNo\":123,\"hotelName\":\"Hotel\",\"hotelMinCharge\":9000}}]]}";
    static class Time extends Clock {
        Instant instant = Instant.parse("2026-10-18T00:00:00Z");
        public ZoneId getZone() { return ZoneOffset.UTC; }
        public Clock withZone(ZoneId zone) { return this; }
        public Instant instant() { return instant; }
        void advance(Duration duration) { instant = instant.plus(duration); }
    }

    @Test void survivesRestartAndExpiresExactly24HoursWithoutSlidingExpiry() {
        Time time = new Time(); Path file = dir.resolve("hotel.sqlite");
        HotelSearchCache cache = new HotelSearchCache(file,time);
        Map<String,Object> query = Map.of("hotelNo",123,"checkinDate","2026-10-20","adultNum",2,"roomNum",1);
        cache.put("vacant",query,HOTEL);
        time.advance(Duration.ofHours(23));
        assertEquals(HOTEL,new HotelSearchCache(file,time).get("vacant",query));
        time.advance(Duration.ofHours(1));
        assertNull(cache.get("vacant",query));
        cache.purgeExpired();
        assertEquals(0,count(file));
    }

    @Test void separatesStayDateAdultsRoomsLocationAndEndpoint() {
        HotelSearchCache cache = new HotelSearchCache(dir.resolve("separate.sqlite"),new Time());
        Map<String,Object> query = Map.of("hotelNo",123,"checkinDate","2026-10-20","checkoutDate","2026-10-21","adultNum",2,"roomNum",1,"latitude",35.1);
        cache.put("vacant",query,HOTEL);
        for (String field : query.keySet()) {
            var changed = new java.util.HashMap<>(query); changed.put(field,"different");
            assertNull(cache.get("vacant",changed),field);
        }
        assertNull(cache.get("simple",query));
        var credential = new java.util.HashMap<>(query); credential.put("accessKey","not-stored");
        assertEquals(HOTEL,cache.get("vacant",credential));
    }

    @Test void errorsAndEmptyResultsAreRetriedInsteadOfCached() {
        Path file=dir.resolve("errors.sqlite"); HotelSearchCache cache=new HotelSearchCache(file,new Time());
        for(String value : new String[]{"not JSON","{\"error\":\"forbidden\"}","{\"hotels\":[]}"}) {
            cache.put("search",Map.of(),value); assertNull(cache.get("search",Map.of()));
        }
        assertEquals(0,count(file));
    }

    static int count(Path file) {
        try(Connection c=DriverManager.getConnection("jdbc:sqlite:"+file); Statement s=c.createStatement(); ResultSet r=s.executeQuery("SELECT COUNT(*) FROM hotel_search_cache")) { r.next(); return r.getInt(1); }
        catch(Exception e) { throw new AssertionError(e); }
    }
}
