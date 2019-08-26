#!/bin/sh
mkdir sparse
cd sparse
git init
git remote add -f origin https://github.com/aeternity/aeternity.git
git config core.sparseCheckout true

echo "aecore" >> .git/info/sparse-checkout
echo "aetx" >> .git/info/sparse-checkout
echo "aechannel" >> .git/info/sparse-checkout
echo "aechannel" >> .git/info/sparse-checkout
echo "aecontract" >> .git/info/sparse-checkout

git pull origin master
git checkout ed54d2e625fdcf7cf7b0189cd213090edbf3a565
cd ..


cd apps
yes | mix new aecore
yes | mix new aetx
yes | mix new aechannel
yes | mix new aecontract
cd ..

cp -r sparse/apps .

# prepare aecore
# TODO, check out sane verions.
# git clone https://github.com/aeternity/aebytecode.git apps/aecore/aebytecode
git clone https://github.com/aeternity/aeminer.git apps/aecore/aeminer
# git clone https://github.com/aeternity/exometer_core.git apps/aecore/exometer_core

#move to known commits
# git --git-dir=apps/aecore/aebytecode/.git checkout 11a8997ac7ab2fc77948e6ab8ad22801640bcece
git --git-dir=apps/aecore/aeminer/.git checkout 1cf2ecfd83f6ca3ec21a183f730083cf63ae7feb
# git --git-dir=apps/aecore/exometer_core/.git checkout 588da231c885390a9b3c08a367949750f32d143c

git apply patches/lima-aechannels.patch
git apply patches/lima-aecore.patch
