PARAMFILE="${ZENFS_PARAMS:-./lib/rocksdb/plugin/zenfs/params.txt}"
sed -i -e   's/^logname .*/logname caza.log/' \
       -e   's/^upper_level_policy .*/upper_level_policy kCAZA/' \
       -e   's/^upper_level_policy_fallback .*/upper_level_policy_fallback kSameLevelNearbyKeysSimple/' \
       -e   's/^lower_level_policy .*/lower_level_policy kCAZA/' \
       -e   's/^lower_level_policy_fallback .*/lower_level_policy_fallback kSameLevelNearbyKeysSimple/' \
       -e   's/^middle_level_policy .*/middle_level_policy kCAZA/' \
       -e   's/^middle_level_policy_fallback .*/middle_level_policy_fallback kSameLevelNearbyKeysSimple/' \
       -e   's/^min_boundary .*/min_boundary 0/' \
       -e   's/^real_caza .*/real_caza 1/' \
       ${PARAMFILE}

cat ${PARAMFILE}
echo ""