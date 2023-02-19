# ord-ordering-service
##Kotlin Spring Boot application for GRPC services

[![Innersource Badge](https://img.shields.io/badge/innersource-expediagroup-00008d.svg)](https://confluence.expedia.biz/display/ISS/Inner-Source+Tech+Committee+Home)
[<img src="https://console.kumo.expedia.biz/v2/static/images/kumo-logo-darkbg.svg" width="90">](https://console.kumo.expedia.biz/apps/ord-ordering-service/pipeline)

[Contributing](CONTRIBUTING.md)

Welcome to your new app, feel free to edit this readme to suit your needs.

More comprehensive gRPC documentation on this template and the sdk it uses can be found at [https://go/stark](https://go/stark)

ONS - Order Notification Service`
By default all ONS APIs map to the VulcanProxyController.
It is a dynamic controller.

## Onboarding REST APIs to VulcanProxyController
1. In application-{environment}.yml add entry under proxy-configurations.proxyConfigurations
2. Values required are

   | Parameter | Description |
      | --- | --- |
   | path | request url that will be called by the client |
   | requestTemplate | construct rest request to vulcan |
   | responseTemplate | construct rest response that will be sent back to the client |
   | workflowConfig | identify vulcan workflow that needs to be called |

   requestTemplate Parameters

   | Parameters | Description |
      | --- | --- |
   | url | vulcan endpoint url |
   | path | url path used to call vulcan endpoint |
   | queryParams | query params to be added while calling the vulcan endpoint |
   | method | rest method to be used (GET, POST etc...) | 
   | headers | http headers to used | 
   | body | set request body while calling vulcan endpoint |

   responseTemplate Parameters

   | Parameters | Description |
      | --- | --- | 
   | headers | set http headers to be sent back to the client | 
   | body | set body to be sent back to the client |

   workflowConfig Parameters

   | Parameters | Description |
      | --- | --- |
   | clientId | vulcan workflow client_id |
   | operationName | vulcan workflow name |
   | version | vulcan workflow version to be called | 
   | includeTaskResults | whether task results are included in the response returned by vulcan or not | 

## Testing your app

### Running locally
There are a few options (from more flexible to least)

1. You can just use the SpringBoot run functionality that is default in IntelliJ or SpringTools in Eclipse

1. Start your application with Maven.
    ```bash
    mvn spring-boot:run
    ```

1. Package the jar file and run it

    ```bash
    mvn clean package
    java -jar target/<yourjar>.jar
    ```

#### Invoking your service

You can use you prefer gprc client for testing your app but this example will use [evans](https://github.com/ktr0731/evans). Your application is listening on por `6565` non TLS and it has reflection turned on so no need to have access to the protos (that is why evans is cool).

```bash
evans repl --reflection --host localhost --port 6565
```

By using REPL you can follow the prompts... if you are interested in [evans](https://github.com/ktr0731/evans) follow their instructions.

### K8s test environment

#### Endpoints

Once deployed to the test environment you will get to endpoints, one for your http traffic and one for your grpc service:

1. The HTTP endpoint scheme is: `https://[appname].kmc-default.[region].[env].[segment].expedia.com/` for example:

  ` https://ord-ordering-service.rcp.us-west-2.orders.test.exp-aws.net/`

1. The gRPC endpoint follows a very similar scheme: `[appname]-grpc.kmc-default.[region].[env].[segment].expedia.com` for example:

    ` ord-ordering-service.rcp.us-west-2.orders.test.exp-aws.net`

#### Invoking your service

You can use you prefer gprc client for testing your app but this example will use [evans](https://github.com/ktr0731/evans). The gRPC endpoint above can be hit with from the corporate network, the port is `443` and TLS is on, notice that the pem certificate for test is in this projects root directory. The first option below allows to to select your own package and service; whereas, the second option configures it for you. 

```bash
evans repl --reflection --host ord-ordering-service.rcp.us-west-2.orders.test.exp-aws.net --port 443 --tls --cacert devK8sCert.pem
```

By using REPL you can follow the prompts... if you are interested in [evans](https://github.com/ktr0731/evans) follow their instructions.


## JVM Performance Tuning

If you wish to do some performance tuning of your application via JVM command line options, this can be configured in the .charts/values.yaml using the the `JAVA_JVM_ARGS` environment configuration.

The `JAVA_JVM_ARGS` configuration is set to `-DLog4jContextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector -XX:MaxRAMPercentage=75` by default to make all loggers asynchronous and sets percentage of RAM available for heap to 75% (default is 25%).

If you experience issues with the `Log4jContextSelector` option, remove it and use the mixed approach documented on the [log4j site](https://logging.apache.org/log4j/2.x/manual/async.html).

To add extra parameters, new lines can be added below the configuration (UseG1GC for example is shown below) :

Please see [go/jvm-config](https://go/jvm-config) for more information on essential JVM configurations.

```yaml
app-service:
  deployment:
    env:
      JAVA_JVM_ARGS: >-
        -DLog4jContextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector
        -XX:InitialRAMPercentage=75.0
        -XX:MaxRAMPercentage=75.0
        -XX:+UseG1GC
```

Note the `-XX:+UseContainerSupport` option is required for `MaxRAMPercentage` to work. This option is now enabled by default (OpenJDK 8u191+) on Linux/Mac. This option uses the cgroups configuration for memory and cpu from the container if your application is running in one. Setting -Xmx and -Xms disables the automatic heap sizing provided by `-XX:+UseContainerSupport`.

If you wish to test these in your local environment, you will need to pass the parameters to Maven, the Java command line or to the Dockerfile manually by setting the JAVA_JVM_ARGS environment variable. The values in the YAML configuration will only be used for deployments.

## Configuring Renovate
[Renovate](https://renovate.whitesourcesoftware.com/) is a powerful, automatic dependency management tool that helps developers keep their libraries up to date with the latest fixes and features.
You should consider on-boarding and configuring your app with renovate.  

By default, ```renovate.json``` is added to the generated app. Please refer to the [documentation](https://pages.github.expedia.biz/stark/info/guide/tools/renovate) for further steps required to get Renovate working for your app.

## Release
TODO

## DevOps and observability

### Actuator paths
Your Spring application uses following actuator endpoints to provide observability endpoints (in the test env):

* [Health](https://ord-ordering-service.rcp.us-west-2.orders.test.exp-aws.net/actuator/health)
* [Info](https://ord-ordering-service.rcp.us-west-2.orders.test.exp-aws.net/actuator/info)
* [Metrics](https://ord-ordering-service.rcp.us-west-2.orders.test.exp-aws.net/actuator/metrics)
* [Prometheus](https://ord-ordering-service.rcp.us-west-2.orders.test.exp-aws.net/actuator/prometheus)

### Splunk logs:
* [Test](https://splunk.test.egmonitoring.expedia.com/en-US/app/search/search?q=search%20index%3Dapp%20sourcetype%3D%22kube%3Acontainer%3Aord-ordering-service*%22%20earliest%3D-15m)
* [Production](https://splunk.prod.egmonitoring.expedia.com/en-US/app/search/search?q=search%20index%3Dapp%20sourcetype%3D%22kube%3Acontainer%3Aord-ordering-service*%22%20earliest%3D-15m)
* [Production-PCI](https://splunk.prodp.egmonitoring.expedia.com/en-US/app/search/search?q=search%20index%3Dapp%20sourcetype%3D%22kube%3Acontainer%3Aord-ordering-service*%22%20earliest%3D-15m)

### Metrics:
* [Grafana - Test](https://grafana.sea.corp.expecn.com/d/Tn394P5Zz/jvm-micrometer?orgId=1&refresh=30s&from=now-24h&to=now&var-application=ord-ordering-service&var-jvm_memory_pool_heap=All&var-jvm_memory_pool_nonheap=All)
* [Grafana - Prod](https://grafana.sea.corp.expecn.com/d/Tn394P5Zz/jvm-micrometer?orgId=1&refresh=30s&from=now-24h&to=now&var-application=ord-ordering-service&var-jvm_memory_pool_heap=All&var-jvm_memory_pool_nonheap=All)

### Distributed Traces
* [Haystack - Test](https://bex.haystack.exp-test.net/search?serviceName=ord-ordering-service&tabId=trends&time.preset=15m)
* [Haystack - Prod](https://bex.haystack.exp-prod.net/search?serviceName=ord-ordering-service&tabId=trends&time.preset=15m)
