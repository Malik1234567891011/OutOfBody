#!/bin/zsh
# Screenshot every screen for a preset on the booted simulator.
# usage: ./shoot.sh disposable pouch   -> shots/<preset>/NN_<id>.png  (ids taken from ../web/shots/<preset>)
cd "${0:A:h}"
BID=com.malikshourbaji.outofbody
for p in "$@"; do
  mkdir -p shots/$p
  for f in ../web/shots/$p/*.png; do
    n=${f:t:r}; id=${n#*_}
    xcrun simctl terminate booted $BID >/dev/null 2>&1
    SIMCTL_CHILD_OOB_PRESET=$p SIMCTL_CHILD_OOB_SCREEN=$id SIMCTL_CHILD_OOB_STILL=1 xcrun simctl launch booted $BID >/dev/null
    sleep ${SHOT_WAIT:-1.6}
    xcrun simctl io booted screenshot --type=png shots/$p/$n.png >/dev/null 2>&1
  done
  echo "$p done"
done
