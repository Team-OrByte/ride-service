# 🚴 Ride Service

Ride Service is a microservice responsible for managing ride lifecycle operations in a ride-sharing system.  
It integrates with **User Service**, **Bike Service**, **Reward Service**, and publishes **Kafka events** for notifications and payments.

---

## 🛠 Configuration (`config.toml`)

```toml
[ride_service]
PORT = 8082
WEBSOCKET_PORT = 27770
pub_key = "./public.crt"

[ride_service.repository]
host = "localhost"
port = 5432
user = "ride_user"
password = "ride_pass"
database = "ride_service_db"

[ride_service.user_service_client.userServiceClient]
url = "http://user_service/"
timeout = 120.0

[ride_service.bike_service_client.bikeServiceClient]
url = "http://bike-service/"
timeout = 120.0

[ride_service.reward_service_client.rewardServiceClient]
url = "http://reward-service/"
timeout = 120.0

[ride_service.user_service_client.userCapabilityCacheConfig]
capacity = 1000
evictionFactor = 0.25
defaultMaxAge = 300.0
cleanupInterval = 600.0

[ride_service.event_handler]
SERVER_URL = "localhost:9094"
RIDE_NOTIF_EVENTS_TOPIC = "ride-events"
PAYMENT_EVENTS_TOPIC = "payment-events"	

[ride_service.event_handler.producerConfiguration]
clientId = "event-producer"
acks = "all"
retryCount = 3
```

---

## 🐳 Docker Compose Setup

Start all dependent services (Kafka, PostgreSQL):

```bash
docker-compose up -d
```

---

## 📖 API Endpoints  

### Base URL  
```
http://localhost:8082/ride-service
```

**All endpoints require JWT authentication** (except admin read-only endpoints):  

```
Authorization: Bearer {token}
```

### 1. Reserve a Ride  

- **Method:** `POST`  
- **Endpoint:** `/reserveRide`  
- **Params:** `bikeId`, `startLocation`  

#### Example Request  
```bash
curl --request POST \
  --url "http://localhost:8082/ride-service/reserveRide?bikeId=B101&startLocation=StationA" \
  --header "Authorization: Bearer {token}" \
  --header "Content-Type: application/json"
```

#### Example Response (202 Accepted)  
```json
{
  "message": "You can start the ride.",
  "rideId": "c14e4c9e-1234-45c7-88a9-90f8e1b9c6a1"
}
```

### 2. Start a Ride  

- **Method:** `POST`  
- **Endpoint:** `/rides/{rideId}/startRide`  

#### Example Request  
```bash
curl --request POST \
  --url "http://localhost:8082/ride-service/rides/c14e4c9e-1234-45c7-88a9-90f8e1b9c6a1/startRide" \
  --header "Authorization: Bearer {token}" \
  --header "Content-Type: application/json"
```

#### Example Response (200 OK)  
```json
{
  "message": "Ride started successfully."
}
```

### 3. End a Ride  

- **Method:** `POST`  
- **Endpoint:** `/rides/{rideId}/end`  
- **Body:**  

```json
{
  "distance": 1200,
  "end_location": "StationB",
  "claimReward": true
}
```

#### Example Request  
```bash
curl --request POST \
  --url "http://localhost:8082/ride-service/rides/c14e4c9e-1234-45c7-88a9-90f8e1b9c6a1/end" \
  --header "Authorization: Bearer {token}" \
  --header "Content-Type: application/json" \
  --data '{
    "distance": 1200,
    "end_location": "StationB",
    "claimReward": true
  }'
```

#### Example Response (200 OK)  
```json
{
  "message": "Ride completed successfully.",
  "rideId": "c14e4c9e-1234-45c7-88a9-90f8e1b9c6a1",
  "durationSeconds": 450,
  "totalPrice": 20.5
}
```

### 4. Cancel a Ride  

- **Method:** `POST`  
- **Endpoint:** `/rides/{rideId}/cancel`  

#### Example Request  
```bash
curl --request POST \
  --url "http://localhost:8082/ride-service/rides/c14e4c9e-1234-45c7-88a9-90f8e1b9c6a1/cancel" \
  --header "Authorization: Bearer {token}"
```

#### Example Response (200 OK)  
```json
{
  "message": "Ride reservation has been canceled.",
  "price": 0
}
```

### 5. Get Ride by ID (Admin)  

- **Method:** `GET`  
- **Endpoint:** `/getRide?rideId={id}`  

#### Example Request  
```bash
curl --request GET \
  --url "http://localhost:8082/ride-service/getRide?rideId=c14e4c9e-1234-45c7-88a9-90f8e1b9c6a1" \
  --header "Content-Type: application/json"
```

#### Example Response (200 OK)  
```json
{
  "ride_id": "c14e4c9e-1234-45c7-88a9-90f8e1b9c6a1",
  "user_id": "user_001",
  "bike_id": "B101",
  "status": "ENDED",
  "start_location": "StationA",
  "end_location": "StationB",
  "duration": 450,
  "price": 20.5
}
```

### 6. Get Active Ride for User  

- **Method:** `GET`  
- **Endpoint:** `/getActiveRide`  

#### Example Request  
```bash
curl --request GET \
  --url "http://localhost:8082/ride-service/getActiveRide" \
  --header "Authorization: Bearer {token}"
```

#### Example Response (200 OK)  
```json
[
  {
    "ride_id": "c14e4c9e-1234-45c7-88a9-90f8e1b9c6a1",
    "user_id": "user_001",
    "bike_id": "B101",
    "status": "IN_PROGRESS",
    "start_location": "StationA"
  }
]
```

---

## 🔔 WebSocket Ride Pricing  

### Base URL  
```
ws://localhost:27770/rides?rideId={rideId}&token={token}
```

- **Auth:** JWT required in the WebSocket handshake.  
- **Description:** Subscribe to **real-time ride pricing updates** for a specific `rideId` after validated using `token`.  

#### Example Connection (using `wscat`)  
```bash
wscat -c "ws://localhost:27770/rides?rideId=c14e4c9e-1234-45c7-88a9-90f8e1b9c6a1&token=auth_token"
```

#### Example Client Update → Server  
```json
{
  "duration_seconds": 450,
  "distance_meters": 1200
}
```

#### Example Server Response (Price Update)  
```json
{
  "current_price": 20.5
}
```

---

## 📨 Kafka Event Integration  

- **Ride Notifications Topic:** `ride-events`  
  - Event Types: `RIDE_STARTED`, `RIDE_ENDED`  
  - Payload: `userId`, `rideId`, `bikeId`, `startStation` / `endStation`, `duration`, `fare`  

- **Payment Events Topic:** `payment-events`  
  - Payload: `rideId`, `userId`, `fare`  

The ride service **publishes Kafka events** for ride start/end and payments which can be consumed by the Notification Service or other downstream systems.

---

## ⚠️ Error Handling  

| Status | Description |
| ------ | ----------- |
| 400 | Invalid request, missing parameters, or unauthorized operation |
| 404 | Ride not found or ride in invalid state |
| 500 | Internal server errors such as DB or service failures |
