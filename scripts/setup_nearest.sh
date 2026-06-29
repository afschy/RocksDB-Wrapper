PARAMFILE="${ZENFS_PARAMS:-./lib/rocksdb/plugin/zenfs/params.txt}"
sed -i -e   's/^logname .*/logname nearest.log/' \
       -e   's/^upper_level_policy .*/upper_level_policy kSameLevelNearbyKeys/' \
       -e   's/^upper_level_policy_fallback .*/upper_level_policy_fallback kArrivalTimeBased/' \
       -e   's/^lower_level_policy .*/lower_level_policy kSameLevelNearbyKeys/' \
       -e   's/^lower_level_policy_fallback .*/lower_level_policy_fallback kArrivalTimeBased/' \
       -e   's/^middle_level_policy .*/middle_level_policy kSameLevelNearbyKeys/' \
       -e   's/^middle_level_policy_fallback .*/middle_level_policy_fallback kArrivalTimeBased/' \
       -e   's/^min_boundary .*/min_boundary 1/' \
       -e   "s/^nearest_newzone_threshold .*/nearest_newzone_threshold 0/" \
       -e   's/^dynamic_level_adjustment .*/dynamic_level_adjustment 1/' \
       ${PARAMFILE}

cat ${PARAMFILE}
echo ""