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
DB="br_full"
TABLE="usertable"
DB_COUNT=10

for i in $(seq $DB_COUNT); do
    run_sql "CREATE DATABASE $DB$i;"
    go-ycsb load mysql -P tests/br_full/workload -p mysql.host=$TIDB_IP -p mysql.port=$TIDB_PORT -p mysql.user=root -p mysql.db=$DB$i
done

for i in $(seq $DB_COUNT); do
    row_count_ori[$i]=$(run_sql_res "SELECT COUNT(*) FROM $DB$i.$TABLE;" | awk '/COUNT/{print $2}')
done

# backup full
br --pd $PD_ADDR backup full -s "local://$TEST_DIR/tidb/backupdata" --ratelimit 100 --concurrency 4

for i in $(seq $DB_COUNT); do
    run_sql "DELETE FROM $DB$i.$TABLE;"
done

# restore full
br restore full --connect "root@tcp($TIDB_ADDR)/" --importer $IMPORTER_ADDR --meta backupmeta --status $TIDB_IP:10080 --pd $PD_ADDR

for i in $(seq $DB_COUNT); do
    row_count_new[$i]=$(run_sql_res "SELECT COUNT(*) FROM $DB$i.$TABLE;" | awk '/COUNT/{print $2}')
done

fail=false
for i in $(seq $DB_COUNT); do
    if [ "$row_count_ori" -ne "$row_count_new" ];then
        fail=true
        echo "TEST: [br_full] fail on database[$i]"
    done
done

if fail; then
    echo "TEST: [br_full] failed!"
else
    echo "TEST: [br_full] successed!"
done