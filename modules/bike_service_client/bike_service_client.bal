import ride_service.types;

import ballerina/http;

configurable types:HttpClientConfig bikeServiceClient = ?;

final http:Client httpClient = check new (bikeServiceClient.url, timeout = bikeServiceClient.timeout);

public isolated function reserveBike(string bikeId, string userId, string rideId) returns boolean|error {
    boolean|error avalability = httpClient->/api/reserve.post(message = (), bikeId = bikeId);

    if avalability is error {
        return error(string `Error reserving bike with Bike ID: ${bikeId}`);
    } else {
        return avalability;
    }
}

public isolated function releaseBike(string bikeId, string userId, string rideId) returns error? {
    //check httpClient->/api/release.post(message = (), bikeId = bikeId);
}
