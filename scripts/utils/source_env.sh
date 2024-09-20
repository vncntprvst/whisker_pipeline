#!/bin/bash
TERM=xterm-256color

# Locate the .env file
if [ -f .env ]; then
    env_file=".env"
elif [ -f ./utils/.env ]; then
    env_file="./utils/.env"
elif [ -f ../utils/.env ]; then
    env_file="../utils/.env"
else
    echo -e "\e[31mError:\e[0m File \e[37;103m.env\e[0m not found \n"
    exit 1
fi

# Read the .env file and export the variables
while IFS='=' read -r key value; do
  if [[ $key != \#* ]]; then
    export "$key=$value"
  fi
done < $env_file