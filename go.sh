if [[ $OSTYPE == *"android"* ]]; then
  export HB_PLATFORM="android"
  export HB_COMPILER="gcc"
  ../harbour/bin/android/gcc/hbmk2 hbide.hbp
fi

if [[ $OSTYPE == *"darwin"* ]]; then
  export HB_PLATFORM="darwin"
  export HB_COMPILER="clang"
  ../harbour/bin/darwin/clang/hbmk2 hbide.hbp
fi

if [[ $OSTYPE == *"linux"* ]]; then
  export HB_PLATFORM="linux"
  export HB_COMPILER="gcc"
  ../harbour/bin/linux/gcc/hbmk2 hbide.hbp
fi

if [ $? == 0 ]; then
  ./hbide
fi

