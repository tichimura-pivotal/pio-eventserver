#!/usr/bin/env bash

# PATH must include
# * the bin/ where `pio build` ran (for an engine)
# * just the distribution's bin/ (for the eventserver)
export PATH=/app/pio-engine/PredictionIO-dist/bin:/app/PredictionIO-dist/bin:$PATH

# Transform env variables to be consumed by PredictionIO's `conf/pio-env.sh`.
#
# Requires `conf/pio-env.sh` to be based on this buildpack's
# `config/pio-env-12f.sh`, which the compile script takes care of.
#
# Originally from https://github.com/jamesward/pio-engine-heroku/blob/master/bin/env.sh

export PIO_STORAGE_REPOSITORIES_METADATA_NAME=pio_meta
export PIO_STORAGE_REPOSITORIES_METADATA_SOURCE=PGSQL
export PIO_STORAGE_REPOSITORIES_EVENTDATA_NAME=pio_event
export PIO_STORAGE_REPOSITORIES_EVENTDATA_SOURCE=PGSQL
export PIO_STORAGE_REPOSITORIES_MODELDATA_NAME=pio_model
export PIO_STORAGE_REPOSITORIES_MODELDATA_SOURCE=PGSQL
export PIO_STORAGE_SOURCES_PGSQL_TYPE=jdbc

if [ -z "${DATABASE_URL}" ]; then
    export PIO_STORAGE_SOURCES_PGSQL_URL=jdbc:postgresql://localhost/pio
    export PIO_STORAGE_SOURCES_PGSQL_USERNAME=pio
    export PIO_STORAGE_SOURCES_PGSQL_PASSWORD=pio
else
    # from: http://stackoverflow.com/a/17287984/77409
    # extract the protocol
    proto="`echo $DATABASE_URL | grep '://' | sed -e's,^\(.*://\).*,\1,g'`"
    # remove the protocol
    url=`echo $DATABASE_URL | sed -e s,$proto,,g`

    # extract the user and password (if any)
    userpass="`echo $url | grep @ | cut -d@ -f1`"
    pass=`echo $userpass | grep : | cut -d: -f2`
    if [ -n "$pass" ]; then
        user=`echo $userpass | grep : | cut -d: -f1`
    else
        user=$userpass
    fi

    # extract the host -- updated
    hostport=`echo $url | sed -e s,$userpass@,,g | cut -d/ -f1`
    port=`echo $hostport | grep : | cut -d: -f2`
    if [ -n "$port" ]; then
        host=`echo $hostport | grep : | cut -d: -f1`
    else
        host=$hostport
    fi

    # extract the path (if any)
    path="`echo $url | grep / | cut -d/ -f2-`"

    export PIO_STORAGE_SOURCES_PGSQL_URL=jdbc:postgresql://$hostport/$path?sslmode=require
    export PIO_STORAGE_SOURCES_PGSQL_USERNAME=$user
    export PIO_STORAGE_SOURCES_PGSQL_PASSWORD=$pass
fi