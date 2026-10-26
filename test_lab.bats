#! /usr/bin/env bash

setup() {
   load 'test_helper/bats-support/load'
   load 'test_helper/bats-assert/load'
   load 'test_helper/bats-file/load'
   mkdir -p /tmp/log
}

teardown() {
   if mountpoint -q /tmp/log ; then
      sudo umount /tmp/log
   fi
   sudo rm -rf /tmp/log /tmp/backup /tmp/test_backup
}

@test "should run script" {
   run bash -c "./bash_code/CA_lab_1_code.sh -p /tmp/log -b /tmp/backup"
   assert_success
}

@test "should fail if input is empty" {
   run bash -c "./bash_code/CA_lab_1_code.sh"
   assert_failure
}

@test "should fail if path is to a file, not to a directory" {
   touch /tmp/a.txt
   run bash -c "./bash_code/CA_lab_1_code.sh -p /tmp/a.txt -b /tmp/backup"
   assert_failure
   rm -f /tmp/a.txt
} 

@test "should fail if path doesnt end with /log" {
   run bash -c "./bash_code/CA_lab_1_code.sh -p /tmp/logs -b /tmp/backup"
   assert_failure
}

@test "should fail if threshold is more than 100" {
   run bash -c "./bash_code/CA_lab_1_code.sh -p /tmp/test_log -b /tmp/backup -x 150"
   assert_failure
}

@test "should fail if threshold is less than 1" {
   run bash -c "./bash_code/CA_lab_1_code.sh -p /tmp/test_log -b /tmp/backup -x 0"
   assert_failure
}

@test "should fail if threshold isnt a number" {
   run bash -c "./bash_code/CA_lab_1_code.sh -p /tmp/test_log -b /tmp/backup -x abc"
   assert_failure
}

@test "should do nothing if usage is below threshold" {
   echo "test data" > /tmp/log/app.log
   rm -f /tmp/backup/*.tar.gz
   run bash -c "./bash_code/CA_lab_1_code.sh -p /tmp/log -b /tmp/backup -x 100"
   assert_success
   run bash -c "ls /tmp/backup/*.tar.gz 2>/dev/null | wc -l"
   assert_output "0"
}

@test "archive should contain files" {
   echo "test data" > /tmp/log/app.log
   run bash -c "./bash_code/CA_lab_1_code.sh -p /tmp/log -b /tmp/test_backup -x 1"
   assert_success
   ARCHIVE=$(ls /tmp/test_backup/*.tar.gz | head -n 1)
   run tar -tzf "$ARCHIVE"
} 