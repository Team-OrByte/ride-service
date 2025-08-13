import ballerina/time;

public type HttpClientConfig record {|
    string url;
    decimal timeout;
|};

public type RideReserveEvent record {|
    string ride_id;
    string user_id;
    string bike_id;
    string start_location;
|};

public type RideStartEvent record {|
    string ride_id;
    string user_id;
    string bike_id;
    time:Utc start_time;
|};

public type EndRideRequest record {|
    string end_location;
    float distance;
|};

public type ClientUpdatePayload record {|
    int duration_seconds;
    float distance_meters;
|};

public type ServerPriceUpdatePayload record {|
    decimal current_price;
|};

public type ErrorResponse record {|
    string code;
    string message;
|};

public const ErrorResponse START_TIME_NULL = {
    code: "RSC-001",
    message: "Start time is null"
};

public const ErrorResponse RIDE_NOT_FOUND = {
    code: "RSC-002",
    message: "Ride is not found"
};

public const ErrorResponse MULTIPLE_RIDE_ACTIVE = {
    code: "RSC-003",
    message: "There is more than one ride in reserved or in progress status"
};

public const ErrorResponse USER_NOT_CAPABLE = {
    code: "RSC-004",
    message: "User is not capable"
};

public const ErrorResponse BIKE_NOT_AVAILABLE = {
    code: "RSC-005",
    message: "Bike is not available"
};

public ErrorResponse INVALID_RIDE_START_REQUEST = {
    code: "RSC-006",
    message: "Ride cannot be started. Invalid state or ownership."
};