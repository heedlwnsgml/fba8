package com.travel.planner.util;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class JwtAdminConfigurationTest {
 @Test void configuredAdministratorGetsRoleOnNewLoginAndOtherUsersDoNot() {
  var jwt=new JwtUtil("local-test-signing-key-012345678901234567890123456789", "heedlwnsgml@naver.com");
  assertEquals("ADMIN",jwt.extractRole(jwt.generateToken("heedlwnsgml@naver.com")));
  assertEquals("USER",jwt.extractRole(jwt.generateToken("someone@example.com")));
 }
 @Test void oldUserTokenNeedsNewLoginBeforeAdministratorRoleApplies() {
  String key="local-test-signing-key-012345678901234567890123456789";
  var before=new JwtUtil(key,"");var after=new JwtUtil(key,"heedlwnsgml@naver.com");
  assertEquals("USER",after.extractRole(before.generateToken("heedlwnsgml@naver.com")));
 }
}
