# Etapa 1: compila el .war con Maven (no hace falta tener Maven instalado).
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -B -DskipTests clean package

# Etapa 2: Tomcat 9 (javax.*, el namespace que usa el backend) con el .war ya desplegado.
FROM tomcat:9.0-jdk17-temurin
COPY --from=build /app/target/geotravel.war /usr/local/tomcat/webapps/geotravel.war
