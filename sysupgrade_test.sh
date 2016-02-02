# Copyright 2012 Google Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# * Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
# * Neither the name of Google Inc. nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

shtk_import unittest


# Creates a fake program that records its invocations for later processing.
#
# The fake program, when invoked, will append its arguments to a commands.log
# file in the test case's work directory.
#
# \param binary The path to the program to create.
# \param delegate If set to 'yes', execute the real program afterwards.
create_mock_binary() {
    local binary="${1}"; shift
    local delegate=no
    [ ${#} -eq 0 ] || { delegate="${1}"; shift; }

    cat >"${binary}" <<EOF
#! /bin/sh

logfile="${HOME}/commands.log"
echo "Command: \${0##*/}" >>"\${logfile}"
echo "Directory: \$(pwd)" >>"\${logfile}"
for arg in "\${@}"; do
    echo "Arg: \${arg}" >>"\${logfile}"
done
    echo >>"\${logfile}"
EOF

    if [ "${delegate}" = yes ]; then
        cat >>"${binary}" <<EOF
PATH="${PATH}"
exec "\${0##*/}" "\${@}"
EOF
    fi

    chmod +x "${binary}"
}


# Generates a NetBSD release dir with fake sets and kernels.
#
# Each generated set contains a single file named '<set>.cookie'.  The kernels
# contain just an hardcoded string within them that can later be validated to
# ensure the right set was unpacked.
#
# \param releasedir Path to the release directory.
# \param ... Names of the sets to create under releasedir/binary/sets/ and the
#     kernels to create under releasedir/binary/kernel/.  No extensions should
#     be given.
create_mock_release() {
    local releasedir="${1}"; shift

    mkdir -p "${releasedir}/binary/kernel"
    mkdir -p "${releasedir}/binary/sets"

    for set_name in "${@}"; do
        case "${set_name}" in
            netbsd-*)
                echo "File from ${set_name}" \
                    >"${releasedir}/binary/kernel/${set_name}"
                gzip "${releasedir}/binary/kernel/${set_name}"
                ;;

            *)
                echo "File from ${set_name}" >"${set_name}.cookie"
                tar czf "${releasedir}/binary/sets/${set_name}.tgz" \
                    "${set_name}.cookie"
                rm "${set_name}.cookie"
                ;;
        esac
    done
}


shtk_unittest_add_test config__builtins
config__builtins_test() {
    cat >expout <<EOF
AUTOCLEAN = yes
CACHEDIR = __SYSUPGRADE_CACHEDIR__
DESTDIR is undefined
ETCUPDATE = yes
KERNEL = AUTO
POSTINSTALL_AUTOFIX is undefined
RELEASEDIR is undefined
SETS = AUTO
EOF
    assert_command -o file:expout sysupgrade -c /dev/null config
}


shtk_unittest_add_test config__default_file
config__default_file_test() {
    mkdir system
    export SYSUPGRADE_ETCDIR="$(pwd)/system"

    echo "KERNEL=abc" >"system/sysupgrade.conf"
    assert_command -o match:"KERNEL = abc" sysupgrade config
}


shtk_unittest_add_test config__explicit_file
config__explicit_file_test() {
    mkdir system
    export SYSUPGRADE_ETCDIR="$(pwd)/system"

    echo "KERNEL=abc" >"system/sysupgrade.conf"
    echo "SETS='d e'" >"my-file.conf"
    assert_command -o not-match:"KERNEL = abc" -o match:"SETS = d e" \
        sysupgrade -c ./my-file.conf config
}


shtk_unittest_add_test config__auto__kernel__found
config__auto__kernel__found_test() {
    cat >config <<EOF
#! /bin/sh
if [ "\${1}" != "-x" ]; then
    echo "-x not passed to config"
    exit 1
fi
if [ "\${2}" != "$(pwd)/root/netbsd" ]; then
    echo "Invalid path passed to config: \${2}"
    exit 1
fi

cat "\${2}"
EOF
    chmod +x config
    PATH="$(pwd):${PATH}"

    mkdir root
    cat >root/netbsd <<EOF
### START CONFIG FILE "foo/bar/ABCDE"
these are some contents
### END CONFIG FILE "foo/bar/ABCDE"
EOF
    assert_command -o match:"KERNEL = ABCDE" \
        sysupgrade -c /dev/null \
        -o DESTDIR="$(pwd)/root" -o KERNEL="AUTO" config -a
}


shtk_unittest_add_test config__auto__kernel__not_found
config__auto__kernel__not_found_test() {

    assert_command -o match:"KERNEL is undefined" \
        sysupgrade -c /dev/null \
        -o DESTDIR="$(pwd)/root" -o KERNEL="AUTO" config -a
}


shtk_unittest_add_test config__auto__kernel__fail
config__auto__kernel__fail_test() {
    cat >config <<EOF
#! /bin/sh
exit 1
EOF
    chmod +x config
    PATH="$(pwd):${PATH}"

    mkdir root
    touch root/netbsd

    cat >experr <<EOF
sysupgrade: E: Failed to determine kernel name; please set KERNEL explicitly
EOF
    assert_command -s exit:1 -e file:experr sysupgrade -c /dev/null \
        -o DESTDIR="$(pwd)/root" -o KERNEL="AUTO" config -a
}


shtk_unittest_add_test config__auto__sets__found
config__auto__sets__found_test() {
    mkdir -p root/etc/mtree
    touch root/etc/mtree/set.first
    touch root/etc/mtree/set.second
    touch root/etc/mtree/set.third
    assert_command -o match:"SETS = first second third" \
        sysupgrade -c /dev/null \
        -o DESTDIR="$(pwd)/root" -o SETS="AUTO" config -a
}


shtk_unittest_add_test config__auto__sets__not_found
config__auto__sets__not_found_test() {

    assert_command -o match:"SETS is undefined" \
        sysupgrade -c /dev/null \
        -o DESTDIR="$(pwd)/root" -o SETS="AUTO" config -a
}


shtk_unittest_add_test config__not_found
config__not_found_test() {
    mkdir .sysupgrade
    mkdir system
    export SYSUPGRADE_ETCDIR="$(pwd)/system"

    cat >experr <<EOF
sysupgrade: E: Configuration file foobar does not exist
EOF
    assert_command -s exit:1 -o empty -e file:experr sysupgrade -c foobar config
}


shtk_unittest_add_test config__overrides
config__overrides_test() {
    cat >custom.conf <<EOF
CACHEDIR=/tmp/cache
KERNEL=foo
EOF

    cat >expout <<EOF
AUTOCLEAN = yes
CACHEDIR = /tmp/cache2
DESTDIR = /tmp/destdir
ETCUPDATE = yes
KERNEL is undefined
POSTINSTALL_AUTOFIX is undefined
RELEASEDIR is undefined
SETS = AUTO
EOF
    assert_command -o file:expout sysupgrade -c custom.conf -o KERNEL= \
        -o CACHEDIR=/tmp/cache2 -o DESTDIR=/tmp/destdir config
}


shtk_unittest_add_test config__too_many_args
config__too_many_args_test() {
    cat >experr <<EOF
sysupgrade: E: config does not take any arguments
Type 'man sysupgrade' for help
EOF
    assert_command -s exit:1 -e file:experr sysupgrade -c /dev/null config foo
}


shtk_unittest_add_test fetch__ftp
fetch__ftp_test() {
    # TODO(jmmv): It would be nice if this test used an actual FTP server, just
    # like the http test below.  Unfortunately, the ftpd shipped by NetBSD does
    # not provide an easy mechanism to run it as non-root (e.g. no easy way to
    # select on which port to serve).
    create_mock_binary ftp
cat >>ftp <<EOF
for arg in "\${@}"; do
    case "\${arg}" in
        -o*) touch \$(echo "\${arg}" | sed -e s,^-o,,) ;;
    esac
done
EOF
    PATH="$(pwd):${PATH}"

    SYSUPGRADE_CACHEDIR="$(pwd)/a/b/c"; export SYSUPGRADE_CACHEDIR
    mkdir -p a/b/c
    touch a/b/c/foo.tgz.tmp
    assert_command -o ignore -e ignore sysupgrade -c /dev/null \
        -o RELEASEDIR="ftp://example.net/pub/NetBSD/X.Y/a-machine" \
        -o KERNEL=GENERIC -o SETS="a foo" fetch

    assert_file stdin commands.log <<EOF
Command: ftp
Directory: $(pwd)
Arg: -o$(pwd)/a/b/c/a.tgz.tmp
Arg: ftp://example.net/pub/NetBSD/X.Y/a-machine/binary/sets/a.tgz

Command: ftp
Directory: $(pwd)
Arg: -R
Arg: -o$(pwd)/a/b/c/foo.tgz.tmp
Arg: ftp://example.net/pub/NetBSD/X.Y/a-machine/binary/sets/foo.tgz

Command: ftp
Directory: $(pwd)
Arg: -o$(pwd)/a/b/c/netbsd-GENERIC.gz.tmp
Arg: ftp://example.net/pub/NetBSD/X.Y/a-machine/binary/kernel/netbsd-GENERIC.gz

EOF
}


shtk_unittest_add_test fetch__http cleanup
fetch__http_test() {
    create_mock_release www/a-machine base comp etc netbsd-GENERIC tests text

    [ -x "/usr/libexec/httpd" ] || skip "/usr/libexec/httpd missing"
    if ! /usr/libexec/httpd -b -s -d -I 30401 -P "$(pwd)/httpd.pid" \
        "$(pwd)/www" >httpd.out 2>httpd.err; then
        if grep 'unknown option -- P' httpd.err >/dev/null; then
            skip "httpd does not support -P"
        else
            sed 's,^,httpd.out:,' httpd.out
            sed 's,^,httpd.err:,' httpd.err
            fail "Failed to start test HTTP server"
        fi
    fi

    SYSUPGRADE_CACHEDIR="$(pwd)/cache"; export SYSUPGRADE_CACHEDIR
    assert_command -o ignore -e ignore sysupgrade -c /dev/null \
        -o RELEASEDIR="http://localhost:30401/a-machine" \
        -o KERNEL=GENERIC -o SETS="base etc text" fetch

    for set_name in base.tgz etc.tgz netbsd-GENERIC.gz text.tgz; do
        [ -e "cache/${set_name}" ] || fail "${set_name} not fetched"
    done
    for set_name in comp.tgz tests.tgz; do
        [ ! -e "cache/${set_name}" ] || fail "${set_name} fetched"
    done

    kill -9 "$(cat httpd.pid)"
    rm -f httpd.pid
}
fetch__http_cleanup() {
    if [ -f httpd.pid ]; then
        echo "Killing stale HTTP server"
        kill -9 "$(cat httpd.pid)"
    fi
}


shtk_unittest_add_test fetch__ssh__one_set
fetch__ssh__one_set_test() {
    create_mock_binary scp
    PATH="$(pwd):${PATH}"

    SYSUPGRADE_CACHEDIR="$(pwd)/a/b/c"; export SYSUPGRADE_CACHEDIR
    mkdir -p a/b/c
    assert_command -o ignore -e ignore sysupgrade -c /dev/null \
        -o RELEASEDIR="ssh://example.net/home/sysbuild/release/machine" \
        -o KERNEL="" -o SETS="one" fetch

    assert_file stdin commands.log <<EOF
Command: scp
Directory: $(pwd)
Arg: example.net:/home/sysbuild/release/machine/{binary/sets/one.tgz}
Arg: $(pwd)/a/b/c/

EOF
}


shtk_unittest_add_test fetch__ssh__many_sets
fetch__ssh__many_sets_test() {
    create_mock_binary scp
    PATH="$(pwd):${PATH}"

    SYSUPGRADE_CACHEDIR="$(pwd)/a/b/c"; export SYSUPGRADE_CACHEDIR
    mkdir -p a/b/c
    assert_command -o ignore -e ignore sysupgrade -c /dev/null \
        -o RELEASEDIR="ssh://example.net/home/sysbuild/release/machine" \
        -o KERNEL=GENERIC -o SETS="one two" fetch

    assert_file stdin commands.log <<EOF
Command: scp
Directory: $(pwd)
Arg: example.net:/home/sysbuild/release/machine/{binary/sets/one.tgz,binary/sets/two.tgz,binary/kernel/netbsd-GENERIC.gz}
Arg: $(pwd)/a/b/c/

EOF
}


shtk_unittest_add_test fetch__ssh__already_exist
fetch__ssh__already_exist_test() {
    create_mock_binary scp
    PATH="$(pwd):${PATH}"

    SYSUPGRADE_CACHEDIR="$(pwd)/a/b/c"; export SYSUPGRADE_CACHEDIR
    mkdir -p a/b/c
    touch a/b/c/netbsd-GENERIC.gz
    touch a/b/c/one.tgz
    assert_command -o ignore -e ignore sysupgrade -c /dev/null \
        -o RELEASEDIR="ssh://example.net/home/sysbuild/release/machine" \
        -o KERNEL=GENERIC -o SETS="one" fetch

    [ ! -f commands.log ] || fail "scp was invoked"
}


shtk_unittest_add_test fetch__local
fetch__local_test() {
    create_mock_release release base comp etc netbsd-GENERIC tests text

    SYSUPGRADE_CACHEDIR="$(pwd)/cache"; export SYSUPGRADE_CACHEDIR
    assert_command -o ignore -e ignore sysupgrade -c /dev/null \
        -o KERNEL=GENERIC -o RELEASEDIR="$(pwd)/release" \
        -o SETS="base etc text" fetch

    for set_name in base.tgz etc.tgz netbsd-GENERIC.gz text.tgz; do
        [ -e "cache/${set_name}" ] || fail "${set_name} not fetched"
    done
    for set_name in comp.tgz tests.tgz; do
        [ ! -e "cache/${set_name}" ] || fail "${set_name} fetched"
    done
}


shtk_unittest_add_test fetch__no_kernel
fetch__no_kernel_test() {
    create_mock_release release base comp netbsd-GENERIC

    SYSUPGRADE_CACHEDIR="$(pwd)/cache"; export SYSUPGRADE_CACHEDIR
    assert_command -o ignore -e ignore sysupgrade -c /dev/null \
        -o KERNEL= -o RELEASEDIR="$(pwd)/release" -o SETS="base comp" fetch

    for set_name in base comp; do
        [ -e "cache/${set_name}.tgz" ] || fail "${set_name} not fetched"
    done
    [ ! -e "cache/netbsd-GENERIC.gz" ] || fail "netbsd-GENERIC fetched"
}


shtk_unittest_add_test fetch__unknown
fetch__unknown_test() {
    cat >experr <<EOF
sysupgrade: E: Don't know how to fetch from ./release; must be an absolute path or an FTP/HTTP site
EOF

    SYSUPGRADE_CACHEDIR="$(pwd)/cache"; export SYSUPGRADE_CACHEDIR
    assert_command -s exit:1 -e file:experr sysupgrade -c /dev/null \
        -o RELEASEDIR="./release" -o SETS="base etc text" fetch
    [ ! -d cache ] || fail "cache directory created even during errors"
}


shtk_unittest_add_test fetch__explicit
fetch__explicit_test() {
    create_mock_release release base

    SYSUPGRADE_CACHEDIR="$(pwd)/cache"; export SYSUPGRADE_CACHEDIR
    assert_command -o ignore -e ignore sysupgrade -c /dev/null \
        -o RELEASEDIR="$(pwd)/foo" -o KERNEL= -o SETS=base \
        fetch "$(pwd)/release"

    [ -e "cache/base.tgz" ] || fail "base not fetched"
}


shtk_unittest_add_test fetch__too_many_args
fetch__too_many_args_test() {
    cat >experr <<EOF
sysupgrade: E: fetch takes zero or one arguments
Type 'man sysupgrade' for help
EOF
    assert_command -s exit:1 -e file:experr sysupgrade -c /dev/null fetch \
        foo bar
}


shtk_unittest_add_test kernel__skip
kernel__skip_test() {
    cat >experr <<EOF
sysupgrade: I: Skipping kernel installation (KERNEL not set)
EOF
    assert_command -s exit:0 -e file:experr sysupgrade -c /dev/null \
        -o KERNEL= kernel
}


shtk_unittest_add_test kernel__from_config
kernel__from_config_test() {
    mkdir root
    echo "my old kernel" >root/netbsd

    create_mock_release release netbsd-FOOBAR
    SYSUPGRADE_CACHEDIR="$(pwd)/release/binary/kernel"
    export SYSUPGRADE_CACHEDIR

    assert_command -s exit:0 \
        -e match:"Upgrading kernel using FOOBAR in $(pwd)/root/" \
        -e match:"Backing up" \
        sysupgrade -c /dev/null \
        -o DESTDIR="$(pwd)/root" -o KERNEL=FOOBAR kernel

    assert_command -o match:"File from netbsd-FOOBAR" cat root/netbsd
    assert_command -o match:"my old kernel" cat root/onetbsd
}


shtk_unittest_add_test kernel__from_arg
kernel__from_arg_test() {
    mkdir root
    echo "my old kernel" >root/netbsd

    create_mock_release release netbsd-FOOBAR netbsd-OTHER
    SYSUPGRADE_CACHEDIR="$(pwd)/release/binary/kernel"
    export SYSUPGRADE_CACHEDIR

    assert_command -s exit:0 \
        -e match:"Upgrading kernel using OTHER in $(pwd)/root/" \
        -e match:"Backing up" \
        sysupgrade -c /dev/null \
        -o DESTDIR="$(pwd)/root" -o KERNEL=FOOBAR kernel OTHER

    assert_command -o match:"File from netbsd-OTHER" cat root/netbsd
    assert_command -o match:"my old kernel" cat root/onetbsd
}


shtk_unittest_add_test kernel__override_backup
kernel__override_backup_test() {
    mkdir root
    echo "my old kernel" >root/netbsd
    echo "my older kernel" >root/onetbsd

    create_mock_release release netbsd-FOOBAR
    SYSUPGRADE_CACHEDIR="$(pwd)/release/binary/kernel"
    export SYSUPGRADE_CACHEDIR

    assert_command -s exit:0 \
        -e match:"Upgrading kernel using FOOBAR in $(pwd)/root/" \
        -e match:"Backing up" \
        sysupgrade -c /dev/null \
        -o DESTDIR="$(pwd)/root" -o KERNEL=FOOBAR kernel

    assert_command -o match:"File from netbsd-FOOBAR" cat root/netbsd
    assert_command -o match:"my old kernel" cat root/onetbsd
}


shtk_unittest_add_test kernel__no_backup
kernel__no_backup_test() {
    mkdir root

    create_mock_release release netbsd-FOOBAR
    SYSUPGRADE_CACHEDIR="$(pwd)/release/binary/kernel"
    export SYSUPGRADE_CACHEDIR

    assert_command -s exit:0 -e not-match:"Backing up" sysupgrade -c /dev/null \
        -o DESTDIR="$(pwd)/root" -o KERNEL=FOOBAR kernel

    assert_command -o match:"File from netbsd-FOOBAR" cat root/netbsd
    [ ! -f root/onetbsd ] || fail "onetbsd backup created, but not expected"
}


shtk_unittest_add_test kernel__missing_set
kernel__missing_set_test() {
    mkdir root
    echo "my old kernel" >root/netbsd

    SYSUPGRADE_CACHEDIR="$(pwd)"; export SYSUPGRADE_CACHEDIR

    cat >experr <<EOF
sysupgrade: E: Cannot find netbsd-GENERIC.gz; did you run 'sysupgrade fetch' first?
EOF
    assert_command -s exit:1 -e file:experr sysupgrade -c /dev/null \
        -o DESTDIR="$(pwd)/root" -o KERNEL=GENERIC kernel

    assert_command -o match:"my old kernel" cat root/netbsd
}


shtk_unittest_add_test kernel__bad_file
kernel__bad_file_test() {
    mkdir root
    echo "my old kernel" >root/netbsd

    echo "invalid gzip file" >netbsd-FOOBAR.gz
    SYSUPGRADE_CACHEDIR="$(pwd)"; export SYSUPGRADE_CACHEDIR

    assert_command -s exit:1 \
        -e match:"Upgrading kernel using FOOBAR in $(pwd)/root/" \
        -e match:"Failed to uncompress new kernel" \
        sysupgrade -c /dev/null \
        -o DESTDIR="$(pwd)/root" -o KERNEL=FOOBAR kernel

    assert_command -o match:"my old kernel" cat root/netbsd
    [ ! -f root/onetbsd ] || fail "onetbsd backup created, but not expected"
}


shtk_unittest_add_test kernel__too_many_args
kernel__too_many_args_test() {
    cat >experr <<EOF
sysupgrade: E: kernel takes zero or one arguments
Type 'man sysupgrade' for help
EOF
    assert_command -s exit:1 -e file:experr sysupgrade -c /dev/null kernel A B
}


shtk_unittest_add_test modules__skip
modules__skip_test() {
    cat >experr <<EOF
sysupgrade: I: Skipping modules installation (modules not in SETS)
EOF
    assert_command -s exit:0 -e file:experr sysupgrade -c /dev/null \
        -o SETS="base comp modules2" modules
}


shtk_unittest_add_test modules__install
modules__install_test() {
    create_mock_release release base modules
    SYSUPGRADE_CACHEDIR="$(pwd)/release/binary/sets"; export SYSUPGRADE_CACHEDIR

    assert_command -s exit:0 -e match:"Upgrading kernel modules" \
        sysupgrade -c /dev/null -o DESTDIR="$(pwd)/root" \
        -o SETS="base modules tests" modules

    [ -f root/modules.cookie ] || fail "modules not extracted"
    [ ! -f root/base.cookie ] || fail "base should not have been extracted"
}


shtk_unittest_add_test modules__too_many_args
modules__too_many_args_test() {
    cat >experr <<EOF
sysupgrade: E: modules does not take any arguments
Type 'man sysupgrade' for help
EOF
    assert_command -s exit:1 -e file:experr sysupgrade -c /dev/null modules A
}


shtk_unittest_add_test sets__from_config
sets__from_config_test() {
    create_mock_release release base etc comp
    SYSUPGRADE_CACHEDIR="$(pwd)/release/binary/sets"; export SYSUPGRADE_CACHEDIR

    expected_sets="base comp"
    unexpected_sets="etc modules xetc"

    assert_command -s exit:0 -e ignore sysupgrade -c /dev/null \
        -o DESTDIR="$(pwd)/root" \
        -o SETS="${expected_sets} ${unexpected_sets}" \
        sets

    for set_name in ${expected_sets}; do
        [ -f "root/${set_name}.cookie" ] \
            || fail "Expected set ${set_name} not extracted"
    done

    for set_name in ${unexpected_sets}; do
        [ ! -f "root/${set_name}.cookie" ] \
            || fail "Unexpected set ${set_name} extracted"
    done
}


shtk_unittest_add_test sets__from_args
sets__from_args_test() {
    create_mock_release release base etc comp
    SYSUPGRADE_CACHEDIR="$(pwd)/release/binary/sets"; export SYSUPGRADE_CACHEDIR

    expected_sets="base comp"
    unexpected_sets="etc modules xetc"

    assert_command -s exit:0 -e ignore sysupgrade -c /dev/null \
        -o DESTDIR="$(pwd)/root" -o SETS="foo bar baz" \
        sets ${expected_sets} ${unexpected_sets}

    for set_name in ${expected_sets}; do
        [ -f "root/${set_name}.cookie" ] \
            || fail "Expected set ${set_name} not extracted"
    done

    for set_name in ${unexpected_sets}; do
        [ ! -f "root/${set_name}.cookie" ] \
            || fail "Unexpected set ${set_name} extracted"
    done
}


shtk_unittest_add_test sets__invalid_kern
sets__invalid_kern_test() {
    cat >experr <<EOF
sysupgrade: E: SETS should not contain any kernel sets; found kern-FOO
EOF
    assert_command -s exit:1 -e file:experr sysupgrade -c /dev/null \
        -o DESTDIR="$(pwd)/root" -o SETS="foo kern-FOO baz" sets
}


shtk_unittest_add_test etcupdate__skip__none
etcupdate__skip__none_test() {
    cat >experr <<EOF
sysupgrade: I: Skipping etcupdate (no etc sets in SETS)
EOF
    assert_command -s exit:0 -e file:experr sysupgrade -c /dev/null \
        -o SETS="base comp etcfoo" etcupdate
}


shtk_unittest_add_test etcupdate__skip__no_etc
etcupdate__skip__no_etc_test() {
    cat >experr <<EOF
sysupgrade: I: Skipping etcupdate (required etc not in SETS)
EOF
    assert_command -s exit:0 -e file:experr sysupgrade -c /dev/null \
        -o SETS="base xetc xfonts" etcupdate
}


shtk_unittest_add_test etcupdate__skip__destdir
etcupdate__skip__destdir_test() {
    cat >experr <<EOF
sysupgrade: I: Skipping etcupdate (DESTDIR upgrades not supported)
EOF
    assert_command -s exit:0 -e file:experr sysupgrade -c /dev/null \
        -o DESTDIR="$(pwd)" -o SETS="etc" etcupdate
}


shtk_unittest_add_test etcupdate__some_etcs
etcupdate__some_etcs_test() {
    create_mock_binary etcupdate
    PATH="$(pwd):${PATH}"

    create_mock_release release base etc comp xbase xetc
    SYSUPGRADE_CACHEDIR="$(pwd)/release/binary/sets"; export SYSUPGRADE_CACHEDIR

    assert_command -s exit:0 -o ignore -e ignore sysupgrade -c /dev/null \
        -o RELEASEDIR="$(pwd)/release" \
        -o SETS="base etc comp xbase xetc" etcupdate

    assert_file stdin commands.log <<EOF
Command: etcupdate
Directory: $(pwd)
Arg: -a
Arg: -l
Arg: -s$(pwd)/release/binary/sets/etc.tgz
Arg: -s$(pwd)/release/binary/sets/xetc.tgz

EOF
}


shtk_unittest_add_test etcupdate__missing_etc
etcupdate__missing_etc_test() {
    SYSUPGRADE_CACHEDIR="$(pwd)"; export SYSUPGRADE_CACHEDIR

    cat >experr <<EOF
sysupgrade: E: Cannot find etc.tgz; did you run 'sysupgrade fetch' first?
EOF
    assert_command -s exit:1 -e file:experr sysupgrade -c /dev/null \
        -o RELEASEDIR="$(pwd)/missing" -o SETS="etc" etcupdate
}


shtk_unittest_add_test etcupdate__too_many_args
etcupdate__too_many_args_test() {
    cat >experr <<EOF
sysupgrade: E: etcupdate does not take any arguments
Type 'man sysupgrade' for help
EOF
    assert_command -s exit:1 -e file:experr sysupgrade -c /dev/null etcupdate foo
}


shtk_unittest_add_test postinstall__skip__none
postinstall__skip__none_test() {
    cat >experr <<EOF
sysupgrade: I: Skipping postinstall (no etc sets in SETS)
EOF
    assert_command -s exit:0 -e file:experr sysupgrade -c /dev/null \
        -o SETS="base comp etcfoo" postinstall
}


shtk_unittest_add_test postinstall__skip__no_etc
postinstall__skip__no_etc_test() {
    cat >experr <<EOF
sysupgrade: I: Skipping postinstall (required etc not in SETS)
EOF
    assert_command -s exit:0 -e file:experr sysupgrade -c /dev/null \
        -o SETS="base xetc xfonts" postinstall
}


shtk_unittest_add_test postinstall__some_etcs
postinstall__some_etcs_test() {
    create_mock_binary postinstall
    PATH="$(pwd):${PATH}"

    create_mock_release release base etc comp xbase xetc
    SYSUPGRADE_CACHEDIR="$(pwd)/release/binary/sets"; export SYSUPGRADE_CACHEDIR

    assert_command -s exit:0 -o ignore -e ignore sysupgrade -c /dev/null \
        -o RELEASEDIR="$(pwd)/release" \
        -o SETS="base etc comp xbase xetc" postinstall

    assert_file stdin commands.log <<EOF
Command: postinstall
Directory: $(pwd)
Arg: -d/
Arg: -s$(pwd)/release/binary/sets/etc.tgz
Arg: -s$(pwd)/release/binary/sets/xetc.tgz
Arg: check

EOF
}


shtk_unittest_add_test postinstall__destdir
postinstall__destdir_test() {
    create_mock_binary postinstall
    PATH="$(pwd):${PATH}"

    create_mock_release release base etc
    SYSUPGRADE_CACHEDIR="$(pwd)/release/binary/sets"; export SYSUPGRADE_CACHEDIR

    assert_command -s exit:0 -o ignore -e ignore sysupgrade -c /dev/null \
        -o DESTDIR="$(pwd)/root" \
        -o RELEASEDIR="$(pwd)/release" \
        -o SETS="base etc" postinstall

    assert_file stdin commands.log <<EOF
Command: postinstall
Directory: $(pwd)
Arg: -d$(pwd)/root/
Arg: -s$(pwd)/release/binary/sets/etc.tgz
Arg: check

EOF
}


shtk_unittest_add_test postinstall__autofix
postinstall__autofix_test() {
    create_mock_binary postinstall
    PATH="$(pwd):${PATH}"

    create_mock_release release etc
    SYSUPGRADE_CACHEDIR="$(pwd)/release/binary/sets"; export SYSUPGRADE_CACHEDIR

    assert_command -s exit:0 -o ignore -e ignore sysupgrade -c /dev/null \
        -o POSTINSTALL_AUTOFIX="first second" \
        -o RELEASEDIR="$(pwd)/release" \
        -o SETS="etc" postinstall

    assert_file stdin commands.log <<EOF
Command: postinstall
Directory: $(pwd)
Arg: -d/
Arg: -s$(pwd)/release/binary/sets/etc.tgz
Arg: fix
Arg: first
Arg: second

Command: postinstall
Directory: $(pwd)
Arg: -d/
Arg: -s$(pwd)/release/binary/sets/etc.tgz
Arg: check

EOF
}


shtk_unittest_add_test postinstall__missing_etc
postinstall__missing_etc_test() {
    SYSUPGRADE_CACHEDIR="$(pwd)"; export SYSUPGRADE_CACHEDIR

    cat >experr <<EOF
sysupgrade: E: Cannot find etc.tgz; did you run 'sysupgrade fetch' first?
EOF
    assert_command -s exit:1 -e file:experr sysupgrade -c /dev/null \
        -o RELEASEDIR="$(pwd)/missing" -o SETS="etc" postinstall
}


shtk_unittest_add_test postinstall__explicit_args
postinstall__explicit_args_test() {
    create_mock_binary postinstall
    PATH="$(pwd):${PATH}"

    create_mock_release release base etc
    SYSUPGRADE_CACHEDIR="$(pwd)/release/binary/sets"; export SYSUPGRADE_CACHEDIR

    assert_command -s exit:0 -o ignore -e ignore sysupgrade -c /dev/null \
        -o RELEASEDIR="$(pwd)/release" -o SETS="base etc" postinstall fix a b c

    assert_file stdin commands.log <<EOF
Command: postinstall
Directory: $(pwd)
Arg: -d/
Arg: -s$(pwd)/release/binary/sets/etc.tgz
Arg: fix
Arg: a
Arg: b
Arg: c

EOF
}


shtk_unittest_add_test clean__nothing
clean__nothing_test() {
    SYSUPGRADE_CACHEDIR="$(pwd)/cache"; export SYSUPGRADE_CACHEDIR
    mkdir "${SYSUPGRADE_CACHEDIR}"
    assert_command -e match:"Cleaning downloaded files" sysupgrade \
        -c /dev/null clean
    [ -d cache ] || fail "Cache directory should not have been deleted"
}


shtk_unittest_add_test clean__only_zipped
clean__only_zipped_test() {
    SYSUPGRADE_CACHEDIR="$(pwd)/cache"; export SYSUPGRADE_CACHEDIR
    mkdir "${SYSUPGRADE_CACHEDIR}"
    touch cache/foo.tgz
    touch cache/foo.tgz.tmp
    touch cache/bar.gz
    touch cache/bar.gz.tmp
    assert_command -e match:"Cleaning downloaded files" sysupgrade \
        -c /dev/null clean
    [ ! -f cache/foo.tgz ] || fail "tgz not deleted"
    [ ! -f cache/foo.tgz.tmp ] || fail "Temporary tgz not deleted"
    [ ! -f cache/bar.gz ] || fail "gz not deleted"
    [ ! -f cache/bar.gz.tmp ] || fail "Temporary gz not deleted"
    [ -d cache ] || fail "Cache directory should not have been deleted"
}


shtk_unittest_add_test clean__too_many_args
clean__too_many_args_test() {
    cat >experr <<EOF
sysupgrade: E: clean does not take any arguments
Type 'man sysupgrade' for help
EOF
    assert_command -s exit:1 -e file:experr sysupgrade -c /dev/null clean foo
}


shtk_unittest_add_test auto__simple
auto__simple_test() {
    create_mock_binary postinstall
    create_mock_binary etcupdate
    PATH="$(pwd):${PATH}"

    create_mock_release release base comp etc netbsd-CUSTOM modules

    mkdir root
    echo "old kernel" >root/netbsd

    cat >sysupgrade.conf <<EOF
CACHEDIR="$(pwd)/cache"
KERNEL="CUSTOM"
RELEASEDIR="$(pwd)/release"
SETS="base comp etc modules"
EOF

    assert_command \
        -e match:"Linking local" \
        -e match:"Upgrading kernel using" \
        -e match:"Upgrading kernel modules" \
        -e match:"Upgrading base system" \
        -e match:"Skipping etcupdate.*DESTDIR" \
        -e match:"Performing postinstall checks" \
        -e match:"Cleaning downloaded files" \
        sysupgrade -c sysupgrade.conf -d "$(pwd)/root" auto

    assert_command -o inline:"File from base\n" cat root/base.cookie
    assert_command -o inline:"File from comp\n" cat root/comp.cookie
    assert_command -o inline:"File from modules\n" cat root/modules.cookie
    assert_command -o inline:"File from netbsd-CUSTOM\n" cat root/netbsd
    assert_command -o inline:"old kernel\n" cat root/onetbsd

    [ ! -f root/etc.cookie ] || fail "etc extracted by mistake"

    [ ! -f cache/base.tgz ] || fail "Cache should have been cleaned"
}


shtk_unittest_add_test auto__custom_releasedir
auto__custom_releasedir_test() {
    create_mock_binary postinstall
    create_mock_binary etcupdate
    PATH="$(pwd):${PATH}"

    create_mock_release release2 base etc

    cat >sysupgrade.conf <<EOF
CACHEDIR="$(pwd)/cache"
KERNEL=
RELEASEDIR="$(pwd)/release"
SETS="base etc"
EOF

    assert_command \
        -e match:"Linking local" \
        -e not-match:"Upgrading kernel using" \
        -e not-match:"Upgrading kernel modules" \
        -e match:"Upgrading base system" \
        -e match:"Skipping etcupdate.*DESTDIR" \
        -e match:"Performing postinstall checks" \
        -e match:"Cleaning downloaded files" \
        sysupgrade -c sysupgrade.conf -d "$(pwd)/root" \
        auto "$(pwd)/release2"

    assert_command -o inline:"File from base\n" cat root/base.cookie

    [ ! -f root/etc.cookie ] || fail "etc extracted by mistake"
    [ ! -f root/onetbsd ] || fail "Spurious kernel backup created"
}


shtk_unittest_add_test auto__skip_etcupdate
auto__skip_etcupdate_test() {
    create_mock_binary postinstall
    PATH="$(pwd):${PATH}"

    create_mock_release release base etc

    cat >sysupgrade.conf <<EOF
CACHEDIR="$(pwd)/cache"
ETCUPDATE=no
RELEASEDIR="$(pwd)/release"
SETS="base etc"
EOF

    assert_command -e not-match:" etcupdate" \
        sysupgrade -c sysupgrade.conf -d "$(pwd)/root" auto
}


shtk_unittest_add_test auto__skip_clean
auto__skip_clean_test() {
    PATH="$(pwd):${PATH}"

    create_mock_release release2 base

    cat >sysupgrade.conf <<EOF
AUTOCLEAN=no
CACHEDIR="$(pwd)/cache"
KERNEL=
RELEASEDIR="$(pwd)/release"
SETS="base"
EOF

    assert_command \
        -e match:"Linking local" \
        -e not-match:"Upgrading kernel using" \
        -e not-match:"Upgrading kernel modules" \
        -e match:"Upgrading base system" \
        -e match:"Skipping etcupdate" \
        -e match:"Skipping postinstall" \
        -e not-match:"Cleaning downloaded files" \
        sysupgrade -c sysupgrade.conf -d "$(pwd)/root" \
        auto "$(pwd)/release2"

    assert_command -o inline:"File from base\n" cat root/base.cookie

    [ ! -f root/etc.cookie ] || fail "etc extracted by mistake"
    [ ! -f root/onetbsd ] || fail "Spurious kernel backup created"

    [ -f cache/base.tgz ] || fail "Cache should not have been cleaned"
}


shtk_unittest_add_test auto__too_many_args
auto__too_many_args_test() {
    cat >experr <<EOF
sysupgrade: E: auto takes zero or one arguments
Type 'man sysupgrade' for help
EOF
    assert_command -s exit:1 -e file:experr sysupgrade -c /dev/null auto a b
}


shtk_unittest_add_test no_command
no_command_test() {
    cat >experr <<EOF
sysupgrade: E: No command specified
Type 'man sysupgrade' for help
EOF
    assert_command -s exit:1 -e file:experr sysupgrade
}


shtk_unittest_add_test unknown_command
unknown_command_test() {
    cat >experr <<EOF
sysupgrade: E: Unknown command foo
Type 'man sysupgrade' for help
EOF
    assert_command -s exit:1 -e file:experr sysupgrade foo
}


shtk_unittest_add_test unknown_flag
unknown_flag_test() {
    cat >experr <<EOF
sysupgrade: E: Unknown option -Z
Type 'man sysupgrade' for help
EOF
    assert_command -s exit:1 -e file:experr sysupgrade -Z
}


shtk_unittest_add_test missing_argument
missing_argument_test() {
    cat >experr <<EOF
sysupgrade: E: Missing argument to option -d
Type 'man sysupgrade' for help
EOF
    assert_command -s exit:1 -e file:experr sysupgrade -d
}
