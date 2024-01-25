#!/bin/bash

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

OKE_CLUSTER_ID="$(terraform output -state=$TERRAFORM_STATE_FILE -raw gru_oke_motando_id)"

source motando.env

echo "[INFO] Configuring access to OKE ..."

#oci ce cluster create-kubeconfig \
#  --cluster-id $OKE_CLUSTER_ID \
#  --file $HOME/.kube/config \
#  --region $OCI_REGION_ID \
#  --token-version 2.0.0  \
#  --kube-endpoint PUBLIC_ENDPOINT

oci ce cluster create-kubeconfig --cluster-id $OKE_CLUSTER_ID --file $HOME/.kube/config --region sa-saopaulo-1 --token-version 2.0.0  --kube-endpoint PUBLIC_ENDPOINT

if [ $? -ne 0 ]; then
   echo "[ERROR] Could not setup the OKE access!"
   exit 1
fi

### Kasten ###
echo -e "\n[INFO] Setting up kasten \"namespace\" ..."

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
#helm install k10 kasten/k10 --namespace=kasten-io --create-namespace --set externalGateway.create=true --set auth.basicAuth.enabled=true --set auth.basicAuth.htpasswd='backupadmin:{SHA}QQIEbeAs1DI3pvFdsg/fhCA8JFw='
helm install k10 kasten/k10 --namespace=kasten-io --create-namespace
kubectl patch svc gateway -n kasten-io -p '{"spec": {"type":"LoadBalancer"}}'
kubectl get services gateway -n kasten-io | awk {'print $1" " $4" "$5'} | column -t

### http://<publicIP:8000/k10/#/dashboard ###


echo -e "\n[INFO] Done!"

exit 0
