#! /usr/bin/env bash

setup() {
   load 'test_helper/bats-support/load'
   load 'test_helper/bats-assert/load'
   load 'test_helper/bats-file/load'
}

@test "should run script" {
   mkdir -p /tmp/log
   run bash -c "sudo ./bash_code/CA_lab_1_code.sh -p /tmp/log -b /tmp/backup"
   assert_success
   sudo rm -rf /tmp/log /tmp/backup
}

@test "should fail if input is empty" {
   run bash -c "sudo ./bash_code/CA_lab_1_code.sh"
   assert_failure
}

@test "should fail if path is to a file, not to a directory" {
   touch /tmp/a.txt
   run bash -c "sudo ./bas_code/CA_lab_1_code.sh -p /tmp/a.txt -b /tmp/backup"
   assert_failure
   sudo rm -f /tmp/a.txt
} 

@test "should fail if path doesnt end with /log" {
   mkdir -p /tmp/logs
   run bash -c "sudo ./bash_code/CA_lab_1_code.sh -p /tmp/logs -b /tmp/backup"
   assert_failure
   sudo rm -rf /tmp/logs
}

@test "should fail if threshold is more than 100" {
   run bash -c "sudo ./bash_code/CA_lab_1_code.sh -p /tmp/test_log -b /tmp/backup -x 150"
   assert_failure
}

@test "should fail if threshold is less than 1" {
   run bash -c "sudo ./bash_code/CA_lab_1_code.sh -p /tmp/test_log -b /tmp/backup -x 0"
   assert_failure
}

@test "should fail if threshold isnt a number" {
   run bash -c "sudo ./bash_code/CA_lab_1_code.sh -p /tmp/test_log -b /tmp/backup -x abc"
   assert_failure
}

@test "should do nothing if usage is below threshold" {
   mkdir -p /tmp/log
   echo "test data" > /tmp/log/app.log
   sudo rm -f /tmp/backup/*.tar.gz
   run bash -c "sudo ./bash_code/CA_lab_1_code.sh -p /tmp/log -b /tmp/backup -x 100"
   assert_success
   run bash -c "ls /tmp/backup/*.tar.gz 2>/dev/null | wc -l"
   assert_output "0"
   sudo rm -rf /tmp/log tmp/backup
}

@test "archive should contain files" {
   mkdir -p /tmp/log
   echo "test data" > /tmp/log/app.log
   sudo rm -rf /tmp/test_backup
   run bash -c "sudo ./bash_code/CA_lab_1_code.sh -p /tmp/log -b /tmp/test_backup -x 1"
   assert_success
   ARCHIVE=$(ls /tmp/test_backup/*.tar.gz | head -n 1)
   run tar -tzf "$ARCHIVE"
   sudo rm -rf /tmp/log /tmp/test_backup
} 

@test "file should be deleted after archiving" {
   mkdir -p /tmp/log
   echo "test data" > /tmp/log/app.log
   dd if=/dev/zero of=/tmp/log/big.log bs=1M count=100
   sudo rm -rf /tmp/test_backup
   run bash -c "sudo ./bash_code/CA_lab_1_code.sh -p /tmp/log -b /tmp/test_backup -x 1"
   assert_success
   assert_file_not_exist /tmp/log/app.log
   sudo rm -rf /tmp/log /tmp/test_backup
}
