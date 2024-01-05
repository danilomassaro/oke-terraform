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

#OBJSTR_NAMESPACE="$(terraform output -state=$TERRAFORM_STATE_FILE -raw objectstorage_namespace)"
OKE_CLUSTER_ID="$(terraform output -state=$TERRAFORM_STATE_FILE -raw gru_oke_motando_id)"
#MYSQL_HOST="$(terraform output -state=$TERRAFORM_STATE_FILE -raw gru_mysql_motando_hostname)"
#MYSQL_USER="admin"
#MYSQL_PASSWD="$(terraform output -state=$TERRAFORM_STATE_FILE -raw gru_mysql_motando_passwd)"
#DJANGO_SECRET_KEY="$(< /dev/urandom tr -dc A-Z-a-z-0-9 | head -c${1:-64};echo;)"
#BROKER_USER="admin"
#BROKER_PASSWD="$(< /dev/urandom tr -dc A-Za-z0-9 | head -c${1:-12};echo;)"
#WEBAPP_LOG_ID="$(terraform output -state=$TERRAFORM_STATE_FILE -raw gru_motando-log_webapp_id)"
#WORKFLOW_LOG_ID="$(terraform output -state=$TERRAFORM_STATE_FILE -raw gru_motando-log_workflow_id)"

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

#echo -e "\n[INFO] Setting up \"docker-registry\" secret ..."
#
#kubectl create secret docker-registry motando-ocir-secret --namespace motando \
#   --docker-server=$OCIR_HOST --docker-username="$OBJSTR_NAMESPACE/$OCIR_USER" \
#   --docker-password=$OCIR_PASSWD

#echo -e "\n[INFO] Setting up \"mysql-secret\" secret ..."
#
#kubectl create secret generic mysql-secret --namespace motando \
#   --from-literal=user=$MYSQL_USER \
#   --from-literal=passwd=$MYSQL_PASSWD \
#   --from-literal=host=$MYSQL_HOST

#echo -e "\n[INFO] Setting up \"motando-keys\" secret ..."

#kubectl create secret generic motando-keys --namespace motando \
#   --from-literal=django-seckey="$DJANGO_SECRET_KEY" \
#   --from-literal=access-key="$OCI_ACCESS_KEY_ID" \
#   --from-literal=secret-key="$OCI_SECRET_ACCESS_KEY"

#echo -e "\n[INFO] Setting up \"broker-secret\" secret ..."

#kubectl create secret generic broker-secret --namespace motando \
#   --from-literal=user=$BROKER_USER \
#   --from-literal=passwd=$BROKER_PASSWD

#echo -e "\n[INFO] Setting up \"motando-config\" configmap ..."

#kubectl create configmap motando-config --namespace motando \
#   --from-literal=objstr-namespace=$OBJSTR_NAMESPACE \
#   --from-literal=webapp-log-id=$WEBAPP_LOG_ID \
#   --from-literal=workflow-log-id=$WORKFLOW_LOG_ID
#
#echo -e "\n[INFO] Setting up \"motando-config\" namespace ..."

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
helm install k10 kasten/k10 --namespace=kasten-io --create-namespace --set externalGateway.create=true --set auth.basicAuth.enabled=true --set auth.basicAuth.htpasswd='backupadmin:{SHA}QQIEbeAs1DI3pvFdsg/fhCA8JFw='
kubectl get services gateway-ext -n kasten-io | awk {'print $1" " $4" "$5'} | column -t

### http://<publicIP/k10/#/dashboard ###
#user: backupadmin
#passwd: Backup@OCI10

echo -e "\n[INFO] Done!"

exit 0