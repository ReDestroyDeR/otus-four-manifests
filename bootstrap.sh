#!/bin/bash
kubectl create -f ns.yaml

./install-postgres.sh

kubectl create -f configmap.yaml
kubectl create -f secret.yaml

kubectl create -f lua-configmap.yaml
kubectl create -f deployment.yaml
kubectl create -f svc.yaml

kubectl create -f dr.yaml
kubectl create -f virtualservice.yaml
kubectl create -f gateway.yaml

kubectl create -f authorizationpolicy.yaml
kubectl create -f envoyfilter.yaml

