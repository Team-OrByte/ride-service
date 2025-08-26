import ride_service.types;

import ballerina/http;
import ballerina/log;

type Response record {
    int statusCode;
    string message?;
    anydata data?;
};

configurable types:HttpClientConfig bikeServiceClient = ?;

final http:Client httpClient = check new (bikeServiceClient.url,
    timeout = bikeServiceClient.timeout,
    circuitBreaker = {
        rollingWindow: {timeWindow: 10, bucketSize: 2, requestVolumeThreshold: 0},
        failureThreshold: 0.5,
        resetTime: 30,
        statusCodes: [500]
    },
    retryConfig = {
        count: 3,
        interval: 3,
        backOffFactor: 2.0,
        maxWaitInterval: 20
    }
);

public isolated function reserveBike(string bikeId, @http:Header string Authorization) returns boolean|error {
    Response|error payload = httpClient->/reserve\-bike/[bikeId].put(message = {}, headers = {"Authorization": Authorization});

    if payload is error {
        log:printInfo(string `Bike reservation failed for Bike ID: ${bikeId}`, payload = payload.message());
        return error(string `Error reserving bike: ${bikeId}`);
    }

    if (payload.statusCode) == http:STATUS_OK {
        log:printInfo(string `Bike successfully reserved: ${bikeId}`);
        return true;
    }
    log:printWarn(string `Bike reservation rejected. Bike ID: ${bikeId}, Status: ${payload.statusCode}`);
    return false;
}

public isolated function releaseBike(@http:Header string Authorization, string bikeId, string endLocation) returns error? {
    Response|error payload = httpClient->/release\-bike/[bikeId].put(message = {}, endLocation = endLocation, headers = {"Authorization": Authorization});

    if payload is error {
        log:printError(string `Bike release failed for Bike ID: ${bikeId}`, payload = payload.message());
        return error(string `Error releasing bike: ${bikeId}`);
    }

    if (payload.statusCode) == http:STATUS_OK {
        log:printInfo(string `Bike successfully released: ${bikeId} at ${endLocation}`);
        return;
    }
    log:printWarn(string `Bike release rejected. Bike ID: ${bikeId}, Status: ${payload.statusCode}`);
    return error(string `Release failed. Status code: ${payload.statusCode}`);
}
