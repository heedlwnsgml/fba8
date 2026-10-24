package com.travel.planner.controller;
import com.travel.planner.service.HotelWebPriceService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import java.util.*;
/** Protected by the administrator URL role rule in SecurityConfig. */
@RestController
@RequestMapping("/api/v1/admin/hotel-prices")
@RequiredArgsConstructor
public class AdminHotelPricesController {
    private final HotelWebPriceService hotelPrices;
    @GetMapping("/missing")
    public Map<String,List<String>> missing() { return Map.of("hotels",hotelPrices.hotelsNeedingPrices()); }
}
