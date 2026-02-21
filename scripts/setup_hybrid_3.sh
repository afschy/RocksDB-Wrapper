PARAMFILE="./lib/rocksdb/plugin/zenfs/params.txt"
sed -i -e   's/^logname .*/logname hybrid_3.log/' \
       -e   's/^upper_level_policy .*/upper_level_policy kCAZA/' \
       -e   's/^upper_level_policy_fallback .*/upper_level_policy_fallback kCAZA/' \
       -e   's/^lower_level_policy .*/lower_level_policy kSameLevelNearbyKeys/' \
       -e   's/^lower_level_policy_fallback .*/lower_level_policy_fallback kSameLevelNearbyKeys/' \
       -e   's/^middle_level_policy .*/middle_level_policy kSameLevelNearbyKeys/' \
       -e   's/^middle_level_policy_fallback .*/middle_level_policy_fallback kSameLevelNearbyKeys/' \
       ${PARAMFILE}

cat ${PARAMFILE}
echo ""