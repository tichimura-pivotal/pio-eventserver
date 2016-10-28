#!/usr/bin/env bash

# PATH must include
# * the bin/ where `pio build` ran (for an engine)
# * just the distribution's bin/ (for the eventserver)
export PATH=/app/pio-engine/PredictionIO-dist/bin:/app/PredictionIO-dist/bin:$PATH
