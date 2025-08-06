import ride_service.types;

import ballerina/log;
import ballerinax/kafka;

configurable string SERVER_URL = kafka:DEFAULT_URL;
configurable string RIDE_RESERVE_TOPIC = ?;
configurable string RIDE_START_TOPIC = ?;
configurable kafka:ProducerConfiguration producerConfiguration = ?;

final kafka:Producer rideProducer;

function init() returns error? {
    rideProducer = check new (SERVER_URL, producerConfiguration);
    log:printInfo("Kafka Ride Event Producer Started.");
}

public isolated function produceReserveEvent(types:RideReserveEvent newRideEvent) returns error? {
    check rideProducer->send({
        topic: RIDE_RESERVE_TOPIC,
        key: newRideEvent.ride_id.toBytes(),
        value: newRideEvent.toJsonString().toBytes()
    });
}

public isolated function produceStartEvent(types:RideStartEvent newRideEvent) returns error? {
    check rideProducer->send({
        topic: RIDE_START_TOPIC,
        key: newRideEvent.ride_id.toBytes(),
        value: newRideEvent.toJsonString().toBytes()
    });
}
