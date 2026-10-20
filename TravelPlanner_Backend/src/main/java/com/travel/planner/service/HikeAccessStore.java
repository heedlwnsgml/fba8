package com.travel.planner.service;

import com.travel.planner.entity.Place;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.*;

/** Supplementary access points; never alters the supplied place table. */
@Component
public class HikeAccessStore {
    private final String url;

    public HikeAccessStore(@Value("${app.hike-access.path:data/hike-access.sqlite}") String file) {
        try {
            Path path=Path.of(file).toAbsolutePath().normalize();
            Files.createDirectories(path.getParent());
            url="jdbc:sqlite:"+path;
            try(Connection c=open();Statement s=c.createStatement()) {
                s.execute("CREATE TABLE IF NOT EXISTS hike_access (place_id TEXT PRIMARY KEY, latitude REAL, longitude REAL, name TEXT NOT NULL)");
            }
        } catch(Exception e) {throw new IllegalStateException("Hike access store initialization failed",e);}
    }

    private Connection open() throws SQLException {
        Connection c=DriverManager.getConnection(url);
        try(Statement s=c.createStatement()){s.execute("PRAGMA busy_timeout=5000");}
        return c;
    }

    public void restore(Place place) {
        if(place==null || place.getPlaceId()==null || place.getTrailheadName()!=null)return;
        try(Connection c=open();PreparedStatement s=c.prepareStatement("SELECT latitude,longitude,name FROM hike_access WHERE place_id=?")) {
            s.setString(1,place.getPlaceId());
            try(ResultSet r=s.executeQuery()) {
                if(!r.next())return;
                place.setTrailheadLat((Double)r.getObject(1));
                place.setTrailheadLng((Double)r.getObject(2));
                place.setTrailheadName(r.getString(3));
            }
        } catch(SQLException e) {System.out.println("[등산] 별도 저장 정보를 읽지 못했습니다.");}
    }

    public void save(Place place) {
        if(place==null || place.getPlaceId()==null || place.getTrailheadName()==null)return;
        try(Connection c=open();PreparedStatement s=c.prepareStatement("INSERT INTO hike_access(place_id,latitude,longitude,name) VALUES(?,?,?,?) ON CONFLICT(place_id) DO UPDATE SET latitude=excluded.latitude,longitude=excluded.longitude,name=excluded.name")) {
            s.setString(1,place.getPlaceId());s.setObject(2,place.getTrailheadLat());s.setObject(3,place.getTrailheadLng());s.setString(4,place.getTrailheadName());s.executeUpdate();
        } catch(SQLException e) {System.out.println("[등산] 별도 저장 정보를 갱신하지 못했습니다.");}
    }
}
