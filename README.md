# Socure Helmfile

Deploys Socure Application stack into Kubernetes

## About

Socure Helmfile uses [helmfile](https://github.com/roboll/helmfile) as a declarative spec for deploying [helm](https://github.com/helm/helm) charts, specifically [socure-helm], a shared helm chart for Socure services. Socure helmfile uses a hierachical value system to maximize consistency and DRY-ness across all environments, namespaces, and applications. Secret values are [SOPS](https://github.com/mozilla/sops)-encrypted values leveraging AWS KMS keys with supporting roles/policies for access control.

Socure helmfile runs concurrently across all releases to vastly improve time to deploy. If certain applications must come up before others helmfile has the capability to depend on certain applications as well.

## Usage

How do I make this thing work?

### Dependancies - Mac OS

```
# helm3 not helm2
brew install helm
brew install helmfile
brew install gnu-getopt
brew install sops
helm plugin install https://github.com/futuresimple/helm-secrets
helm plugin install https://github.com/databus23/helm-diff --version master
```

### Examples

To view a diff for a particulare namespace in a particular environment with minimal text:
```
helmfile -e staging -n namespace0 diff --context 2
```

To apply changes:
```
helmfile -e staging -n namespace0 sync
```

To deploy a single app:
```
helmfile -e staging -n namespace0 -l name=foo0 sync
```

Override value defaults:
```
helmfile -e staging -n namespace0 sync --set service.enabled=true
```

## Repo Structure

### helmfile.yaml

The base helmfile that describes exactly what Socure Helmfile does.

### Socure Helm

socure-helm will be the library helm chart that deploys all our releases into a Kubernetes cluster. For now it will be part of this helmfile repository, but in the future this chart can be broken out and controlled in a much tigher manner. This will allow DevOps to primarily own the helm chart itself and let developers own their values and secrets.

### Values

Similarly to [helm templates](https://helm.sh/docs/chart_template_guide/), helmfile supports values files appended with `.gotmpl` to be parsed as yaml-rendering [golang templates](https://golang.org/pkg/text/template/) with included support for [Sprig templating functions](https://masterminds.github.io/sprig/).
Values files support a merged inheritance in the following order:

```
- ../values/base.yaml.gotmpl
- ../values/{{ .Release.Name }}.yaml.gotmpl
- ../values/{{ .Environment.Name }}/base.yaml.gotmpl
- ../values/{{ .Environment.Name }}/{{ .Release.Name }}.yaml.gotmpl
- ../values/{{ .Environment.Name }}/{{ .Namespace }}/base.yaml.gotmpl  # optional
- ../values/{{ .Environment.Name }}/{{ .Namespace }}/{{ .Release.Name }}.yaml.gotmpl  # optional
```

As a best practice, you should try to write relevant values that apply to multiple services as a templated pattern in a shared inheritance level, than declaring multiple versions in more specific levels.

Good:

```
./values/base.yaml.gotmpl:  DB_NAME: "{{ printf "%s_%s_%s" .Namespace .Release.Name .Environment.Name | replace "-" "_" }}"
```

Bad:

```
./values/staging/foo0.yaml.gotmpl:  DB_NAME: "namespace0_foo0_staging"
./values/staging/foo1.yaml.gotmpl:  DB_NAME: "namespace0_foo1_staging"
./values/qa/foo0.yaml.gotmpl:  DB_NAME: "qa0_foo0_qa"
./values/qa/foo1.yaml.gotmpl:  DB_NAME: "qa0_foo1_qa"
...
```

### Secrets

Secrets follow the same merged inheritance order as _Values_ but must be decrypted before editing. The _Secrets_ files are where usernames, passwords, and other sensitive data should be kept. Note that secrets are plain yaml and not go templates.

```
- ../secrets/base.yaml
- ../secrets/{{ .Environment.Name }}/base.yaml
- ../secrets/{{ .Environment.Name }}/{{ .Release.Name }}.yaml
- ../secrets/{{ .Environment.Name }}/{{ .Namespace }}/base.yaml
- ../secrets/{{ .Environment.Name }}/{{ .Namespace }}/{{ .Release.Name }}.yaml
```
