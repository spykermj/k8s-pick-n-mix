#!/bin/sh

helm upgrade --install -n fluentd --create-namespace fluentd ./pointless-fluentd
