#!/bin/sh
#
# Copyright 2019 PingCAP, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# See the License for the specific language governing permissions and
# limitations under the License.

set -eu
DB="br_single_table"
TABLE="table_1"

run_sql "CREATE DATABASE $DB;"
run_sql "CREATE TABLE $TABLE(a int);"

for i in $(seq 100); do
    run_sql "INSERT INTO $TABLE VALUES ($i);"
done

# backup table
br --pd $PD_ADDR backup table -s "local://$TEST_DIR/tidb/backupdata" --db $DB -t $TABLE --ratelimit 100 --concurrency 4

run_sql "DELETE * FROM $TABLE;"

# restore table
br restore table --db $DB --table $TABLE --connect "root@tcp($TIDB_IP:$TIDB_PORT)/" --importer $IMPORTER_ADDR --meta backupmeta --status $TIDB_IP:10080 --pd $PD_ADDR

for i in $(seq 100) do
    run_sql "SELECT sum(a) FROM $DB.$TABLE WHERE a=$i;"
    check_contain "sum(a): $i"
done