## What is Istio?

### Introduction
- A service mesh.
- A service mesh is an extra layer of software you deploy alongside your cluster (eg k8s).
- In a standard k8s cluster, we don't have visibility or control over connections between different k8s containers.
- The big feature that everybody is looking from service mesh is telemetry - fancy word for gathering metrics.
  - We use Prometheus and Grafana to gather metrics about the overall health of the cluster. 
  - Service mesh is about gathering metrics for individual network requests.
- Without a service mesh, it would be difficult to know what service is returning what statuses and taking how much time.
- Service mesh can also be used for security and traffic management like rerouting requests on some particular requirement.

### How Istio implements a service mesh?

- For each of the pod in the system, istio will add its own container called proxy.
- Istiod (Istio daemon) pod present in istio-system namespace implements most of the istio functionality/mesh logic such as telemetry, traffic management, etc
- There are more pods (total 6) in control plane, like UI pods like Kiali UI, which is neat interface to visualise how our pods connect together.

Note:
- Istio - Service mesh, layer applied to k8s cluster, used to manage and monitor traffic moving b/w pods.
- To inject istio proxy container in pods running in a particular namespace, we have to add the label of istio-injection=enabled for that namespace.
- For example - To run istio proxy / sidecar container in pods in default namespace:
```
kubectl label namespace default istio-injection=enabled
```

Istio has 2 sections:
- Control-plane: Set of pods running istio-system namespace.
- Data-plane: The proxies, running on each pod, are collectively called 'data plane'.

## Telemetry

### Kiali
- Istio is gathering data constantly based on what it sees going through service mesh and is collating that data - This is a very dynamic picture, which is showed on Kiali.
- We can create an istio config (VS and DR) to stop traffic from going in some particular connection to some service without deleting the pod on Kiali UI.
- We can right click on that service on Kiali UI and choose 'Suspend traffic' option. It would automatically create VS and DR k8s yaml file for that service to stop/suspend traffic to that service.

### Jaegar
- Jaegar is used to view traces similar to datadog. Traces help to visualise request lifecycle.
- The x-request-id header has to sent in the request header by every service called for a particular request so as to stitch traces.
- For this we would have to make changes in application code to propagate this header to other downstreams, if istio proxy container doesn't get this header from the app container then it would generate a new x-request-id and trace-stitching for this request would break.
- To leverage distributed tracing feature of Istio, it requires us to make app level change to propagate this header.

## Traffic Management

### Canary release
- We deploy a new version of a software components (for us, new image) but only make that new image "live" for a percentage of the time. 
- Most of the time, the old (definitely working) version is the one being used.

#### Achieving it using K8s deployment yaml
- To implement canary via k8s, we can create 2 deployment objects - 1 would have pod running on old version and other would have pod running on new/canary version. The label given to pods managed by both the deployments would be the same so that the service object, which would have selector set to that label, can route traffic randomly (mostly round-robin) to any of the pod - be it old or canary.
- So we can have some traffic going to lets say 3 pods of old version and 1 pod of new/canary version. 
- Istio would help to route any % of traffic to canary version which isn't possible as of this solution.
- We can create weighted routing for the service on Kiali UI console, here in we can mention what % of traffic has to goto what workload (deployment - old and canary), this automatically create VS and DR yaml and applies to the cluster.

#### Virtual Service
- It allows us to apply traffic rules for custom routing, and re-configure the proxies.
- VS is managed by istiod and allow us to re-configure/override envoy proxy configuration to achieve things such as intelligent traffic management.

Note:
- If we are calling service in another namespace then we need to use fully qualified domain name of service: <service-name>.<namespace-name>.svc.cluster.local. K8s documentation recommends to always use the fully qualified domain name.
- In host field of VS, we should always mention the fully qualified dns name for service instead of just the service name.

#### Destination Rule
- Istio via envoy can implement far more sophisticated load balancing (compared to service LB) and we can influence that LB, we configure that LB using DR.
- DR: Configuration of a LB for a particular service.

```
kind: VirtualService
apiVersion: networking.istio.io/v1alpha3
metadata:
  name: a-set-of-routing-rules-we-can-call-this-anything  # "just" a name for this virtualservice
  namespace: default
spec:
  hosts:
    - fleetman-staff-service.default.svc.cluster.local  # The Service DNS (ie the regular K8S Service) name that we're applying routing rules to, i.e. which incoming host are we applying the proxy rules to?
  http:
    - route:
        - destination:
            host: fleetman-staff-service.default.svc.cluster.local # The Target DNS name
            subset: safe-group  # The name defined in the DestinationRule
          weight: 90
        - destination:
            host: fleetman-staff-service.default.svc.cluster.local # The Target DNS name
            subset: risky-group  # The name defined in the DestinationRule
          weight: 10
---
kind: DestinationRule       # Defining which pods should be part of each subset
apiVersion: networking.istio.io/v1alpha3
metadata:
  name: grouping-rules-for-our-photograph-canary-release # This can be anything you like.
  namespace: default
spec:
  host: fleetman-staff-service # Service
  subsets:
    - labels:   # SELECTOR.
        version: safe # find pods with label "safe"
      name: safe-group
    - labels:
        version: risky
      name: risky-group
```

#### Summary
- VirtualService, managed by istiod, is used to reconfigure the envoy proxy by setting routing rules i.e DestinationRule for a host/service, leading to a more intelligent/sophisticated traffic management which is % based.
- In example, whenever this fleetman-staff-service service is called, the traffic to this would be routed as per VS created for this service.

## Load Balancing

- Don't try to mix weighting (% based traffic management) and stickiness.
- When a request comes, first the weighting rules are applied and then request goes to the target workload so stickiness won't come into picture by then.
  - This stickiness is configured at LB level which has done traffic routing on basis of %.
- Load balancing policies to apply for a specific destination. See Envoy’s load balancing documentation for more details: https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/load_balancing/load_balancing
- Consistent Hash-based load balancing can be used to provide soft session affinity based on HTTP headers, cookies or other properties.

Note:
- Consistent hashing: It is useful incase we want to route requests on basis of a hash value, computed for request, to any of the servers. 
  - It can help in such a way that a specific request (having hash computed on request headers / source ip) always lands on a specific server, so if we have cached something related to that request on earlier server (that would be required later) then performance-wise it is better to use the same server, however in k8s we shouldn't rely on this because the pods/node can get re-scheduled.

## Gateway

### Introduction
- Ingress GTW - Used to expose multiple services to outside world without needing expensive load balancers. In Ingress GTW, we define custom routing rules to expose different services to outside the cluster, there is an ingress controller present in every cluster in the master node which is used to implement these rules, each cloud provider has its own.
- In istio service mesh, a better approach is to use a different configuration model - Istio gateway, this gateway allows istio features such as monitoring and route rules to be applied to traffic entering the cluster.

### Edge Proxy
- If we have traffic coming into the cluster then we would need edge proxy, this edge proxy would listen to requests coming from the outside world. And we can configure this edge proxy such as traffic management -- otherwise if we are directly trying to hit the service then by-default the traffic is routed equally to all pods.
- The concept of istio gateway is there to do exactly that - it allows us to configure edge proxy.
- Istio comes up with a pod for istio ingress gateway.

```
kubectl get pod -n istio-system
kubectl get svc -n istio-system
```

### Configuring VS for Istio GTW
- The hosts field in VirtualService tells - which incoming host are we applying the proxy rules to? 
  - For the frontend service lets say web-app service, hosts should be - web-app-service itself (so that any incoming request to this service is routed by proxy container as per configuration) 
  - ... and the ingress-gateway host (so that any incoming request by this host is also routed by proxy container as per configuration).
  
### Important Node
- The proxies run after a container makes a request.
- Istio gateway becomes essential if we want to apply custom traffic rules to any service which are on the edge i.e. any service which is accessed directly from outside the cluster or the first service in the chain which is being accessed.
- Istio Ingress GTW example:
```
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: ingress-gateway-configuration
spec:
  selector:
    istio: ingressgateway # use Istio default gateway implementation
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"   # Domain name of the external website
---
kind: VirtualService
apiVersion: networking.istio.io/v1alpha3
metadata:
  name: fleetman-webapp
  namespace: default
spec:
  hosts:      # which incoming host are we applying the proxy rules to???
    - "*" # Copy the value in the gateway hosts - usually a Domain Name
  gateways:
    - ingress-gateway-configuration
  http:
    - route:
        - destination:
            host: fleetman-webapp
            subset: original
          weight: 90
        - destination:
            host: fleetman-webapp
            subset: experimental
          weight: 10
```

### Prefix, Sub-domain and Headers based routing
- https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPMatchRequest
- VS for istio ingress gateway is configured to do prefix uri based routing:
```
kind: VirtualService
apiVersion: networking.istio.io/v1alpha3
metadata:
  name: fleetman-webapp
  namespace: default
spec:
  hosts:      # which incoming host are we applying the proxy rules to???
    - "*"
  gateways:
    - ingress-gateway-configuration
  http:
    - match:
      - uri:  # IF
          prefix: "/experimental"
      - uri:  # OR
          prefix: "/canary"
      route: # THEN
      - destination:
          host: fleetman-webapp
          subset: experimental
    - match:
      - uri :
          prefix: "/"
      route:
      - destination:
          host: fleetman-webapp
          subset: original
```
- Example for subdomain based routing:
```
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: ingress-gateway-configuration
spec:
  selector:
    istio: ingressgateway # use Istio default gateway implementation
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*.fleetman.com"
    - "fleetman.com"
---
...
spec:
  hosts:
    - "fleetman.com"
  gateways:
    - ingress-gateway-configuration
  http:
    - route:
      - destination:
          host: fleetman-webapp
          subset: original
---
...
spec:
  hosts:
    - "experimental.fleetman.com"
  gateways:
    - ingress-gateway-configuration
  http:
     - route:
        - destination:
            host: fleetman-webapp
            subset: experimental
```
- Example for header based routing:
```
kind: VirtualService
apiVersion: networking.istio.io/v1alpha3
metadata:
  name: fleetman-webapp
  namespace: default
spec:
  hosts:      # which incoming host are we applying the proxy rules to???
    - "*"
  gateways:
    - ingress-gateway-configuration
  http:
    - match:
      - headers:  # IF
          my-header:
            exact: canary
      route: # THEN
      - destination:
          host: fleetman-webapp
          subset: experimental
    - route: # CATCH ALL
      - destination:
          host: fleetman-webapp
          subset: original
```

## Dark Release

- This uses headers based routing feature of istio proxy.
- Dark release - How to exploit Istio to allow you to potentially release software without testing it first?
- Although we have got a untested micro-service (canary) in our live cluster but normal users can't access it, only if specific header is passed (lets say by some tester) then only that untested micro-service would be called, this is how we would be able to test unreleased changes in live cluster.
- For above to happen, we are using header based routing in VirtualService for the istio ingress gateway (which would initially receive the header) -- optional
- and propagate that header to the untested/canary version of micro-service, we would again be using header based routing (using VirtualService) having host as that service and route traffic to tested or untested version on basis of that header.

## Fault Injection

### Introduction
- We can introduce delays and faults in micro-service using VS having host as service dns for that micro-service, this could help test the fault-tolerance of system.
```
kind: VirtualService
apiVersion: networking.istio.io/v1alpha3
metadata:
  name: ftv
  namespace: default
spec:
  hosts:
    - ftv
  http:
    - fault:
        abort:
          httpStatus: 503
          percentage:
            value: 100
      route:
        - destination:
            host: ftv
```
- Another example:
```
kind: VirtualService
apiVersion: networking.istio.io/v1alpha3
metadata:
  name: fss
  namespace: default
spec:
  hosts:
    - fss
  http:
    - match:
        - headers:
            x-my-header:
              exact: canary
      fault:
        delay:
          percentage:
            value: 100.0
        fixedDelay: 10s
      route:
        - destination:
            host: fss
            subset: risky
    - route:
        - destination:
            host: fss
            subset: safe
```

### Chaos Engineering
- Fault injection is a kind of chaos engineering - We are injecting faults (delays or abort) into the system, this can help test the fault-tolerance of the system.
- https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPFaultInjection
- We can write a script that once a day picks a service at random and generate a VS file for that with a fault in such as abort or delay and apply it to the cluster, lets say for 10 mins and then delete that change.
- If our architecture can withstand the temporary loss of some service, for a short period, then we would be building fault-tolerant micro-service architecture.
  - Using VS in Istio, we have a very simple way of throwing faults in a system.

## Circuit Breaker

### Introduction
- Network is unreliable, there will always be failures and we need wherever possible to design to be fault tolerant.
- In distributed architecture and in k8s based systems is a cascading failure - any failure where one or few parts can trigger failure of other parts.
- Circuit breaker would relay the call to target micro-service, and on basis of status code from target would close the circuit if required.
- The circuit breaker would re-open the circuit incase it feels that the struggling target micro-service is back up running.
- With circuit breaker, we have a fail-fast mechanism, its better for the requests to fail immediately as they were going to fail anyways rather than having requests holding n/w resources for 30+ seconds when they were never going to succeed.
- In micro-service architecture, we should have good fallbacks, so when circuit breaker returns its error then the micro-service would degrade gracefully.

### Using Istio for Circuit Breaker
- We know all our micro-service network traffic is relayed through sidecar proxies, so therefore we could build a circuit break logic in the proxy instead of micro-service. 
- The envoy proxy already have a circuit breakers built-in, its just for us a case of configuring them.

### Scenario
- In k8s system, all traffic would be routed through proxies, the traffic would be by-default load balanced by the service 50-50, now if any pod is struggling for some reason (no matter why - hardware issue or bad code) - the circuit breaker's logic is simply that if there a certain number of consecutive failures coming from a particular pod (like a pod has returned 3 consecutive 503 in a row in a very short period of time), the circuit breaker's logic is then to stop load balancing to it, it would simply stop sending requests to that pod, it will continue to send requests to the other pod.
- It's important to remember that circuit breaker works on a pod level and not on service level.
- There's a configurable interval where circuit breaker is going to check again (like 5 minutes) to struggling replica, if that pod is recovered then circuit breaker would be happy and continue to load balance traffic but if the situation is same like - pod has returned 3 consecutive 503 in a row in a very short period of time then again proxy would remove that struggling pod from the load balancing it is doing for the service.
- If its relatively easy to build and use circuit breakers on our architecture, have circuit breakers, it was hard traditionally since we had to load hystrix into every single micro-service, if we are using istio then its fairly simple to switch the circuit breaker on, we never know it gonna save us from a cascading failure in future.
- We got to tune this circuit breaker properly. Any micro-service architecture should be using circuit breakers.

#### Important Note
- Circuit breaking isn't really there to mitigate against bad code that you are deploying, it could be sometimes, but most cascading failures are caused by environmental problems - a node running out of memory, something wrong in network stack somewhere or something we can't even reason about.

### Outlier Detection
- Outlier detection = circuit breaking as per Istio docs.
- For any service, we need to write circuit breaker for, we need to write a destination rule.
- We need VS config when we are doing custom routing, we need a DR when we are configuring the load balancer.
- For CB, we are only configuring the LB hence only DR needs to be configured for the service's LB.
- Docs Link:
  - https://istio.io/latest/docs/reference/config/networking/
  - https://istio.io/latest/docs/reference/config/networking/destination-rule/
- Circuit breaker need to be switched on, without trafficPolicy.outlierDetection yaml block - we won't get a circuit breaker for a particular service.
- Example:
```
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: circuit-breaker-for-the-entire-default-namespace
spec:
  host: "fleetman-staff-service.default.svc.cluster.local" # This is the name of the k8s service that we're configuring
 
  trafficPolicy:
    outlierDetection: # Circuit Breakers HAVE TO BE SWITCHED ON
      maxEjectionPercent: 10
      consecutive5xxErrors: 2
      interval: 10s
      baseEjectionTime: 30s
```

#### Understanding Params for CB
- consecutive5xxErrors: Number of 5xx errors before a host is ejected from the connection pool. This feature defaults to 5. Consecutive errors from same pod.
- interval: Time interval between ejection sweep analysis. format: 1h/1m/1s/1ms. MUST BE >=1ms. Default is 10s.
- baseEjectionTime: Minimum ejection duration. A host will remain ejected for a period equal to the product of minimum ejection duration and the number of times the host has been ejected. This technique allows the system to automatically increase the ejection period for unhealthy upstream servers. Default is 30s.
- maxEjectionPercent: Maximum % of hosts in the load balancing pool for the upstream service that can be ejected. Defaults to 10%.

## MutualTLS

### Introduction
- By default, simple HTTP is used for communication between the pods and the traffic is not encrypted.
- Without Istio, implementing HTTPS inside the cluster would a nightmare, we would have to made sure that every single micro-service is coded to send HTTPS traffic and we would be issuing certificates to every single pod.
- If we are doing a multi-availability zone deployment then our request could be leaving from one data centre (us-east-1a) to another data centre (us-east-1b).
- Even with same availability zone, there is a non-zero probability of traffic leaving the building. Even if it's the same building, the employee in that building are able to intersect that traffic as it moves between racks inside that data centre.
- For any passwords or credit card data, we should be upgrading our cluster so that all traffic inside the cluster is HTTPS.

### How does Istio implement?
- Istio-d has a component (citadel), it is responsible for ensuring that the proxies are all configured with correct certificates needed to allow secure traffic b/w the two.
- Proxy to proxy communication is using mTLS (mutual TLS), which is a lower level protocol that HTTPS builds upon, in this the source/client proxy and target/server proxy would verify each other identity using certificates issued by citadel (part of istiod).

Q. How does istio implement?
- Enforce a policy that BLOCKS all non-TLS traffic.
- Automatically upgrade all proxy to proxy communication to use mTLS.

### Automatically Enabled
- TLS is automatically switched on for pod-to-pod traffic by default in current versions of Istio.
- So even if our service is doing http calls to other services in the code, but the proxy that is intercepting that traffic is automatically upgrading it to TLS.

### Strict and Permissive mTLS
- Strict mTLS - If the connection cannot be upgraded and that would be because we have an unencrypted HTTP call coming from a client, which does not have an istio proxy, if the connection cannot be upgraded then it would be rejected. This is to ensure we don't allow non-TLS connection to the istio proxies.
- By default Istio uses permissive mTLS i.e. if it cannot automatically upgrade the connection from client, it would allow non-TLS connection to the istio proxies however it would be an insecure call.
