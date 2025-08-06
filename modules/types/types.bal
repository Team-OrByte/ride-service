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