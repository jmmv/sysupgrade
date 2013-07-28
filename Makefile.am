# Copyright 2013 Google Inc.
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

PHONY_TARGETS =

doc_DATA = AUTHORS COPYING NEWS README
noinst_DATA = INSTALL README
EXTRA_DIST = $(doc_DATA) INSTALL README

BUILD_SED = \
	sed -e 's,__ATF_SH__,$(ATF_SH),g' \
	    -e 's,__SYSUPGRADE_CACHEDIR__,$(SYSUPGRADE_CACHEDIR),g' \
	    -e 's,__SYSUPGRADE_ETCDIR__,$(sysconfdir),g'
BUILD_SCRIPT = \
	$(BUILD_SED) <"$(srcdir)/$${source}" | \
	    $(SHTK_TOOL) build -o "$${target}" -
BUILD_FILE = \
	$(BUILD_SED) <"$(srcdir)/$${source}" >"$${target}.tmp"; \
	mv "$${target}.tmp" "$${target}"
BUILD_TEST = \
	$(BUILD_FILE); \
	chmod +x "$${target}"

sbin_SCRIPTS = sysupgrade
CLEANFILES = sysupgrade
EXTRA_DIST += sysupgrade.sh
sysupgrade: $(srcdir)/sysupgrade.sh
	source=sysupgrade.sh target=sysupgrade; $(BUILD_SCRIPT)

man_MANS = sysupgrade.8
CLEANFILES += sysupgrade.8
EXTRA_DIST += sysupgrade.8.in
sysupgrade.8: $(srcdir)/sysupgrade.8.in
	source=sysupgrade.8.in target=sysupgrade.8; $(BUILD_FILE)

man_MANS += sysupgrade.conf.5
CLEANFILES += sysupgrade.conf.5
EXTRA_DIST += sysupgrade.conf.5.in
sysupgrade.conf.5: $(srcdir)/sysupgrade.conf.5.in
	source=sysupgrade.conf.5.in target=sysupgrade.conf.5; $(BUILD_FILE)

dist_sysconf_DATA = default.conf

if WITH_ATF
dist_pkgtests_DATA = Kyuafile

pkgtests_SCRIPTS = sysupgrade_test
CLEANFILES += sysupgrade_test
EXTRA_DIST += sysupgrade_test.sh
sysupgrade_test: $(srcdir)/sysupgrade_test.sh
	source=sysupgrade_test.sh target=sysupgrade_test; $(BUILD_TEST)

if HAVE_KYUA
CHECK_ENVIRONMENT  = PATH=$(abs_top_builddir):$${PATH}
INSTALLCHECK_ENVIRONMENT = PATH=$(prefix)/sbin:$${PATH}

check-local: check-kyua
PHONY_TARGETS += check-kyua
check-kyua:
	$(CHECK_ENVIRONMENT) $(TESTS_ENVIRONMENT) \
	    $(KYUA) --config=none test \
	    --kyuafile='$(top_srcdir)/Kyuafile' --build-root='$(top_builddir)'

installcheck-local: installcheck-kyua
PHONY_TARGETS += installcheck-kyua
installcheck-kyua:
	cd $(pkgtestsdir) && $(INSTALLCHECK_ENVIRONMENT) $(TESTS_ENVIRONMENT) \
	    $(KYUA) --config=none test
else  # HAVE_KYUA
PHONY_TARGETS += missing-kyua
missing-kyua:
	@echo "WARNING: kyua not found; no tests run"

check-local: missing-kyua
installcheck-local: missing-kyua
endif  # HAVE_KYUA
else  # WITH_ATF
dist-hook: forbid-dist
PHONY_TARGETS += forbid-dist
forbid-dist:
	@echo "Sorry; cannot make dist without atf."
	@false
endif  # WITH_ATF

PHONY_TARGETS += clean-all
clean-all:
	GIT="$(GIT)" $(SH) $(srcdir)/admin/clean-all.sh

.PHONY: $(PHONY_TARGETS)
