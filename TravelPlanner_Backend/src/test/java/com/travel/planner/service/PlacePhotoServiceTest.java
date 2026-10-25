package com.travel.planner.service;

import com.travel.planner.controller.PlacePhotoController;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class PlacePhotoServiceTest {

    static final String PLACE = "ChIJ_test_place_0001";
    static final String NAME = "places/ChIJ_test_place_0001/photos/AXCi2Q_photo";

    /** 구글 대신 정해 둔 답을 돌려주고, 받은 요청을 기록한다 */
    static class FakeGoogle extends RestTemplate {
        final List<String> calls = new ArrayList<>();
        final List<String> keys = new ArrayList<>();
        String details = "{\"photos\":[{\"name\":\"" + NAME + "\",\"authorAttributions\":[{\"displayName\":\"Hana\",\"uri\":\"https://maps.google.com/maps/contrib/1\"}]}]}";
        RuntimeException detailsError;

        @Override
        public <T> ResponseEntity<T> exchange(String url, HttpMethod method, HttpEntity<?> entity, Class<T> type, Object... vars) {
            keys.add(entity.getHeaders().getFirst("X-Goog-Api-Key"));
            if (url.endsWith("/v1/places/{placeId}")) {
                calls.add("details:" + vars[0] + ":" + entity.getHeaders().getFirst("X-Goog-FieldMask"));
                if (detailsError != null) throw detailsError;
                return cast(details);
            }
            assertEquals(PlacePhotoService.MEDIA_URL, url);
            calls.add("media:places/" + vars[0] + "/photos/" + vars[1] + ":" + vars[2]);
            return cast("{\"photoUri\":\"https://lh3.googleusercontent.com/p/w" + vars[2] + "\"}");
        }

        @SuppressWarnings("unchecked")
        private static <T> ResponseEntity<T> cast(String body) {
            return (ResponseEntity<T>) ResponseEntity.ok(body);
        }
    }

    long now = 1_000_000L;

    PlacePhotoService service(FakeGoogle google) {
        PlacePhotoService s = new PlacePhotoService(google, () -> now);
        ReflectionTestUtils.setField(s, "key", "test-secret");
        return s;
    }

    @Test
    void smallPhotoComesWithAuthorAndNoApiKeyInTheResult() {
        FakeGoogle google = new FakeGoogle();
        var photo = service(google).photo(PLACE, false).orElseThrow();
        assertEquals("https://lh3.googleusercontent.com/p/w240", photo.photoUri());
        assertEquals("Hana", photo.author());
        assertEquals("https://maps.google.com/maps/contrib/1", photo.authorUri());
        assertFalse(photo.toString().contains("test-secret"));
        assertEquals(List.of("details:" + PLACE + ":photos", "media:" + NAME + ":240"), google.calls);
        assertTrue(google.keys.stream().allMatch("test-secret"::equals), "키는 헤더로만 보낸다");
    }

    @Test
    void largePhotoReusesThePhotoNameAndRepeatsAreCached() {
        FakeGoogle google = new FakeGoogle();
        PlacePhotoService s = service(google);
        s.photo(PLACE, false);
        s.photo(PLACE, false);
        assertEquals("https://lh3.googleusercontent.com/p/w1200", s.photo(PLACE, true).orElseThrow().photoUri());
        s.photo(PLACE, true);
        assertEquals(List.of("details:" + PLACE + ":photos", "media:" + NAME + ":240", "media:" + NAME + ":1200"), google.calls);
    }

    @Test
    void cacheExpiresAfterAnHour() {
        FakeGoogle google = new FakeGoogle();
        PlacePhotoService s = service(google);
        s.photo(PLACE, false);
        now += PlacePhotoService.CACHE_MILLIS + 1;
        s.photo(PLACE, false);
        assertEquals(4, google.calls.size());
    }

    @Test
    void placeWithoutPhotosIsRememberedAsEmpty() {
        FakeGoogle google = new FakeGoogle();
        google.details = "{}";
        PlacePhotoService s = service(google);
        assertTrue(s.photo(PLACE, false).isEmpty());
        assertTrue(s.photo(PLACE, true).isEmpty());
        assertEquals(1, google.calls.size());
    }

    @Test
    void networkFailureIsNotRememberedSoTheNextOpenRetries() {
        FakeGoogle google = new FakeGoogle();
        google.detailsError = new HttpClientErrorException(HttpStatus.TOO_MANY_REQUESTS);
        PlacePhotoService s = service(google);
        assertTrue(s.photo(PLACE, false).isEmpty());
        google.detailsError = null;
        assertTrue(s.photo(PLACE, false).isPresent());
    }

    @Test
    void notFoundPlaceHasNoPhoto() {
        FakeGoogle google = new FakeGoogle();
        google.detailsError = new HttpClientErrorException(HttpStatus.NOT_FOUND);
        PlacePhotoService s = service(google);
        assertTrue(s.photo(PLACE, false).isEmpty());
        s.photo(PLACE, false);
        assertEquals(1, google.calls.size());
    }

    @Test
    void oddIdsAndMissingKeyNeverReachGoogle() {
        FakeGoogle google = new FakeGoogle();
        PlacePhotoService s = service(google);
        for (String id : new String[]{null, "", "short", "AIRPORT_HND_000001", "DUMMY_abcdefghij", "airport-access:NRT", "../../etc/passwd_x", "ChIJ abc def ghi"})
            assertTrue(s.photo(id, false).isEmpty(), String.valueOf(id));
        ReflectionTestUtils.setField(s, "key", "");
        assertTrue(s.photo(PLACE, false).isEmpty());
        assertTrue(google.calls.isEmpty());
    }

    @Test
    void unexpectedPhotoNameOrNonHttpsUriIsIgnored() {
        FakeGoogle google = new FakeGoogle();
        google.details = "{\"photos\":[{\"name\":\"https://evil.example/x\"}]}";
        assertTrue(service(google).photo(PLACE, false).isEmpty());
        FakeGoogle google2 = new FakeGoogle();
        google2.details = "{\"photos\":[{\"name\":\"" + NAME + "\",\"authorAttributions\":[{\"displayName\":\"A\",\"uri\":\"javascript:alert(1)\"}]}]}";
        assertEquals("", service(google2).photo(PLACE, false).orElseThrow().authorUri());
    }

    @Test
    void photoNameKeepsItsSlashesWhenExpandedIntoTheMediaUrl() {
        var uri = new RestTemplate().getUriTemplateHandler().expand(
                PlacePhotoService.MEDIA_URL, "ChIJ_test_place_0001", "AXCi2Q_photo", 240);
        assertEquals("https://places.googleapis.com/v1/" + NAME + "/media?maxWidthPx=240&skipHttpRedirect=true", uri.toString());
    }

    @Test
    void controllerAnswersAvailableFlag() {
        FakeGoogle google = new FakeGoogle();
        PlacePhotoController controller = new PlacePhotoController(service(google));
        Map<String, Object> ok = controller.photo(PLACE, "large");
        assertEquals(true, ok.get("available"));
        assertEquals("https://lh3.googleusercontent.com/p/w1200", ok.get("photoUri"));
        assertEquals(Map.of("available", false), controller.photo("AIRPORT_HND_000001", "small"));
    }
}
