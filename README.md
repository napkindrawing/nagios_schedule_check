## USAGE:

    nagios_schedule_check.sh [PARAMETERS]

## SYNOPSIS:

Query nagios for services and schedule forced service checks for the results.

This script must be able to access the `/cgi-bin/objectjson.cgi` script of your
nagios installation through your web server.

By default, this script schedules the services it can find via the
`SCHEDULE_FORCED_SVC_CHECK` external command, writing directly to the nagios
command_file (see `-c` below). To disable this and print the generated
`SCHEDULE_FORCED_SVC_CHECK` external command lines directly to standard out, use
the `-p` option.

Status messages (the number of hosts & services found, etc.) are printed to
standard error.

## REQUIRED PARAMETERS:

One or more of the following is required to perform a search for relevant
services:

```
  -s SERVICE_DESCR ... Specify service checks by service description
  -S SERVICE_GROUP ... Specify service checks by service group name
  -o HOST ............ Specify service checks on a specific host
  -O HOST_GROUP ...... Specify service checks on a specific host group

```

## OPTIONAL PARAMETERS:

```
  -d ................. Enable debugging output
  -h ................. Display usage information
  -l LIMIT ........... Specify the maximum number of services to schedule.
                       The default is 50. If more services are
                       found than this limit an error is displayed and the
                       script will exit
  -n ................. Dry-Run. Do not actually submit commands
  -t SECONDS ......... The number of seconds over which to spread the
                       scheduled run times. Defaults to 60.
  -k ................. Display the path for, and do not delete the retreived
                       JSON search results
  -c COMMAND_FILE .... The path to the nagios command file. Defaults to:
                       /usr/local/nagios/var/rw/nagios.cmd
  -u URL ............. URL where nagios is installed.
                       Defaults to:
                       http://localhost/nagios
  -p ................. Print the generated commands to send to the nagios
                       command file instead of writing directly to it
```

## CONFIG FILE:

Any command-line parameters may be specified one per-line in the file
`.nagios_schedule_check.conf` in your home directory, for example:

    -u https://nagios.prod.internal/nagios4
    -c /var/run/nagios/nagios.cmd

## EXAMPLES:

Schedule service checks for all services in the 'ssl-cert' service group on
all hosts, for the nagios installation at
`https://nagios.party-time.net/ops/nagios`:

	nagios_schedule_check.sh -u 'https://nagios.party-time.net/ops/nagios' -S ssl-cert

Schedule service checks for the service 'Processes - Burninator' on all hosts:

	nagios_schedule_check.sh -s 'Processes - Burninator'

Schedule service checks for the all services in the service group
'dns-resolution' on hosts in the host group 'web-servers', spreading them out over
the next 5 minutes (300 seconds):

	nagios_schedule_check.sh -S dns-resolution -O web-servers -t 300

## LICENSE

BSD 2-Clause License

Copyright (c) 2017, Michael Walker, napkindrawing.com
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
