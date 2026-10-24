package com.travel.planner.controller;

import java.util.Map;
import javax.sql.DataSource;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** Minimal unauthenticated probes; no environment or database details are exposed. */
@RestController
public class DeploymentHealthController {
    private final DataSource dataSource;
    public DeploymentHealthController(DataSource dataSource) { this.dataSource = dataSource; }
    @GetMapping("/api/v1/auth/health/live")
    public Map<String, String> live() { return Map.of("status", "UP"); }
    @GetMapping("/api/v1/auth/health/ready")
    public ResponseEntity<Map<String, String>> ready() {
        try (var connection = dataSource.getConnection(); var statement = connection.createStatement()) {
            statement.setQueryTimeout(2);
            try (var result = statement.executeQuery("SELECT 1")) {
                if (result.next() && result.getInt(1) == 1) return ResponseEntity.ok(Map.of("status", "UP"));
            }
        } catch (Exception ignored) { /* Only generic status is public. */ }
        return ResponseEntity.status(503).body(Map.of("status", "DOWN"));
    }
}
