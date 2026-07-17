PARAMFILE="${ZENFS_PARAMS:-./lib/rocksdb/plugin/zenfs/params.txt}"
sed -i -e   's/^logname .*/logname plaza-adv.log/' \
       -e   's/^upper_level_policy .*/upper_level_policy kPlazaAdvanced/' \
       -e   's/^upper_level_policy_fallback .*/upper_level_policy_fallback kArrivalTimeBased/' \
       -e   's/^lower_level_policy .*/lower_level_policy kPlazaAdvanced/' \
       -e   's/^lower_level_policy_fallback .*/lower_level_policy_fallback kArrivalTimeBased/' \
       -e   's/^middle_level_policy .*/middle_level_policy kPlazaAdvanced/' \
       -e   's/^middle_level_policy_fallback .*/middle_level_policy_fallback kArrivalTimeBased/' \
       -e   's/^min_boundary .*/min_boundary 1/' \
       -e   "s/^nearest_newzone_threshold .*/nearest_newzone_threshold 0/" \
       -e   "s/^zone_fill_threshold .*/zone_fill_threshold 0.8/" \
       -e   's/^dynamic_level_adjustment .*/dynamic_level_adjustment 0/' \
       -e   's/^zones_to_open .*/zones_to_open 1,1,4,4/' \
       ${PARAMFILE}

cat ${PARAMFILE}
echo ""