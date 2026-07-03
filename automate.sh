ORIG_USER=${SUDO_USER:-$(whoami)}

for counter in {1..3}
do
    for gc_start_level in 25 20 15 10 5; do
        gc_stop_level=$((gc_start_level + 10))

        sed -i -e   "s/^gc_start_level=.*/gc_start_level=${gc_start_level}/" \
            -e   "s/^gc_stop_level=.*/gc_stop_level=${gc_stop_level}/" \
            ./experiment.sh

        env SUDO_USER=$ORIG_USER ZENFS_PARAMS="$ZENFS_PARAMS" ./experiment.sh
    done
done
