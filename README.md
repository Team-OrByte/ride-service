# Ride Service

Ride Service is a microservice designed to manage ride operations within a ride-sharing system. It integrates with other services such as User Service and Bike Service, and it communicates with Kafka for asynchronous events.

---

## 🛠 Configuration Format (`config.toml`)

```toml
[ride_service]
PORT = 8081

[ride_service.repository]
host = "localhost"
port = 5432
user = "ride_user"
password = "ride_pass"
database = "ride_service_db"

[ride_service.user_service_client.userServiceClient]
url = "http://user_service/"
timeout = 2.0

[ride_service.bike_service_client.bikeServiceClient]
url = "http://bike_service/"
timeout = 2.0

[ride_service.user_service_client.userCapabilityCacheConfig]
capacity = 1000
evictionFactor = 0.25
defaultMaxAge = 300.0
cleanupInterval = 600.0

[ride_service.event_handler]
SERVER_URL = "localhost:9094"
RIDE_RESERVE_TOPIC = "ride-reserve-topic"	
RIDE_START_TOPIC = "ride-start-topic"

[ride_service.event_handler.producerConfiguration]
clientId = "event-producer"
acks = "all"
retryCount = 3
```

## 🐳 Docker Compose Setup (Kafka + PostgreSQL)

To start the services:

```bash
docker-compose up -d
```

## 📖 API Endpoints and Functionalities

| HTTP Method | Endpoint               | Description                       |
| ----------- | ---------------------- | --------------------------------- |
| `POST`      | `/reserveRide`               | Create a new ride                 |
| `POST`      | `/rides/{id}/startRide`    | Start a ride                      |

### 1. Reserve a Ride
Endpoint: POST /reserveRide

Request Param: String bikeId, String startLocation

### 2. Start a Ride
Endpoint: POST /rides/{id}/startRide

Request Param: String rideId
