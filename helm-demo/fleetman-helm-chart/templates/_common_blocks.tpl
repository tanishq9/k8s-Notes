# Named template called webAppImage
{{ define "webAppImage" }}
- name: webapp
  image: {{ .Values.dockerRepoName | default "DefaultRepo" | lower }}/k8s-fleetman-helm-demo:v1.0.0{{ if .Values.development }}-dev{{ end }}
{{ end }}
