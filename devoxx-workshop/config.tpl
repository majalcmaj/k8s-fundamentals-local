security:
  realm: jenkins_database
  adminPassword: [ADMIN PASSWORD]

  remove_master_envvars:
  - '.*PASSWORD.*'

credentials:
  kubernetestoken:
    type: text
    text: [KUBERNETES TOKEN]

clouds:
  kube-cloud:
    ## Max connections to Kubernetes API (Default 32)
    maxRequestsPerHost: 32
    ## default is false
    directConnection: false
    ## Use WebSocket to connect agents rather than the TCP port. Default is false
    webSocket: false
    # type is mandatory
    type: kubernetes
    # Kubernetes URL
    serverUrl: https://10.10.10.11:6443
    skipTlsVerify: true
    # Default kubernetes namespace for slaves
    namespace: [YOUR USERNAME]
    # Pod templates
    credentialsId: kubernetestoken 
    templates:
      - name: kubeslave
        image: jenkins/inbound-agent:4.11-1-jdk11
        labels:
          - kubeslave
        resourceRequestMemory: 512Mi
        resourceRequestCpu: 500m
        resourceLimitCpu: 2000m
        resourceLimitMemory: 4096Mi
        yaml: |-
          apiVersion: v1
          kind: Pod
          spec:
            volumes:
            - name: docker-socket
              emptyDir: {}
            - name: docker-credentials
              secret:
                secretName: dockercreds
            containers:
            - name: builder
              image: docker:20.10.19
              tty: true
              stdin: true
              command:
              - sleep
              args:
              - 99d
              volumeMounts:
              - name: docker-socket
                mountPath: /var/run
              - name: docker-credentials
                mountPath: /root/.docker
            - name: docker-daemon
              image: docker:dind
              securityContext:
                privileged: true
              volumeMounts:
              - name: docker-socket
                mountPath: /var/run
