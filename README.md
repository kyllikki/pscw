# Scaleway control tool

this tool allows basic control of scaleway servers.

The tool is written in perl and uses the WebService::Scaleway perl module

## commands available

   list servers and status
       ps [OPTIONS]
   start a server
       start [OPTIONS] SERVER
   stop a server
       stop [OPTIONS] SERVER

## OPTIONS
    -v verbose
    -w <seconds> wait for completion timeout
    -t <token> API token
