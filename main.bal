import ballerina/http;
import ballerina/time;

public type Country record {
    string name;
    string continent;
    int population;
    decimal gdp;
    decimal area;
};

type RideRequest readonly & record {|
    string bike_id;
    string user_id;
    string start_time;
    string start_station;
|};

final http:Client countriesClient = check new ("https://dev-tools.wso2.com/gs/helpers/v1.0/");
final Client sClient = check new ();

service / on new http:Listener(8080) {

    resource function post ride() returns string[]|error {
        RideInsert rideInsert = {
            "ride_id": "ride-12345",
            "user_id": "user-12345",
            "bike_id": "bike-67890",
            "start_time": time:utcNow(),
            "end_time": time:utcNow(),
            "status": RESERVED,
            "distance": 4.8,
            "duration": 25,
            "start_location": "Zone-A",
            "end_location": "Zone-B",
            "price": 36.75
        };
        string[]|error success = sClient->/rides.post([rideInsert]);

        return success;
    }
}
