import ballerina/persist;

final Client sClient = check new ();

public isolated function insertRide(RideInsert rideInsert) returns string[]|error {
    string[]|error created = sClient->/rides.post([rideInsert]);
    return created;
}

public isolated function changeRideStatus(string ride_id, Status rideStatus) returns Ride|error {
    Ride|error updated = sClient->/rides/ride_id.put({status: rideStatus});
    return updated;
}

public isolated function getRideById(string rideId) returns Ride?|error {
    Ride|error result = sClient->/rides/[rideId];
    if result is Ride {
        return result;
    } else if result is persist:NotFoundError {
        return ();
    } else {
        return result;
    }
}

public isolated function updateRide(string rideId, RideUpdate rideUpdate) returns Ride|error {
    Ride ride = check sClient->/rides/[rideId].put(rideUpdate);
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
            check rideStream.close();
            return nextResult;
        } else {
            check rideStream.close();
            break;
        }
    }

    return rides.length() > 0 ? rides : ();
}