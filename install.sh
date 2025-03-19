#!/usr/bin/env bash

odin build . -out=oc
sudo cp ./oc /usr/local/bin/oc
rm ./oc
