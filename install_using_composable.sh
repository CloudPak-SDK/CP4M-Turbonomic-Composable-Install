#!/bin/bash

# Offer EULA
which java >> /dev/null 2>&1
if [ $? -eq 0 ]; then
	java -jar LAPApp.jar -l Softcopy -s Status -text_only
else
	tar xzf OpenJDK11U-jre_x64_linux_hotspot_11.0.7_10.tar.gz
	./jdk-11.0.7+10-jre/bin/java -jar LAPApp.jar -l Softcopy -s Status -text_only
fi
if [ $? -ne 9 ]
then
	echo "EULA not accepted, exiting installation."
	exit 9
fi

# Set the namespace to turbonomic by default
if [ -z "${NS}" ]; then
	export NS=turbonomic
fi

# Use custom repository URL
if [ -z "${REPOSITORY}" ]; then
	export REPOSITORY=registry.connect.redhat.com/turbonomic
fi
export TAG=8.4.3
export CP_ROUTE=$(oc get route -n ibm-common-services cp-console -o jsonpath='{.spec.host}')

#Set the image tool
IMAGE_TOOL=podman
which podman >> /dev/null 2>&1 || IMAGE_TOOL=docker

# load and push platform images
cd images/
FILES="*.tar"
for tar in $FILES
do
	image=${tar%.tar}
	${IMAGE_TOOL} load -i $tar
	${IMAGE_TOOL} tag $image:$TAG $REPOSITORY/$image:$TAG
	${IMAGE_TOOL} push $REPOSITORY/$image:$TAG
done
cd ..

#Create project
oc get ns ${NS} >>/dev/null 2>&1 || oc create ns ${NS}
oc adm policy add-scc-to-group anyuid system:serviceaccounts:${NS}
oc -n ${NS} get cm repository >>/dev/null 2>&1 || oc -n ${NS} create cm repository --from-literal=repository=${REPOSITORY}
#Create a master encryption key
openssl rand 32 > primary_key_256.out
kubectl create secret -n ${NS} generic master-key-secret --from-file=primary_key_256.out=primary_key_256.out

#Install CP4M Hooks
cat << EOF | oc -n ${NS} apply -f -
apiVersion: integrations.sdk.management.ibm.com/v1beta1
kind: OidcClientRegistration
metadata:
  name: turbonomic-oidc-registration
spec:
  registration:
    post_logout_redirect_uris:
      - https://api-${NS}.{{ .OpenShiftBaseUrl }}/app/index.html
    trusted_uri_prefixes:
      - https://api-${NS}.{{ .OpenShiftBaseUrl }}
      - https://api-${NS}.{{ .OpenShiftBaseUrl }}:443
    redirect_uris:
      - https://api-${NS}.{{ .OpenShiftBaseUrl }}/vmturbo/oauth2/login/code/ibm
      - https://api-${NS}.{{ .OpenShiftBaseUrl }}/vmturbo/oauth2/login/code/cp-console.{{ .OpenShiftBaseUrl }}
    client_secret:
      secretName: turbonomic-oidc-secret
      secretKey: CLIENT_SECRET
    apply_client_secret: true
EOF
cat << EOF | oc -n ${NS} apply -f -
apiVersion: integrations.sdk.management.ibm.com/v1beta1
kind: NavMenuEntry
metadata:
  name: turbonomic-navmenu
  # This resource is Cluster-Scoped, so leave the namespace blank
spec:
  # The name of the browser tab that the link will be opened in
  target: "Turbonomic"
  # The name that will be displayed on the item in the drop-down menu
  name: "Application Resource Management"
  # The submenu that the new entry will appear under, available options are:
  # "administer-mcm";"sre";"monitor";"costs";"automate";"applications";"observe"
  parentId: "monitor"
  # User roles that will be able to see the menu item in the UI, available options are:
  # "ClusterAdministrator";"Administrator";"Operator";"Viewer";"Editor";"Auditor";"AccountAdministrator"
  roles:
    - name: ClusterAdministrator
    - name: Administrator
    - name: Operator
    - name: Viewer
    - name: Editor
    - name: Auditor
    - name: AccountAdministrator
  # The URL that the new menu entry will link to
  url: https://api-${NS}.{{ .OpenShiftBaseUrl }}/vmturbo/oauth2/authorization/cp-console.{{ .OpenShiftBaseUrl }}
EOF

#Install Composable
cat << EOF | oc -n ${NS} apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  annotations:
    olm.providedAPIs: Composable.v1alpha1.ibmcloud.ibm.com, Xl.v1.charts.helm.k8s.io
  name: turbonomic-mkk5d
  namespace: ${NS}
spec:
  targetNamespaces:
  - ${NS}
EOF

cat << EOF | oc -n ${NS} apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/t8c-certified.turbonomic: ""
  name: t8c-certified
  namespace: ${NS}
spec:
  name: t8c-certified
  source: certified-operators
  sourceNamespace: openshift-marketplace
EOF
until oc get crd xls.charts.helm.k8s.io >> /dev/null 2>&1; do sleep 5; done

cat << EOF | oc -n ${NS} apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/composable-operator.turbonomic: ""
  name: composable-operator
  namespace: ${NS}
spec:
  name: composable-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
EOF
until oc get crd composables.ibmcloud.ibm.com >> /dev/null 2>&1; do sleep 5; done

#Install Turbonomic Composable
echo "Installing Turbonomic Composable"
cat << EOF | oc -n ${NS} apply -f -
apiVersion: ibmcloud.ibm.com/v1alpha1
kind: Composable
metadata:
  name: turbonomic-release
spec:
  template:
    apiVersion: charts.helm.k8s.io/v1
    kind: Xl
    metadata:
      name: xl-release
    spec:
      # Global settings
      global:
      #  registry: registry.connect.redhat.com
      #  imageUsername: turbouser
      #  imagePassword: turbopassword
        repository:
          getValueFrom:
            kind: ConfigMap
            name: repository
            path: '{.data.repository}'
        tag: ${TAG}
        enableExternalSecrets: true
#        securityContext:
#          fsGroup: 1000640000
        customImageNames: false
        annotations:
          prometheus.io/port: "8080"
          prometheus.io/scrape: "true"

      nginxingress:
        enabled: false
      ui:
        enabled: false
      openshiftingress:
        enabled: true

      api:
        javaComponentOptions: "-Djavax.net.ssl.trustStore=/home/turbonomic/data/helper_dir/cacerts"

      properties:
        api:
          openIdEnabled: true
          openIdClients: ${CP_ROUTE}
          openIdClientAuthentication: post
          openIdUserAuthentication: form
          openIdClientId:
            getValueFrom:
              kind: Secret
              name: turbonomic-oidc-secret
              path: '{.data.CLIENT_ID}'
              format-transformers:
                - "Base64ToString"
          openIdClientSecret:
            getValueFrom:
              kind: Secret
              name: turbonomic-oidc-secret
              path: '{.data.CLIENT_SECRET}'
              format-transformers:
                - "Base64ToString"
          openIdIssuerLocation:
            getValueFrom:
              kind: Secret
              name: turbonomic-oidc-secret
              path: '{.data.BASE_ID_PROVIDER_OIDC_URL}'
              format-transformers:
                - "Base64ToString"
EOF
#Wait for API Pod to be ready
until oc -n ${NS} get xl xl-release >>/dev/null 2>&1; do sleep 5; done
sleep 10
until oc -n ${NS} get secret cs-ca-certificate-secret -o jsonpath={.data."ca\.crt"} | base64 -d > ca.crt 2>>/dev/null; do sleep 5; done
KT=keytool
which keytool >> /dev/null 2>&1 || tar xzf OpenJDK11U-jre_x64_linux_hotspot_11.0.7_10.tar.gz && KT=jdk-11.0.7+10-jre/bin/keytool
rm -f cacerts && cp /etc/pki/ca-trust/extracted/java/cacerts .
${KT} -import -trustcacerts -alias cp -file ca.crt -keystore cacerts -storepass changeit -noprompt
oc create secret generic api-secret -n ${NS} --from-file=cacerts=cacerts
oc -n ${NS} wait --'for=condition=Ready' pod -l app.kubernetes.io/name=api --timeout 10m
TURBO_ROUTE=$(oc get route api -n ${NS} -o jsonpath='{.spec.host}')
echo "Turbonomic Console URL is: https://${TURBO_ROUTE}"
