#!/bin/bash

htpasswd=""
TERRAFORM_STATE_FILE="../terraform.tfstate"
REQUIRED_BIN=('terraform' 'oci' 'kubectl')

if [ ! -f "$TERRAFORM_STATE_FILE" ]; then
   echo "[ERROR] Terraform state file \"$TERRAFORM_STATE_FILE\" was not found!"
   exit 1
else
   for ((i =  0 ; i < ${#REQUIRED_BIN[*]} ; i++)); do

      if [ ! -f "$(which ${REQUIRED_BIN[$i]})" ]; then
         echo "[ERROR] The required binary \"${REQUIRED_BIN[$i]}\" was not found!"
         exit 1
      fi

   done
fi

echo -e "\n[INFO] Setting up kasten \"namespace\" ..."

kubectl create namespace kasten-io

echo -e "\n[INFO] Installing Kasten \"service\" ..."

kubectl patch storageclass oci -p '{"metadata": {"annotations": {"storageclass.beta.kubernetes.io/is-default-class":"false"}}}'

kubectl patch storageclass oci-bv -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml

cat <<EOF | kubectl create -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
   name: oci-bv-csi-snapclass
   annotations:
     k10.kasten.io/is-snapshot-class: "true"
driver: blockvolume.csi.oraclecloud.com
deletionPolicy: Delete
EOF

helm repo add kasten https://charts.kasten.io/

#helm install k10 kasten/k10 --namespace=kasten-io --create-namespace --set externalGateway.create=true --set auth.basicAuth.enabled=true --set auth.basicAuth.htpasswd='okekastenadmin:{SHA}ubuRH9kQqVmF3gonT9jBCkkRArM='
helm install k10 kasten/k10 --namespace=kasten-io --create-namespace --set externalGateway.create=true --set auth.basicAuth.enabled=true --set auth.basicAuth.htpasswd='$htpasswd'

kubectl get services gateway-ext -n kasten-io | awk {'print $1" " $4" "$5'} | column -t

### http://<publicIP/k10/#/dashboard ###

echo -e "\n[INFO] Done!"

exit 0

#https://blogs.oracle.com/cloud-infrastructure/post/kasten-k10-support-data-protection-oci-oke
#https://github.com/oracle-terraform-modules/terraform-oci-oke
#https://www.youtube.com/watch?v=5cGj5AlPeQ0
#https://www.kasten.io/kubernetes/resources/blog/protecting-oracle-kubernetes-in-the-cloud
