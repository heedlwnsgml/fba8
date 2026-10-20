package com.travel.planner.lodging;

import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.test.util.ReflectionTestUtils;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import static org.junit.jupiter.api.Assertions.*;

class RakutenTravelClientTest {
    @TempDir Path dir;

    RakutenTravelClient client(String url, String id, String key) {
        HotelSearchCache cache = new HotelSearchCache(dir.resolve("hotels.sqlite").toString());
        RakutenTravelClient client = new RakutenTravelClient(cache);
        ReflectionTestUtils.setField(client,"applicationId",id);
        ReflectionTestUtils.setField(client,"accessKey",key);
        ReflectionTestUtils.setField(client,"referer","https://github.com/NaDongHwi/TravelPlanner_Backend");
        ReflectionTestUtils.setField(client,"simpleUrl",url);
        return client;
    }

    @Test void actualJavaTransportSendsBothHeadersAndReuses24HourCache() throws Exception {
        AtomicInteger calls = new AtomicInteger();
        AtomicReference<String> referer = new AtomicReference<>(), origin = new AtomicReference<>();
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1",0),0);
        String json="{\"hotels\":[[{\"hotelBasicInfo\":{\"hotelNo\":7801,\"hotelMinCharge\":13100}}]]}";
        server.createContext("/hotel",exchange->{
            calls.incrementAndGet();
            referer.set(exchange.getRequestHeaders().getFirst("Referer"));
            origin.set(exchange.getRequestHeaders().getFirst("Origin"));
            byte[] body=json.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type","application/json");
            exchange.sendResponseHeaders(200,body.length);
            try(var stream=exchange.getResponseBody()) { stream.write(body); }
            exchange.close();
        });
        server.start();
        try {
            RakutenTravelClient client=client("http://127.0.0.1:"+server.getAddress().getPort()+"/hotel","test-id","test-key");
            assertEquals(json,client.simpleSearch(34.6687,135.5013,0.5));
            assertEquals(json,client.simpleSearch(34.6687,135.5013,0.5));
            assertEquals("https://github.com/NaDongHwi/TravelPlanner_Backend/",referer.get());
            assertEquals("https://github.com",origin.get());
            assertEquals(1,calls.get(),"Second lookup must use the persistent cache");
        } finally {server.stop(0);}
    }

    @Test void originAndRefererFollowUpstreamNormalization() {
        assertEquals("https://github.com",RakutenTravelClient.originOf(" https://github.com/NaDongHwi/TravelPlanner_Backend "));
        assertEquals("http://localhost:5173",RakutenTravelClient.originOf("http://localhost:5173/path?q=test#x"));
        assertEquals("https://github.com/project/",RakutenTravelClient.refererValue("https://github.com/project"));
        assertEquals("https://github.com/project/",RakutenTravelClient.refererValue("https://github.com/project/"));
    }

    @Test void parsesGatewayErrorInsteadOfSilentlyDroppingTheReason() {
        assertEquals("REQUEST_CONTEXT_BODY_HTTP_REFERRER_MISSING",RakutenHotels.error(
            "{\"errors\":{\"errorCode\":403,\"errorMessage\":\"REQUEST_CONTEXT_BODY_HTTP_REFERRER_MISSING\"}}"));
        assertEquals("wrong_parameter: bad request",RakutenHotels.error(
            "{\"error\":\"wrong_parameter\",\"error_description\":\"bad request\"}"));
    }

    @Test
    @EnabledIfEnvironmentVariable(named="RAKUTEN_LIVE_CHECK", matches="true")
    void realRakutenReturnsNightlyMinimumWithUpstreamJavaHttpClient() {
        RakutenTravelClient client=client(
            "https://openapi.rakuten.co.jp/engine/api/Travel/SimpleHotelSearch/20170426",
            System.getenv("RAKUTEN_TEST_APPLICATION_ID"),System.getenv("RAKUTEN_TEST_ACCESS_KEY"));
        ReflectionTestUtils.setField(client,"referer",System.getenv("RAKUTEN_TEST_REFERER"));
        String response=client.simpleSearch(34.6687,135.5013,0.5);
        assertNotNull(response,"Live provider request must succeed");
        var hotels=RakutenHotels.parse(response);
        assertFalse(hotels.isEmpty(),"Live response must contain hotels");
        var lowest=hotels.stream().filter(h->h.minCharge!=null && h.minCharge>0).findFirst().orElseThrow();
        assertEquals(response,client.simpleSearch(34.6687,135.5013,0.5));
        System.out.println("LIVE_RAKUTEN_OK hotelNo="+lowest.hotelNo+" minNightlyYen="+lowest.minCharge+" hotelCount="+hotels.size());
    }
}
