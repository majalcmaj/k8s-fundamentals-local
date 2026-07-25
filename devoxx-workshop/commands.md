curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

docker pull odavid/my-bloody-jenkins

kubectl -n geraltofrivia get secret geraltofrivia-secret -o=jsonpath='{.items[0].data.token}' | base64 -d

kubectl -n geralt create secret docker-registry dockercreds --docker-server=docker.io --docker-username=itechartpoland --docker-password=<token>
