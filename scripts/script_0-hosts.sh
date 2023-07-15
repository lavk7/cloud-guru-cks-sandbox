#!/usr/bin/env bash

HOST_NAME=$(cat /tmp/hostname)
sudo hostnamectl set-hostname $HOST_NAME
cat /tmp/hosts | sudo tee -a /etc/hosts