#! /usr/bin/env sh
# Returns GPU Temperature in Celsius.
# NOTE: Dial covers 20-100 degrees.
nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader
