package com.travel.planner.service;
import java.util.*;
import java.util.function.ToIntBiFunction;

/** Spend an available destination stay day on a reachable intermediate overnight stop. */
public final class LandStopoverPlanner {
 private LandStopoverPlanner(){}
 public static List<String> split(List<String> original,Set<Integer> fixedNights,List<String> candidates,ToIntBiFunction<String,String> minutes,int dailyLimit){
  return split(original,fixedNights,(a,z)->candidates,minutes,dailyLimit);
 }
 public static List<String> split(List<String> original,Set<Integer> fixedNights,java.util.function.BiFunction<String,String,List<String>> candidates,ToIntBiFunction<String,String> minutes,int dailyLimit){
  var days=new ArrayList<>(original);
  for(int i=1;i+1<days.size();i++){
   String from=days.get(i-1),to=days.get(i);
   if(from==null || to==null || from.equals(to) || fixedNights.contains(i+1) || !to.equals(days.get(i+1)))continue;
   int direct=minutes.applyAsInt(from,to);if(direct<=dailyLimit || direct==Integer.MAX_VALUE)continue;
   String best=null;int remaining=direct;
   for(String stop:candidates.apply(from,to)){
    if(stop.equals(from)||stop.equals(to))continue;
    int first=minutes.applyAsInt(from,stop);if(first<=0 || first>dailyLimit)continue;
    int second=minutes.applyAsInt(stop,to);
    if(second>=direct*0.85 || (long)first+second>direct*1.3)continue;
    if(second<remaining){best=stop;remaining=second;}
   }
   if(best!=null)days.set(i,best);
  }
  return days;
 }
}
