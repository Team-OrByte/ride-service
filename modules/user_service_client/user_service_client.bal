import ride_service.types;

import ballerina/cache;
import ballerina/http;
import ballerina/log;

configurable types:HttpClientConfig userServiceClient = ?;
configurable cache:CacheConfig userCapabilityCacheConfig = ?;

final http:Client httpClient = check new (userServiceClient.url,
    timeout = userServiceClient.timeout,
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
final cache:Cache userCapabilityCache = new (userCapabilityCacheConfig);

public isolated function userCapability(string userId) returns boolean|error {
    if userCapabilityCache.hasKey(userId) {
        any cachedValue = check userCapabilityCache.get(userId);
        if cachedValue is boolean {
            log:printInfo("Cache hit for user capability", userId = userId);
            return cachedValue;
        }
    }

    log:printInfo("Calling user service... Cache miss for user capability", userId = userId);
    boolean|error capability = httpClient->/api/checkCapability.post(message = (), userId = userId);

    if capability is error {
        if userCapabilityCache.hasKey(userId) {
            log:printWarn("User service down, falling back to cached capability", userId = userId);
            any cachedValue = check userCapabilityCache.get(userId);
            if cachedValue is boolean {
                return cachedValue;
            }
        }
        return error(string `Error checking user capability for User ID: ${userId}`);
    } else {
        check userCapabilityCache.put(userId, capability);
        log:printInfo("User Capability cached.", userId = userId);
        return capability;
    }
}

//Note: Should utilize this function in the case of something changed for user in user service that affects the capability
public isolated function invalidateCapabilityCache(string userId) returns error? {
    boolean result = userCapabilityCache.hasKey(userId);
    if result is true {
        log:printDebug("Invalidating user capability cache", userId = userId);
        check userCapabilityCache.invalidate(userId);
    }
}
