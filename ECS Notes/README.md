### ECS Objects
- Task definition
- Cluster
	- Types - Fargate (Serverless), EC2 + Linux, EC2 + Windows.
- Service
- Task

### Introduction

- Container Definition: Nothing but the container image and container level settings (example: container image, port, registry, environment variable to pass to container, etc)

- Task Definition: A task definition is a blueprint for our application and describes one or more container through attributes. Very few attributes are configured at the task level, but majority of attributes are configured per container. It is a combination of multiple container definitions if we are using more than one container image in a task.

- Service: A service allows you to run and maintain a specified number (the "desired count") of simultaneous instances of task definition in an ECS cluster.

- Fargate Cluster: The infra in a Fargate cluster is fully managed by AWS. Our containers run without we managing and configuring individual Amazon EC2 instances.

- Task: A task in the instantiation of a task definition within a cluster. After we have created a task definition for our application within Amazon ECS, we can specify the number of tasks that will run on our cluster (run task directly or configure to run from a service). Each task that uses Fargate launch type has its own isolation boundary and does not share the underlying kernel, cpu resources or memory resources with another task.

Note:
- Each ECS task has its own ip address, similar to k8s pod. Each task can be accessed via their public ip address.
- ECS Service is similar to ReplicaSet in k8s, which controls the number of replicas that needs to be running for each pod.
- https://www.simform.com/blog/aws-fargate-vs-lambda/
- https://github.com/stacksimplify/aws-fargate-ecs-masterclass


### Cluster Features

Cluster:
- We have 3 types of cluster templates
	- Fargate - Serverless
	- EC2 - Linux
	- EC2 - Windows
- An ECS cluster is a logical grouping of tasks or services.
- Clusters are region-specific.
- Clusters can contain tasks using both the Fargate and EC2 launch types.


Cluster Features:
- Services: A service allows you to run and maintain a specified number of simultaneous instances of a task definition in an ECS cluster.
- Tasks: A task is the instantiation of a task definition within a cluster.
- Scheduled tasks: Used primarily for long running stateless services and applications.
- Capacity provider: A capacity provider is used in association with a cluster to determine the infrastructure that a task runs on.


Task Definition:
- Task Role: IAM role that tasks can use to make API requests to authorized AWS services.
- Network Mode: For Fargate, the only option available is awsvpc, an IP address from VPC will be allocated to each task.
- Task Execution Role: This role is required by tasks to pull container images and publish container logs to Amazon CW.
- Task Size: The task size allows us to specify a fixed size for our task from memory and cpu perspective and accordingly billing would be happening. Only for Fargate launch type. Container level memory settings are optional when task size is set.
- Container definition:
	- Standard Settings
		- Container name
		- Image
		- Memory Limits (Soft/Hard)
		- Port Mappings
	- Advanced Container Configuration
		- Proxy and Logging Configuration

### Load Balancing and Auto-Scaling
- We can configure ECS service to use a LB so as to trigger service using LB's URL or IP rather than task IP.

Note:
- The IPv4 CIDR for VPC is the private IP address range which is allocated to services created in that VPC.
- To access the services from outside the VPC, we would need to use the public IP address.
- To ssh into EC2 server:
```
ssh -i <pem-file> ec2-user@public-ip-address
```
- To execute commands as root:

```
sudo su -
```
