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
configurable int WEBSOCKET_PORT = ?;
configurable string pub_key = ?;

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
service /ride\-service on new http:Listener(PORT) {

    function init() {
        log:printInfo(`The Ride Service Initiated on Port: ${PORT}`);
    }

    resource function post reserveRide(@http:Header string Authorization, string bikeId, string startLocation) returns http:Accepted|http:BadRequest|http:InternalServerError|error {
        string? userId = check getUserIdFromHeader(Authorization);
        if userId is null {
            return <http:BadRequest>{body: "Invalid Token"};
        }

        boolean|error userCap = usc:userCapability(userId, Authorization);
        if userCap is error {
            log:printError("User capability check failed", err = userCap.message());
            return <http:InternalServerError>{body: "User Service Unavailable"};
        }
        if !userCap {
            return <http:BadRequest>{body: types:USER_NOT_CAPABLE};
        }

        string rideId = uuid:createType4AsString();
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
            status: repository:PENDING,
            price: ()
        };
        string[]|error insertResult = repository:insertRide(newRide);
        if insertResult is error {
            log:printError("Failed to insert ride", rideId = rideId, err = insertResult.message());
            return <http:InternalServerError>{body: "Failed to reserve ride"};
        }
        log:printInfo(`Ride ${rideId} inserted with PENDING status`);

        boolean|error bikeresult = bsc:reserveBike(bikeId, Authorization);
        if bikeresult is error {
            _ = check repository:updateRide(rideId, {status: repository:FAILED});
            return <http:InternalServerError>{body: "Bike reservation failed. Ride marked as FAILED."};
        }
        if bikeresult is false {
            return <http:BadRequest>{
                body: types:BIKE_NOT_AVAILABLE
            };
        }
        log:printInfo(`Bike ${bikeId} reserved successfully`);

        repository:Ride|error updateRideResult = repository:updateRide(rideId, {status: repository:RESERVED});
        if updateRideResult is error {
            // Punlish release as event
            _ = check bsc:releaseBike(Authorization, bikeId, startLocation);
            _ = check repository:updateRide(rideId, {status: repository:FAILED});
            return <http:InternalServerError>{body: "Failed to mark ride as RESERVED. Bike released."};
        }
        log:printInfo(`Ride ${rideId} updated to RESERVED`);

        return <http:Accepted>{
            body: {
                message: "You can start the ride.",
                rideId: rideId
            }
        };
    }

    resource function post rides/[string rideId]/startRide(@http:Header string Authorization) returns http:Ok|http:BadRequest|http:NotFound|http:InternalServerError|error {
        string? userId = check getUserIdFromHeader(Authorization);
        if userId is null {
            return <http:BadRequest>{body: "Invalid Token"};
        }

        repository:Ride?|error ride = check repository:getRideById(rideId);
        if ride is error {
            return <http:InternalServerError>{body: string `Failed to fetch ${rideId} from DB`};
        }
        if ride is () {
            return <http:NotFound>{body: {message: types:RIDE_NOT_FOUND}};
        }
        if (ride.user_id != userId || ride.status != repository:RESERVED) {
            return <http:BadRequest>{body: types:INVALID_RIDE_START_REQUEST};
        }

        time:Utc startTime = time:utcNow();
        repository:RideUpdate rideUpdate = {
            status: repository:IN_PROGRESS,
            start_time: startTime
        };
        _ = check repository:updateRide(rideId, rideUpdate);

        types:RideStartedData rideStartedData = {
            bikeId: ride.bike_id,
            startStation: ride.start_location
        };
        types:Event notifEvent = {
            userId: userId,
            eventType: types:RIDE_STARTED,
            data: rideStartedData
        };
        event_handler:produceRideNotifEvent(notifEvent, notifEvent.userId);

        log:printInfo(`Ride ${rideId} started by user ${userId}.`);
        return <http:Ok>{body: {message: "Ride started successfully."}};
    }

    resource function post rides/[string rideId]/end(@http:Header string Authorization, types:EndRideRequest endRequest) returns http:Ok|http:BadRequest|http:NotFound|http:InternalServerError|error {
        string? userId = check getUserIdFromHeader(Authorization);
        if userId is null {
            return <http:BadRequest>{body: "Invalid Token"};
        }

        repository:Ride?|error ride = repository:getRideById(rideId);
        if ride is error {
            return <http:InternalServerError>{body: string `Failed to fetch ${rideId} from DB`};
        }
        if ride is () || ride.start_time is () {
            return <http:NotFound>{body: {message: "Ride not found or not started.", rideId: rideId}};
        }

        if ride.user_id != userId || ride.status != "IN_PROGRESS" {
            return <http:BadRequest>{body: {message: "Ride cannot be ended. Invalid state or ownership."}};
        }

        time:Utc endTime = time:utcNow();
        int durationInSeconds = <int>time:utcDiffSeconds(endTime, <time:Utc>ride.start_time);
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

        // should publish this as event
        _ = check bsc:releaseBike(Authorization, ride.bike_id, endRequest.end_location);

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
            // should publish this as event
            _ = check rsc:rewardPoints(rewardRequest, Authorization);
        }

        types:PaymentEvent paymentEvent = {
            rideId: rideId,
            userId: userId,
            fare: price.toString()
        };
        event_handler:producePaymentEvent(paymentEvent, userId);

        types:RideEndedData rideEndedData = {
            bikeId: ride.bike_id,
            duration: durationInSeconds.toString(),
            fare: price.toString()
        };
        types:Event notifEvent = {
            userId: userId,
            eventType: types:RIDE_ENDED,
            data: rideEndedData
        };
        event_handler:produceRideNotifEvent(notifEvent, notifEvent.userId);

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

    resource function post rides/[string rideId]/cancel(@http:Header string Authorization) returns http:Ok|http:BadRequest|http:NotFound|http:InternalServerError|error {
        string? userId = check getUserIdFromHeader(Authorization);
        if userId is null {
            return <http:BadRequest>{body: "Invalid Token"};
        }

        repository:Ride?|error ride = repository:getRideById(rideId);
        if ride is error {
            return <http:InternalServerError>{body: string `Failed to fetch ${rideId} from DB`};
        }
        if ride is () {
            return <http:NotFound>{body: types:RIDE_NOT_FOUND};
        }

        if ride.user_id != userId || ride.status != "RESERVED" {
            return <http:BadRequest>{body: {message: "This ride cannot be canceled."}};
        }

        int durationInSeconds = <int>time:utcDiffSeconds(time:utcNow(), <time:Utc>ride.start_time);
        decimal price = ps:calculatePrice(durationInSeconds, 0);

        repository:Ride|error updatedRide = repository:updateRide(rideId, {status: repository:CANCELLED, price: price});
        if updatedRide is error {
            return <http:InternalServerError>{body: "Failed to cancel ride in DB"};
        }

        types:PaymentEvent paymentEvent = {
            rideId: rideId,
            userId: userId,
            fare: price.toString()
        };
        event_handler:producePaymentEvent(paymentEvent, userId);

        //update this as an event
        _ = check bsc:releaseBike(Authorization, ride.bike_id, endLocation = ride.start_location);

        log:printInfo(`Ride ${rideId} canceled by user ${userId}.`);
        return <http:Ok>{body: {message: "Ride reservation has been canceled.", price: price}};
    }

    // This should be admin endpoint
    resource function get getRide(string rideId) returns http:Ok|http:NotFound|error {
        repository:Ride? ride = check repository:getRideById(rideId);
        if ride is () {
            return <http:NotFound>{body: types:RIDE_NOT_FOUND};
        }
        return <http:Ok>{body: ride};
    }

    resource function get getActiveRide(@http:Header string Authorization) returns
        http:Ok|http:NotFound|http:BadRequest|error {
        string? userId = check getUserIdFromHeader(Authorization);
        if userId is null {
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

service /rides on new websocket:Listener(WEBSOCKET_PORT) {

    function init() {
        io:println("Websocket Initalized for ride pricing.");
    }

    resource function get .(string rideId, http:Request req) returns websocket:Service|websocket:UpgradeError {
        string? token = req.getQueryParamValue("token");
        if token is () {
            return error("Missing token");
        }
        jwt:ValidatorConfig validatorConfig = {
            issuer: "Orbyte",
            audience: "vEwzbcasJVQm1jVYHUHCjhxZ4tYa",
            signatureConfig: {
                certFile: pub_key
            }
        };
        jwt:Payload|error payload = jwt:validate(token, validatorConfig);
        if payload is error {
            return error("JWT validation error : ", payload);
        }

        repository:Ride?|error ride = repository:getRideById(rideId);
        if ride is error {
            return error(ride.message());
        }
        if ride is () {
            return error("Ride not found");
        }
        if ride.status != "IN_PROGRESS" && ride.status != "RESERVED" {
            return error("Ride is not in progress or reserved");
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
