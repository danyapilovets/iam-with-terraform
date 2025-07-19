{{/* Helm template helper */}}
{{- define "producer.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "producer.fullname" -}}
{{- printf "%s" .Chart.Name -}}
{{- end -}} 