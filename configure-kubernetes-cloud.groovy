import jenkins.model.*
import org.csanchez.jenkins.plugins.kubernetes.*
import org.csanchez.jenkins.plugins.kubernetes.volumes.*

def jenkins = Jenkins.getInstance()

// Create Kubernetes cloud configuration
def kubernetesCloud = new KubernetesCloud("kubernetes")

// Set Kubernetes URL (from inside cluster)
kubernetesCloud.setServerUrl("https://kubernetes.default.svc.cluster.local")

// Set namespace
kubernetesCloud.setNamespace("jenkins")

// Set Jenkins URL (for agent connection)
kubernetesCloud.setJenkinsUrl("http://jenkins.jenkins.svc.cluster.local:8080")

// Set Jenkins tunnel (for JNLP connection)
kubernetesCloud.setJenkinsTunnel("jenkins.jenkins.svc.cluster.local:50000")

// Set connection timeout
kubernetesCloud.setConnectionTimeout(300)
kubernetesCloud.setReadTimeout(300)

// Set max connections
kubernetesCloud.setMaxRequestsPerHost(32)

// Add the cloud to Jenkins
jenkins.clouds.replace(kubernetesCloud)

// Save configuration
jenkins.save()

println "✅ Kubernetes cloud configured successfully!"
println "Cloud name: kubernetes"
println "Server URL: https://kubernetes.default.svc.cluster.local"
println "Namespace: jenkins"
println "Jenkins URL: http://jenkins.jenkins.svc.cluster.local:8080"
