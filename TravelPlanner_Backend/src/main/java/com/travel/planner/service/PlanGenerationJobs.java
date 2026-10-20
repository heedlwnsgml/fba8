package com.travel.planner.service;

import com.travel.planner.dto.AiRouteResponse;
import jakarta.annotation.PreDestroy;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.*;
import java.util.function.Supplier;

/** Owner-scoped background jobs with cancellation and an atomic save boundary. */
@Service
public class PlanGenerationJobs {
 public record Result(String jobId,String status,AiRouteResponse response,String error,String message,boolean cancellationPending) {
  public Result(String jobId,String status,AiRouteResponse response,String error){this(jobId,status,response,error,null,false);}
 }
 private record Key(String owner,String id) {}
 private static final class Job {
  final String id,fingerprint;volatile String status="QUEUED",error,message="생성 순서를 기다리고 있습니다.";volatile AiRouteResponse response;
  volatile Instant finished;volatile Thread worker;volatile boolean cancelled,committing;
  final Map<Object,Object> cache=new HashMap<>();long started=System.nanoTime();int displayLookups;long stageStarted=System.nanoTime();
  Job(String id,String fingerprint){this.id=id;this.fingerprint=fingerprint;}
  Result result(){return new Result(id,status,response,error,message,cancelled&&finished==null);}
 }
 private static final ThreadLocal<Job> CURRENT=new ThreadLocal<>();
 private final ConcurrentHashMap<Key,Job> jobs=new ConcurrentHashMap<>();
 private final ThreadPoolExecutor executor=new ThreadPoolExecutor(2,2,0,TimeUnit.SECONDS,new ArrayBlockingQueue<>(8),r->{var t=new Thread(r,"plan-generation");t.setDaemon(true);return t;},new ThreadPoolExecutor.AbortPolicy());
 public static void checkCancellation(){var job=CURRENT.get();if(Thread.currentThread().isInterrupted()||(job!=null&&job.cancelled))throw new CancellationException("일정 생성이 취소되었습니다.");}
 public static void progress(String message){checkCancellation();var job=CURRENT.get();if(job!=null && !java.util.Objects.equals(job.message,message)){System.getLogger(PlanGenerationJobs.class.getName()).log(System.Logger.Level.INFO,"Generation stage [{0}] took {1} ms",job.message,TimeUnit.NANOSECONDS.toMillis(System.nanoTime()-job.stageStarted));job.message=message;job.stageStarted=System.nanoTime();}}
 public static boolean allowDisplayLookup(){checkCancellation();var job=CURRENT.get();return job==null||(job.displayLookups++<2&&System.nanoTime()-job.started<TimeUnit.SECONDS.toNanos(20));}
 public static void beforeCommit(){var job=CURRENT.get();if(job==null)return;synchronized(job){checkCancellation();job.committing=true;}}
 public static <T> T memoize(Object key,Supplier<T> work){
  checkCancellation();var job=CURRENT.get();if(job==null)return work.get();
  if(job.cache.containsKey(key)){@SuppressWarnings("unchecked") T result=(T)job.cache.get(key);return result;}
  T result=work.get();checkCancellation();if(job.cache.size()<4096)job.cache.put(key,result);return result;
 }
 public synchronized Result submit(String owner,String id,String fingerprint,Supplier<AiRouteResponse> generate){
  jobs.entrySet().removeIf(e->e.getValue().finished!=null&&e.getValue().finished.isBefore(Instant.now().minusSeconds(3600)));
  var key=new Key(owner,id);var old=jobs.get(key);
  if(old!=null){if(!old.fingerprint.equals(fingerprint))throw new ResponseStatusException(HttpStatus.CONFLICT,"같은 생성 요청의 조건이 변경되었습니다.");return old.result();}
  if(jobs.size()>=128)throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,"생성 요청이 많습니다. 잠시 후 다시 시도하세요.");
  if(jobs.entrySet().stream().filter(e->e.getKey().owner.equals(owner)&&e.getValue().finished==null).count()>=2)
   throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,"일정은 한 번에 최대 2개까지 생성할 수 있습니다.");
  var job=new Job(id,fingerprint);jobs.put(key,job);
  try{executor.execute(()->{
   CURRENT.set(job);
   try{
    synchronized(job){checkCancellation();job.worker=Thread.currentThread();job.status="RUNNING";job.started=System.nanoTime();}
    var result=generate.get();checkCancellation();
    if(result==null||result.getTimeline()==null||result.getTimeline().isEmpty())throw new IllegalArgumentException("생성된 일정이 비어 있습니다. 여행 조건을 조정하세요.");
    synchronized(job){checkCancellation();job.response=result;job.status="SUCCEEDED";}
   }catch(Exception error){
    Throwable cause=error;while(cause.getCause()!=null&&cause.getCause()!=cause)cause=cause.getCause();
    if(!job.cancelled)System.getLogger(PlanGenerationJobs.class.getName()).log(System.Logger.Level.ERROR,"Generation failure type {0} at {1}",cause.getClass().getSimpleName(),cause.getStackTrace().length==0?"unknown":cause.getStackTrace()[0]);
    synchronized(job){
    if(!job.cancelled){job.error=error instanceof ResponseStatusException responseError && java.util.Set.of(400,409,422,429).contains(responseError.getStatusCode().value()) && responseError.getReason()!=null ? responseError.getReason() : (error instanceof IllegalArgumentException || error instanceof PlanGenerationException)?error.getMessage():error.getMessage()!=null&&error.getMessage().startsWith("현재 조건으로 생성 가능한 일정이 없습니다.")?"현재 조건으로 생성 가능한 일정이 없습니다. 조건을 완화해 주세요.":"일정 생성 중 서버 오류가 발생했습니다. 다시 시도하세요.";job.status="FAILED";}
   }}finally{System.getLogger(PlanGenerationJobs.class.getName()).log(System.Logger.Level.INFO,"Generation finished status={0}, elapsed={1} ms, stage={2}",job.status,TimeUnit.NANOSECONDS.toMillis(System.nanoTime()-job.started),job.message);job.finished=Instant.now();job.worker=null;job.cache.clear();CURRENT.remove();Thread.interrupted();}
  });}catch(RejectedExecutionException e){jobs.remove(key);throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,"생성 요청이 많습니다. 잠시 후 다시 시도하세요.");}
  return job.result();
 }
 private static void stop(Job job){synchronized(job){
  if(job.finished!=null||job.committing||job.status.equals("SUCCEEDED")||job.status.equals("FAILED"))return;
  job.cancelled=true;job.status="CANCELLED";
  job.error=null;
  if(job.worker!=null)job.worker.interrupt();
 }}
 public Result cancel(String owner,String id){var job=jobs.get(new Key(owner,id));if(job==null)throw new ResponseStatusException(HttpStatus.NOT_FOUND,"생성 작업을 찾을 수 없습니다.");
  synchronized(job){if(job.committing&&job.finished==null)throw new ResponseStatusException(HttpStatus.CONFLICT,"저장 마무리 중입니다. 잠시 후 완료된 일정에서 삭제할 수 있습니다.");stop(job);return job.result();}}
 public Result find(String owner,String id){var job=jobs.get(new Key(owner,id));return job==null?null:job.result();}
 public List<Result> list(String owner){return jobs.entrySet().stream().filter(e->e.getKey().owner.equals(owner)).map(e->e.getValue().result()).toList();}
 @PreDestroy public void close(){jobs.values().forEach(j->stop(j));executor.shutdownNow();}
}
