import ballerina/log;
import ballerina/persist;

final Client sClient = check new ();

public isolated function insertRide(RideInsert rideInsert) returns string[]|error {
    string[]|persist:Error created = sClient->/rides.post([rideInsert]);
    if created is persist:Error {
        log:printError("Failed to insert ride", rideId = rideInsert.ride_id, err = created.message());
        return error(string `Insert failed for ride ${rideInsert.ride_id}`);
    }
    return created;
}

public isolated function changeRideStatus(string rideId, Status rideStatus) returns Ride|error {
    Ride|persist:Error updated = sClient->/rides/ride_id.put({status: rideStatus});
    if updated is persist:Error {
        log:printError("Failed to change ride status", rideId = rideId, status = rideStatus, err = updated.message());
        return error(string `Update failed for ride ${rideId}`);
    }
    return updated;
}

public isolated function getRideById(string rideId) returns Ride?|error {
    Ride|persist:Error result = sClient->/rides/[rideId];
    if result is Ride {
        return result;
    } else if result is persist:NotFoundError {
        return ();
    } else {
        log:printError("Failed to fetch ride", rideId = rideId, err = result.message());
        return result;
    }
}

public isolated function updateRide(string rideId, RideUpdate rideUpdate) returns Ride|error {
    Ride|persist:Error ride = check sClient->/rides/[rideId].put(rideUpdate);
    if ride is persist:Error {
        log:printError("Failed to update ride", rideId = rideId, err = ride.message());
        return error(string `Update failed for ride ${rideId}`);
    }
    return ride;
}

public isolated function getActiveRidesByUserId(string userId) returns Ride[]?|error {
    stream<Ride, persist:Error?> rideStream = sClient->
        queryNativeSQL(
            `SELECT * FROM ride WHERE user_id = ${userId} AND status IN ('IN_PROGRESS','RESERVED');`,
            Ride
        );
    Ride[] rides = [];

    while true {
        (record {|Ride value;|}|persist:Error)? nextResult = rideStream.next();

        if nextResult is record {|Ride value;|} {
            rides.push(nextResult.value);
        } else if nextResult is persist:NotFoundError {
            check rideStream.close();
            break;
        } else if nextResult is persist:Error {
            log:printError("Error while streaming rides", userId = userId, err = nextResult.message());
            check rideStream.close();
            return nextResult;
        } else {
            check rideStream.close();
            break;
        }
    }

    return rides.length() > 0 ? rides : ();
}
