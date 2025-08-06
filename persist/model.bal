import ballerina/persist as _;
import ballerina/time;
import ballerinax/persist.sql;

@sql:Name {value: "ride"}
type Ride record {|
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
    @sql:Decimal {precision: [10, 2]}
    decimal? price;
|};

enum Status {
    RESERVED,
    IN_PROGRESS,
    PAUSED,
    ENDED
}
