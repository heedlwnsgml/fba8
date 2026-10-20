package com.travel.planner.service;
import com.travel.planner.entity.Plan;
import jakarta.persistence.*;
import org.springframework.stereotype.Component;
import org.springframework.jdbc.core.JdbcTemplate;
@Component
public class PlanPeriodListener {
    private final JdbcTemplate jdbc;
    public PlanPeriodListener(JdbcTemplate jdbc) { this.jdbc = jdbc; }
    @PostLoad public void load(Plan plan) {
        var days = jdbc.queryForList("SELECT trip_days FROM test_planner_app_metadata.plan_period WHERE planner_database=DATABASE() AND plan_id=?", Integer.class, plan.getId());
        plan.setTripDays(days.isEmpty() ? null : days.getFirst());
    }
    @PostPersist @PostUpdate public void save(Plan plan) {
        if (plan.getTripDays() == null) { remove(plan); return; }
        jdbc.update("INSERT INTO test_planner_app_metadata.plan_period (planner_database,plan_id,trip_days) VALUES (DATABASE(),?,?) ON DUPLICATE KEY UPDATE trip_days=VALUES(trip_days)", plan.getId(), plan.getTripDays());
    }
    @PreRemove public void remove(Plan plan) {
        jdbc.update("DELETE FROM test_planner_app_metadata.plan_period WHERE planner_database=DATABASE() AND plan_id=?", plan.getId());
    }
}
