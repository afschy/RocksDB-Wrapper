PARAMFILE="./lib/rocksdb/plugin/zenfs/params.txt"
sed -i -e   's/^logname .*/logname overlap.log/' \
       -e   's/^upper_level_policy .*/upper_level_policy kOverlapChildren/' \
       -e   's/^upper_level_policy_fallback .*/upper_level_policy_fallback kArrivalTimeBased/' \
       -e   's/^lower_level_policy .*/lower_level_policy kOverlapChildren/' \
       -e   's/^lower_level_policy_fallback .*/lower_level_policy_fallback kArrivalTimeBased/' \
       -e   's/^middle_level_policy .*/middle_level_policy kOverlapChildren/' \
       -e   's/^middle_level_policy_fallback .*/middle_level_policy_fallback kArrivalTimeBased/' \
       -e   's/^min_boundary .*/min_boundary 1/' \
       ${PARAMFILE}

cat ${PARAMFILE}
echo ""