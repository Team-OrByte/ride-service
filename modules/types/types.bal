public type RideRequestEvent record {|
    string bike_id;
    string user_id;
    string ride_id;
|};

public type HttpClientConfig record {|
    string url;
    decimal timeout;
|};