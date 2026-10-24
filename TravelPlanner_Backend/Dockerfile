# syntax=docker/dockerfile:1
FROM eclipse-temurin:25-jdk-noble AS build
WORKDIR /build
COPY gradlew build.gradle settings.gradle ./
COPY gradle ./gradle
RUN sed -i 's/\r$//' gradlew && chmod +x gradlew
ENV GRADLE_OPTS="-Dorg.gradle.daemon=false -Dorg.gradle.jvmargs=-Xmx1536m"
RUN --mount=type=cache,target=/root/.gradle ./gradlew --no-daemon dependencies --configuration runtimeClasspath
COPY src ./src
RUN --mount=type=cache,target=/root/.gradle ./gradlew --no-daemon bootJar -x test

FROM eclipse-temurin:25-jre-noble AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 planner && useradd --uid 10001 --gid planner --no-create-home planner
WORKDIR /app
COPY --from=build --chown=10001:10001 /build/build/libs/*.jar /app/app.jar
COPY --chmod=755 container-entrypoint.sh /usr/local/bin/container-entrypoint
RUN mkdir /app/data /app/config && chown 10001:10001 /app/data
USER 10001:10001
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=65.0 -Dfile.encoding=UTF-8" TZ=Asia/Seoul
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=5s --start-period=180s --retries=4 \
    CMD curl --fail --silent http://127.0.0.1:8080/api/v1/auth/health/ready || exit 1
ENTRYPOINT ["container-entrypoint"]
