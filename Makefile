#
#  Author: Hari Sekhon
#  Date: 2013-02-03 10:25:36 +0000 (Sun, 03 Feb 2013)
#
#  https://github.com/harisekhon/pytools
#
#  License: see accompanying LICENSE file
#
#  https://www.linkedin.com/in/harisekhon
#

#ifdef VIRTUAL_ENV
# Travis has custom python install earlier in $PATH even in Perl builds so need to install PyPI modules to non-system python otherwise they're not found by programs.
# Better than modifying $PATH to put /usr/bin first which is likely to affect many other things including potentially not finding the perlbrew installation first
ifneq '$(VIRTUAL_ENV)$(CONDA_DEFAULT_ENV)$(TRAVIS)' ''
	SUDO2 =
else
	SUDO2 = sudo -H
endif

# must come after to reset SUDO2 to blank if root
# EUID /  UID not exported in Make
# USER not populated in Docker
ifeq '$(shell id -u)' '0'
	SUDO =
	SUDO2 =
else
	SUDO = sudo -H
endif

PARQUET_VERSION=1.5.0

.PHONY: build
build:
	if [ -x /sbin/apk ];        then make apk-packages; fi
	if [ -x /usr/bin/apt-get ]; then make apt-packages; fi
	if [ -x /usr/bin/yum ];     then make yum-packages; fi
	
	git submodule init
	git submodule update --recursive
	
	cd pylib && make
	
	[ -d "parquet-tools-$(PARQUET_VERSION)" ] || wget -t 100 --retry-connrefused -c -O "parquet-tools-$(PARQUET_VERSION)-bin.zip" "http://search.maven.org/remotecontent?filepath=com/twitter/parquet-tools/$(PARQUET_VERSION)/parquet-tools-$(PARQUET_VERSION)-bin.zip"
	[ -d "parquet-tools-$(PARQUET_VERSION)" ] || unzip "parquet-tools-$(PARQUET_VERSION)-bin.zip"
	
	# json module built-in to Python >= 2.6, backport not available via pypi
	#$(SUDO2) pip install json
	
	# for impyla
	$(SUDO2) pip install --upgrade setuptools || :
	$(SUDO2) pip install --upgrade -r requirements.txt
	# prevents https://urllib3.readthedocs.io/en/latest/security.html#insecureplatformwarning
	$(SUDO2) pip install --upgrade ndg-httpsclient
	# for ipython-notebook-pyspark.py
	#$(SUDO2) pip install jinja2
	# HiveServer2
	#$(SUDO2) pip install pyhs2
	# Impala
	#$(SUDO2) pip install impyla
	# must downgrade happybase library to work on Python 2.6
	if [ "$$(python -c 'import sys; sys.path.append("pylib"); import harisekhon; print(harisekhon.utils.getPythonVersion())')" = "2.6" ]; then $(SUDO2) pip install --upgrade "happybase==0.9"; fi
	
	# Python >= 2.7 - won't build on 2.6, handle separately and accept failure
	$(SUDO2) pip install "ipython[notebook]" || :
	@echo
	bash-tools/python_compile.sh
	@echo
	@echo
	make spark-deps
	@echo
	@echo 'BUILD SUCCESSFUL (pytools)'

.PHONY: quick
quick:
	QUICK=1 make

.PHONY: apk-packages
apk-packages:
	$(SUDO) apk update
	$(SUDO) apk add `sed 's/#.*//; /^[[:space:]]*$$/d' < setup/apk-packages.txt`
	which java || $(SUDO) apk add openjdk8-jre-base
	# Spark Java Py4J gets java linking error without this
	if [ -f /lib/libc.musl-x86_64.so.1 ]; then [ -e /lib/ld-linux-x86-64.so.2 ] || ln -sv /lib/libc.musl-x86_64.so.1 /lib/ld-linux-x86-64.so.2; fi

# for validate_multimedia.py
# available in Alpine 2.6, 2.7 and 3.x
.PHONY: apk-packages-multimedia
apk-packages-multimedia:
	$(SUDO) apk update
	$(SUDO) apk add ffmpeg

.PHONY: apk-packages-remove
apk-packages-remove:
	cd pylib && make apk-packages-remove
	$(SUDO) apk del `sed 's/#.*//; /^[[:space:]]*$$/d' < setup/apk-packages-dev.txt` || :
	$(SUDO) rm -fr /var/cache/apk/*

.PHONY: apt-packages
apt-packages:
	$(SUDO) apt-get update
	$(SUDO) apt-get install -y `sed 's/#.*//; /^[[:space:]]*$$/d' < setup/deb-packages.txt`
	which java || $(SUDO) apt-get install -y openjdk-8-jdk || $(SUDO) apt-get install -y openjdk-7-jdk

# for validate_multimedia.py
# Ubuntu 16.04 Xenial onwards, not available in Ubuntu 14.04 Trusty
# Debian 9 Stretch onwards, not available in Debian 8 Jessie
.PHONY: apt-packages-multimedia
apt-packages-multimedia:
	$(SUDO) apt-get update
	$(SUDO) apt-get install -y --no-install-recommends ffmpeg

.PHONY: apt-packages-remove
apt-packages-remove:
	cd pylib && make apt-packages-remove
	$(SUDO) apt-get purge -y `sed 's/#.*//; /^[[:space:]]*$$/d' < setup/deb-packages-dev.txt`

# for validate_multimedia.py
.PHONY: yum-packages-multimedia
yum-packages:
	@echo "This requires 3rd party rpm repos which could result in rpm hell, please handle this manually yourself so you understand what you're doing"
	exit 1

.PHONY: yum-packages-remove
yum-packages-remove:
	cd pylib                 && make yum-packages-remove
	for x in `sed 's/#.*//; /^[[:space:]]*$$/d' < setup/rpm-packages-dev.txt`; do rpm -q $$x && $(SUDO) yum remove -y $$x; done

.PHONY: jython-install
jython-install:
	./jython_install.sh

.PHONY: sonar
sonar:
	sonar-scanner

.PHONY: test
test:
	cd pylib && make test
	tests/all.sh

.PHONY: test2
test2:
	cd pylib && make test2
	tests/all.sh

.PHONY: install
install:
	@echo "No installation needed, just add '$(PWD)' to your \$$PATH"

.PHONY: update
update:
	make update2
	make

.PHONY: update2
update2:
	make update-no-recompile

.PHONY: update-no-recompile
update-no-recompile:
	git pull
	git submodule update --init --recursive

.PHONY: update-submodules
update-submodules:
	git submodule update --init --remote
.PHONY: updatem
updatem:
	make update-submodules

.PHONY: clean
clean:
	@# the xargs option to ignore blank input doesn't work on Mac
	@find . -maxdepth 3 -iname '*.py[co]' -o -iname '*.jy[co]' | xargs rm -f
	@find . -type d -ipath '*/tests/*' -iname 'test-*spark*.avro' | xargs rm -rf
	@find . -type d -ipath '*/tests/*' -iname 'test-*spark*.parquet' | xargs rm -rf
	@rm -f parquet-tools-$(PARQUET_VERSION)-bin.zip
	@if test -f /.dockerenv; then echo "detected running in Docker, removing Spark tarballs for space efficiency" && rm -fr tests/spark-*-bin-hadoop*; fi

.PHONY: spark-deps
spark-deps:
	rm -vf spark-deps.zip
	zip spark-deps.zip pylib

.PHONY: docker-run
docker-run:
	docker run -ti --rm harisekhon/pytools ${ARGS}

.PHONY: run
run:
	make docker-run

.PHONY: docker-mount
docker-mount:
	docker run -ti --rm -v $$PWD:/py harisekhon/pytools bash -c "cd /py; exec bash"

.PHONY: mount
mount:
	make docker-mount

.PHONY: push
push:
	git push
