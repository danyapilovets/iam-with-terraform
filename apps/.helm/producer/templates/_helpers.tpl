{{/* Helm template helper */}}
{{- define "producer.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "producer.fullname" -}}
{{- printf "%s" .Chart.Name -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "producer.labels" -}}
helm.sh/chart: {{ include "producer.chart" . }}
{{ include "producer.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "producer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "producer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "producer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }} 