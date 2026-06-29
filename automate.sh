ORIG_USER=${SUDO_USER:-$(whoami)}

for counter in {1..3}
do
    sed -i -e   's/^gc_start_level=.*/gc_start_level=25/' \
        -e   's/^gc_stop_level=.*/gc_stop_level=35/' \
        ./experiment.sh

    env SUDO_USER=$ORIG_USER ZENFS_PARAMS="$ZENFS_PARAMS" ./experiment.sh

    sed -i -e   's/^gc_start_level=.*/gc_start_level=20/' \
        -e   's/^gc_stop_level=.*/gc_stop_level=30/' \
        ./experiment.sh

    env SUDO_USER=$ORIG_USER ZENFS_PARAMS="$ZENFS_PARAMS" ./experiment.sh

    sed -i -e   's/^gc_start_level=.*/gc_start_level=15/' \
        -e   's/^gc_stop_level=.*/gc_stop_level=25/' \
        ./experiment.sh

    env SUDO_USER=$ORIG_USER ZENFS_PARAMS="$ZENFS_PARAMS" ./experiment.sh

    sed -i -e   's/^gc_start_level=.*/gc_start_level=10/' \
        -e   's/^gc_stop_level=.*/gc_stop_level=20/' \
        ./experiment.sh

    env SUDO_USER=$ORIG_USER ZENFS_PARAMS="$ZENFS_PARAMS" ./experiment.sh

    sed -i -e   's/^gc_start_level=.*/gc_start_level=5/' \
        -e   's/^gc_stop_level=.*/gc_stop_level=15/' \
        ./experiment.sh

    env SUDO_USER=$ORIG_USER ZENFS_PARAMS="$ZENFS_PARAMS" ./experiment.sh
done
