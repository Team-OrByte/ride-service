final Client sClient = check new();

public isolated function insertRide(RideInsert rideInsert) returns string[]|error {
    string[]|error created = sClient->/rides.post([rideInsert]);
    return created;
}

public isolated function changeRideStatus(string ride_id, Status rideStatus) returns Ride|error {
    Ride|error updated = sClient->/rides/ride_id.put({status: rideStatus});
    return updated;
}

public isolated function getRideById(string rideId) returns Ride|error {
    Ride ride = check sClient->/rides/[rideId];
    return ride;
} 

public isolated function updateRide(string rideId, RideUpdate rideUpdate) returns Ride|error {
    Ride ride = check sClient->/rides/[rideId].put(rideUpdate);
    return ride;
}