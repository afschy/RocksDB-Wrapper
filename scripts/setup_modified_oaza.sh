PARAMFILE="${ZENFS_PARAMS:-./lib/rocksdb/plugin/zenfs/params.txt}"
sed -i -e   's/^logname .*/logname modified_oaza.log/' \
       -e   's/^upper_level_policy .*/upper_level_policy kClusterTogether/' \
       -e   's/^upper_level_policy_fallback .*/upper_level_policy_fallback kClusterTogether/' \
       -e   's/^lower_level_policy .*/lower_level_policy kOverlapChildren/' \
       -e   's/^lower_level_policy_fallback .*/lower_level_policy_fallback kArrivalTimeBased/' \
       -e   's/^middle_level_policy .*/middle_level_policy kOverlapChildren/' \
       -e   's/^middle_level_policy_fallback .*/middle_level_policy_fallback kArrivalTimeBased/' \
       ${PARAMFILE}

cat ${PARAMFILE}
echo ""