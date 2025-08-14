FROM maven:3.8.7-openjdk-18-slim AS build
# FROM maven:3.8.7-openjdk-18 AS build
# FROM maven:3.9.11-ibm-semeru-21-noble AS build
WORKDIR /app
COPY .  .
RUN mvn package -DskipTests

# FROM openjdk:18-alpine AS run
# FROM ibm-semeru-runtimes:open-jdk-24.0.2_12-jre AS run
FROM openjdk:19-jdk-alpine3.16 AS run
COPY --from=build /app/target/demo-0.0.1-SNAPSHOT.jar /run/demo.jar

ARG USER=devops
ENV HOME /home/$USER
RUN adduser --disabled-password $USER && \
    chown $USER:$USER /run/demo.jar

RUN apk add curl --no-cache
HEALTHCHECK --interval=30s --timeout=10s --retries=2 --start-period=20s \
    CMD curl -f http://localhost:8080/ || exit 1

USER $USER
EXPOSE 8080
CMD java  -jar /run/demo.jar
