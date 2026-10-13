CREATE TABLE ehr_encounters (
    patient   TEXT,
    provider  TEXT,
    dos       DATE,
    cpt_codes TEXT,
    n_codes   INTEGER
);

CREATE TABLE db_encounters (
    patient    TEXT,
    provider   TEXT,
    dos        DATE,
    cpt_codes  TEXT,
    n_codes    INTEGER,
    db_records INTEGER
);

CREATE TABLE ehr_codes (
    patient  TEXT,
    provider TEXT,
    dos      DATE,
    cpt      TEXT
);

CREATE TABLE db_codes (
    patient  TEXT,
    provider TEXT,
    dos      DATE,
    cpt      TEXT
);