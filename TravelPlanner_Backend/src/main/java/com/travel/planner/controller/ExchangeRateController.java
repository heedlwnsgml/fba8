package com.travel.planner.controller;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.bind.annotation.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

@RestController
public class ExchangeRateController {
    private final JdbcTemplate jdbc;
    private final String editor;
    public ExchangeRateController(JdbcTemplate jdbc,@Value("${app.exchange-rate-editor-email:}") String editor) {this.jdbc=jdbc;this.editor=editor;}
    public record Rate(@NotNull @DecimalMin("0.0001") @DecimalMax("10000") BigDecimal krwPerJpy,
        @NotNull @PastOrPresent LocalDate rateDate,@NotBlank @Size(max=500) String sourceUrl) {}
    public boolean canEdit(Authentication user) {
        return !editor.isBlank() && user.getName().equalsIgnoreCase(editor) && user.getAuthorities().stream().anyMatch(a->a.getAuthority().equals("ROLE_ADMIN"));
    }
    @GetMapping("/api/v1/exchange-rates/jpy-krw")
    public Map<String,Object> current() {
        var rows=jdbc.queryForList("SELECT krw_per_jpy AS krwPerJpy,DATE_FORMAT(rate_date,'%Y-%m-%d') AS rateDate,source_url AS sourceUrl FROM test_planner_app_metadata.exchange_rate WHERE rate_date<=CURRENT_DATE ORDER BY rate_date DESC,updated_at DESC LIMIT 1");
        if(rows.isEmpty())throw new ResponseStatusException(HttpStatus.NOT_FOUND,"등록된 환율이 없습니다.");
        return rows.getFirst();
    }
    @PostMapping("/api/v1/admin/exchange-rates/jpy-krw")
    public Map<String,Object> save(Authentication user,@Valid @RequestBody Rate rate) {
        if(!canEdit(user))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"환율 수정 권한이 없습니다.");
        var uri=java.net.URI.create(rate.sourceUrl());
        if(!List.of("https","http").contains(uri.getScheme()) || uri.getHost()==null || uri.getUserInfo()!=null)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"환율 출처 주소를 확인하세요.");
        jdbc.update("INSERT INTO test_planner_app_metadata.exchange_rate (rate_date,krw_per_jpy,source_url,updated_by) VALUES (?,?,?,?) ON DUPLICATE KEY UPDATE krw_per_jpy=VALUES(krw_per_jpy),source_url=VALUES(source_url),updated_by=VALUES(updated_by),updated_at=CURRENT_TIMESTAMP",rate.rateDate(),rate.krwPerJpy(),rate.sourceUrl(),user.getName());
        return current();
    }
}
