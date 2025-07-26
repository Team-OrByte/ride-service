final Client sClient = check new();

public isolated function insertRide(RideInsert rideInsert) returns string[]|error {
    string[]|error created = sClient->/rides.post([rideInsert]);
    return created;
}

public isolated function changeRideStatus(string ride_id, Status rideStatus) returns Ride|error {
    Ride|error updated = sClient->/rides/ride_id.put({status: rideStatus});
    return updated;
}