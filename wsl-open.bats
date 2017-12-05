#!/usr/bin/env bats

load "node_modules/bats-support/load"
load "node_modules/bats-assert/load"

TestDir="$BATS_TEST_DIRNAME/test_folder"
TestDisks="$BATS_TEST_DIRNAME/test_mnt"
Source() {
  $BATS_TEST_DIRNAME/wsl-open.sh $@
}
TestSource() {
  if refute_wsl; then
    export EnableWslCheck=false
  fi
  export TempDir=$TempDir
  export WslDisks=$TestDisks
  export OpenExe="echo Open: "
  Source $*
}
Exe=$(basename $Source .sh)
ConfigFile=~/.$Exe

setup() {
  create_test_env
  cd $TestDir
  if grep -q "env:" <(echo $BATS_TEST_NAME) &>/dev/null; then
    # Env tests, do nothing
    true
  else
    create_valid_windisk c
    assert_valid_windisk
  fi
}

@test "env: test environment" {
assert_equal $(pwd) $TestDir
assert [ -d $TestDisks ]
}

@test "env: not on WSL error" {
if assert_wsl; then
  # We are on a real WSL
  skip "Cannot test non-WSL behavior on WSL machine"
else
  # Test functionality if ran on non WSL machine
  run Source
  assert_failure
  assert_error
  assert_output --partial "Could not detect WSL"
fi
}

@test "env: emulate WSL" {
if assert_wsl; then
  skip "Cannot emulate WSL on WSL machine"
else
  run TestSource
  refute_error
  refute_warning
  assert_success
fi
}

@test "basic: no input" {
run TestSource
assert_success
refute_error
refute_warning
assert_output ""
}

@test "basic: missing file" {
run TestSource noexist
assert_failure
assert_error
assert_output --partial "does not exist"
}

@test "basic: file on Windows" {
File="$UserDir/test.txt"
touch $File
run TestSource $File
assert_success
refute_error
refute_warning
assert_openfile "$UserFolder\\$(basename $File)"
}

@test "basic: directory on Windows" {
Dir="$UserDir/test"
mkdir $Dir
run TestSource $Dir
assert_success
refute_error
refute_warning
assert_openfile "$UserFolder\\$(basename $Dir)"
}

@test "basic: file on Linux" {
File="$TestDir/test.txt"
touch $File
run TestSource $File
assert_success
assert_warning
refute_error
assert_openfile "$ExecTempFolder\\$(basename $File)"
assert [ -e $ExecTempDir/$(basename $File) ]
}

@test "basic: directory on Linux failure" {
Dir="$TestDir/test"
mkdir $Dir
run TestSource $Dir
assert_failure
assert_error
assert_output --partial "Directory not in Windows partition"
refute_warning
}

teardown() {
  cd ..
  rm -rf $TestDir $TestDisks
}

## Helper functions

# Environment checkers
assert_wsl() {
  [[ $(uname -r) == *Microsoft ]]
}
refute_wsl() {
  ! assert_wsl
}

# Output checkers
assert_error() {
  assert_output --partial "ERROR: "
}
assert_warning() {
  assert_output --partial "WARNING: "
}
refute_error() {
  refute_output --partial "ERROR: "
}
refute_warning() {
  refute_output --partial "WARNING: "
}
assert_openfile() {
  assert_output --partial "Open: \"$*\""
}

# Utilities
safe_mkdir() {
  Dir="$*"
  if [[ -e $Dir ]]; then
    rm -rf $Dir
  fi
  refute [ -e $Dir ]
  mkdir $Dir
  assert [ -d $Dir ]
}
create_test_env() {
  # Create test folder and test disk
  for TempDir in "$TestDir" "$TestDisks"; do
    safe_mkdir $TempDir
  done
  if [[ -z $USER ]]; then
    export USER="avalera"
  fi
}
create_valid_windisk() {
  Disk="$TestDisks/$*"
  export WinDisk=$Disk
  export UserDir=$Disk/Users/$USER
  export TempDir=$UserDir/AppData/Temp
  export ExecTempDir=$TempDir/wsl-open
  export UserFolder=$(tr 'a-z' 'A-Z' <<< $*):\\\\Users\\$USER
  export TempFolder=$UserFolder\\AppData\\Temp
  export ExecTempFolder=$TempFolder\\wsl-open
  for Dir in $Disk $Disk/Windows $Disk/Windows/System32 $Disk/Users \
    $Disk/Users/$USER $UserDir/AppData $TempDir; do
    safe_mkdir $Dir
  done
}
assert_valid_windisk() {
  Disk="$WinDisk"
  assert [ -d $UserDir ]
  assert_equal $UserDir $Disk/Users/$USER
  assert [ -d $TempDir ]
  assert_equal $TempDir $UserDir/AppData/Temp
}
