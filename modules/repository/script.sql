-- AUTO-GENERATED FILE.

-- This file is an auto-generated file by Ballerina persistence layer for model.
-- Please verify the generated scripts and execute them against the target DB server.

DROP TABLE IF EXISTS "ride";

CREATE TABLE "ride" (
	"ride_id" VARCHAR(191) NOT NULL,
	"user_id" VARCHAR(191) NOT NULL,
	"bike_id" VARCHAR(191) NOT NULL,
	"start_time" TIMESTAMP NOT NULL,
	"end_time" TIMESTAMP,
	"status" VARCHAR(11) CHECK ("status" IN ('RESERVED', 'IN_PROGRESS', 'PAUSED', 'ENDED')) NOT NULL,
	"distance" FLOAT NOT NULL,
	"duration" INT NOT NULL,
	"start_location" VARCHAR(191) NOT NULL,
	"end_location" VARCHAR(191) NOT NULL,
	"price" DECIMAL(10,2) NOT NULL,
	PRIMARY KEY("ride_id")
);


