// AUTO-GENERATED FILE. DO NOT MODIFY.

// This file is an auto-generated file by Ballerina persistence layer for model.
// It should not be modified by hand.

import ballerina/time;

public enum Status {
    PENDING,
    RESERVED,
    IN_PROGRESS,
    CANCELLED,
    ENDED,
    FAILED
}

public type Ride record {|
    readonly string ride_id;
    string user_id;
    string bike_id;
    time:Utc? start_time;
    time:Utc? end_time;
    Status status;
    float? distance;
    int? duration;
    string start_location;
    string? end_location;
    decimal? price;
|};

public type RideOptionalized record {|
    string ride_id?;
    string user_id?;
    string bike_id?;
    time:Utc? start_time?;
    time:Utc? end_time?;
    Status status?;
    float? distance?;
    int? duration?;
    string start_location?;
    string? end_location?;
    decimal? price?;
|};

public type RideTargetType typedesc<RideOptionalized>;

public type RideInsert Ride;

public type RideUpdate record {|
    string user_id?;
    string bike_id?;
    time:Utc? start_time?;
    time:Utc? end_time?;
    Status status?;
    float? distance?;
    int? duration?;
    string start_location?;
    string? end_location?;
    decimal? price?;
|};

