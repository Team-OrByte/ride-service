import ride_service.bike_service_client as bsc;
import ride_service.repository;
import ride_service.user_service_client as usc;
import ride_service.event_handler;

import ballerina/http;
import ballerina/log;
import ballerina/time;
import ballerina/uuid;

configurable int PORT = ?;

service / on new http:Listener(PORT) {

    function init() {
        log:printInfo(`The Ride Service Initiated on Port: ${PORT}`);
    }

    resource function post startRide(http:RequestContext ctx, string bikeId) returns http:Accepted|http:BadRequest|error {
        string userId = "user-001"; // Assumes we get use ID with http header or user service
        boolean isCapable = check usc:userCapability(userId);
        if isCapable is false {
            return <http:BadRequest>{
                body: {
                    message: "User is not capable at the moment."
                }
            };
        }

        string rideId = uuid:createType4AsString();
        boolean isSuccess = check bsc:reserveBike(bikeId, userId, rideId);
        if isSuccess is false {
            return <http:BadRequest>{
                body: {
                    message: "Bike is not available at the moment."
                }
            };
        }

        repository:RideInsert newRide = {
            bike_id: bikeId,
            ride_id: rideId,
            user_id: userId,
            start_time: time:utcNow(),
            end_time: (),
            duration: 0,
            distance: 0.0,
            start_location: "START",
            end_location: "END",
            status: "RESERVED",
            price: 0
        };
        _ = check repository:insertRide(newRide);

        check event_handler:produce(newRide);

        return <http:Accepted>{
            body: {
                message: "You can start the ride.",
                rideId: rideId
            }
        };
    }
}
