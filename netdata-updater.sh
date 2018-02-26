#!/usr/bin/env bash

force=0
[ "${1}" = "-f" ] && force=1

export PATH="${PATH}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/lib/jvm/java-8-oracle/bin:/usr/lib/jvm/java-8-oracle/db/bin:/usr/lib/jvm/java-8-oracle/jre/bin"
export CFLAGS="-O2"
export NETDATA_CONFIGURE_OPTIONS=""

# make sure we have a UID
[ -z "${UID}" ] && UID="$(id -u)"
INSTALL_UID="0"
if [ "${INSTALL_UID}" != "${UID}" ]
    then
    echo >&2 "This script should be run as user with uid ${INSTALL_UID} but it now runs with uid ${UID}"
    exit 1
fi

# make sure we cd to the working directory
cd "/home/lain/gits/netdata" || exit 1

# make sure there is .git here
[ ${force} -eq 0 -a ! -d .git ] && echo >&2 "No git structures found at: /home/lain/gits/netdata (use -f for force re-install)" && exit 1

# signal netdata to start saving its database
# this is handy if your database is big
pids=$(pidof netdata)
[ ! -z "${pids}" ] && kill -USR1 ${pids}

tmp=
if [ -t 2 ]
    then
    # we are running on a terminal
    # open fd 3 and send it to stderr
    exec 3>&2
else
    # we are headless
    # create a temporary file for the log
    tmp=$(mktemp /tmp/netdata-updater.log.XXXXXX)
    # open fd 3 and send it to tmp
    exec 3>${tmp}
fi

info() {
    echo >&3 "$(date) : INFO: " "${@}"
}

emptyline() {
    echo >&3
}

error() {
    echo >&3 "$(date) : ERROR: " "${@}"
}

# this is what we will do if it fails (head-less only)
failed() {
    error "FAILED TO UPDATE NETDATA : ${1}"

    if [ ! -z "${tmp}" ]
    then
        cat >&2 "${tmp}"
        rm "${tmp}"
    fi
    exit 1
}

get_latest_commit_id() {
	git rev-parse HEAD 2>&3
}

update() {
    [ -z "${tmp}" ] && info "Running on a terminal - (this script also supports running headless from crontab)"

    emptyline

    if [ -d .git ]
        then
        info "Updating netdata source from github..."

        last_commit="$(get_latest_commit_id)"
        [ ${force} -eq 0 -a -z "${last_commit}" ] && failed "CANNOT GET LAST COMMIT ID (use -f for force re-install)"

        git pull >&3 2>&3 || failed "CANNOT FETCH LATEST SOURCE (use -f for force re-install)"

        new_commit="$(get_latest_commit_id)"
        if [ ${force} -eq 0 ]
            then
            [ -z "${new_commit}" ] && failed "CANNOT GET NEW LAST COMMIT ID (use -f for force re-install)"
            [ "${new_commit}" = "${last_commit}" ] && info "Nothing to be done! (use -f to force re-install)" && exit 0
        fi
    elif [ ${force} -eq 0 ]
        then
        failed "CANNOT FIND GIT STRUCTURES IN $(pwd) (use -f for force re-install)"
    fi

    emptyline
    info "Re-installing netdata..."
    ./netdata-installer.sh  --dont-wait >&3 2>&3 || failed "FAILED TO COMPILE/INSTALL NETDATA"

    [ ! -z "${tmp}" ] && rm "${tmp}" && tmp=
    return 0
}

# the installer updates this script - so we run and exit in a single line
update && exit 0
###############################################################################
###############################################################################
