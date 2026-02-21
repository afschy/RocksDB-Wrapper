PARAMFILE="./lib/rocksdb/plugin/zenfs/params.txt"
sed -i -e   's/^logname .*/logname default.log/' \
       -e   's/^upper_level_policy .*/upper_level_policy kLifetimeBased/' \
       -e   's/^upper_level_policy_fallback .*/upper_level_policy_fallback kLifetimeBased/' \
       -e   's/^lower_level_policy .*/lower_level_policy kLifetimeBased/' \
       -e   's/^lower_level_policy_fallback .*/lower_level_policy_fallback kLifetimeBased/' \
       -e   's/^middle_level_policy .*/middle_level_policy kLifetimeBased/' \
       -e   's/^middle_level_policy_fallback .*/middle_level_policy_fallback kLifetimeBased/' \
       ${PARAMFILE}

cat ${PARAMFILE}
echo ""