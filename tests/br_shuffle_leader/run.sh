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
TABLE="usertable"

run_sql "CREATE DATABASE $DB;"

go-ycsb load mysql -P tests/br_shuffle_leader/workload -p mysql.host=$TIDB_IP -p mysql.port=$TIDB_PORT -p mysql.user=root -p mysql.db=$DB

row_count_ori=$(run_sql_res "SELECT COUNT(*) FROM $DB.$TABLE;" | awk '/COUNT/{print $2}')

# backup with shuffle leader
br --pd $PD_ADDR backup full -s "local://$TEST_DIR/$DB/backupdata" --ratelimit 100 --concurrency 4 &
pd-ctl -u "http://$PD_ADDR" -d sched add shuffle-leader-scheduler &
wait

run_sql "DELETE FROM $DB.$TABLE;"

# restore with shuffle leader
br restore full --connect "root@tcp($TIDB_ADDR)/" --importer $IMPORTER_ADDR --meta backupmeta --status $TIDB_IP:10080 --pd $PD_ADDR &
pd-ctl -u "http://$PD_ADDR" -d sched add shuffle-leader-scheduler &
wait

row_count_new=$(run_sql_res "SELECT COUNT(*) FROM $DB.$TABLE;" | awk '/COUNT/{print $2}')

echo "original row count: $row_count_ori, new row count: $row_count_new"

if [ "$row_count_ori" -eq "$row_count_new" ];then
    echo "TEST: [br_shuffle_leader] sucess!"
else
    echo "TEST: [br_shuffle_leader] fail!"
fi