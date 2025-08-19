import ride_service.bike_service_client as bsc;
import ride_service.event_handler;
import ride_service.pricing_service as ps;
import ride_service.repository;
import ride_service.reward_service_client as rsc;
import ride_service.types;
import ride_service.user_service_client as usc;

import ballerina/http;
import ballerina/io;
import ballerina/jwt;
import ballerina/log;
import ballerina/time;
import ballerina/uuid;
import ballerina/websocket;

configurable int PORT = ?;
configurable string pub_key = ?;

public type Claims record {|
    string? userId;
    string? email;
    string? role;
|};

final map<websocket:Caller> rideConnections = {};

@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"],
        allowMethods: ["POST", "PUT", "GET", "POST", "OPTIONS"],
        allowHeaders: ["Content-Type", "Access-Control-Allow-Origin", "X-Service-Name"]
    },
    auth: [
        {
            jwtValidatorConfig: {
                issuer: "Orbyte",
                audience: "vEwzbcasJVQm1jVYHUHCjhxZ4tYa",
                signatureConfig: {
                    certFile: pub_key
                },
                scopeKey: "scp"
            },
            scopes: "user"
        }
    ]
}
service /ride on new http:Listener(PORT) {

    function init() {
        log:printInfo(`The Ride Service Initiated on Port: ${PORT}`);
    }

    resource function post reserveRide(@http:Header string Authorization, string bikeId, string startLocation) returns http:Accepted|http:BadRequest|error {
        Claims claims = check extractClaims(Authorization);
        string userId;
        if claims.userId is string {
            userId = <string>claims.userId;
        } else {
            return <http:BadRequest>{body: "Invalid Token"};
        }
        boolean isCapable = check usc:userCapability(userId);
        if isCapable is false {
            return <http:BadRequest>{
                body: types:USER_NOT_CAPABLE
            };
        }
        string rideId = uuid:createType4AsString();
        boolean isSuccess = check bsc:reserveBike(bikeId, Authorization);
        if isSuccess is false {
            return <http:BadRequest>{
                body: types:BIKE_NOT_AVAILABLE
            };
        }

        repository:RideInsert newRide = {
            bike_id: bikeId,
            ride_id: rideId,
            user_id: userId,
            start_time: time:utcNow(),
            end_time: (),
            duration: (),
            distance: (),
            start_location: startLocation,
            end_location: (),
            status: "RESERVED",
            price: ()
        };
        _ = check repository:insertRide(newRide);

        types:RideReserveEvent newReserveEvent = {
            bike_id: bikeId,
            ride_id: rideId,
            user_id: userId,
            start_location: startLocation
        };
        check event_handler:produceReserveEvent(newReserveEvent);

        log:printInfo(`Ride ${rideId} reserved for user ${userId} with bike ${bikeId}`);
        return <http:Accepted>{
            body: {
                message: "You can start the ride.",
                rideId: rideId
            }
        };
    }

    resource function post rides/[string rideId]/startRide(@http:Header string Authorization) returns http:Ok|http:BadRequest|http:NotFound|error {
        Claims claims = check extractClaims(Authorization);
        string userId;
        if claims.userId is string {
            userId = <string>claims.userId;
        } else {
            return <http:BadRequest>{body: "Invalid Token"};
        }

        repository:Ride? ride = check repository:getRideById(rideId);
        if ride is () {
            return <http:NotFound>{body: {message: types:RIDE_NOT_FOUND}};
        }

        if (ride.user_id != userId || ride.status != repository:RESERVED) {
            return <http:BadRequest>{body: types:INVALID_RIDE_START_REQUEST};
        }

        types:RideStartEvent newStartEvent = {
            bike_id: ride.bike_id,
            ride_id: ride.ride_id,
            user_id: ride.user_id,
            start_time: time:utcNow()
        };
        repository:RideUpdate rideUpdate = {
            status: repository:IN_PROGRESS,
            start_time: newStartEvent.start_time
        };

        _ = check repository:updateRide(rideId, rideUpdate);
        check event_handler:produceStartEvent(newStartEvent);

        log:printInfo(`Ride ${rideId} started by user ${userId}.`);
        return <http:Ok>{body: {message: "Ride started successfully."}};
    }

    resource function post rides/[string rideId]/end(@http:Header string Authorization, types:EndRideRequest endRequest) returns http:Ok|http:BadRequest|http:NotFound|error {
        Claims claims = check extractClaims(Authorization);
        string userId;
        if claims.userId is string {
            userId = <string>claims.userId;
        } else {
            return <http:BadRequest>{body: "Invalid Token"};
        }

        repository:Ride? ride = check repository:getRideById(rideId);
        if ride is () || ride.start_time is () {
            return <http:NotFound>{body: {message: "Ride not found or has not been started.", rideId: rideId}};
        }

        if ride.user_id != userId || ride.status != "IN_PROGRESS" {
            return <http:BadRequest>{body: {message: "Ride cannot be ended. Invalid state or ownership."}};
        }

        time:Utc endTime = time:utcNow();
        time:Utc startTime;
        time:Utc? startTimeOpt = ride.start_time;
        if startTimeOpt is time:Utc {
            startTime = startTimeOpt;
        } else {
            return <http:BadRequest>{body: types:START_TIME_NULL};
        }
        int durationInSeconds = <int>time:utcDiffSeconds(endTime, startTime);

        decimal price = ps:calculatePrice(durationInSeconds, <int>endRequest.distance);
        repository:RideUpdate rideUpdate = {
            end_time: endTime,
            duration: durationInSeconds,
            distance: endRequest.distance,
            end_location: endRequest.end_location,
            status: repository:ENDED,
            price: price
        };
        _ = check repository:updateRide(rideId, rideUpdate);
        check bsc:releaseBike(Authorization, ride.bike_id, endRequest.end_location);

        if endRequest.claimReward is true {
            rsc:RewardPointsRequest rewardRequest = {
                rideId: ride.ride_id,
                timestamp: 0,
                distance: endRequest.distance,
                time: 5,
                startFrom: ride.start_location,
                stopAt: endRequest.end_location,
                userId: userId
            };
            _ = check rsc:rewardPoints(rewardRequest, Authorization);
        }

        types:RideEndEvent endEvent = {
            bike_id: ride.bike_id,
            ride_id: ride.ride_id,
            user_id: ride.user_id,
            end_time: endTime,
            price: price
        };
        check event_handler:produceEndEvent(endEvent);

        log:printInfo(`Ride ${rideId} ended. Duration: ${durationInSeconds}s, Price: ${price}`);
        return <http:Ok>{
            body: {
                message: "Ride completed successfully.",
                rideId: rideId,
                durationSeconds: durationInSeconds,
                totalPrice: price
            }
        };
    }

    resource function post rides/[string rideId]/cancel(@http:Header string Authorization) returns http:Ok|http:BadRequest|http:NotFound|error {
        Claims claims = check extractClaims(Authorization);
        string userId;
        if claims.userId is string {
            userId = <string>claims.userId;
        } else {
            return <http:BadRequest>{body: "Invalid Token"};
        }

        repository:Ride? ride = check repository:getRideById(rideId);
        if ride is () {
            return <http:NotFound>{body: types:RIDE_NOT_FOUND};
        }

        if ride.user_id != userId || ride.status != "RESERVED" {
            return <http:BadRequest>{body: {message: "This ride cannot be canceled."}};
        }
        decimal basePrice = ps:BASE_PRICE;
        _ = check repository:updateRide(rideId, {status: repository:CANCELLED, price: basePrice});
        _ = check bsc:releaseBike(Authorization, ride.bike_id, endLocation = ride.start_location);

        types:RideCancelEvent cancelEvent = {
        bike_id: ride.bike_id,
        ride_id: ride.ride_id,
        user_id: ride.user_id,
        start_location: ride.start_location,
        price: basePrice
        };
        check event_handler:produceCancelEvent(cancelEvent);

        log:printInfo(`Ride ${rideId} canceled by user ${userId}.`);
        return <http:Ok>{body: {message: "Ride reservation has been canceled.", price: basePrice}};
    }

    resource function get getRide(string rideId) returns http:Ok|http:NotFound|error {
        repository:Ride? ride = check repository:getRideById(rideId);
        if ride is () {
            return <http:NotFound>{body: types:RIDE_NOT_FOUND};
        }
        return <http:Ok>{body: ride};
    }

    resource function get getActiveRide(@http:Header string Authorization) returns
        http:Ok|http:NotFound|http:BadRequest|error {
        Claims claims = check extractClaims(Authorization);
        string userId;
        if claims.userId is string {
            userId = <string>claims.userId;
        } else {
            return <http:BadRequest>{body: "Invalid Token"};
        }

        repository:Ride[]? ride = check repository:getActiveRidesByUserId(userId);
        if ride is () {
            return <http:NotFound>{body: types:RIDE_NOT_FOUND};
        } else if (ride.length() > 1) {
            return <http:BadRequest>{body: types:MULTIPLE_RIDE_ACTIVE};
        } else {
            return <http:Ok>{body: ride};
        }
    }
}

service /rides on new websocket:Listener(27751) {

    function init() {
        io:println("Websocket Initalized.");
    }

    resource function get .(string rideId) returns websocket:Service|websocket:UpgradeError {
        repository:Ride?|error ride = repository:getRideById(rideId);
        if ride is error {
            return error(ride.message());
        }
        if ride is () {
            return error("Ride not found");
        }
        if ride.status != "IN_PROGRESS" && ride.status != "RESERVED" {
            return error("Ride is not in progess");
        }
        return new RidePricingService(rideId);
    }
}

service class RidePricingService {
    *websocket:Service;

    private final string rideId;

    function init(string rideId) {
        self.rideId = rideId;
    }

    remote function onOpen(websocket:Caller caller) {
        lock {
            rideConnections[self.rideId] = caller;
        }

        log:printInfo(string `Client connected for ride ${self.rideId} price tracking`);
    }

    remote function onClose(websocket:Caller caller, int statusCode, string reason) {
        lock {
            _ = rideConnections.remove(self.rideId);
        }
        log:printInfo(string `Client disconnected from ride ${self.rideId}, reason: ${reason}`);
    }

    remote function onError(websocket:Caller caller, error err) {
        lock {
            _ = rideConnections.remove(self.rideId);
        }
        log:printError(string `WebSocket error for ride ${self.rideId}: `, err);
    }

    remote function onTextMessage(websocket:Caller caller, string text) {
        log:printInfo(string `Ride update received from client ${self.rideId}`);

        json|error parsed = checkpanic text.fromJsonString();
        if parsed is json {
            types:ClientUpdatePayload|error payload = parsed.cloneWithType(types:ClientUpdatePayload);
            if payload is types:ClientUpdatePayload {
                decimal currentPrice = ps:calculatePrice(
                        payload.duration_seconds,
                        <int>payload.distance_meters
                );

                types:ServerPriceUpdatePayload response = {
                    current_price: currentPrice.round(2)
                };
                error? writeResult = caller->writeMessage(response);
                if writeResult is error {
                    log:printError("Failed to push price update", writeResult);
                }
            } else {
                log:printWarn(string `Invalid payload received for ride ${self.rideId}`);
            }
        } else {
            log:printWarn(string `Failed to parse message as JSON for ride ${self.rideId}`);
        }
    }
}

public function extractClaims(string authHeader) returns Claims|error {
    int? index = authHeader.indexOf("Bearer ");
    if index is () {
        return error("Invalid Authorization header format");
    }

    string jwtString = authHeader.substring(index + 7);

    var decoded = jwt:decode(jwtString);
    if decoded is [jwt:Header, jwt:Payload] {
        jwt:Payload payload = decoded[1];
        Claims claims = {role: (), userId: (), email: ()};

        // Extract userId
        if payload["userId"] is string {
            claims.userId = payload["userId"].toString();
        }

        // Extract email
        if payload["sub"] is string {
            claims.email = payload["sub"];
        }

        // Extract scopes
        if (payload["scp"] is string) {
            claims.role = payload["scp"].toString();
        }

        return claims;
    } else if decoded is jwt:Error {
        return error("JWT decode failed: " + decoded.toString());
    }
}
