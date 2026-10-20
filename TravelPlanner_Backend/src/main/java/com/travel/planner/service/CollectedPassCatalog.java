package com.travel.planner.service;
import com.travel.planner.entity.TransportPass;
import com.travel.planner.transit.PassAdvisor;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import java.util.*;
@Service
public class CollectedPassCatalog {
    private final JdbcTemplate jdbc;
    private final String database;
    public CollectedPassCatalog(JdbcTemplate jdbc, @Value("${transit.passes.catalog-database:}") String database) {
        if (!database.isEmpty() && !database.matches("[a-zA-Z0-9_]+")) throw new IllegalArgumentException("Invalid pass catalog database");
        this.jdbc=jdbc;this.database=database;
    }
    public boolean configured() { return !database.isEmpty(); }
    public record Snapshot(List<PassAdvisor.Pass> passes, Map<String,TransportPass> rows) {}
    public Snapshot snapshot() {
        List<PassAdvisor.Pass> passes=new ArrayList<>();Map<String,TransportPass> rows=new LinkedHashMap<>();
        if (!configured()) return new Snapshot(passes,rows);
        jdbc.query("SELECT * FROM `"+database+"`.transport_pass WHERE enabled=1 ORDER BY id", (org.springframework.jdbc.core.RowCallbackHandler)rs -> {
            TransportPass row=new TransportPass();
            row.setId(rs.getLong("id"));row.setPassKey(rs.getString("pass_key"));row.setName(rs.getString("name"));row.setCity(rs.getString("city"));
            row.setPriceEnyen(rs.getInt("price_enyen"));row.setChildPriceYen(rs.getObject("child_price_yen",Integer.class));
            row.setValidityDays(rs.getInt("validity_days"));row.setValidityHours(rs.getObject("validity_hours",Integer.class));
            row.setConsecutive(rs.getBoolean("consecutive"));row.setDayRule(rs.getString("day_rule"));row.setExtraDaysOfMonth(rs.getString("extra_days_of_month"));row.setYearEndAsHoliday(rs.getBoolean("year_end_as_holiday"));
            row.setCoverage(rs.getString("coverage"));row.setConditions(rs.getString("conditions"));row.setNote(rs.getString("note"));
            row.setApproximate(rs.getBoolean("approximate"));row.setUrl(rs.getString("url"));
            java.sql.Date checked=rs.getDate("verified_at");row.setVerifiedAt(checked==null?null:checked.toLocalDate());
            PassAdvisor.Pass pass=FareDataService.toPass(row);
            java.sql.Date start=rs.getDate("valid_from"),end=rs.getDate("valid_until");
            pass.validFrom=start==null?null:start.toLocalDate();pass.validUntil=end==null?null:end.toLocalDate();
            if (!pass.covers.isEmpty() && pass.priceYen>0) {passes.add(pass);rows.put(pass.key,row);}
        });
        return new Snapshot(List.copyOf(passes),Map.copyOf(rows));
    }
}
