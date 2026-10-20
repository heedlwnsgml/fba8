package com.travel.planner.service;

import com.travel.planner.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import java.util.*;

/** Profile extension in a separate database; the supplied planner schema is unchanged. */
@Service
@RequiredArgsConstructor
public class UserProfileService {
    private final UserRepository users;
    private final JdbcTemplate jdbc;
    private static final String TABLE="test_planner_app_metadata.user_profile";

    @Transactional(readOnly=true)
    public Map<String,Object> get(String email) {
        var user=users.findByEmail(email).orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED,"다시 로그인하세요."));
        var names=jdbc.queryForList("SELECT display_name FROM "+TABLE+" WHERE planner_database=DATABASE() AND user_id=? AND email=?",String.class,user.getId(),email);
        Map<String,Object> result=new LinkedHashMap<>();
        result.put("email",user.getEmail());result.put("displayName",names.isEmpty() ? "" : names.get(0));
        result.put("ageGroup",user.getAgeGroup());result.put("gender",user.getGender());result.put("provider",user.getProvider());
        return result;
    }

    @Transactional
    public Map<String,Object> rename(String email,String requested) {
        String name=requested==null ? "" : requested.trim();
        if(name.isEmpty() || name.length()>40 || name.chars().anyMatch(Character::isISOControl))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"이름은 1~40자로 입력하세요.");
        var user=users.findByEmail(email).orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED,"다시 로그인하세요."));
        jdbc.update("INSERT INTO "+TABLE+" (planner_database,user_id,email,display_name) VALUES (DATABASE(),?,?,?) ON DUPLICATE KEY UPDATE display_name=VALUES(display_name)",user.getId(),email,name);
        return get(email);
    }
    public void delete(String email) {
        jdbc.update("DELETE FROM test_planner_app_metadata.user_preferences WHERE planner_database=DATABASE() AND email=?",email);
        jdbc.update("DELETE FROM test_planner_app_metadata.weather_settings WHERE planner_database=DATABASE() AND email=?",email);
        jdbc.update("DELETE FROM "+TABLE+" WHERE planner_database=DATABASE() AND email=?",email);
    }
}
