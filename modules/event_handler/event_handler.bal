import ride_service.types;

import ballerina/log;
import ballerinax/kafka;

configurable string SERVER_URL = kafka:DEFAULT_URL;
configurable string RIDE_RESERVE_TOPIC = ?;
configurable string RIDE_START_TOPIC = ?;
configurable string RIDE_END_TOPIC = ?;
configurable string RIDE_CANCEL_TOPIC = ?;
configurable kafka:ProducerConfiguration producerConfiguration = ?;

final kafka:Producer rideProducer;

function init() returns error? {
    rideProducer = check new (SERVER_URL, producerConfiguration);
    log:printInfo("Kafka Ride Event Producer Started.");
}

public isolated function produceReserveEvent(types:RideReserveEvent newRideEvent) returns error? {
    check produceRideEvent(RIDE_RESERVE_TOPIC, newRideEvent, newRideEvent.ride_id);
}

public isolated function produceStartEvent(types:RideStartEvent newRideEvent) returns error? {
    check produceRideEvent(RIDE_START_TOPIC, newRideEvent, newRideEvent.ride_id);
}

public isolated function produceEndEvent(types:RideEndEvent newRideEvent) returns error? {
    check produceRideEvent(RIDE_END_TOPIC, newRideEvent, newRideEvent.ride_id);
}

public isolated function produceCancelEvent(types:RideCancelEvent newRideEvent) returns error? {
    check produceRideEvent(RIDE_CANCEL_TOPIC, newRideEvent, newRideEvent.ride_id);
}

isolated function produceRideEvent(string topic, anydata newRideEvent, string rideId) returns error? {
    check rideProducer->send({
        topic: topic,
        key: rideId.toBytes(),
        value: newRideEvent.toJsonString().toBytes()
    });
}