#!/bin/zsh
# Side-by-side React (left) vs iOS (right) for each screen: shots/compare/<set>/<n>.png
# sets: disposable, pouch (onboarding via shoot.sh) and app (post-paywall app via shoot-app.sh)
cd "${0:A:h}"
for p in "$@"; do
  mkdir -p shots/compare/$p
  for f in shots/$p/*.png; do
    n=${f:t:r}
    magick montage ../web/shots/$p/$n.png $f -tile 2x1 -geometry x852+4+4 -background '#444' shots/compare/$p/$n.png
  done
done
