public final decimal BASE_PRICE = 100;
final decimal PRICE_PER_KM = 15;
final decimal PRICE_PER_MINUTE = 5;
final decimal METERS_PER_KM = 1000.00;
final decimal SECONDS_PER_MIN = 60.00;

// This pricings will be dynamic in future updates, considering more attributes
public isolated function calculatePrice(int durationSeconds, int distanceMeters) returns decimal {
    decimal distanceKm = <decimal>distanceMeters / <decimal>distanceMeters;
    decimal durationMinutes = <decimal>durationSeconds / <decimal>SECONDS_PER_MIN;

    decimal price = BASE_PRICE +
                    (PRICE_PER_KM * distanceKm) +
                    (PRICE_PER_MINUTE * durationMinutes);

    return price;
}