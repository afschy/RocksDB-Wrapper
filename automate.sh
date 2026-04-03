sed -i -e   's/^gc_start_level=.*/gc_start_level=25/' \
       -e   's/^gc_stop_level=.*/gc_stop_level=35/' \
       ./experiment.sh

sudo ./experiment.sh

sed -i -e   's/^gc_start_level=.*/gc_start_level=20/' \
       -e   's/^gc_stop_level=.*/gc_stop_level=30/' \
       ./experiment.sh

sudo ./experiment.sh

sed -i -e   's/^gc_start_level=.*/gc_start_level=15/' \
       -e   's/^gc_stop_level=.*/gc_stop_level=25/' \
       ./experiment.sh

sudo ./experiment.sh

sed -i -e   's/^gc_start_level=.*/gc_start_level=10/' \
       -e   's/^gc_stop_level=.*/gc_stop_level=20/' \
       ./experiment.sh

sudo ./experiment.sh

sed -i -e   's/^gc_start_level=.*/gc_start_level=5/' \
       -e   's/^gc_stop_level=.*/gc_stop_level=15/' \
       ./experiment.sh

sudo ./experiment.sh

sed -i -e   's/^gc_start_level=.*/gc_start_level=25/' \
       -e   's/^gc_stop_level=.*/gc_stop_level=27/' \
       ./experiment.sh

sudo ./experiment.sh

sed -i -e   's/^gc_start_level=.*/gc_start_level=20/' \
       -e   's/^gc_stop_level=.*/gc_stop_level=22/' \
       ./experiment.sh

sudo ./experiment.sh

sed -i -e   's/^gc_start_level=.*/gc_start_level=15/' \
       -e   's/^gc_stop_level=.*/gc_stop_level=17/' \
       ./experiment.sh

sudo ./experiment.sh

sed -i -e   's/^gc_start_level=.*/gc_start_level=10/' \
       -e   's/^gc_stop_level=.*/gc_stop_level=12/' \
       ./experiment.sh

sudo ./experiment.sh

sed -i -e   's/^gc_start_level=.*/gc_start_level=5/' \
       -e   's/^gc_stop_level=.*/gc_stop_level=7/' \

