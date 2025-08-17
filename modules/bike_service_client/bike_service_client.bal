import ride_service.types;

import ballerina/http;

type Response record {
    int statusCode;
    string message?;
    anydata data?;
};

configurable types:HttpClientConfig bikeServiceClient = ?;

final http:Client httpClient = check new (bikeServiceClient.url, timeout = bikeServiceClient.timeout);

public isolated function reserveBike(string bikeId) returns boolean|error {
    Response|error payload = httpClient->/reserve\-bike/[bikeId].put(message = {});

    if payload is error {
        return error(string `Error reserving bike with Bike ID: ${bikeId}`);
    }

    if (payload.statusCode) == http:STATUS_OK {
        return true;
    } else {
        return false;
    }
}

public isolated function releaseBike(string bikeId, string endLocation) returns error? {
    Response|error payload = httpClient->/release\-bike/[bikeId].put(message = {}, endLocation = endLocation);

    if payload is error {
        return error(string `Error releasing bike with Bike ID: ${bikeId}`);
    }

    if (payload.statusCode) == http:STATUS_OK {
        return;
    }
}
