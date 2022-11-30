#!/bin/sh
set -e pipefail
# Shut down after run is completed. This is important as a fresh VM will only start after this one shuts down.
function onexit {
	sudo shutdown -h now
}
trap onexit EXIT
cd '/Volumes/My Shared Files/Resources'
sh ./setup-actions.sh
