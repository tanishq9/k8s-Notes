## k8s Architecture

master / control-plane: 1 or more (for prod env for HA)
- api-server: APIs for clients to talk to the cluster and create workloads.
- etcd (et-c-d): A distributed key-value store to store cluster data.
- controller-manager: A process which continuously monitors workloads/nodes, etc.
- scheduler: Workload scheduler. 

Note: If controller-manager observes any anomaly i.e. running pods != desired pods then it will use scheduler to schedule more pods.

worker node (upto 5000)
- kubelet: An agent which creates containers and monitors.
- container runtime (docker)
- kube-proxy: Maintains n/w rules on the node for communication among workloads in the cluster.

Note: 
- Scheduler will pick nodes where to create pods, api-server would inform kubelet (waiting for instruction from master) to create pods/instances of application.
- kube-proxy is for routing requests between containers running across different nodes.

kind cluster:
- To set up a k8s cluster for learning.
   - https://kind.sigs.k8s.io/
   - https://kind.sigs.k8s.io/docs/user/quick-start/#configuring-your-kind-cluster
- kubectl: CLI tool to interact with k8s master/api-server.
   - kubectl version --output=yaml: This gives client and server version.
   - kubectl get nodes
   
kube Config file:
- A config file to organise cluster info.
- Default path: $HOME/.kube/config. kubectl looks for master (api-server) info in config file under this location.
- environment variable KUBECONFIG = /a/b/c

Note: containerd - container runtime

## Pod

- Smallest deployable unit of k8s.
- Pod can run one or more containers, only one of the containers is app container, other containers are helpers.
- In docker world, each docker container represents a VM and is given an IP address.
- In k8s world, each pod represents a VM and containers running inside the pod represent a process so each pod is given an IP address and multiple containers can run inside that pod.
- Inside the pod, the containers can talk just by using localhost, it needs to know the port number however.
- https://kubernetes.io/docs/concepts/workloads/pods/
- https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/

### k8s resource yaml format

- apiVersion: [api version]
- kind: [k8s workload type]
- metadata: [name for your resource, additional labels]
- spec: [this will change depends on the workload type]
- Pod: https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/

```
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: nginx
    image: nginx
```

kubectl get [resource]
- kubectl get pod

kubectl describe [resource]
- kubectl describe pod

### Describing Pod

By describing the pod, we saw the events and got to know that is how pod was created:
- We will use kubectl to talk to api-server in master/control-plan.
- api-server will ask scheduler for the node assignment to the pod. From scheduler logs: Successfully assigned default/my-pod [POD] to dev-kind-worker2 [NODE]
- Once node has been assigned, kubelet running on worker node create container inside pod (first pull image).
- kubelet will throw ImagePullBackOff / ErrImagePull error in case the image is not found in the registry.
- If the container exits with error then kubelet would try to restart it, it this happens frequently then pod would have CrashLoopBackoff status.

### Pod Labels

- We might be having lots of pod, sometimes we want to query pod, label would help us.
- Label is part of metadata and consists of key-value pairs.

### Some commands

To get a particular pod status:
- kubectl get pod <pod-name>

To describe a particular pod:
- kubectl describe pod <pod-name>

To get a pod by label(s):
- kubectl get pod <pod-name> -l label1=value1,label2!=value2

To get more details about pod like which node runs that pod:
- kubectl get pod -o wide // o is shorthand for --output

To get yaml file of pod:
- kubectl get pod <pod-name> -o yaml

To switch to other cluster:
- kubectl config use-context <cluster-name>

```
kubectl get pod/<pod-name>
Actually above applies to any 'kind', Pod is one such 'kind':
kubectl get <kind>/<resource-name>
```

### Port forwarding

Port forwarding: Technique to create a tunnel between pod and local machine via api-server (using kubectl) to access the pod.

```
apiVersion: v1
kind: Pod
metadata:
name: my-pod
spec:
containers:
- name: nginx
  image: nginx
  ports:
   - name: "web-port" # we have to give name for the port
     containerPort: 80
     protocol: TCP # this is the default as well
```

kubectl port-forward <pod-name> <port-on-local-machine>:80

80 is the port of pod we are forwarding traffic to from localhost:<port-on-local-machine>


### Restart Policy

For the containers which are not always supposed to always run and exit after their work has been done, for such containers, the pod will keep restarting thinking it's a failure. For such containers, we can set restartPolicy value.

```
apiVersion: v1
kind: Pod
metadata:
name: my-pod
spec:
restartPolicy: OnFailure # Always, Never, OnFailure (only if failure then restart, if completed then don't restart)
containers:
- name: ubuntu
  image: ubuntu
```

### Pod Container Logs

- args field is equivalent to exec command in docker basically some command which would be executed when pod is created.
- To get logs of a pod: kubectl logs <pod-name>

To explore pod (similar like we do for docker container):
- kubectl exec -it <pod-name> bash
- exec will default to some default container running inside that pod. If only one container is running then it be defaulted to that else it would be first container mention in order, therefore it is better to mention the container as well in such scenario:
- kubectl exec -it <pod-name> -c <container-name> bash
- To get logs of particular docker container running inside a pod:
- kubectl logs <pod-name> -c <container-name>

### Termination Grace Period

- By default, k8s waits for 30 seconds before it terminates the pod (when the delete pod command is executed).
- The way the grace period works is that the main docker process is immediately sent a SIGTERM signal, and then it is allowed a certain amount of time to exit on its own before it is more forcefully shutdown. If your app is quitting right away, it is because it quits when it gets this signal.
- Your app could catch the SIGTERM signal, and then quit on its own after all the open operations complete. Or it could catch the SIGTERM signal and just do nothing and wait for it to be forced down a different way.
   - https://stackoverflow.com/questions/50627308/terminationgraceperiodseconds-not
- In short, when a SIGTERM signal is issued on delete command then pod is allowed to exit on its own before terminationGracePeriodSeconds otherwise it would be forcefully shutdown.

### Multi container pod

- Each docker container is like a VM (doesn't have its own OS, instead use host system OS) having their own IP address and exposed ports. And if one docker container wants to talk to other docker container then we should know that container's IP and port or container name (if in same docker network).

```
2023/01/28 13:02:37 [emerg] 1#1: bind() to 0.0.0.0:80 failed (98: Address already in use)
```

- However Pod is also a VM and each docker container running inside it is treated as a process. So if more than 2 containers (process) are trying to listen on same port (80) then that won't be possible. So 2 processes exposing same port cannot be run in a k8s pod.

```
apiVersion: v1
kind: Pod
metadata:
name: my-pod1
spec:
containers:
- name: nginx1
  image: nginx
- name: nginx2
  image: nginx
```

- We can access other processes (containers) inside a pod (from inside the pod) since all are running inside same host/pod via localhost.

Note:
- No docker image consist of kernel as docker install/uses linux kernel on its own (Docker needs linux kernel to work).
- Ubuntu docker image doesn't include kernel, it just brings in layer to be used on top of linux kernel provided by docker.
   - https://stackoverflow.com/questions/56645286/did-the-base-os-image-ever-contain-a-linux-kernel-to-begin-with#:~:text=Docker%20image%20never%20includes%20the,tar%20archive%20and%20extract%20it


## ReplicaSet

- Manages pod.
- It ensures that our desired replicas for the given pod spec are running.
- How does it ensure this?
   - ReplicaSet has 1 controller running as part of controller-manager (part of master node) which monitors the cluster and ensures desired number of instances are running.
   - ReplicaSet -> restartPolicy:Always
- If we are not managing desired replica count via ReplicaSet and were doing via Pod (created Pod manually) then if that Pod would have been killed (due to node becoming unavailable, hence no kubelet to create container on that node) then it would't have been recreated.
- etcd -> k8s resource info is queried from here.
- In order to tell clearly what to manage (by what resource), we will be using labels concept i.e. metadata.labels.
- In selector/matchLabels field , we mention the label key-value pair and the replica count according to which pod would be created or terminated.
- https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/replica-set-v1/


## Deployment

- DeploymentSpec = ReplicaSetSpec + additional properties
   - https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/deployment-v1/#DeploymentSpec
   - Analogy in terms of Java: Consider Deployment as an child class of ReplicaSet, so Deployment inherits all properties of ReplicaSet and also adds some additional behaviour on top of that.
- When we update PodTemplateSpec i.e. the app/workload config then a new revision is created for k8s deployment, in this case, deployment would create a new replica set and the corresponding pods.

### Rollout History

To view different versions of deployment:
```
kubectl rollout history deploy <deploy-name>
```

To rollback to some last version of deployment:
```
kubectl rollout undo deploy <deploy-name>
```

To rollback to a specific version of deployment:
- We can add kubernetes.io/change-cause in metadata/annotations to provide info about change-cause for the deployment rolled out.
- The kubernetes.io/ and k8s.io/ prefixes are reserved for Kubernetes core components.
- https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/

To rollback to a specific revision:
```
kubectl rollout undo deploy/my-service-deploy --to-revision=3
```

Having change-cause set for each revision would help when rolling back to some specific revision.

### Min ready seconds

- minReadySeconds: Property of DeploymentSpec. The number of seconds the deployment takes to become available to serve traffic essentially this is the time app takes to boot up.
- Probes is a better way to do this^


### Deployment Strategy

Deployment strategy: 2 types
- Recreate: terminate the old pods (v1) and then create the new pods (v2).
- RollingUpdate: gradually roll out the changes, we can have a mix of old and new pod temporarily, below properties can be a number or % - maxSurge (max number of additional pods that can be created) and maxUnavailable (max number of pods that can be terminated).
- https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/deployment-v1/#DeploymentSpec
- Default is RollingUpdate with maxSurge and maxUnavailable being 25%.
- Example: If desired replica count is 4, then during rollout, we can have maximum pods as 5 and minimum pods as 3.

## Service

- Logical abstraction for a set of pods and expose them via a single reliable network endpoint.
- When we create a service, we get a stable ip address and also a service name which can be used to route traffic to appropriate pods we want to.
- https://kubernetes.io/docs/reference/kubernetes-api/service-resources/service-v1/#ServiceSpec
```
apiVersion: v1
kind: Service
metadata:
name: my-service
spec:
selector:
app: my-app # Route service traffic to pods with label keys and values matching this selector.
ports:
- port: 80 # The port that will be exposed by this service.
  targetPort: 80 # Number or name of the port to access on the pods targeted by the service.
```

- A default service called kubernetes is already present in the cluster, this service is for talking to api-server (within the cluster), if any pod wants to talk to api-server internally then they can use this service endpoint. 
- We can check kubectl get pods -o wide and delete a particular pod, we will observe that an IP address is deleted from endpoints part of service and another IP address is added in endpoints part of service, we can observe it by watching our service continuously, we can use watch -tx kubectl describe svc/my-service

### Kube-proxy

- kube-proxy runs inside every worker node, it maintains IP table/rules that any request comes to a service via its name or ip then where the requests (which pods) the request could be forwarded to.
- Service is a simple proxy, does not consume any memory/cpu, doesn't do round-robin LB, it is random and sends request to a healthy pod only (how does it know pod is healthy or not? tbd).
- Service is not used for path based routing, for that we have ingress.
- Service [ClusterIP] is accessible only within the cluster.

### Service Types

- ClusterIP: For communication within the k8s cluster. Cannot be accessed from outside the cluster. This is the default and mostly this is what we would use.
- NodePort: Can be accessed from outside via k8s master/nodes via specific port, it is used for testing purpose. In this, we will be opening a port on each and every machine in the cluster, so we will sending request to that port and it will forward it to service and pods.
   - Allowed node port ranges are 30000-32767.
- LoadBalancer: To be used in AWS/GCP cloud providers. Can be used to receive traffic from outside. In cloud, a ALB/NLB would be created by cloud provider itself for the service k8s object.


## Namespace

- Virtual cluster/partitioning within a cluster.
- Used to isolate team resources or Dev/QA environments.
- We can have same resource name in different namespaces but obviously not in same namespace. 
- To create namespace in k8s cluster: kubectl create ns <namespace-name>
- To get pods in a particular namespace: kubectl get pod -n <namespace-name>
- To create/update deployment or resource in a particular ns: kubectl create/apply -f <file-name.yaml> -n <namespace-name>
- Alternate way is to add namespace key inside metadata of the resource so that it gets created in that particular namespace rather than us mentioning namespace in the kubectl command every time.

## Probes

Problem: Pods are considered to be live and ready as soon as the containers are started.
   - Docker container may be started but that doesn't mean that app inside is actually started, Spring takes some time to create bean and get ready.
   - If the pod is ready, the service will send requests to the pod and rollingUpdate will terminate the old pods.
   - We should ensure that our pods are live and ready to avoid surprises.

Probes:

- Probes are tools/utilities to measure the health of the pod.
   - Has the app inside pod has started?
   - Is it alive?
   - Is it ready to serve requests?

### Probe Types

Probes specific terms:

- Live: Is the pod alive?
- Ready: Can the pod service the request? Basically is app inside pod ready? Example the DB that app interacts with is down, in that case, app is not ready (health check for app fails) but pod is alive.

Probe types:

- startupProbe: To check if the app inside container has started, example springboot application has started listening on port 8080, if this probe fails then container is restarted.
- livenessProbe: To check if app is still alive. Sometime app may be running but not alive. If this probe fails then container is restarted.
- readinessProbe: To check if app is ready to take the requests from service. If this probe fails then pod is removed from service temporarily.

### Probe execution phase

Probe execution phase:
- startupProbe: It starts as soon as container started. If this check passes, then startupProbe stops.
- livenessProbe: It starts once startupProbe completes. It is executed throughout the pod lifecycle.
- readinessProbe: It starts once startupProbe completes. It is executed throughput the pod lifecycle.
- Probes are executed by kubelet: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/


### Probe checking

- exec: Execute any command to check, for ex: cat /tmp/app.log
   - Check is passed if command is successfully executed.

- httpGet: To invoke a http endpoint, for ex: /health.
   - Used for web application.
   - Check is passed if 2xx http status code is returned.

- tcpSocket: To check if the app started listening on a specific port.
   - Use for app which listen on port like DB.
   - Check is passed if port is open.
   
### Probe properties

Each probe has some properties:

- initialDelaySeconds: After how much time to start this probe?
- periodSeconds: How often the probe has to do the check?
- timeoutSeconds: To get response from exec/httpGet/tcpSocket
- successThreshold: How many consecutive success response should I get to confirm it passed?
- failureThreshold: How many consecutive failure response should I get to confirm it passed?


Note:
- Till the time startupProbe or livenessProbe (incase startupProbe is not there) is not successful once (successThreshold is 1 for these 2 type of probes, can't be more), even if container is started (first time) or restarted (after lets say livenessProbe failure), the pod won't be listed in service endpoints.
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/


## ConfigMap & Secret

- To keep the config data separately from the application.
- ConfigMap
   - non-sensitive data like application.properties
- Secret
   - sensitive data like credentials

In ConfigMap,
- Properties as key/value
- Properties as file
- Store any binary file
- Max size is 1 MB.

Benefit: k8s can give whole file content in docker container in any location we like.

Note:
- ConfigMap is stored in etcd (on master node) and when Pod want ConfigMap as env vars (using envFrom or valueFrom) or as file (using Volume), it is injected wherever the Pod is running.

In Secret,
- Same as ConfigMap - but for sensitive data.
- Value is base64 encoded.
- Use cases - ssh key files, basic credentials, service accounts, etc
- k8s admin can restrict only certain users to have access to these Secret object, not everyone should be having access to these Secret objects however everyone can have access to ConfigMap objects.
- Secret are stored in etcd as well and when Pod can inject these.

## HPA

Consequences of exceeding resources limit:
- Memory: Kubelet will kill the container and restart.
- CPU: Container will NOT be killed. Throttled (more cpu cycles won't be allocated in that 100ms period), which may slow down app performance but container won't be killed, CPU restriction is a flexible restriction and pod/container would be forgiven.

kubectl top command can be used to get memory and CPU usage.
- kubectl top pod
- kubectl top node

Metrics server needs to be installed in k8s cluster, doesn't come by default. Important to have if we want to scale the pods based on CPU utilisation.

```
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: [ ? ] 
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: [ ? ]
  minReplicas: [ ? ]
  maxReplicas: [ ? ]
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: [ ? ]
  - type: Resource
    resource:
      name: memory
      target:
        type: AverageValue
        averageValue: [ ? ]    
  behavior: 
    scaleDown:
      stabilizationWindowSeconds: [ ? ]
```

Values to provide:
- Deployment name, which HPA will monitor.
- The min and max replica are the min and max pod count, depending on load, pod count can scale up to max.
- Metric value threshold like for resource/memory or resource/cpu.
- stabilizationWindowSeconds: The stabilization window is used to restrict the flapping of replica count when the metrics used for scaling keep fluctuating. When the metrics indicate that the target should be scaled down the algorithm looks into previously computed desired states, and uses the highest value from this specified interval. This approximates a rolling maximum, and avoids having the scaling algorithm frequently remove Pods only to trigger recreating an equivalent Pod just moments later.
- https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#stabilization-window

Note: ClusterAutoscaler would add more worker nodes to cluster when it sees pods are in pending status due to lack of nodes.

## Ingress

Service recap:

- ClusterIP: For within the cluster (pod to pod) communication.
- NodePort: Expose service (and its underlying pods) via node port
- LoadBalancer: Used in cloud (AWS/GCP), etc.

NodePort and LoadBalancer is used to expose app outside the cluster, but here we are exposing only a set of pods via service like user service app or product service app.

Can we access all services via a single domain name or host name like we do in API gateway using path-based routing? Yes, ingress.

Drawback of LB approach: We don't want to create LB for each micro-service that we have.

- Ingress contains a set of rules, when it receives the request, based on path, it can route the traffic to corresponding ClusterIP service.
- Ingress can route traffic within the cluster.

### Ingress Controller

- Ingress contains a set of routing rules.
- We need Ingress Controller to manage Ingress.
   - All controllers are packaged as a single binary and run in controller-manager in master node.
   - Ingress Controller is an add-on and needs to be explicitly added and depends on the cluster we have.
      - For kind cluster, we have to add Ingress Controller which would work for kind.
      - If you are going to use GCP/EKS, cloud provider would have already added Ingress Controller.
      - Ingress Controller has multiple implementations, we have to choose what would work for us.
      - Ingress Controller implements the rules while Ingress contains the rules.
- https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/


Note:
- NGINX Ingress controller (other ingress controller can behave differently) would be consolidating all ingress rules created across different namespaces, if a path is already taken, controller won't allow another ingress rule for same path.
- We can use host in the rule incase route is common.

Summary:
- Ingress: Contains routing rules.
- IngressController: Implements routing rules like nginx ingress controller.

## Persistent Volume

Persistent Volumes (PV):
- Storage abstraction/Volume plugin.
- Provides storage: Similar to node in the cluster which provides CPU/Memory.

Terminologies:
- Storage class: Type of storage, each storage its performance characteristics.
   - Example: GCP PD standard.
- Persistent volume claim (PVC): Request to create PV. Resource which links PV and Pod.
   - Example: Request to create 5GB of GCP PD standard for the application.
- Persistent volume: Actual storage created for a specific storage class.
   - Example: 5GB of GCP PD standard.
- https://kubernetes.io/docs/concepts/storage/storage-classes/

PV can be provisioned in 2 different modes:
- It consists of predefined storage class, defined by k8s admin.

Static provisioning
- Persistent volumes are created in advance by the k8s admin.
- Only these volumes of these storage class can be claimed.

Dynamic provisioning
- Volumes can be created on demand.

Access Modes: It is to tell k8s in which mode is storage attached to the node.
- ReadWriteOnce (per node): Storage is attached to node and pods running on it can rw to storage. One RW storage per node.
- ReadWriteOncePod (per pod):  Storage is attached to node and only one pod in that node can rw to storage. One RW storage per pod.
- ReadOnlyMany: One RO storage for all pods (across all nodes).
- ReadWriteMany: One RW storage for all pods (across all nodes).

### Some Commands

To view storage class in cluster:
kubectl get sc

To view PVC (Persistent Volume Claim):
kubectl get pvc

To view PV (Persistent Volume):
kubectl get pv

Reason for PVC to be in pending state:
- WaitForFirstConsumer
- Controller and Message details: persistentvolume-controller: waiting for first consumer to be created before binding

Important: Once a pod is using that volume (we specify in this volumeMounts) then only PV is created corresponding to the PVC so that the pod(s) can leverage it.

### Reclaim policy
- By default the reclaim policy for PV is delete i.e. if PVC is deleted then PV is also deleted, we can set it to retain if we want to retain PV even after PVC deletion.
- Default access mode is RWO (ReadWriteOnce - All pods running on same node with access same storage for RW).

## StatefulSet

- In SS, the pods are not controlled by replica set
- All pods are given fixed names and are indexed
- Example: mongo-db-pod-0, mongo-db-pod-1, etc depends on replicas count
- Particularly used in scenarios when we want to route request to a specific pod always (make it predictable)

Headless Service:
- Required for SS, in this case svc won't have a IP address infact it won't have a DNS entry
- To access the pod this service points, we would have to use: pod_name.svc_name
- For StatefulSet, when we use this headless service then each replica in that SS gets a different access identifier like: pod-1.mongo-svc, pod-2.mongo.svc, ... Now based on internal logic we can route request to any of the pod
- clusterIP: None has to be specified like this in Service.

Note:
- Recommendation: Use Ingress to route traffic from outside into the cluster and ClusterIP type service to route traffic internally in the cluster.
- LB type service can also be used to expose one specific service to outside cluster.
