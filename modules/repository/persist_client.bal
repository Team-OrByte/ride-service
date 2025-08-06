// AUTO-GENERATED FILE. DO NOT MODIFY.

// This file is an auto-generated file by Ballerina persistence layer for model.
// It should not be modified by hand.

import ballerina/jballerina.java;
import ballerina/persist;
import ballerina/sql;
import ballerinax/persist.sql as psql;
import ballerinax/postgresql;
import ballerinax/postgresql.driver as _;

const RIDE = "rides";

public isolated client class Client {
    *persist:AbstractPersistClient;

    private final postgresql:Client dbClient;

    private final map<psql:SQLClient> persistClients;

    private final record {|psql:SQLMetadata...;|} metadata = {
        [RIDE]: {
            entityName: "Ride",
            tableName: "ride",
            fieldMetadata: {
                ride_id: {columnName: "ride_id"},
                user_id: {columnName: "user_id"},
                bike_id: {columnName: "bike_id"},
                start_time: {columnName: "start_time"},
                end_time: {columnName: "end_time"},
                status: {columnName: "status"},
                distance: {columnName: "distance"},
                duration: {columnName: "duration"},
                start_location: {columnName: "start_location"},
                end_location: {columnName: "end_location"},
                price: {columnName: "price"}
            },
            keyFields: ["ride_id"]
        }
    };

    public isolated function init() returns persist:Error? {
        postgresql:Client|error dbClient = new (host = host, username = user, password = password, database = database, port = port, options = connectionOptions);
        if dbClient is error {
            return <persist:Error>error(dbClient.message());
        }
        self.dbClient = dbClient;
        if defaultSchema != () {
            lock {
                foreach string key in self.metadata.keys() {
                    psql:SQLMetadata metadata = self.metadata.get(key);
                    if metadata.schemaName == () {
                        metadata.schemaName = defaultSchema;
                    }
                    map<psql:JoinMetadata>? joinMetadataMap = metadata.joinMetadata;
                    if joinMetadataMap == () {
                        continue;
                    }
                    foreach [string, psql:JoinMetadata] [_, joinMetadata] in joinMetadataMap.entries() {
                        if joinMetadata.refSchema == () {
                            joinMetadata.refSchema = defaultSchema;
                        }
                    }
                }
            }
        }
        self.persistClients = {[RIDE]: check new (dbClient, self.metadata.get(RIDE).cloneReadOnly(), psql:POSTGRESQL_SPECIFICS)};
    }

    isolated resource function get rides(RideTargetType targetType = <>, sql:ParameterizedQuery whereClause = ``, sql:ParameterizedQuery orderByClause = ``, sql:ParameterizedQuery limitClause = ``, sql:ParameterizedQuery groupByClause = ``) returns stream<targetType, persist:Error?> = @java:Method {
        'class: "io.ballerina.stdlib.persist.sql.datastore.PostgreSQLProcessor",
        name: "query"
    } external;

    isolated resource function get rides/[string ride_id](RideTargetType targetType = <>) returns targetType|persist:Error = @java:Method {
        'class: "io.ballerina.stdlib.persist.sql.datastore.PostgreSQLProcessor",
        name: "queryOne"
    } external;

    isolated resource function post rides(RideInsert[] data) returns string[]|persist:Error {
        psql:SQLClient sqlClient;
        lock {
            sqlClient = self.persistClients.get(RIDE);
        }
        _ = check sqlClient.runBatchInsertQuery(data);
        return from RideInsert inserted in data
            select inserted.ride_id;
    }

    isolated resource function put rides/[string ride_id](RideUpdate value) returns Ride|persist:Error {
        psql:SQLClient sqlClient;
        lock {
            sqlClient = self.persistClients.get(RIDE);
        }
        _ = check sqlClient.runUpdateQuery(ride_id, value);
        return self->/rides/[ride_id].get();
    }

    isolated resource function delete rides/[string ride_id]() returns Ride|persist:Error {
        Ride result = check self->/rides/[ride_id].get();
        psql:SQLClient sqlClient;
        lock {
            sqlClient = self.persistClients.get(RIDE);
        }
        _ = check sqlClient.runDeleteQuery(ride_id);
        return result;
    }

    remote isolated function queryNativeSQL(sql:ParameterizedQuery sqlQuery, typedesc<record {}> rowType = <>) returns stream<rowType, persist:Error?> = @java:Method {
        'class: "io.ballerina.stdlib.persist.sql.datastore.PostgreSQLProcessor"
    } external;

    remote isolated function executeNativeSQL(sql:ParameterizedQuery sqlQuery) returns psql:ExecutionResult|persist:Error = @java:Method {
        'class: "io.ballerina.stdlib.persist.sql.datastore.PostgreSQLProcessor"
    } external;

    public isolated function close() returns persist:Error? {
        error? result = self.dbClient.close();
        if result is error {
            return <persist:Error>error(result.message());
        }
        return result;
    }
}

