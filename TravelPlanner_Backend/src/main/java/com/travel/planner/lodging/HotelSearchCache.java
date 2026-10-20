package com.travel.planner.lodging;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.*;
import java.time.Clock;
import java.time.Duration;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.Map;
import java.util.TreeMap;

/** Public provider responses only. Uses its own SQLite file, never the application datasource. */
@Component
public class HotelSearchCache {
    private static final long TTL = Duration.ofHours(24).toMillis();
    private final String url;
    private final Clock clock;

    @org.springframework.beans.factory.annotation.Autowired
    public HotelSearchCache(@Value("${app.hotel-search-cache.path:data/hotel-search-cache.sqlite}") String file) {
        this(Path.of(file), Clock.systemUTC());
    }

    HotelSearchCache(Path file, Clock clock) {
        this.clock = clock;
        try {
            Path absolute = file.toAbsolutePath().normalize();
            Files.createDirectories(absolute.getParent());
            url = "jdbc:sqlite:" + absolute;
            try (Connection c = open(); Statement s = c.createStatement()) {
                s.execute("CREATE TABLE IF NOT EXISTS hotel_search_cache (cache_key TEXT PRIMARY KEY, response_json TEXT NOT NULL, fetched_at INTEGER NOT NULL, expires_at INTEGER NOT NULL)");
                s.execute("CREATE INDEX IF NOT EXISTS hotel_search_expiry ON hotel_search_cache(expires_at)");
            }
            purgeExpired();
        } catch (Exception e) { throw new IllegalStateException("Hotel cache initialization failed", e); }
    }

    private Connection open() throws SQLException {
        Connection c = DriverManager.getConnection(url);
        try (Statement s = c.createStatement()) { s.execute("PRAGMA busy_timeout=5000"); }
        return c;
    }

    static String key(String endpoint, Map<String, Object> query) {
        TreeMap<String, Object> publicQuery = new TreeMap<>(query);
        publicQuery.keySet().removeAll(java.util.Set.of("applicationId", "accessKey", "affiliateId"));
        StringBuilder canonical = new StringBuilder(endpoint);
        publicQuery.forEach((k,v) -> canonical.append('|').append(k.length()).append(':').append(k)
                .append('=').append(String.valueOf(v).length()).append(':').append(v));
        try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(canonical.toString().getBytes(StandardCharsets.UTF_8))); }
        catch (Exception e) { throw new IllegalStateException(e); }
    }

    public String get(String endpoint, Map<String, Object> query) {
        try (Connection c = open(); PreparedStatement s = c.prepareStatement("SELECT response_json FROM hotel_search_cache WHERE cache_key=? AND expires_at>?")) {
            s.setString(1, key(endpoint, query)); s.setLong(2, clock.millis());
            try (ResultSet r = s.executeQuery()) { return r.next() ? r.getString(1) : null; }
        } catch (SQLException e) { return null; } // A cache failure must not prevent a fresh lookup.
    }

    public void put(String endpoint, Map<String, Object> query, String response) {
        // Do not retain failed, malformed or empty searches for a whole day.
        if (RakutenHotels.parse(response).isEmpty()) return;
        long now = clock.millis();
        try (Connection c = open(); PreparedStatement s = c.prepareStatement("INSERT INTO hotel_search_cache(cache_key,response_json,fetched_at,expires_at) VALUES(?,?,?,?) ON CONFLICT(cache_key) DO UPDATE SET response_json=excluded.response_json,fetched_at=excluded.fetched_at,expires_at=excluded.expires_at")) {
            s.setString(1,key(endpoint,query)); s.setString(2,response); s.setLong(3,now); s.setLong(4,now+TTL); s.executeUpdate();
        } catch (SQLException e) { /* The provider response can still be used without caching. */ }
    }

    @Scheduled(fixedDelay = 3600000)
    public void purgeExpired() {
        try (Connection c = open(); PreparedStatement s = c.prepareStatement("DELETE FROM hotel_search_cache WHERE expires_at<=?")) {
            s.setLong(1,clock.millis()); s.executeUpdate();
        } catch (SQLException e) { /* Reads always enforce expiry, even when physical cleanup fails. */ }
    }
}
