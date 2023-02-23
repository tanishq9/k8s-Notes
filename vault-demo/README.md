### Vault Installation

Install Vault via Helm Chart:

- helm repo add hashicorp https://helm.releases.hashicorp.com
- helm install vault --set ui.enabled=true --set ui.serviceType=NodePort --set server.dataStorage.enabled=false hashicorp/vault --version 0.16.1

Check Vault status:

- kubectl exec -it vault-0 -- vault status


### Vault Initialisation

When a vault server is started, it starts in a sealed state.

Unsealing Vault:

- kubectl exec -it vault-0 -- /bin/sh
- vault operator unseal <unseal-key>; these ’n’ number of unseal-keys would together form the master key, which is used to protect the encryption key, which is further used to protect data present in vault.
- vault login <root-token>; this is the root token generated after vault was unsealed.


### Vault Secret Engines

- Secret engines are vault components which store, generate or encrypt secrets.
- There are different type of secret engines - key-value, certificates, etc.
- Enable kv (key value) secret engine at crds path.
```
vault secrets enable -path=crds kv-v2
```
- Put key-value creds
```
vault kv put crds/mysql username=root
```
- Get kv creds
```
vault kv get crds/mysql
```

### Vault Authorization

- Authorization policy in Vault control what a user/machine can access. 
- A vault token is assigned with a set of policies, which decided what a user having this token can do within the vault.

Everything a user can access is in terms of path i.e. policy would tell at what paths the user can do what. Example policy:

```
path "crds/data/mongodb" {
capabilities = ["create", "update", "read"]
}

path "crds/data/mysql" {
capabilities = ["read"]
}
```

Create policy, lets say using above file^

- vault policy write app <file-name>.hcl

Read policy:

- vault policy read app

Vault CLI reads the token from VAULT_TOKEN env variable, this token is attached to a policy.

- export VAULT_TOKEN="$(vault token create -field token -policy=app)"


### Vault Authentication

- Process by which a user/machine gets a Vault token.
- We use /config endpoint to configure Vault to talk to k8s, we mention k8s cluster info here such as host and crt.
- We create role -- it uses app service account name (example) within the demo namespace (example) and it gives the app policy which we created in the previous step.
- Auth method of Vault accesses k8s token review api to validate the provided JWT is still valid, the vault service account used in this auth method will need to have access to the token review API, if k8s is configured to use the rbac role, the vault service account should be granted permissions to access this token review api. 
    - After enabling this using clusterrolebinding, the vault will be able to authenticate with k8s and would generate a vault token which will be used by the k8s pod to pull secrets from vault.


### Vault Annotations

Annotations are of 2 types - Agent and Vault annotation.

Agent annotation allow user to define what secret they want and how to render them.

- agent-inject: configures whether injection is explicitly enabled or disabled for a pod, default is false.
- agent-inject-status: this will block further mutations by adding the value injected to the pod after a successful mutation, we can use update if we want to allow mutations.
- agent-inject-secret: this configures vault agent to retrieve secret from Vault required by the container, the name of the secret is any unique string after agent-inject-secret- and the value is the path in Vault where the secret is stored.
- agent-inject-template: this configures the template vault agent should use for rendering a secret. The name of the template is any unique string after agent-inject-template- however it should be the same as what is provided in agent-inject-secret-.
- role: configures the vault role used by vault agent for authnz.

Vault annotation change how vault agent connector communicate with Vault such as Vault address, TLS certificate to use, etc.


### How Vault works internally?

- Recommendation is to install vault via helm chart - download is locally first so as to version control it further.
    - It launches 2 pods - vault-0 and vault-agent-injector.
    - Admin or vault user can exec in vault-0 pod to init the vault, add secrets, define policies and configure authentication.
    - The vault-agent-injector pod is k8s mutation webhook controller, the controller intercepts pod events and applies mutation to pod if annotation exist within the request.

- Apply the vault related annotations to the pod object.
    - This will be intercepted by vault-agent-injector, which will invoke mutation admission controller and then inject the init and sidecar containers. 
    - The init container will pre-populate the shared memory volume with the requested secrets prior to the other container starting and the sidecar container which is the vault-agent container will continue to authenticate and render secrets to same location as the pod runs.

- But how do the vault container fetch secret from the vault server? As per logs of vault init container:
    - Init container initially tries to authenticate with the vault server. 
        - The primary method of authentication with vault is the svc account attached to the pod.
        - This svc account tells what policy is there corresponding to the svc account name and namespace and provides token with that level of access for secrets.
    - Init container is going to send JWT to Vault for authentication, Vault now would validate this pod svc account JWT.
    - For accessing the k8s token review api from vault (to validate pod JWT), the vault's svc account needs to have access to this review api, once this token review api request has been sent, this api will respond with status as authenticated and details like svc account name and namespace.
    - Once authenticated, Vault will generate a vault access token (after matching svc account name and namespace with be matched with authorization policy) and return it to init container.
    - The token is stored in /home/vault/.vault-token in init container.
    - Init container will request Vault server for the secret and pass in the auth token (which it received in previous call).
    - Vault will match auth token with policy for specific secrets and then secrets are returned to init container.
    - The init container will store the secret in an empty directory volume which is shared among all 3 containers within the pod.
    
<img width="1053" alt="Screenshot 2023-02-24 at 2 34 06 AM" src="https://user-images.githubusercontent.com/35667308/221030531-4419b1b5-f96d-413b-9a52-05eea4f1aa84.png">

   
 
