#!/bin/zsh
# Screenshot every post-paywall app screen/state on the booted simulator, named like the React shots
# (../web/shots/app, from `node shoot-app.mjs`) so compare.sh can pair them: shots/app/NN_<name>.png
# usage: ./shoot-app.sh [preset] [name-filter]
cd "${0:A:h}"
BID=com.malikshourbaji.outofbody
P=${1:-disposable}
F=${2:-}
mkdir -p shots/app
xcrun simctl status_bar booted override --time 9:41 --batteryState discharging --batteryLevel 100 --cellularBars 4 --wifiBars 3 >/dev/null 2>&1
typeset -A seen
for f in ../web/shots/app/*.png; do
  n=${f:t:r}; name=${n#*_}
  [[ -n "$F" && "$name" != *$F* ]] && continue
  base=${name%_more}; base=${base%_end}
  scroll=""
  [[ "$name" == *_end ]] && scroll=end
  if [[ "$name" == *_more ]]; then
    # midweek-you has two "_more" shots (560 then 1100), like shoot-app.mjs
    seen[$base]=$(( ${seen[$base]:-0} + 1 ))
    (( ${seen[$base]} == 2 )) && scroll=1100 || scroll=560
  fi
  envs=(SIMCTL_CHILD_OOB_PRESET=$P SIMCTL_CHILD_OOB_STILL=1)
  if [[ "$base" == review-rough ]]; then envs+=(SIMCTL_CHILD_OOB_SCENARIO=rough SIMCTL_CHILD_OOB_SCREEN=review)
  elif [[ "$base" == *-today || "$base" == *-plan || "$base" == *-you ]]; then
    envs+=(SIMCTL_CHILD_OOB_SCENARIO=${base%-*} SIMCTL_CHILD_OOB_TAB=${base##*-} SIMCTL_CHILD_OOB_SCREEN=none)
  else envs+=(SIMCTL_CHILD_OOB_SCREEN=$base); fi
  [[ -n "$scroll" ]] && envs+=(SIMCTL_CHILD_OOB_SCROLL=$scroll)
  xcrun simctl terminate booted $BID >/dev/null 2>&1
  env $envs xcrun simctl launch booted $BID >/dev/null
  sleep ${SHOT_WAIT:-2.2}
  xcrun simctl io booted screenshot --type=png shots/app/$n.png >/dev/null 2>&1
done
echo "app shots done"
