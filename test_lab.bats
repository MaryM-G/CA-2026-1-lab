#!/ /usr/bin/env bash

setup() {
   load 'test_helper/bats-support/load'
   load 'test_helper/bats-assert/load'
   load 'test_helper/bats-file/load'
   DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>81 && pwd )"
   PATH="$DIR/.../src:$PATH"
}

@test "should run script" {
   mkdir -p /tmp/test_logs
   run bash -c "echo '/tmp/test_logs' | sudo ./bash_code/CA_lab_1_code.sh"
   assert_success
   rm -rf /tmp/test_logs
}

@test "should fail if input is empty" {
   run bash -c "echo '' | sudo ./bash_code/CA_lab_1_code.sh"
   assert_failure
   assert_output --partial "This directory doesnt exist"
}

@test "should fail if path is to a file, not to a directory" {
   touch /tmp/a.txt
   run bash -c "echo '/tmp/a.txt' | sudo ./bas_code/CA_lab_1_code.sh"
   assert_failure
   assert_output --partial "This directory doesnt exist"
   rm -f /tmp/a.txt
} 

@test "should fail if path doesnt end with /log" {
   mkfir -p /tmp/logs
   run bash -c "echo '/tmp/logs' | sudo /bash_code/CA_lab_1_code.sh"
   assert_failure
   assert_output --partial ""
   rm -rf /tmp/logs
}

@test "should fail if threshold is more than 100" {
   run bash -c "sudo /bash_code/CA_lab_1_code.sh -p /tmp/test_log -b /tmp/backup -x 150"
   assert_failure
}

@test "should fail if threshold is less than 1" {
   run bash -c "sudo /bash_code/CA_lab_1_code.sh -p /tmp/test_log -b /tmp/backup -x 0"
   assert_failure
}

@test "should fail if threshold isnt a number" {
   run bash -c "sudo /bash_code/CA_lab_1_code.sh -p /tmp/test_log -b /tmp/backup-x abc"
   assert_failure
}

@test "should do nothing if usage is below threshold" {
   mkdir -p /tmp/test_log
   echo "test data" > /tmp/test_log/app.log
   rm -f /tmp/backup/*.tar.gz
   run bash -c "sudo /bash_code/CA_lab_1_code.sh -p /tmp/test_log -b /tmp/backup -x 100"
   assert_success
   run bash -c "ls /tmp/backup/*.tar.gz 2>/dev/null | wc -1"
   assert_output "0"
   rm -rf /tmp/test_log tmp/backup
}

@test "archive should contain files" {
   mkdir -p /tmp/test_log
   echo "test data" > /tmp/test_log/app.log
   run bash -c "sudo /bash_code/CA_lab_1_code.sh -p /tmp/test_log -b /tmp/test_backup -x 1"
   assert_success
   ARCHIVE=$(ls /tmp/test_backup/*.tar.gz | head -n 1)
   run tar -tzf "$ARCHIVE"
   rm -rf /tmp/test_log /tmp/test_backup
} 

@test "file should be deleted after archiving" {
   mkdir -p /tmp/test_log
   echo "test data" > /tmp/test_logs/app.log
   run bash -c "sudo /bash_code/CA_lab_1 -p /tmp/test_log -b /tmp/test_backup -x 1"
   assert_success
   assert_file_not_exist /tmp/test_logs/app.log
   rm -rf /tmp/test_log /tmp/test_backup
}
