# SamplesSubsystem

## Description
This subsystem allows user to put or get samples for any chosen project
with a prescribed structure.
This makes easier to maintain a great amount of samples generated
during fuzzing actions.

## Visuals
Current schema of Postgres Database that is using in this project.

![Postgres Database Schema](./doc/pictures/img.png)

## Installation
You need Perl and PostgreSQL have been installed on your computer.
Also, it is necessary to install Postgres DBI package:

`apt install libdbd-pg-perl`

To check on Debian-based systems if Perl DBI package is installed use:

`dpkg --get-selections | grep "^libdb[id]-`

To use fusermount it needs to be installed:

`apt install fuse`

## Usage

There are several usage options. You can:

1. Get the sample of specific column values, e.g.:

`test.pl JSON_CONFIG_PATH get PROJECT_NAME CERTIFICATION_NAME BRANCH_NAME TRAKT_NAME TARGET_NAME SAMPLE_NAME`

2. Get the latest added sample, e.g:

`test.pl JSON_CONFIG_PATH get latest`

3. Put desired sample into your samples database:

`test.pl JSON_CONFIG_PATH put SAMPLE_PATH PROJECT_NAME CERTIFICATION_NAME BRANCH_NAME TRAKT_NAME TARGET_NAME SAMPLE_NAME`

4. Print help:

`test.pl --help` or `script.pl -h`

5. Get samples names for specified target:

`test.pl JSON_CONFIG_PATH get-target TARGET_NAME`

6. Send all samples in the given path for the given target to the database:

`test.pl JSON_CONFIG_PATH put-samples SAMPLE_PATH PROJECT_NAME CERTIFICATION_NAME BRANCH_NAME TRAKT_NAME TARGET_NAME PATH/*`

7. Get all samples in a given path for a given target:

`test.pl JSON_CONFIG_PATH get-samples PROJECT_NAME CERTIFICATION_NAME BRANCH_NAME TRAKT_NAME TARGET_NAME SAMPLE_NAME PATH`


## Authors and acknowledgment
Ian Ilyasov, Nikolay Shaplov
