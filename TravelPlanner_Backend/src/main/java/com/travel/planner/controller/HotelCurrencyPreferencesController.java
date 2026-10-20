package com.travel.planner.controller;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/account/preferences")
public class HotelCurrencyPreferencesController {
    private final JdbcTemplate jdbc;
    public record Preferences(@NotNull @Pattern(regexp="KRW|JPY") String hotelBudgetCurrency) {}
    @GetMapping
    public Map<String,String> get(Authentication user) {
        var rows=jdbc.queryForList("SELECT hotel_budget_currency FROM test_planner_app_metadata.user_preferences WHERE planner_database=DATABASE() AND email=?",String.class,user.getName());
        return Map.of("hotelBudgetCurrency",rows.isEmpty()?"KRW":rows.getFirst());
    }
    @PutMapping
    public Map<String,String> save(Authentication user,@Valid @RequestBody Preferences value) {
        jdbc.update("INSERT INTO test_planner_app_metadata.user_preferences (planner_database,email,hotel_budget_currency) VALUES (DATABASE(),?,?) ON DUPLICATE KEY UPDATE hotel_budget_currency=VALUES(hotel_budget_currency)",user.getName(),value.hotelBudgetCurrency());
        return get(user);
    }
}
