package com.travel.planner.service;
import com.travel.planner.entity.User;
import com.travel.planner.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
/** Metadata writes are rolled back; the main users table is never modified. */
@SpringBootTest
@Transactional
class UserProfileServiceTest {
    @Autowired JdbcTemplate jdbc;
    private User user(long id,String email) {User u=new User();u.setId(id);u.setEmail(email);u.setAgeGroup("30대");u.setGender("여성");u.setProvider("local");return u;}
    @Test void savesOwnNameAndReadsItAgainWithoutTouchingMainUserData() {
        var users=mock(UserRepository.class);var service=new UserProfileService(users,jdbc);
        when(users.findByEmail("profile-test@example.invalid")).thenReturn(Optional.of(user(-991L,"profile-test@example.invalid")));
        when(users.findByEmail("other-test@example.invalid")).thenReturn(Optional.of(user(-992L,"other-test@example.invalid")));
        assertEquals("테스트 이름",service.rename("profile-test@example.invalid"," 테스트 이름 ").get("displayName"));
        assertEquals("테스트 이름",service.get("profile-test@example.invalid").get("displayName"));
        assertEquals("",service.get("other-test@example.invalid").get("displayName"));
        assertEquals("30대",service.get("profile-test@example.invalid").get("ageGroup"));
        service.delete("profile-test@example.invalid");
        assertEquals("",service.get("profile-test@example.invalid").get("displayName"));
        verify(users,never()).save(any());verify(users,never()).delete(any());
    }
    @Test void invalidNamesAndMissingUsersAreRejected() {
        var users=mock(UserRepository.class);var service=new UserProfileService(users,jdbc);
        assertEquals(400,assertThrows(ResponseStatusException.class,()->service.rename("me"," ")).getStatusCode().value());
        assertEquals(400,assertThrows(ResponseStatusException.class,()->service.rename("me","x".repeat(41))).getStatusCode().value());
        when(users.findByEmail("missing")).thenReturn(Optional.empty());
        assertEquals(401,assertThrows(ResponseStatusException.class,()->service.get("missing")).getStatusCode().value());
    }
}
