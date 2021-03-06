#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2016-12-08 14:38:37 +0000 (Thu, 08 Dec 2016)
#
#  https://github.com/harisekhon/nagios-plugins
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help steer this or other code I publish
#
#  https://www.linkedin.com/in/harisekhon
#

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x
srcdir="$(cd "$(dirname "$0")" && pwd)"

cd "$srcdir/.."

. "bash-tools/docker.sh"
. "bash-tools/utils.sh"

section "Docker Image"

export DOCKER_IMAGE="harisekhon/pytools"

if is_CI && is_docker_available; then
    docker pull "$DOCKER_IMAGE"
    docker run "$DOCKER_IMAGE" welcome.py
    #docker run -e CI=1 "$DOCKER_IMAGE" tests/all.sh
fi
