import ballerina/log;
import ballerinax/kafka;

configurable string SERVER_URL = kafka:DEFAULT_URL;
configurable string RIDE_NOTIF_EVENTS_TOPIC = ?;
configurable string PAYMENT_EVENTS_TOPIC = ?;
configurable kafka:ProducerConfiguration producerConfiguration = ?;

final kafka:Producer rideProducer;

function init() returns error? {
    rideProducer = check new (SERVER_URL, producerConfiguration);
    log:printInfo("Kafka Ride Event Producer Started.");
}

public isolated function produceRideNotifEvent(anydata newRideEvent, string userId) {
    kafka:Error? result = rideProducer->send({
        topic: RIDE_NOTIF_EVENTS_TOPIC,
        key: userId.toBytes(),
        value: newRideEvent.toJson()
    });
    if result is kafka:Error {
        log:printError("Error occured while publishing ride notification event.", err = result.message());
    }
    log:printInfo("Ride notif event published", event = newRideEvent.toJsonString());
}

public isolated function producePaymentEvent(anydata newRideEvent, string userId) {
    kafka:Error? result = rideProducer->send({
        topic: PAYMENT_EVENTS_TOPIC,
        key: userId.toBytes(),
        value: newRideEvent.toJson()
    });
    if result is kafka:Error {
        log:printError("Error occured while publishing payment event.", err = result.message());
    }
    log:printInfo("Payment event published", event = newRideEvent.toJsonString());
}