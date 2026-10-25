package com.travel.planner.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.client.RestTemplate;

import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.LongSupplier;
import java.util.regex.Pattern;

/**
 * 일정 카드에 띄울 장소 대표 사진 (구글 지도 장소 사진의 첫 번째 장).
 *
 * 1) Place Details(필드: photos) 로 첫 사진의 이름과 올린 사람을 알아낸다.
 * 2) Place Photo(media, skipHttpRedirect=true) 로 사진 주소(photoUri)를 받는다.
 *    photoUri 는 구글이 주는 짧게 유효한 이미지 주소이고 API 키가 들어 있지 않으므로 앱에 그대로 넘겨도 된다.
 *
 * - 사진은 사용자가 일정 카드를 볼 때만 부른다 (일정 생성 때 미리 받지 않는다: 비용).
 * - 구글 약관상 사진 정보는 DB 에 오래 저장하지 않는다. 같은 장소를 다시 열 때 비용이 두 번 들지 않도록
 *   서버 메모리에만 잠깐(1시간) 둔다. DB 구조는 바꾸지 않는다.
 * - 구글 약관상 사진을 보여 줄 때 올린 사람(authorAttributions)을 함께 표시해야 하므로 같이 돌려준다.
 */
@Service
public class PlacePhotoService {

    /** 작은 사진(카드 왼쪽 네모)과 큰 사진(눌렀을 때) 너비. 작은 사진은 고해상도 화면(3배)에서 68px 정도 */
    static final int SMALL_WIDTH_PX = 240;
    static final int LARGE_WIDTH_PX = 1200;
    static final long CACHE_MILLIS = 60L * 60 * 1000;
    static final int CACHE_MAX = 3000;

    /** 구글 Place ID 모양만 받는다 (URL 경로에 들어가므로 다른 글자는 거절) */
    private static final Pattern PLACE_ID = Pattern.compile("[A-Za-z0-9_-]{10,300}");
    private static final Pattern PHOTO_NAME = Pattern.compile("places/([A-Za-z0-9_-]+)/photos/([A-Za-z0-9_-]+)");

    /** 사진 이름(places/장소/photos/사진)을 둘로 나눠 넣는다. 통째로 넣으면 '/' 가 %2F 로 바뀌어 구글이 못 찾는다 */
    static final String MEDIA_URL =
            "https://places.googleapis.com/v1/places/{place}/photos/{photo}/media?maxWidthPx={width}&skipHttpRedirect=true";

    @Value("${google.maps.api-key:}")
    private String key;

    private final RestTemplate http;
    private final ObjectMapper json = new ObjectMapper();
    private final LongSupplier clock;

    /** placeId → 첫 사진 정보 (사진이 없는 장소도 "없음"으로 잠깐 기억해 같은 요청을 반복하지 않는다) */
    private final Map<String, Timed<Optional<PhotoRef>>> refs = new ConcurrentHashMap<>();
    /** placeId|너비 → 사진 주소 */
    private final Map<String, Timed<Optional<Photo>>> photos = new ConcurrentHashMap<>();

    @org.springframework.beans.factory.annotation.Autowired
    public PlacePhotoService(RestTemplate http) {
        this(http, System::currentTimeMillis);
    }

    PlacePhotoService(RestTemplate http, LongSupplier clock) {
        this.http = http;
        this.clock = clock;
    }

    /** 앱에 넘기는 사진 정보. photoUri 에는 API 키가 없다 */
    public record Photo(String photoUri, String author, String authorUri) {}

    record PhotoRef(String name, String author, String authorUri) {}

    private record Timed<T>(T value, long at) {}

    public static boolean isGooglePlaceId(String placeId) {
        return placeId != null && PLACE_ID.matcher(placeId).matches()
                && !placeId.startsWith("DUMMY_") && !placeId.startsWith("AIRPORT_");
    }

    /** 대표 사진. 사진이 없거나 조회에 실패하면 빈 값 */
    public Optional<Photo> photo(String placeId, boolean large) {
        if (key == null || key.isBlank() || !isGooglePlaceId(placeId)) return Optional.empty();
        int width = large ? LARGE_WIDTH_PX : SMALL_WIDTH_PX;
        String cacheKey = placeId + "|" + width;
        Optional<Photo> cached = fresh(photos, cacheKey);
        if (cached != null) return cached;

        Optional<PhotoRef> ref = fresh(refs, placeId);
        if (ref == null) {
            ref = firstPhoto(placeId);
            if (ref == null) return Optional.empty();          // 통신 실패: 기억하지 않고 다음에 다시 시도
            put(refs, placeId, ref);
        }
        if (ref.isEmpty()) return Optional.empty();

        String uri = photoUri(ref.get().name(), width);
        if (uri == null) return Optional.empty();
        Optional<Photo> result = Optional.of(new Photo(uri, ref.get().author(), ref.get().authorUri()));
        put(photos, cacheKey, result);
        return result;
    }

    /** @return 사진 정보, 사진이 없는 장소면 Optional.empty(), 통신 실패면 null */
    private Optional<PhotoRef> firstPhoto(String placeId) {
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.set("X-Goog-Api-Key", key);
            headers.set("X-Goog-FieldMask", "photos");
            ResponseEntity<String> response = http.exchange(
                    "https://places.googleapis.com/v1/places/{placeId}",
                    HttpMethod.GET, new HttpEntity<Void>(headers), String.class, placeId);
            JsonNode first = json.readTree(response.getBody()).path("photos").path(0);
            String name = first.path("name").asText("");
            if (!PHOTO_NAME.matcher(name).matches()) return Optional.empty();
            JsonNode author = first.path("authorAttributions").path(0);
            String authorUri = author.path("uri").asText("");
            return Optional.of(new PhotoRef(name, author.path("displayName").asText(""),
                    authorUri.startsWith("https://") ? authorUri : ""));
        } catch (RestClientResponseException e) {
            if (e.getStatusCode().value() == 404) return Optional.empty();   // 구글에 없는 장소
            System.out.println("[장소 사진] Google HTTP " + e.getStatusCode().value());
            return null;
        } catch (Exception e) {
            System.out.println("[장소 사진] 조회 실패: " + e.getClass().getSimpleName());
            return null;
        }
    }

    private String photoUri(String photoName, int width) {
        var parts = PHOTO_NAME.matcher(photoName);
        if (!parts.matches()) return null;
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.set("X-Goog-Api-Key", key);
            ResponseEntity<String> response = http.exchange(
                    MEDIA_URL, HttpMethod.GET, new HttpEntity<Void>(headers), String.class,
                    parts.group(1), parts.group(2), width);
            String uri = json.readTree(response.getBody()).path("photoUri").asText("");
            return uri.startsWith("https://") ? uri : null;
        } catch (RestClientResponseException e) {
            System.out.println("[장소 사진] Google HTTP " + e.getStatusCode().value());
            return null;
        } catch (Exception e) {
            System.out.println("[장소 사진] 주소 조회 실패: " + e.getClass().getSimpleName());
            return null;
        }
    }

    private <T> T fresh(Map<String, Timed<T>> cache, String cacheKey) {
        Timed<T> hit = cache.get(cacheKey);
        if (hit == null) return null;
        if (clock.getAsLong() - hit.at() > CACHE_MILLIS) {
            cache.remove(cacheKey);
            return null;
        }
        return hit.value();
    }

    private <T> void put(Map<String, Timed<T>> cache, String cacheKey, T value) {
        if (cache.size() >= CACHE_MAX) cache.clear();   // 단순하게: 가득 차면 비운다 (오래 둘 필요가 없는 값)
        cache.put(cacheKey, new Timed<>(value, clock.getAsLong()));
    }
}
