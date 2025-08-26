import ride_service.types;

import ballerina/http;
import ballerina/log;

public type RewardPointsRequest record {|
    string rideId;
    int timestamp;
    float distance;
    float time;
    string startFrom;
    string stopAt;
    string userId;
|};

configurable types:HttpClientConfig rewardServiceClient = ?;

final http:Client httpClient = check new (rewardServiceClient.url, timeout = rewardServiceClient.timeout);

public isolated function rewardPoints(RewardPointsRequest request, @http:Header string Authorization) returns http:Response|error {
    http:Response|error payload = check httpClient->/rewardPoints.post(message = request, headers = {"Authorization": Authorization});
    if payload is error {
        log:printInfo(string `Assign reward point for the ride failed for Ride ID: ${request.rideId}`, payload = payload.message());
        return error(string `Error assign reward points: ${request.rideId}`);
    }
    return payload;
}
