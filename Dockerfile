FROM ballerina/ballerina:2201.12.7 AS builder

WORKDIR /app

COPY . .

RUN bal build

FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

COPY --from=builder /app/target/bin/ride_service.jar .

RUN mkdir -p logs

EXPOSE 8084 27760

CMD ["java", "-jar", "ride_service.jar"]