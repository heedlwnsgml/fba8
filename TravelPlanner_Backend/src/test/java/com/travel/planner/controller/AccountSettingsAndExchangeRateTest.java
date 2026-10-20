package com.travel.planner.controller;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import jakarta.validation.Validation;
import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@Transactional
class AccountSettingsAndExchangeRateTest {
    @Autowired JdbcTemplate jdbc;
    private UsernamePasswordAuthenticationToken user(String email,String role) {
        return new UsernamePasswordAuthenticationToken(email,null,List.of(new SimpleGrantedAuthority("ROLE_"+role)));
    }
    @Test void settingsPersistPerAccountAndNeverLeakAcrossUsers() {
        var controller=new AccountSettingsController(jdbc);
        var a=user("weather-check-a@example.invalid","USER");
        var b=user("weather-check-b@example.invalid","USER");
        controller.save(a,new AccountSettingsController.Settings(true,"morning","07:35","19:20"));
        assertEquals("07:35",controller.get(a).get("morningTime"));
        assertEquals("morning",controller.get(a).get("frequency"));
        assertEquals("08:00",controller.get(b).get("morningTime"));
    }
    @Test void onlyConfiguredEditorWithAdminRoleCanWriteRates() {
        var controller=new ExchangeRateController(jdbc,"editor@example.invalid");
        var rate=new ExchangeRateController.Rate(new BigDecimal("8.4906"),LocalDate.now(),"https://example.com/rate");
        assertThrows(ResponseStatusException.class,()->controller.save(user("other@example.invalid","ADMIN"),rate));
        assertThrows(ResponseStatusException.class,()->controller.save(user("editor@example.invalid","USER"),rate));
        var saved=controller.save(user("editor@example.invalid","ADMIN"),rate);
        assertEquals(0,new BigDecimal(saved.get("krwPerJpy").toString()).compareTo(rate.krwPerJpy()));
    }
    @Test void invalidTimeAndRatesAreRejectedByValidation() {
        try(var factory=Validation.buildDefaultValidatorFactory()) {
            var validator=factory.getValidator();
            assertFalse(validator.validate(new AccountSettingsController.Settings(true,"morning","25:00","08:00")).isEmpty());
            assertFalse(validator.validate(new ExchangeRateController.Rate(BigDecimal.ZERO,LocalDate.now(),"https://example.com")).isEmpty());
            assertFalse(validator.validate(new ExchangeRateController.Rate(BigDecimal.ONE,LocalDate.now().plusDays(1),"https://example.com")).isEmpty());
        }
    }
    @Test void hotelCurrencyDefaultsToWonAndPersistsOnlyForItsOwner() {
        var controller=new HotelCurrencyPreferencesController(jdbc);
        var a=user("currency-a@example.invalid","USER");var b=user("currency-b@example.invalid","USER");
        assertEquals("KRW",controller.get(a).get("hotelBudgetCurrency"));
        controller.save(a,new HotelCurrencyPreferencesController.Preferences("JPY"));
        assertEquals("JPY",controller.get(a).get("hotelBudgetCurrency"));
        assertEquals("KRW",controller.get(b).get("hotelBudgetCurrency"));
    }
    @Test void onlyWonAndYenAreAcceptedAsDefaultCurrency() {
        try(var factory=Validation.buildDefaultValidatorFactory()) {
            assertFalse(factory.getValidator().validate(new HotelCurrencyPreferencesController.Preferences("USD")).isEmpty());
            assertFalse(factory.getValidator().validate(new HotelCurrencyPreferencesController.Preferences(null)).isEmpty());
        }
    }
}
