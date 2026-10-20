package com.travel.planner.controller;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/weather/settings")
public class AccountSettingsController {
    private final JdbcTemplate jdbc;
    public record Settings(@NotNull Boolean enabled,
        @NotNull @Pattern(regexp="morning|afternoon|both") String frequency,
        @NotNull @Pattern(regexp="(?:[01][0-9]|2[0-3]):[0-5][0-9]") String morningTime,
        @NotNull @Pattern(regexp="(?:[01][0-9]|2[0-3]):[0-5][0-9]") String afternoonTime) {}
    @GetMapping
    public Map<String,Object> get(Authentication user) {
        var rows=jdbc.queryForList("SELECT enabled,frequency,morning_time,afternoon_time FROM test_planner_app_metadata.weather_settings WHERE planner_database=DATABASE() AND email=?",user.getName());
        if(rows.isEmpty())return Map.of("enabled",true,"frequency","both","morningTime","08:00","afternoonTime","18:00");
        var row=rows.getFirst();
        return Map.of("enabled",((Number)row.get("enabled")).intValue()!=0,"frequency",row.get("frequency"),"morningTime",row.get("morning_time"),"afternoonTime",row.get("afternoon_time"));
    }
    @PutMapping
    public Map<String,Object> save(Authentication user,@Valid @RequestBody Settings value) {
        jdbc.update("INSERT INTO test_planner_app_metadata.weather_settings (planner_database,email,enabled,frequency,morning_time,afternoon_time) VALUES (DATABASE(),?,?,?,?,?) ON DUPLICATE KEY UPDATE enabled=VALUES(enabled),frequency=VALUES(frequency),morning_time=VALUES(morning_time),afternoon_time=VALUES(afternoon_time)",user.getName(),value.enabled()?1:0,value.frequency(),value.morningTime(),value.afternoonTime());
        return get(user);
    }
}
