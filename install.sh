#!/usr/bin/env bash

odin build src -out=oc
sudo cp ./oc /usr/local/bin/oc
rm ./oc
