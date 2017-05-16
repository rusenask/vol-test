## Introduction

vol-test is a set of integration tests that is intended to prove and test API support of volume plugins for Docker. vol-test is based upon BATS(https://github.com/sstephenson/bats.git) and depends on some helper libraries - bats-support and bats-assert which are linked as submodules.

vol-test supports testing against remote environments. Remote Docker hosts should have ssh keys configured for access without a password.

## Setup

- Install BATS.

    ```
    git clone https://github.com/sstephenson/bats.git
    cd bats
    sudo ./install.sh /usr/local
    ```

- Clone this repository (optionally, fork), and pull submodules

    ```
    git clone https://github.com/khudgins/vol-test
    cd vol-tests
    git submodule update --recursive --remote
```

## Provisioning


- as a standalone run of the automated tests (currently in digital ocean):

Depending on whether machines need to be created from scratch in digital ocean set `BOOTSTRAP` env variable and run `provision.sh` from top level directory.
You can check if the cluster has been built before or not by verifying are no machines tagged vol-test or consul-vol-test in the Digital Ocean shared account.

This will create 3 node cluster in digital ocean and a separate consul VM running a consul container.

On subsequent runs or if you can see that VMS with tags vol-test and consul-node are 
already created unset `BOOTSTRAP` and run `provision.sh` this will have the advantage of reusing the VMS and your tests will be quicker.

- as a Jenkins run:

When the script is run as part of a Jenkins run these vars have to be set:

1. A unique build number which will be used in tags passed through `BUILD` ENV variable
1. A `DO_KEY` env variable containing an API key for jenkins functional account in Digital Ocean
1. The fingerprint of JENKINS SSH KEY which should have been previously added to DO
1. `JENKINS_JOB` has to be set to "true"

You can also optionally set the 
`VERSION` or `CLI_VERSION` environment variables for plugin version and CLI version
respectively.

## Running

source the test.env script as prompted after provisioning, and then 
call ./run_volume_test.sh from the top level.

- Configuration:

vol-test requires a few environment variables to be configured before running:

* VOLDRIVER - this should be set to the full path (store/vendor/pluginname:tag) of the volume driver to be tested
* PLUGINOPTS - Gets appended to the 'docker volume install' command for install-time plugin configuration
* CREATEOPTS - Optional. Used in 'docker volume create' commands in testing to pass options to the driver being tested
* PREFIX - Optional. Commandline prefix for remote testing. Usually set to 'ssh address_of_node1'
* PREFIX2 - Optional. Commandline prefix for remote testing. Usually set to 'ssh address_of_node2'


- To validate a volume plugin:

1. Export the name of the plugin that is referenced when creating a network as the environmental variable `$VOLDRIVER`.
2. Run the bats tests by running `bats singlenode.bats secondnode.bats`

Example using the vieux/sshfs driver (replace `vieux/sshfs` with the name of the plugin/driver you wish to test):

Prior to running tests the first time, you'll want to pull all the BATS assist submodules, as well:
```
git submodule update --recursive --remote
```

```
$PREFIX="docker-machine ssh node1 "
$VOLDRIVER=vieux/sshfs
$CREATEOPTS="-o khudgins@192.168.99.1:~/tmp -o password=yourpw"

bats singlenode.bats

✓ Test: Create volume using driver (vieux/sshfs)
✓ Test: Confirm volume is created using driver (vieux/sshfs)
...

15 tests, 0 failures
```
