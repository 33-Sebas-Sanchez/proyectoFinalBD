# syntax=docker/dockerfile:1

# ---------- Etapa de compilación ----------
FROM docker.io/library/eclipse-temurin:25-jdk AS build
WORKDIR /app
COPY . .
RUN chmod +x mvnw && ./mvnw -q -B -pl compras-service -am -DskipTests package

# ---------- Etapa de ejecución ----------
FROM docker.io/library/eclipse-temurin:25-jre
WORKDIR /app
RUN useradd --system --uid 1001 spring
USER spring
COPY --from=build /app/compras-service/target/*.jar app.jar

ENV JAVA_OPTS=""
EXPOSE 8080
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
