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
DB="br_shuffle_leader"
TABLE_COUNT=10

run_sql "CREATE DATABASE $DB;"

for i in $(seq $TABLE_COUNT); do
    run_sql "CREATE TABLE $DB.$TABLE_$i(a int);"
    for j in $(seq 100); do
        run_sql "INSERT INTO $DB.$TABLE_$i VALUES ($j);"
    done
done


# backup table
br --pd $PD_ADDR backup full -s "local://$TEST_DIR/tidb/backupdata" --ratelimit 100 --concurrency 4 &
pd-ctl -u "http://$PD_ADDR" -d sched add shuffle-leader-scheduler &
wait

for i in $(seq $TABLE_COUNT); do
    run_sql "DELETE FROM $DB.$TABLE_$i;"
done

# restore table
br restore table full --connect "root@tcp($TIDB_ADDR)/" --importer $IMPORTER_ADDR --meta backupmeta --status $TIDB_IP:10080 --pd $PD_ADDR &
pd-ctl -u "http://$PD_ADDR" -d sched add shuffle-leader-scheduler &
wait

for i in $(seq $TABLE_COUNT); do
    for j in $(seq 100); do
        run_sql "SELECT sum(a) FROM $DB.$TABLE_$i WHERE a=$j;"
        check_contain "sum(a): $j"
    done
done