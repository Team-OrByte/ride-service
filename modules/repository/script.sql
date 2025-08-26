-- AUTO-GENERATED FILE.

-- This file is an auto-generated file by Ballerina persistence layer for model.
-- Please verify the generated scripts and execute them against the target DB server.

DROP TABLE IF EXISTS "ride";

CREATE TABLE "ride" (
	"ride_id" VARCHAR(191) NOT NULL,
	"user_id" VARCHAR(191) NOT NULL,
	"bike_id" VARCHAR(191) NOT NULL,
	"start_time" TIMESTAMP,
	"end_time" TIMESTAMP,
	"status" VARCHAR(11) CHECK ("status" IN ('PENDING', 'RESERVED', 'IN_PROGRESS', 'CANCELLED', 'ENDED', 'FAILED')) NOT NULL,
	"distance" FLOAT,
	"duration" INT,
	"start_location" VARCHAR(191) NOT NULL,
	"end_location" VARCHAR(191),
	"price" DECIMAL(10,2),
	PRIMARY KEY("ride_id")
);


