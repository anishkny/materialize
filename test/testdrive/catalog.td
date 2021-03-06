# Copyright Materialize, Inc. All rights reserved.
#
# Use of this software is governed by the Business Source License
# included in the LICENSE file at the root of this repository.
#
# As of the Change Date specified in that file, in accordance with
# the Business Source License, use of this software will be governed
# by the Apache License, Version 2.0.

$ set-sql-timeout duration=1s

# What schemas do we have by default?
> SHOW SCHEMAS
public
> SHOW EXTENDED SCHEMAS
name
-------
public
mz_catalog
pg_catalog

# What objects do we have by default?
> SHOW OBJECTS
name
----

> SHOW FULL OBJECTS
name   type
-----------

# Creating a schema should be reflected in the output of SHOW SCHEMAS.
> CREATE SCHEMA s
> SHOW SCHEMAS
name
----
public
s

# Creating a schema with a name that already exists should fail.
! CREATE SCHEMA s
schema 's' already exists

# Dropping a schema with a view should only succeed with CASCADE.
> CREATE VIEW s.v AS SELECT 1
! DROP SCHEMA s
schema 'materialize.s' cannot be dropped without CASCADE while it contains objects
> DROP SCHEMA s CASCADE

# Dropping a schema with no objects should succeed without CASCADE.
> CREATE SCHEMA s
> CREATE VIEW s.v AS SELECT 1
> DROP VIEW s.v
> DROP SCHEMA s

# What databases do we have by default?
> SHOW DATABASES
name
----
materialize

> SELECT id, name FROM mz_databases
id          name
-----------------------
1           materialize

# Creating a database should be reflected in the output of SHOW DATABASES.
> CREATE DATABASE d
> SHOW DATABASES
name
----
d
materialize

> SELECT id, name FROM mz_databases
id          name
-----------------------
1           materialize
2           d

# The same catalog information should be accessible with any amount of
# database or schema qualification.
> SELECT count(*) FROM materialize.mz_catalog.mz_databases
2
> SELECT count(*) FROM d.mz_catalog.mz_databases
2

# SHOW DATABASES should filter its output according to the provided LIKE or
# WHERE clause.
> SHOW DATABASES LIKE 'foo'
> SHOW DATABASES LIKE 'd'
d
> SHOW DATABASES LIKE 'mat%'
materialize
> SHOW DATABASES WHERE (SELECT name = name)
materialize
d
> SHOW DATABASES WHERE (name = (SELECT min(name) FROM mz_databases))
d
! SHOW DATABASES WHERE 7
WHERE clause must have type bool, not type i32

# Creating a database with a name that already exists should fail.
! CREATE DATABASE d
database 'd' already exists

# The new database should have a default public schema.
> SHOW SCHEMAS FROM d
name
----
public

# New schemas in the database should appear in the output of SHOW SCHEMAS FROM.
> CREATE SCHEMA d.s
> SHOW SCHEMAS FROM d
name
------
public
s

# SHOW SCHEMAS should filter its output based on the provided LIKE or WHERE
# clause.
> SHOW SCHEMAS LIKE 'pub%'
public
> SHOW SCHEMAS LIKE 'private'
> SHOW SCHEMAS WHERE name = 'public'
public

# New views in the database should work.
> CREATE MATERIALIZED VIEW d.public.v1 AS SELECT 1
> SHOW VIEWS FROM d.public
name
----
v1

# Setting the session database should update name resolution appropriately.
> SET DATABASE = d
> SHOW DATABASE
d
> SHOW SCHEMAS
public
s
> CREATE MATERIALIZED VIEW v2 AS SELECT 2
> SHOW VIEWS
v1
v2
> SELECT * FROM v1 UNION ALL SELECT * FROM v2
1
2

> SHOW OBJECTS
name
----
v1
v1_primary_idx
v2
v2_primary_idx

! DROP OBJECT v1
Expected DATABASE, SCHEMA, TABLE, VIEW, SOURCE, SINK, INDEX, or TYPE after DROP, found identifier

> SHOW FULL OBJECTS
name            type
--------------------------
v1              user
v1_primary_idx  user
v2              user
v2_primary_idx  user

# DROP DATABASE should not support RESTRICT or CASCADE.
! DROP DATABASE d RESTRICT
Expected end of statement, found RESTRICT
! DROP DATABASE d RESTRICT
Expected end of statement, found RESTRICT

# DROP DATABASE should succeed even when there are objects in the database.
> DROP DATABASE d
# SHOW DATABASES should work, even if the current database has been dropped.
> SHOW DATABASES
name
----
materialize
> SELECT id, name FROM mz_databases
id          name
-----------------------
1           materialize

# The session database should remain set to the dropped database, but future
# queries that depend on the session database should fail with sensible error
# messages.
> SHOW DATABASE
d
! SELECT * FROM v
unknown catalog item 'v'

# But queries that do not depend on the session database should work fine.
> CREATE VIEW materialize.public.v AS SELECT 1
> CREATE DATABASE d

# Dropping the public schema is okay, but dropping the catalog schemas is not.
> DROP SCHEMA public
! DROP SCHEMA mz_catalog
cannot drop schema mz_catalog because it is required by the database system
! DROP SCHEMA pg_catalog
cannot drop schema pg_catalog because it is required by the database system

# Schema names that start with "mz_" or "pg_" are reserved for future use by the
# system.
! CREATE SCHEMA mz_foo
unacceptable schema name 'mz_foo'
! CREATE SCHEMA pg_bar
unacceptable schema name 'pg_bar'

# The search path is currently hardcoded.
> SHOW search_path
"mz_catalog, pg_catalog, public, mz_temp"
! SET search_path = foo
parameter search_path is read only

# Creating views in non-existent databases should fail.
! CREATE VIEW noexist.ignored AS SELECT 1
unknown schema 'noexist'
! CREATE VIEW materialize.noexist.ignored AS SELECT 1
unknown schema 'noexist'
! CREATE VIEW noexist.ignored.ignored AS SELECT 1
unknown database 'noexist'

# As should showing views.
! SHOW VIEWS FROM noexist
unknown schema 'noexist'
! SHOW VIEWS FROM noexist_db.noexist_schema
unknown database 'noexist_db'

# Dropping database with cross-schema dependencies is ok.
> CREATE DATABASE d1;
> CREATE SCHEMA d1.s1;
> CREATE VIEW d1.s1.t as select 1;
> CREATE VIEW d1.public.tt as select * from d1.s1.t;
> DROP DATABASE d1;

# Dropping database with cross-database dependencies is ok and drops the
# dependent views.
> CREATE DATABASE d1;
> CREATE VIEW d1.public.t as select 1;
> CREATE DATABASE d2;
> CREATE VIEW d2.public.t AS SELECT * FROM d1.public.t;
> DROP DATABASE d1;
> SHOW DATABASES
name
----
d
d2
materialize
> SELECT id, name FROM mz_databases
id          name
-----------------------
1           materialize
2           d
4           d2

> SHOW VIEWS FROM d2.public;
 name
------

# Check default sources, tables, and views in mz_catalog.

> SHOW SOURCES FROM mz_catalog
mz_arrangement_sharing
mz_arrangement_sizes
mz_dataflow_channels
mz_dataflow_operator_addresses
mz_dataflow_operators
mz_materialization_dependencies
mz_materializations
mz_peek_active
mz_peek_durations
mz_scheduling_elapsed
mz_scheduling_histogram
mz_scheduling_parks
mz_source_info
mz_worker_materialization_frontiers

> SHOW FULL SOURCES FROM mz_catalog
name                                 type   materialized
--------------------------------------------------------
mz_arrangement_sharing               system true
mz_arrangement_sizes                 system true
mz_dataflow_channels                 system true
mz_dataflow_operator_addresses       system true
mz_dataflow_operators                system true
mz_materialization_dependencies      system true
mz_materializations                  system true
mz_peek_active                       system true
mz_peek_durations                    system true
mz_scheduling_elapsed                system true
mz_scheduling_histogram              system true
mz_scheduling_parks                  system true
mz_source_info                       system true
mz_worker_materialization_frontiers  system true

> SHOW TABLES FROM mz_catalog
mz_array_types
mz_avro_ocf_sinks
mz_base_types
mz_columns
mz_databases
mz_index_columns
mz_indexes
mz_kafka_sinks
mz_list_types
mz_map_types
mz_schemas
mz_sinks
mz_sources
mz_tables
mz_types
mz_view_foreign_keys
mz_view_keys
mz_views

> SHOW FULL TABLES FROM mz_catalog
name                  type
----------------------------
mz_array_types        system
mz_avro_ocf_sinks     system
mz_base_types         system
mz_columns            system
mz_databases          system
mz_index_columns      system
mz_indexes            system
mz_kafka_sinks        system
mz_list_types         system
mz_map_types          system
mz_schemas            system
mz_sinks              system
mz_sources            system
mz_tables             system
mz_types              system
mz_view_foreign_keys  system
mz_view_keys          system
mz_views              system

! SHOW EXTENDED TABLES
SHOW EXTENDED TABLES not yet supported

# `SHOW TABLES` and `mz_tables` should agree.
> SELECT COUNT(*) FROM mz_tables WHERE id LIKE 's%'
18

# There is one entry in mz_indexes for each field_number/expression of the index.
> SELECT COUNT(id) FROM mz_indexes WHERE id LIKE 's%'
32

> SHOW VIEWS FROM mz_catalog
mz_addresses_with_unit_length
mz_catalog_names
mz_dataflow_names
mz_dataflow_operator_dataflows
mz_materialization_frontiers
mz_objects
mz_perf_arrangement_records
mz_perf_dependency_frontiers
mz_perf_peek_durations_aggregates
mz_perf_peek_durations_bucket
mz_perf_peek_durations_core
mz_records_per_dataflow
mz_records_per_dataflow_global
mz_records_per_dataflow_operator
mz_relations

> SHOW FULL VIEWS FROM mz_catalog
name                              type   materialized
-------------------------------------------------------
mz_addresses_with_unit_length     system false
mz_dataflow_names                 system false
mz_dataflow_operator_dataflows    system false
mz_materialization_frontiers      system false
mz_objects                        system false
mz_perf_arrangement_records       system false
mz_perf_dependency_frontiers      system false
mz_perf_peek_durations_aggregates system false
mz_perf_peek_durations_bucket     system false
mz_perf_peek_durations_core       system false
mz_records_per_dataflow           system false
mz_records_per_dataflow_global    system false
mz_records_per_dataflow_operator  system false
mz_relations                      system false
mz_catalog_names                  system false

> SHOW MATERIALIZED SOURCES FROM mz_catalog LIKE '%peek%';
mz_peek_active
mz_peek_durations

> SHOW VIEWS FROM mz_catalog LIKE '%peek%';
mz_perf_peek_durations_aggregates
mz_perf_peek_durations_bucket
mz_perf_peek_durations_core
