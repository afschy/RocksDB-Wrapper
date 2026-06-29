PARAMFILE="${ZENFS_PARAMS:-./lib/rocksdb/plugin/zenfs/params.txt}"
sed -i -e   's/^logname .*/logname zonekv.log/' \
       -e   's/^upper_level_policy .*/upper_level_policy kArrivalTimeBased/' \
       -e   's/^upper_level_policy_fallback .*/upper_level_policy_fallback kArrivalTimeBased/' \
       -e   's/^lower_level_policy .*/lower_level_policy kArrivalTimeBased/' \
       -e   's/^lower_level_policy_fallback .*/lower_level_policy_fallback kArrivalTimeBased/' \
       -e   's/^middle_level_policy .*/middle_level_policy kArrivalTimeBased/' \
       -e   's/^middle_level_policy_fallback .*/middle_level_policy_fallback kArrivalTimeBased/' \
       -e   's/^dynamic_level_adjustment .*/dynamic_level_adjustment 0/' \
       ${PARAMFILE}

cat ${PARAMFILE}
echo ""