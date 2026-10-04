/*
  01: Database schema
  Purpose:  Create the rideshare database as a star schema: one fact
            table of trips and two lookup tables.
  Method:   CREATE TABLE statements with primary keys, foreign keys
            from fact_trip to both lookups, and an is_valid flag.
  Tables:   dim_company, dim_zone, fact_trip
  Result:   3 tables, later loaded with 2 companies, 265 zones and
            2,400,067 trips.
*/

CREATE DATABASE IF NOT EXISTS rideshare;

USE rideshare;

CREATE TABLE dim_company (
    license_num   CHAR(6)      PRIMARY KEY,
    company_name  VARCHAR(20)  NOT NULL
);

CREATE TABLE dim_zone (
    location_id   INT           PRIMARY KEY,
    borough       VARCHAR(20),
    zone          VARCHAR(60),
    service_zone  VARCHAR(20),
    in_cbd        TINYINT       DEFAULT 0
);

CREATE TABLE fact_trip (
    trip_id               INT            AUTO_INCREMENT PRIMARY KEY,
    license_num           CHAR(6)        NOT NULL,
    pickup_datetime       DATETIME       NOT NULL,
    dropoff_datetime      DATETIME,
    pu_location_id        INT,
    do_location_id        INT,
    trip_miles            DECIMAL(8,2),
    trip_time_sec         INT,
    base_passenger_fare   DECIMAL(10,2),
    tolls                 DECIMAL(10,2),
    bcf                   DECIMAL(10,2),
    sales_tax             DECIMAL(10,2),
    congestion_surcharge  DECIMAL(10,2),
    airport_fee           DECIMAL(10,2),
    cbd_congestion_fee    DECIMAL(10,2),
    tips                  DECIMAL(10,2),
    driver_pay            DECIMAL(10,2),
    shared_request_flag   CHAR(1),
    period                VARCHAR(4),
    is_valid              TINYINT        DEFAULT 1,
    FOREIGN KEY (license_num)    REFERENCES dim_company(license_num),
    FOREIGN KEY (pu_location_id) REFERENCES dim_zone(location_id),
    FOREIGN KEY (do_location_id) REFERENCES dim_zone(location_id)
);