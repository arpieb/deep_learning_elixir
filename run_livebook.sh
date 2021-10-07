#!/bin/bash
export ELIXIR_ERL_OPTIONS="+sssdio 128" 
export XLA_TARGET=cuda111
livebook server -p 8081
