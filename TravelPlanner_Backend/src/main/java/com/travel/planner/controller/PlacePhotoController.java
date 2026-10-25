package com.travel.planner.controller;

import com.travel.planner.service.PlacePhotoService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 일정 카드의 장소 대표 사진.
 * GET /api/v1/places/{placeId}/photo?size=small|large
 *  → {"available":true,"photoUri":"https://...","author":"올린 사람","authorUri":"https://..."}
 *  → 사진이 없으면 {"available":false}
 * 로그인한 사용자만 부를 수 있다 (SecurityConfig 의 anyRequest().authenticated()).
 */
@RestController
@RequestMapping("/api/v1/places")
public class PlacePhotoController {

    private final PlacePhotoService photos;

    public PlacePhotoController(PlacePhotoService photos) {
        this.photos = photos;
    }

    @GetMapping("/{placeId}/photo")
    public Map<String, Object> photo(@PathVariable String placeId,
                                     @RequestParam(defaultValue = "small") String size) {
        Map<String, Object> body = new LinkedHashMap<>();
        var photo = photos.photo(placeId, "large".equals(size));
        body.put("available", photo.isPresent());
        photo.ifPresent(p -> {
            body.put("photoUri", p.photoUri());
            body.put("author", p.author());
            body.put("authorUri", p.authorUri());
        });
        return body;
    }
}
