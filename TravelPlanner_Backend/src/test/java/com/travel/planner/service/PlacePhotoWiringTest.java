package com.travel.planner.service;
import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;
import org.springframework.web.client.RestTemplate;
import static org.junit.jupiter.api.Assertions.assertNotNull;
class PlacePhotoWiringTest {
 @Test void productionServiceCanBeCreatedBySpring() {
  try(var context=new AnnotationConfigApplicationContext()) {
   context.registerBean(RestTemplate.class, () -> new RestTemplate());
   context.register(PlacePhotoService.class);
   context.refresh();
   assertNotNull(context.getBean(PlacePhotoService.class));
  }
 }
}

