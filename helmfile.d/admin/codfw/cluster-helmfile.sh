#!/bin/bash

for NS in $(ls values/*.yaml); do helmfile -e $(basename -s .yaml $NS) $1 ;done