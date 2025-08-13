import ride_service.bike_service_client as bsc;
import ride_service.event_handler;
import ride_service.repository;
import ride_service.types;
import ride_service.user_service_client as usc;

import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerina/time;
import ballerina/uuid;
import ballerina/websocket;

configurable int PORT = ?;

final map<websocket:Caller> rideConnections = {};

service / on new http:Listener(PORT) {

    function init() {
        log:printInfo(`The Ride Service Initiated on Port: ${PORT}`);
    }

    resource function post reserveRide(http:RequestContext ctx, string bikeId, string startLocation) returns http:Accepted|http:BadRequest|error {
        string userId = "user-001"; // Assumes we get use ID with http header or user service
        boolean isCapable = check usc:userCapability(userId);
        if isCapable is false {
            return <http:BadRequest>{
                body: types:USER_NOT_CAPABLE
            };
        }

        string rideId = uuid:createType4AsString();
        boolean isSuccess = check bsc:reserveBike(bikeId);
        if isSuccess is false {
            return <http:BadRequest>{
                body: types:BIKE_NOT_AVAILABLE
            };
        }

        repository:RideInsert newRide = {
            bike_id: bikeId,
            ride_id: rideId,
            user_id: userId,
            start_time: (),
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

    resource function post rides/[string rideId]/startRide() returns http:Ok|http:BadRequest|http:NotFound|error {
        string userId = "user-001";

        repository:Ride? ride = check repository:getRideById(rideId);
        if ride is () {
            return <http:NotFound>{body: {message: "Ride with ID not found.", rideId: rideId}};
        }

        if (ride.user_id != userId || ride.status != repository:RESERVED) {
            return <http:BadRequest>{body: {message: "Invalid request."}};
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

    resource function post rides/[string rideId]/end(types:EndRideRequest endRequest) returns http:Ok|http:BadRequest|http:NotFound|error {
        string userId = "user-001"; // TODO: Get userId from JWT

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
        // call reward service to calculate price and reward
        // decimal price = self.calculatePrice(durationInSeconds);
        decimal price = 1000.00;

        repository:RideUpdate rideUpdate = {
            end_time: endTime,
            duration: durationInSeconds,
            distance: endRequest.distance,
            end_location: endRequest.end_location,
            status: repository:ENDED,
            price: price
        };
        _ = check repository:updateRide(rideId, rideUpdate);

        // boolean paymentSuccess = check psc:processPayment(userId, rideId, price);
        boolean paymentSuccess = true;
        if !paymentSuccess {
            log:printError("Payment failed for ride " + rideId);
            // handle the debt
        }

        check bsc:releaseBike(ride.bike_id);

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

    resource function get getRide(string rideId) returns http:Ok|http:NotFound|error {
        repository:Ride? ride = check repository:getRideById(rideId);
        if ride is () {
            return <http:NotFound>{body: types:RIDE_NOT_FOUND};
        }
        return <http:Ok>{body: ride};
    }

    resource function get getActiveRide(http:RequestContext ctx) returns
        http:Ok|http:NotFound|http:BadRequest|error {

        string userId = "user-001";
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

service /rides on new websocket:Listener(27750) {

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
        if ride.status != "IN_PROGRESS" {
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
                // Calculate price using reward service here
                decimal currentPrice = 0.0;

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
