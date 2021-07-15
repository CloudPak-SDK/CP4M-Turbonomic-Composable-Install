#!/bin/bash

# Set the namespace to turbonomic by default
if [ -z "${NS}" ]; then
	export NS=turbonomic
fi

# bring down the platform and delete the operator
oc delete Composable turbonomic-release --cascade='foreground' -n ${NS}
oc delete NavMenuEntry turbonomic-navmenu -n ${NS}
oc delete OidcClientRegistration turbonomic-oidc-registration -n ${NS}

# Remove the turbonomic and composable operator subscription
oc delete Subscription t8c-certified -n ${NS}
oc delete Subscription composable-operator -n ${NS}
oc delete ClusterServiceVersion composable-operator.v0.1.3 -n ${NS}
oc delete ClusterServiceVersion t8c-operator.v8.1.0 -n ${NS}

# Let the user delete the project afterwards
#oc delete ns ${NS}

