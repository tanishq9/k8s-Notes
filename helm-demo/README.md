## Helm

### Introduction

- Helm - Package manger for k8s.
- https://helm.sh/
- https://artifacthub.io/packages/helm/bitnami/mysql
```
$ helm repo add my-repo https://charts.bitnami.com/bitnami
$ helm install my-release my-repo/mysql
```
- Creating your own helm chart is the real value of helm.

- To view pod in all namespaces:
```
kubectl get pod --all-namespaces
```
- To view all resources (workload) in all namespaces:
```
kubectl get all --all-namespaces
```
- To list all helm charts:
```
helm list
```
- To list all helm repos:
```
helm repo list
```
- To install and uninstall chart:
```
helm install <release-name> <repo-name>/<helm-chart>
helm uninstall <release-name>
```
Example:
```
helm install prom-stack prom-repo/kube-prometheus-stack
helm uninstall prom-stack
```

Note:
k8s monitoring solution:
- Use Prometheus to gather data from nodes.
- Use Grafana as frontend, which will give nice graphical charts to visualise the data.
- We would need an alert manager as well.

Any chart that we use is going to have a configuration and that is called values in helm chart.


For any chart that has been published, we can do:
- helm show values <repo-name>/<helm-chart>

Example:
```
helm show values prom-repo/kube-prometheus-stack
https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack
```
- Helm recognises this values.yaml file and uses this to set up the pods, the services and so on.
- We can use helm as a generator to generate k8s yaml using the values.yaml file.

- To upgrade/update some value in values.yaml for helm chart, we can do:

```
helm upgrade <release-name> <repo-name>/<helm-chart-name>
```
Example:
```
helm upgrade prom-stack prom-repo/kube-prometheus-stack --set grafana.adminPassword=admin
```

- If we do helm list we can see the revision being incremented by 1 after doing the above upgrade.

### Configuring Helm Chart

If we want to configure a chart, there are 2 main ways:
- Refer user guide for that chart (if the devs have been conscientious enough of providing one). Like: https://github.com/grafana/helm-charts/tree/main/charts/grafana
- Look at the implementation of chart.

To upgrade helm release using values.yaml file: helm upgrade prom-stack prom-repo/kube-prometheus-stack --values=values-promstack.yaml

1. helm install prom-stack prom-repo/kube-prometheus-stack # To create helm release
2. helm show values prom-repo/kube-prometheus-stack # To show values of helm chart the release is made using

Save above output in some file like values-promstack.yaml and update the desired values. Then upgrade the helm release using that.

3. helm upgrade prom-stack prom-repo/kube-prometheus-stack --values=values-promstack.yaml # To upgrade helm release
4. helm list # To check if revision has increased for the helm release

Note:
- Phoenix server: If you wanna put something on the server, you can't without upgrading the script. This means entire configuration of server is kept in a file and is stored in source control. This is a standard good practice and would help to replicate/create similar server. We need to take control of the yaml for any helm chart that we are using. Its not advisable to install any helm charts from any remote repo in production cluster as it can happen that repo cease to exist after few days or we install any upgrades to cluster NOT via source control, we would end  up with a snowflake cluster having no idea how the server was configured.

### Helm Pull

- values.yaml - Used to configure and tune any particular charts.

helm pull <repo-name>/<helm-chart-name> --untar=true
^ pull is used to download any helm chart source code.

- Example: helm pull prom-repo/kube-prometheus-stack --untar=true
- helm install prom-stack ./kube-prometheus-stack

^Install/creating helm release using helm chart present in local system at ./kube-prometheus-stack path.

Note:
- --values=myvalues.yaml
- All values in values.yaml are going to be used unless there is an override in myvalues.yaml, similar analogy to application.yaml and application-{env}.yaml file.

### Generating Yaml with Helm Template

- Sometimes we don't have helm present on the cluster and just want the k8s yaml file as the source then we can download k8s yaml files corresponding to the helm charts using helm template command, for example:
- helm template <release-name> <path-to-helm-chart> --values=override-values.yaml
- The above command would generate the yaml and prints that to the console, it won't apply it to the cluster. The same yaml was applied to cluster when we did helm upgrade.

Note:
- We can either make the source code for chart as the single source of truth or we can use this generated yaml as single source of truth (lots of code to maintain, rather make it abstract using values.yaml and go for helm chart approach).

### Writing Go Templates with Helm

- Helm was originally designed as package manager which would enable projects to package their k8s yaml and broadcast to a large number of users.
- Helm's feature of template processing is very useful to projects that don't need to package up and broadcast their software.
- Benefit of converting yaml to helm chart - All of the k8s yaml can become dynamic/configurable and by dynamic, it means we can configure it using variables.
- https://github.com/DickChesterwood/k8s-fleetman/tree/master/_course_files/MacARM64Edition/Going%20Further%20with%20Kubernetes/Helm

### Standard Helm Chart

Fields in Chart.yaml:
- version: version of helm chart, expected to follow semantic versioning.
- appVersion: app version, not relevant to end users.
- type: application or library, library charts can't be deployed and are used as dependency to application type charts. Library charts do not define any templates and therefore cannot be deployed.

templates folder:
- Any yaml file inside this template folder is going to be send through a text processor and generate a k8s yaml.
- helm template .  --> The above command would generate the yaml and prints that to the console, execute this command in directory where chart is present.

### Helm Function and Pipelines

- https://helm.sh/docs/chart_template_guide/functions_and_pipelines/
- Function calling template:
 
<Function_Name><space><List_Of_Parameters>
```
Example: {{ lower .Values.dockerRepoName }}
```
- Pipeline syntax:
- We are taking the result in each step and passing it in as a parameter into the next function.
```
{{ .Values.dockerRepoName | default "DefaultRepo" | upper }}
```

### Flow Control in Helm Template

- if env is dev then append -dev in image name, if not then do nothing:
```
image: {{ .Values.dockerRepoName | default "DefaultRepo" | upper }}/k8s-fleetman-helm-demo:v1.0.0{{ if eq .Values.env "dev"}}-dev{{ end }}
```

Exploring more syntax:
```
k8s-fleetman-helm-demo:v1.0.0{{ if .Values.development }}-dev{{ end }}

k8s-fleetman-helm-demo:v1.0.0{{ if .Values.development }}-dev{{ else }}-prod{{ end }}

k8s-fleetman-helm-demo:v1.0.0{{ if .Values.development }}-dev{{ else if eq .Values.development false }}-prod{{ end }}
```

### Named Templates

- If we prepend _ in the filename inside templates folder then that file won't be considered while generating the yaml.
- For the above files, we can use any extension, however there is a convention to use .tpl
- We use define function to declare a named template.
```
# Named template called webAppImage
{{ define "webAppImage" }}
- name: webapp
  image: {{ .Values.dockerRepoName | default "DefaultRepo" | upper }}/k8s-fleetman-helm-demo:v1.0.0{{ if .Values.development }}-dev{{ else if eq .Values.development false }}-prod{{ end }}
{{ end }}
```
```
spec:
      containers:
      # . is to tell variable path in the named template, . means the variables in webAppImage start from .Values, mainly we use .
      # inplace of template, we could have used include as well, both are used to import named template
      # - is added to remove whitespace like new line, which is left after evalution of go expression, fyi result of expression is posted underneath
      {{- template "webAppImage" . }}
```

- The position of {{- template "webAppImage" . }} is irrelevant, it position doesn't dictate where the values corresponding to this named template has to be placed, it is as good as on the extreme left as on the extreme right as it doesn't dictate the position of the value.
- What dictates the position of value is actually the user that how deep they want it to be nested by using indent function, ideally we shouldn't have spaces/indents in the named template.

Like:  {{- include "webAppImage" . | indent 6 }}

- In place of template, we could have used include as well, both are used to import named template. In include, we can use it in pipeline but not in template.
